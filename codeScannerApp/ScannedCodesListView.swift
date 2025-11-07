import SwiftUI
import CoreData

struct ScannedCodesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ScannedCode.scanDate, ascending: false)],
        animation: .default)
    private var scannedCodes: FetchedResults<ScannedCode>
    
    @State private var showingScanner = false
    @State private var selectedCode: ScannedCode?
    @State private var showingEditName = false
    @State private var editingCode: ScannedCode?
    @State private var newName = ""
    @StateObject private var scannerViewModel = ScannerViewModel()
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if scannedCodes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("Нет отсканированных кодов")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Нажмите кнопку сканирования, чтобы добавить первый код")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(scannedCodes) { code in
                            ScannedCodeRowView(
                                code: code,
                                onTap: { selectedCode = code },
                                onRename: {
                                    editingCode = code
                                    newName = code.customName ?? ""
                                    showingEditName = true
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Удалить", role: .destructive) {
                                    deleteCode(code)
                                }
                                
                                Button("Переименовать") {
                                    editingCode = code
                                    newName = code.customName ?? ""
                                    showingEditName = true
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Коды")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                CodeScannerView()
                    .environmentObject(scannerViewModel)
                    .onDisappear {
                        // Очистка состояния сканера при закрытии
                        scannerViewModel.lastScannedCodeObject = nil
                    }
            }
            .sheet(item: $selectedCode) { code in
                NavigationView {
                    CodeDetailView(code: code)
                        .onDisappear {
                            // Очистка selectedCode при закрытии
                            selectedCode = nil
                        }
                }
            }
            .onChange(of: scannerViewModel.lastScannedCodeObject) { newCode in
                if let code = newCode {
                    showingScanner = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        selectedCode = code
                        // Очистка ссылки после открытия для оптимизации
                        scannerViewModel.lastScannedCodeObject = nil
                    }
                }
            }
            .alert("Переименовать код", isPresented: $showingEditName) {
                TextField("Название", text: $newName)
                Button("Сохранить") {
                    if let code = editingCode {
                        updateCodeName(code, newName: newName.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Введите новое название для кода")
            }
            .alert("Ошибка", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }
    
    private func deleteCode(_ code: ScannedCode) {
        withAnimation {
            viewContext.delete(code)
            
            do {
                try viewContext.save()
            } catch {
                deleteErrorMessage = "Не удалось удалить код: \(error.localizedDescription)"
                showDeleteError = true
            }
        }
    }
    
    private func updateCodeName(_ code: ScannedCode, newName: String) {
        code.customName = newName.isEmpty ? nil : newName
        
        do {
            try viewContext.save()
        } catch {
            deleteErrorMessage = "Не удалось обновить название: \(error.localizedDescription)"
            showDeleteError = true
        }
    }
}

struct ScannedCodeRowView: View {
    let code: ScannedCode
    let onTap: () -> Void
    let onRename: () -> Void
    
    var body: some View {
        HStack {
            VStack {
                Image(systemName: codeTypeIcon)
                    .font(.title2)
                    .foregroundColor(codeTypeColor)
                
                Text(code.codeType ?? "Неизвестно")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(code.codeValue ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text("Отсканировано: \(formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            Button(action: onRename) {
                Image(systemName: "square.and.pencil")
                    .font(.body)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.trailing, 6)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private var displayName: String {
        if let customName = code.customName, !customName.isEmpty {
            return customName
        } else if let productName = code.productName, !productName.isEmpty {
            return productName
        } else {
            return "Код \(code.codeType ?? "неизвестного типа")"
        }
    }
    
    private var codeTypeIcon: String {
        switch code.codeType {
        case "Штрих-код":
            return "barcode"
        case "QR-код":
            return "qrcode"
        default:
            return "questionmark.square"
        }
    }
    
    private var codeTypeColor: Color {
        switch code.codeType {
        case "Штрих-код":
            return .blue
        case "QR-код":
            return .green
        default:
            return .gray
        }
    }
    
    private var formattedDate: String {
        guard let date = code.scanDate else { return "Неизвестно" }
        return Self.dateFormatter.string(from: date)
    }
}

#Preview {
    ScannedCodesListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

private extension ScannedCodeRowView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
