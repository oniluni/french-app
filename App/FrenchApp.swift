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
                // UI tests ask for dark mode this way: the simulator ignores XCUIDevice.appearance.
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-uitest-dark") ? .dark : nil)
        }
    }
}
