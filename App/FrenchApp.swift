import SwiftUI

@main
struct FrenchApp: App {
    @State private var library = Result { try Library() }
    @State private var store = Store()
    @State private var speech = Speech()
    @State private var navigator = Navigator()

    init() {
        Theme.applyToNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch library {
                case .success(let library):
                    RootView()
                        .environment(library)
                        .environment(speech)
                        .environment(navigator)
                case .failure(let error):
                    LaunchErrorView(error: error) { library = Result { try Library() } }
                }
            }
            .environment(store)
            .font(Theme.body)
            .tint(Theme.acc)
            // The design has one theme.
            .preferredColorScheme(.dark)
        }
    }
}
