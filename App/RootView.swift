import FrenchCore
import SwiftUI

enum AppTab: Hashable {
    case lessons, practice, analysis, dictionary
}

/// Three tabs and a separate search button, each with its own navigation stack.
struct RootView: View {
    @State private var tab = AppTab.lessons
    @State private var query = ""

    var body: some View {
        TabView(selection: $tab) {
            Tab("Уроки", systemImage: "book", value: AppTab.lessons) {
                NavigationStack {
                    placeholder("Уроки появятся здесь").navigationTitle("Уроки")
                }
            }
            Tab("Практика", systemImage: "rectangle.on.rectangle.angled", value: AppTab.practice) {
                NavigationStack {
                    placeholder("Карточки и формы").navigationTitle("Практика")
                }
            }
            Tab("Разбор", systemImage: "text.magnifyingglass", value: AppTab.analysis) {
                NavigationStack {
                    placeholder(Markup.plain("le{s}‿[en]f[an](ts)")).navigationTitle("Разбор")
                }
            }
            Tab(value: AppTab.dictionary, role: .search) {
                NavigationStack {
                    placeholder(query.isEmpty ? "Все слова" : query).navigationTitle("Словарь")
                }
                .searchable(text: $query, prompt: "Слово или перевод")
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary)
    }
}
