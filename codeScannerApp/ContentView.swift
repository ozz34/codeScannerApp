import SwiftUI

struct ContentView: View {
    var body: some View {
        ScannedCodesListView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
