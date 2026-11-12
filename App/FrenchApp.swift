import SwiftUI

@main
struct FrenchApp: App {
    @State private var library = Library()
    @State private var store = Store()
    @State private var speech = Speech()
    @State private var navigator = Navigator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(store)
                .environment(speech)
                .environment(navigator)
        }
    }
}
