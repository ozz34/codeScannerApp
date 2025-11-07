import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        let sampleCode1 = ScannedCode(context: viewContext)
        sampleCode1.id = UUID()
        sampleCode1.codeValue = "1234567890123"
        sampleCode1.codeType = "Штрих-код"
        sampleCode1.scanDate = Date()
        sampleCode1.productName = "Тестовый продукт"
        sampleCode1.brand = "Тестовый бренд"
        sampleCode1.ingredients = "Тестовые ингредиенты"
        sampleCode1.nutriScore = "A"
        
        let sampleCode2 = ScannedCode(context: viewContext)
        sampleCode2.id = UUID()
        sampleCode2.codeValue = "https://example.com"
        sampleCode2.codeType = "QR-код"
        sampleCode2.scanDate = Date().addingTimeInterval(-3600)
        sampleCode2.rawContent = "https://example.com"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "codeScannerApp")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
