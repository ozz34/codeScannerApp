import SwiftUI

struct CodeDetailView: View {
    let code: ScannedCode
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: codeTypeIcon)
                                .font(.title)
                                .foregroundColor(codeTypeColor)
                            
                            VStack(alignment: .leading) {
                                Text(code.codeType ?? "Неизвестный тип")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Отсканировано: \(formattedDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Основная информация о коде
                    VStack(alignment: .leading, spacing: 16) {
                        InfoSection(title: "Значение кода", content: code.codeValue ?? "Неизвестно")
                        
                        if let customName = code.customName, !customName.isEmpty {
                            InfoSection(title: "Название", content: customName)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Информация о продукте (штрих-коды)
                    if code.codeType == "Штрих-код" {
                        ProductInfoSection(code: code)
                    }
                    
                    // MARK: - Обработка QR-кодов
                    if code.codeType == "QR-код", let content = code.rawContent {
                        QRCodeContentSection(content: content)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Детали кода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareContent)
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
    
    // MARK: - Функциональность шаринга
    private var shareContent: [Any] {
        var content = "Отсканированный код:\n"
        content += "Тип: \(code.codeType ?? "Неизвестно")\n"
        content += "Значение: \(code.codeValue ?? "")\n"
        content += "Дата: \(formattedDate)\n"
        
        if let customName = code.customName, !customName.isEmpty {
            content += "Название: \(customName)\n"
        }
        
        if let productName = code.productName, !productName.isEmpty {
            content += "Продукт: \(productName)\n"
        }
        
        if let brand = code.brand, !brand.isEmpty {
            content += "Бренд: \(brand)\n"
        }
        
        if let ingredients = code.ingredients, !ingredients.isEmpty {
            content += "Ингредиенты: \(ingredients)\n"
        }
        
        if let nutriScore = code.nutriScore, !nutriScore.isEmpty {
            content += "Nutri-Score: \(nutriScore)\n"
        }
        
        return [content]
    }
}

private extension CodeDetailView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Секция с информацией о продукте
struct ProductInfoSection: View {
    let code: ScannedCode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Информация о продукте")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                if let productName = code.productName, !productName.isEmpty {
                    InfoSection(title: "Название продукта", content: productName)
                }
                
                if let brand = code.brand, !brand.isEmpty {
                    InfoSection(title: "Бренд", content: brand)
                }
                
                if let ingredients = code.ingredients, !ingredients.isEmpty {
                    InfoSection(title: "Ингредиенты", content: ingredients)
                }
                
                if let nutriScore = code.nutriScore, !nutriScore.isEmpty {
                    NutriScoreSection(score: nutriScore)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Секция для содержимого QR-кода
struct QRCodeContentSection: View {
    let content: String
    @State private var isLink = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Содержимое QR-кода")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoSection(title: "Содержимое", content: content)
                
                // MARK: - Опциональная функция открытия ссылки
                if isLink {
                    Button(action: openLink) {
                        HStack {
                            Image(systemName: "link")
                            Text("Открыть ссылку")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            checkIfLink()
        }
    }
    
    private func checkIfLink() {
        if let url = URL(string: content), 
           ["http", "https"].contains(url.scheme?.lowercased()) {
            isLink = true
        }
    }
    
    private func openLink() {
        if let url = URL(string: content) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Секция с Nutri-Score
struct NutriScoreSection: View {
    let score: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutri-Score")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text(score.uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(nutriScoreColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(nutriScoreDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    private var nutriScoreColor: Color {
        switch score.lowercased() {
        case "a":
            return .green
        case "b":
            return .green.opacity(0.7)
        case "c":
            return .yellow
        case "d":
            return .orange
        case "e":
            return .red
        default:
            return .gray
        }
    }
    
    private var nutriScoreDescription: String {
        switch score.lowercased() {
        case "a":
            return "Отличное качество питания"
        case "b":
            return "Хорошее качество питания"
        case "c":
            return "Среднее качество питания"
        case "d":
            return "Плохое качество питания"
        case "e":
            return "Очень плохое качество питания"
        default:
            return "Неизвестный рейтинг"
        }
    }
}

struct InfoSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let code = ScannedCode(context: context)
    code.id = UUID()
    code.codeValue = "1234567890123"
    code.codeType = "Штрих-код"
    code.scanDate = Date()
    code.productName = "Тестовый продукт"
    code.brand = "Тестовый бренд"
    code.ingredients = "Тестовые ингредиенты"
    code.nutriScore = "A"
    
    return CodeDetailView(code: code)
}
