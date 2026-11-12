import FrenchCore
import SwiftUI

/// The lesson list: where the learner stopped, what is due today, and every lesson.
struct LessonsView: View {
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let cards = store.data.cards
        let starred = library.content.entries(forWords: store.data.favorites).filter { $0.lesson == 0 }
        let due = Session.due(in: library.content.entries + starred, cards: cards, now: .now).count
        List {
            if let current = library.lesson(store.data.lastLesson ?? 1) ?? library.content.lessons.first {
                Section {
                    NavigationLink(value: Route.lesson(current.id)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Продолжить").font(.subheadline.weight(.semibold)).opacity(0.8)
                            Text("Урок \(current.id)").font(.title2.bold())
                            Text(current.topic).font(.subheadline).lineLimit(2).opacity(0.9)
                            ProgressView(value: Session.progress(of: current.entries, cards: cards))
                                .tint(.white)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(Theme.hero)
                }
            }

            Section {
                Button {
                    navigator.tab = .practice
                } label: {
                    HStack {
                        Label("Повторить сегодня", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(plural(due, "карточка", "карточки", "карточек")).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("due-today")
            }

            Section("Все уроки") {
                ForEach(library.content.lessons) { lesson in
                    NavigationLink(value: Route.lesson(lesson.id)) {
                        HStack(spacing: 14) {
                            ProgressRing(progress: Session.progress(of: lesson.entries, cards: cards)) {
                                Text("\(lesson.id)").font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lesson.topic).font(.subheadline).lineLimit(2)
                                Text(plural(lesson.words.count, "слово", "слова", "слов")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("lesson-\(lesson.id)")
                }
            }

            Section {
                BackupButtons()
            } header: {
                Text("Данные")
            } footer: {
                Text("Прогресс и заметки хранятся только на этом устройстве. Сохраните копию перед переустановкой приложения.\n\nСловарь форм: Lexique 3.83, лицензия CC BY-SA 4.0. Примеры вне уроков: Tatoeba (tatoeba.org), лицензия CC BY 2.0 FR. Переводы вне уроков: WikDict (wikdict.com, по Викисловарю), CC BY-SA. Уровни A1–C2: FLELex (UCLouvain), CC BY-NC-SA 4.0.")
            }
        }
        .navigationTitle("Уроки")
    }
}
