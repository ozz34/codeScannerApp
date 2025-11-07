import SwiftUI
import AVFoundation
import UIKit

struct CodeScannerView: View {
    @EnvironmentObject var viewModel: ScannerViewModel
    @State private var isTorchOn = false
    @State private var scannerSession: AVCaptureSession?
    @State private var metadataOutput: AVCaptureMetadataOutput?
    @State private var scannerDelegate: CodeScannerDelegate?
    
    private let scanFrameWidth: CGFloat = 280
    private let scanFrameHeight: CGFloat = 200
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                ZStack {
                    // Затемненная область вокруг области камеры
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: scanFrameWidth, height: scanFrameHeight)
                                .blendMode(.destinationOut)
                        )
                    
                    CameraPreviewWrapper(session: scannerSession, metadataOutput: metadataOutput)
                        .frame(width: scanFrameWidth, height: scanFrameHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Рамка прямоугольника
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: scanFrameWidth, height: scanFrameHeight)
                }
                .frame(width: 320, height: 240)
                
                Spacer()
                
                VStack(spacing: 20) {
                    Button(action: toggleTorch) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Наведите камеру на код")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .minimumScaleFactor(0.8)
                }
                .padding(.bottom, 60)
            }
            
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Получение информации о продукте...")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
            }
        }
        .task {
            let granted = await viewModel.checkCameraPermission()
            if granted { self.setupCamera() }
        }
        .onDisappear { stopCamera() }
        .alert("Ошибка", isPresented: $viewModel.showAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Разрешение на использование камеры", isPresented: $viewModel.showPermissionAlert) {
            Button("Настройки") { viewModel.openSettings() }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Для сканирования кодов необходимо разрешение на использование камеры. Пожалуйста, разрешите доступ в настройках.")
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            viewModel.handleError("Камера недоступна")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            viewModel.handleError("Ошибка инициализации камеры: \(error.localizedDescription)")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            viewModel.handleError("Не удалось добавить вход камеры")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            let delegate = CodeScannerDelegate(viewModel: viewModel)
            self.scannerDelegate = delegate
            metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
            
            scannerSession = session
            self.metadataOutput = metadataOutput
            
            Task(priority: .userInitiated) {
                session.startRunning()
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard session.isRunning else { return }
                await MainActor.run {
                    metadataOutput.metadataObjectTypes = Self.supportedMetadataTypes
                    metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
                }
            }
        } else {
            viewModel.handleError("Не удалось добавить выход метаданных")
            return
        }
    }
    
    private func stopCamera() {
        guard let session = scannerSession else { return }
        
        Task(priority: .userInitiated) { session.stopRunning() }
        
        scannerSession = nil
        metadataOutput = nil
    }
    
    private func toggleTorch() {
        guard let session = scannerSession,
              let device = session.inputs.first(where: { $0 is AVCaptureDeviceInput }) as? AVCaptureDeviceInput else {
            return
        }
        
        let captureDevice = device.device
        guard captureDevice.hasTorch else { return }
        
        do {
            try captureDevice.lockForConfiguration()
            if isTorchOn {
                captureDevice.torchMode = .off
            } else {
                try captureDevice.setTorchModeOn(level: 1.0)
            }
            captureDevice.unlockForConfiguration()
            isTorchOn.toggle()
        } catch {
            viewModel.handleError("Ошибка управления фонариком: \(error.localizedDescription)")
        }
    }
}

private extension CodeScannerView {
    static var supportedMetadataTypes: [AVMetadataObject.ObjectType] {
        return [.qr, .ean8, .ean13, .code128, .code39, .code93, .pdf417, .aztec, .dataMatrix]
    }
}


final class CodeScannerDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private let viewModel: ScannerViewModel
    private var lastScannedCode: String?
    private var lastScanTime: Date?
    
    init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !metadataObjects.isEmpty else { return }
        

        for metadataObject in metadataObjects {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
                continue
            }
            
            // Получаем строковое значение
            guard let stringValue = readableObject.stringValue,
                  !stringValue.isEmpty else {
                continue
            }
            
            // Защита от повторного сканирования того же кода 2 секунды
            let now = Date()
            if let lastCode = lastScannedCode, lastCode == stringValue,
               let lastTime = lastScanTime, now.timeIntervalSince(lastTime) < 2.0 {
                continue
            }
            
            lastScannedCode = stringValue
            lastScanTime = now
            
            // Тип кода
            let codeType: CodeType
            switch metadataObject.type {
            case .ean8, .ean13, .pdf417, .code128, .code39, .code93, .interleaved2of5, .itf14:
                codeType = .barcode
            case .qr, .aztec, .dataMatrix:
                codeType = .qrCode
            default:
                codeType = .unknown
            }
            
            // Обрабатываем код на главном акторе (UI)
            Task { [weak self] in
                guard let self else { return }
                await self.viewModel.processScannedCode(stringValue, type: codeType)
            }
            break
        }
    }
}

struct CameraPreviewWrapper: UIViewRepresentable {
    let session: AVCaptureSession?
    let metadataOutput: AVCaptureMetadataOutput?
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.setSession(session, metadataOutput: metadataOutput)
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        
        if let metadataOutput = metadataOutput, let session = videoPreviewLayer.session, session.isRunning {
            configureScanArea(metadataOutput: metadataOutput)
        }
    }
    
    private var metadataOutput: AVCaptureMetadataOutput?
    
    func setSession(_ session: AVCaptureSession?, metadataOutput: AVCaptureMetadataOutput?) {
        self.metadataOutput = metadataOutput
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let session = session {
                self.videoPreviewLayer.session = session
                self.videoPreviewLayer.videoGravity = .resizeAspectFill
                
                if let metadataOutput = metadataOutput {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self.configureScanArea(metadataOutput: metadataOutput)
                }
            } else {
                self.videoPreviewLayer.session = nil
            }
        }
    }
    
    private func configureScanArea(metadataOutput: AVCaptureMetadataOutput) {
        let scanArea = CGRect(x: 0, y: 0, width: 1, height: 1)
        metadataOutput.rectOfInterest = scanArea
    }
}

