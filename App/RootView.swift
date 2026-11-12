import FrenchCore
import Observation
import SwiftUI

enum AppTab: Hashable {
    case lessons, practice, analysis, dictionary
}

/// A screen pushed onto the stack of a tab.
enum Route: Hashable {
    case lesson(Int)
    case rule(String)
    /// Analysis of a word; the string is what the learner typed or tapped.
    case word(String)
}

/// Which tab is shown and what is pushed in each. Every tab keeps its own stack.
@MainActor
@Observable
final class Navigator {
    var tab = AppTab.lessons
    var paths: [AppTab: [Route]] = [:]

    func push(_ route: Route) {
        paths[tab, default: []].append(route)
    }

    func path(for tab: AppTab) -> Binding<[Route]> {
        Binding { self.paths[tab] ?? [] } set: { self.paths[tab] = $0 }
    }
}

/// Three tabs and a separate search button, as in the prototype.
struct RootView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Speech.self) private var speech
    @State private var query = ""

    var body: some View {
        @Bindable var navigator = navigator
        TabView(selection: $navigator.tab) {
            Tab("Уроки", systemImage: "book", value: AppTab.lessons) {
                stack(.lessons) { LessonsView() }
            }
            Tab("Практика", systemImage: "rectangle.on.rectangle.angled", value: AppTab.practice) {
                stack(.practice) { PracticeView() }
            }
            Tab("Разбор", systemImage: "text.magnifyingglass", value: AppTab.analysis) {
                stack(.analysis) { AnalysisView() }
            }
            Tab(value: AppTab.dictionary, role: .search) {
                stack(.dictionary) { DictionaryView(query: query) }
                    .searchable(text: $query, prompt: "Слово или перевод")
            }
        }
        .alert("Что-то пошло не так", isPresented: hasFailure) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(store.failure ?? speech.failure ?? "")
        }
    }

    private var hasFailure: Binding<Bool> {
        Binding { store.failure != nil || speech.failure != nil } set: { isShown in
            if !isShown {
                store.failure = nil
                speech.failure = nil
            }
        }
    }

    private func stack(_ tab: AppTab, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: navigator.path(for: tab)) {
            root().navigationDestination(for: Route.self) { route in
                switch route {
                case .lesson(let id):
                    if let lesson = library.lesson(id) {
                        LessonView(lesson: lesson)
                    } else {
                        ContentUnavailableView("Урок \(id) не найден", systemImage: "book.closed")
                    }
                case .rule(let id):
                    if let rule = library.content.rule(id: id) {
                        RuleView(rule: rule)
                    } else {
                        ContentUnavailableView("Правило не найдено", systemImage: "questionmark.circle")
                    }
                case .word(let query):
                    WordAnalysisView(query: query)
                }
            }
        }
    }
}
