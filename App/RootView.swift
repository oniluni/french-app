import FrenchCore
import Observation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

enum AppTab: Hashable {
    case lessons, practice, analysis, reference, dictionary
}

/// A screen pushed onto the stack of a tab.
enum Route: Hashable {
    case lesson(Int)
    case rule(String)
    /// Analysis of a word; the string is what the learner typed or tapped.
    case word(String)
    /// A kind of function word in the reference, by `ReferenceCategory.id`.
    case category(String)
    /// Every rule of the lessons of one kind: «Грамматика».
    case rules(String)
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
            Tab("Практика", systemImage: "rectangle.stack", value: AppTab.practice) {
                stack(.practice) { PracticeView() }
            }
            Tab("Разбор", systemImage: "waveform", value: AppTab.analysis) {
                stack(.analysis) { AnalysisView() }
            }
            Tab("Справочник", systemImage: "books.vertical", value: AppTab.reference) {
                stack(.reference) { ReferenceView() }
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
                        let ids = library.content.lessons.map(\.id)
                        NotFoundView(title: "Урок \(id) не найден",
                                     text: "Его нет в этой версии приложения. Сейчас доступны уроки \(ids.min() ?? 0)–\(ids.max() ?? 0).")
                    }
                case .rule(let id):
                    if let rule = library.content.rule(id: id) {
                        RuleView(rule: rule)
                    } else {
                        NotFoundView(title: "Правило не найдено", text: "Его нет в этой версии приложения: уроки могли измениться.")
                    }
                case .word(let query):
                    WordAnalysisView(query: query)
                case .category(let id):
                    if let category = library.reference.categories.first(where: { $0.id == id }) {
                        CategoryView(category: category)
                    } else {
                        NotFoundView(title: "Раздел не найден", text: "Его нет в этой версии справочника.")
                    }
                case .rules(let kind):
                    AllRulesView(kind: kind)
                }
            }
        }
    }
}

/// A pushed screen whose content is not in this version of the app.
private struct NotFoundView: View {
    let title: String
    let text: String
    @Environment(Navigator.self) private var navigator

    var body: some View {
        EmptyState(systemImage: "questionmark.circle", iconColor: Theme.amber, title: title, text: text) {
            Button("К списку уроков") {
                navigator.paths[.lessons] = []
                navigator.tab = .lessons
            }
            .buttonStyle(.pill(.quiet, small: true))
        }
        .frame(maxHeight: .infinity)
        .background(Theme.bg)
    }
}

/// The bundled lessons cannot be read: say so, and let the learner keep their progress.
struct LaunchErrorView: View {
    let error: Error
    let retry: () -> Void

    @Environment(Store.self) private var store
    @State private var exported: BackupDocument?
    @State private var exportFailure: String?

    var body: some View {
        EmptyState(systemImage: "exclamationmark.triangle", iconColor: Theme.red, iconFill: Theme.redSoft,
                   title: "Не удалось открыть уроки",
                   text: "Файл с уроками в приложении повреждён. Ваши карточки, заметки и избранное хранятся отдельно и не пострадали.") {
            VStack(spacing: 10) {
                Button("Попробовать снова", action: retry).buttonStyle(.pill(.primary, small: true))
                Button("Сохранить копию прогресса") {
                    do {
                        exported = BackupDocument(data: try store.backup())
                    } catch {
                        exportFailure = "Не удалось подготовить копию: \(error.localizedDescription)"
                    }
                }
                .buttonStyle(.pill(.quiet, small: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .fileExporter(isPresented: Binding { exported != nil } set: { if !$0 { exported = nil } },
                      document: exported, contentType: .json, defaultFilename: BackupDocument.filename) { result in
            if case .failure(let error) = result { exportFailure = "Копия не сохранена: \(error.localizedDescription)" }
        }
        .alert(exportFailure ?? "", isPresented: Binding { exportFailure != nil } set: { if !$0 { exportFailure = nil } }) {
            Button("Понятно", role: .cancel) {}
        }
        .onAppear { LaunchErrorView.log.error("Bundled content: \(String(describing: error), privacy: .public)") }
    }

    private static let log = Logger(subsystem: "io.github.oniluni.french", category: "launch")
}
