import FrenchCore
import SwiftUI

/// Grammar lessons to read, then test yourself on. The track is separate from the numbered
/// lessons: short theory pages with a multiple-choice test and a return date.
struct GrammarTopicsView: View {
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store

    var body: some View {
        let workshops = library.grammarWorkshops.workshops
        Screen {
            if workshops.isEmpty {
                EmptyState(systemImage: "character.book.closed",
                           title: "Грамматика недоступна",
                           text: "В этой версии приложения нет грамматических уроков.")
            } else {
                Text("Короткие уроки: прочитайте теорию, затем пройдите тест. Тема вернётся в повторение по расписанию.")
                    .font(Theme.subhead)
                    .foregroundStyle(Theme.t2)
                    .padding(.horizontal, 4)

                SectionHeader(title: "Темы", trailing: "\(workshops.count)")
                Card {
                    ForEach(workshops) { workshop in
                        NavigationLink(value: Route.grammar(workshop.id)) {
                            row(workshop)
                        }
                        .buttonStyle(RowButtonStyle())
                        .accessibilityIdentifier("grammar-\(workshop.id)")
                    }
                }
                Footer(text: "Тест можно проходить сколько угодно раз. Результат и дата следующего повторения сохраняются в прогрессе.")
            }
        }
        .navigationTitle("Грамматика")
    }

    private func row(_ workshop: GrammarWorkshop) -> some View {
        let status = store.grammarStatus(workshop.id)
        return HStack(spacing: 12) {
            EmptyIcon(systemImage: workshop.icon, color: Theme.acc, fill: Theme.accSoft, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(workshop.title).font(Theme.bodyMedium).multilineTextAlignment(.leading)
                Text(workshop.subtitle).font(Theme.subhead).foregroundStyle(Theme.t2)
                    .multilineTextAlignment(.leading).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Chip(text: label(status), tone: tone(status))
            Chevron()
        }
        .row()
    }

    private func label(_ status: CardStatus) -> String {
        switch status {
        case .new: "Новое"
        case .learning: "Пройдено"
        case .due: "Пора повторить"
        case .known: "Закреплено"
        }
    }

    private func tone(_ status: CardStatus) -> Chip.Tone {
        switch status {
        case .new: .new
        case .learning: .learning
        case .due: .due
        case .known: .known
        }
    }
}

/// One grammar lesson: theory, the last test result, and the button that opens the test.
struct GrammarLessonView: View {
    let workshop: GrammarWorkshop

    @Environment(Store.self) private var store
    @State private var isTesting = false

    var body: some View {
        Screen {
            HStack(alignment: .top, spacing: 12) {
                EmptyIcon(systemImage: workshop.icon, color: Theme.acc, fill: Theme.accSoft, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workshop.title).font(Theme.title2).multilineTextAlignment(.leading)
                    Text(workshop.subtitle).font(Theme.subhead).foregroundStyle(Theme.t2)
                        .multilineTextAlignment(.leading)
                    Chip(text: workshop.level, tone: .level).padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .panel()

            if let review = store.data.grammar[workshop.id] {
                SectionHeader(title: "Результат")
                Card {
                    resultRow("Последний тест", value: "\(review.correct) из \(review.total)")
                    resultRow("Следующее повторение", value: review.state.due.dayAndTime)
                    if !review.lastMistakes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Повторить").font(Theme.bodyMedium)
                            ForEach(Array(review.lastMistakes.enumerated()), id: \.offset) { _, prompt in
                                Text("• \(prompt)").font(Theme.subhead).foregroundStyle(Theme.t2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .row()
                    }
                }
            }

            SectionHeader(title: "Теория")
            Card {
                BlocksView(blocks: workshop.blocks)
                    .padding(16)
            }

            Button { isTesting = true } label: {
                Text(reviewTitle)
            }
            .buttonStyle(.pill(.primary, wide: true))
            .padding(.top, 16)
            .accessibilityIdentifier("grammar-test")

            Footer(text: "После теста урок вернётся в повторение: чем лучше результат, тем позже. Ошибки сохраняются, чтобы можно было повторить именно их.")
        }
        .navigationTitle(workshop.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isTesting) {
            GrammarQuizView(workshop: workshop)
        }
    }

    private var reviewTitle: String {
        store.data.grammar[workshop.id] == nil ? "Пройти тест" : "Пройти тест снова"
    }

    private func resultRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(Theme.bodyMedium)
            Spacer(minLength: 12)
            Text(value).font(Theme.subhead).foregroundStyle(Theme.t2)
                .multilineTextAlignment(.trailing)
        }
        .row()
    }
}

/// The test of one grammar lesson. The result is written to the learner's progress once,
/// when the last question is answered; leaving early does not change the schedule.
struct GrammarQuizView: View {
    let workshop: GrammarWorkshop

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var progress = QuizProgress()
    @State private var recorded = false

    var body: some View {
        let questions = workshop.questions
        let isOver = progress.index >= questions.count

        SessionFrame(title: workshop.title, current: progress.index + 1, total: questions.count,
                     done: progress.index + (progress.chosen == nil ? 0 : 1)) {
            if isOver {
                ScoreSummary(right: progress.right, total: questions.count, mistakes: progress.mistakes)
            } else {
                question(questions[progress.index])
            }
        } bottom: {
            if isOver {
                VStack(spacing: 10) {
                    Button("Ещё раз") {
                        progress = QuizProgress()
                        recorded = false
                    }
                    .buttonStyle(.pill(.quiet, wide: true))
                    Button("Готово") { dismiss() }
                        .buttonStyle(.pill(.primary, wide: true))
                }
            } else {
                let question = questions[progress.index]
                ChoiceGrid(options: question.options, answer: question.answer,
                           chosen: $progress.chosen, isFrench: true, columns: 1)
                NextButton(isEnabled: progress.chosen != nil) {
                    progress.next(answer: question.answer) {
                        Mistake(marked: nil, plain: question.prompt, isFrench: false,
                                answered: progress.chosen.map { question.options[$0] } ?? "")
                    }
                }
            }
        }
        .onChange(of: progress.index) { _, index in
            guard index >= questions.count, !recorded else { return }
            recorded = true
            store.recordGrammar(
                workshop.id,
                correct: progress.right,
                total: questions.count,
                mistakes: progress.mistakes.map(\.plain)
            )
        }
        .sensoryFeedback(trigger: progress.chosen) { _, picked in
            guard let picked, progress.index < questions.count else { return nil }
            return picked == questions[progress.index].answer ? .success : .error
        }
    }

    private func question(_ question: GrammarQuestion) -> some View {
        let isAnswered = progress.chosen != nil
        return VStack(spacing: 0) {
            Instruction(text: "Выберите правильный вариант").padding(.bottom, 16)
            QuestionCard {
                ScrollView {
                    VStack(spacing: 10) {
                        Text(question.prompt)
                            .font(Theme.sans(26, .medium, relativeTo: .title2))
                            .multilineTextAlignment(.center)
                            .environment(\.locale, Locale(identifier: "fr"))
                        if let translation = question.translation {
                            Text(translation).font(Theme.subhead).foregroundStyle(Theme.t2)
                                .multilineTextAlignment(.center)
                        }
                        if isAnswered {
                            Verdict(isRight: progress.chosen == question.answer,
                                    answer: progress.chosen == question.answer ? nil : question.options[question.answer])
                            InlineText(md: question.explanation)
                                .font(Theme.subhead)
                                .foregroundStyle(Theme.t2)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.center)
            }
        }
    }
}
