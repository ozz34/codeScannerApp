import Foundation
import CoreData
import AVFoundation
import UIKit

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scannedCode: String = ""
    @Published var codeType: CodeType = .unknown
    @Published var productInfo: ProductInfo?
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var showPermissionAlert = false
    @Published var isLoading = false
    @Published var lastScannedCodeObject: ScannedCode?
    
    private let persistenceController = PersistenceController.shared
    
    
    func startScanning() {
        isScanning = true
        errorMessage = nil
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    func processScannedCode(_ code: String, type: CodeType) {
        scannedCode = code
        codeType = type
        
        if type == .barcode {
            Task { await fetchProductInfo(for: code) }
        } else {
            saveScannedCode(code: code, type: type, rawContent: code)
        }
    }
    
    private func fetchProductInfo(for barcode: String) async {
        isLoading = true
        
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            handleError("Неверный URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            handleProductResponse(response, barcode: barcode)
        } catch {
            isLoading = false
            saveScannedCode(code: barcode, type: .barcode, rawContent: barcode)
        }
    }
    
    private func handleProductResponse(_ response: OpenFoodFactsResponse, barcode: String) {
        isLoading = false
        
        if response.status == 1, let product = response.product {
            productInfo = ProductInfo(
                name: product.productName ?? "Неизвестный продукт",
                brand: product.brands ?? "",
                ingredients: product.ingredientsText ?? "",
                nutriScore: product.nutritionGrades ?? ""
            )
            
            // Сохраняем информацию о продукте, если он есть
            saveScannedCode(
                code: barcode,
                type: .barcode,
                rawContent: barcode,
                productInfo: productInfo
            )
        } else {
            // Продукта нет - сохраняем без информации о продукте
            saveScannedCode(code: barcode, type: .barcode, rawContent: barcode)
            
        }
    }
    
    private func saveScannedCode(
        code: String,
        type: CodeType,
        rawContent: String,
        productInfo: ProductInfo? = nil
    ) {
        let context = persistenceController.container.viewContext
        
        let fetchRequest: NSFetchRequest<ScannedCode> = ScannedCode.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "codeValue == %@", code)
        fetchRequest.fetchLimit = 1
        
        do {
            let existingCodes = try context.fetch(fetchRequest)
            if !existingCodes.isEmpty {
            self.lastScannedCodeObject = existingCodes.first
                return
            }
            
            let scannedCode = ScannedCode(context: context)
            scannedCode.id = UUID()
            scannedCode.codeValue = code
            scannedCode.codeType = type.rawValue
            scannedCode.scanDate = Date()
            scannedCode.rawContent = rawContent
            
            if let productInfo = productInfo {
                scannedCode.productName = productInfo.name
                scannedCode.brand = productInfo.brand
                scannedCode.ingredients = productInfo.ingredients
                scannedCode.nutriScore = productInfo.nutriScore
            }
            
            try context.save()
            
            // Сохраняем ссылку на последний отсканированный код
            self.lastScannedCodeObject = scannedCode
        } catch {
            handleError("Ошибка при сохранении: \(error.localizedDescription)")
        }
    }
    
    func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startScanning()
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            if granted { startScanning() } else { showPermissionAlert = true }
            return granted
        case .denied, .restricted:
            showPermissionAlert = true
            return false
        @unknown default:
            showPermissionAlert = true
            return false
        }
    }
    
    func handleError(_ message: String) {
        errorMessage = message
        showAlert = true
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

enum CodeType: String, CaseIterable {
    case barcode = "Штрих-код"
    case qrCode = "QR-код"
    case unknown = "Неизвестно"
}

struct ProductInfo {
    let name: String
    let brand: String
    let ingredients: String
    let nutriScore: String
}

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: Product?
}

struct Product: Codable {
    let productName: String?
    let brands: String?
    let ingredientsText: String?
    let nutritionGrades: String?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case ingredientsText = "ingredients_text"
        case nutritionGrades = "nutrition_grades"
    }
}
