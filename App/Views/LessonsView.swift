import FrenchCore
import SwiftUI

/// The lesson list: where the learner stopped, what is due today, every lesson, and where the data comes from.
struct LessonsView: View {
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator

    private static let sources = [
        ("Lexique 3.83", "Транскрипция, леммы, формы слов", "CC BY-SA 4.0"),
        ("Tatoeba", "Примеры и фразы для тренировок", "CC BY 2.0 FR"),
        ("WikDict", "Переводы слов вне уроков", "CC BY-SA"),
        ("FLELex", "Уровни слов A1–C2", "CC BY-NC-SA 4.0"),
    ]

    var body: some View {
        let cards = store.data.cards
        let starred = library.entries(forWords: store.data.favorites).filter { $0.lesson == 0 }
        let due = Session.due(in: library.content.entries + starred, cards: cards, now: .now).count
        Screen {
            if let current = library.lesson(store.data.lastLesson ?? 1) ?? library.content.lessons.first {
                continueCard(current, cards: cards)
            }

            DueTile(count: due, button: .tinted) { navigator.tab = .practice }
                .padding(.top, 12)
                .accessibilityIdentifier("due-today")

            let grammar = library.grammarWorkshops.workshops
            if !grammar.isEmpty {
                grammarTile(due: grammar.filter { store.grammarStatus($0.id) == .due }.count,
                            total: grammar.count)
                    .padding(.top, 12)
            }

            SectionHeader(title: "Все уроки", trailing: "\(library.content.lessons.count)")
            Card {
                ForEach(library.content.lessons) { lesson in
                    NavRow(route: .lesson(lesson.id)) {
                        LessonRing(progress: Session.progress(of: lesson.entries, cards: cards), number: lesson.id)
                        RowTitles(title: "Урок \(lesson.id)", subtitle: lesson.topic,
                                  detail: "\(plural(lesson.entries.cardEntries.count, "слово", "слова", "слов")) · \(plural(lesson.rules.count, "правило", "правила", "правил"))")
                    }
                    .accessibilityIdentifier("lesson-\(lesson.id)")
                }
            }

            SectionHeader(title: "Данные")
            Card {
                ForEach(LessonsView.sources, id: \.0) { name, use, license in
                    HStack(spacing: 12) {
                        RowTitles(title: name, subtitle: use)
                        Chip(text: license, tone: .level)
                    }
                    .row()
                }
            }
        }
        .navigationTitle("Уроки")
    }

    /// Grammar is a separate track: short theory plus a test, so it gets one entry above the
    /// numbered lessons rather than another lesson row.
    private func grammarTile(due: Int, total: Int) -> some View {
        NavigationLink(value: Route.grammarTopics) {
            HStack(spacing: 12) {
                EmptyIcon(systemImage: "character.book.closed.fill",
                          color: Theme.acc, fill: Theme.accSoft, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Грамматика").font(Theme.bodyMedium)
                    Text("\(total) тем · теория и тесты").font(Theme.subhead).foregroundStyle(Theme.t2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if due > 0 { Chip(text: "\(due) к повторению", tone: .due) }
                Chevron()
            }
            .panel()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("grammar-topics")
    }

    private func continueCard(_ lesson: Lesson, cards: [String: CardState]) -> some View {
        let cardsOnly = lesson.entries.cardEntries
        let progress = Session.progress(of: cardsOnly, cards: cards)
        let started = cardsOnly.filter { cards[$0.id] != nil }.count
        return NavigationLink(value: Route.lesson(lesson.id)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ProgressRing(progress: progress, size: 56) {
                        Text("\(Int((progress * 100).rounded()))%").font(Theme.mono(15, .medium))
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Продолжить").font(Theme.footnote).foregroundStyle(Theme.t2)
                        Text("Урок \(lesson.id)").font(Theme.title2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Chevron()
                }
                Text(lesson.topic).font(Theme.subhead).foregroundStyle(Theme.t2).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Chip(text: plural(lesson.rules.count, "правило", "правила", "правил"))
                    Chip(text: "\(started) из \(plural(cardsOnly.count, "слова", "слов", "слов"))")
                }
            }
            .panel()
        }
        .buttonStyle(.plain)
    }
}

/// The ring of a lesson row with its number: grey before it starts, white while learnt, accent when done.
struct LessonRing: View {
    let progress: Double
    let number: Int

    var body: some View {
        ProgressRing(progress: progress) {
            Text("\(number)")
                .font(Theme.mono(13, .medium))
                .foregroundStyle(progress >= 1 ? Theme.acc : progress > 0 ? Theme.t1 : Theme.t2)
        }
    }
}

/// «12 · Сегодня · к повторению» with the button that starts the review.
struct DueTile: View {
    let count: Int
    var button = PillButtonStyle.Kind.primary
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(count)").font(Theme.mono(32, .medium, relativeTo: .largeTitle))
            VStack(alignment: .leading, spacing: 0) {
                Text("Сегодня").font(Theme.bodyMedium)
                Text(count == 0 ? "всё повторено" : "к повторению").font(Theme.subhead).foregroundStyle(Theme.t2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Повторить", action: action)
                .buttonStyle(.pill(button, small: true))
                .disabled(count == 0)
        }
        .panel()
        .accessibilityElement(children: .contain)
    }
}
