import FrenchCore
import SwiftUI

/// A drill of word forms: pick the right one out of four.
struct DrillSessionView: View {
    let request: DrillRequest

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var progress = QuizProgress()

    var body: some View {
        let questions = request.questions
        let isOver = progress.index >= questions.count
        SessionFrame(title: request.title, current: progress.index + 1, total: questions.count,
                     done: progress.index + (progress.chosen == nil ? 0 : 1)) {
            if isOver {
                ScoreSummary(right: progress.right, total: questions.count, mistakes: progress.mistakes)
            } else {
                question(questions[progress.index]).padding(.vertical, 16)
            }
        } bottom: {
            if isOver {
                Button("Готово") { dismiss() }.buttonStyle(.pill(.primary, wide: true))
            } else {
                let question = questions[progress.index]
                ChoiceGrid(options: question.options, answer: question.answer, chosen: $progress.chosen)
                NextButton(isEnabled: progress.chosen != nil) {
                    progress.next(answer: question.answer) {
                        Mistake(marked: question.solution.marked, plain: question.solution.plain, ipa: question.solution.ipa,
                                answered: progress.chosen.map { question.options[$0] } ?? "")
                    }
                }
            }
        }
        .sensoryFeedback(trigger: progress.chosen) { _, picked in
            guard let picked, progress.index < questions.count else { return nil }
            return picked == questions[progress.index].answer ? .success : .error
        }
        .sensoryFeedback(.success, trigger: isOver)
    }

    /// «я иду» when the lessons teach this very form, otherwise «я · идти, ехать».
    private func translation(of question: DrillQuestion) -> String? {
        switch library.content.translation(ofForm: question.solution.plain, lemma: question.lemma) {
        case .form(let russian): russian
        case .lemma(let russian) where question.wordClass == .verb: "\(question.wordClass.cellLabels[question.solution.cell]) · \(russian)"
        case .lemma(let russian): russian
        case nil: nil
        }
    }

    private func question(_ question: DrillQuestion) -> some View {
        VStack(spacing: 0) {
            Instruction(text: question.instruction).padding(.bottom, 16)
            QuestionCard {
                HStack(spacing: 8) {
                    Chip(text: question.lemma).environment(\.locale, Locale(identifier: "fr"))
                    Chip(text: question.task)
                }
                if let chosen = progress.chosen {
                    MarkedText(marked: question.solution.marked, size: 40, weight: .semibold)
                    IPAText(ipa: question.solution.ipa, size: 17)
                    translationText(question)
                    Verdict(isRight: chosen == question.answer, answer: chosen == question.answer ? nil : question.options[question.answer])
                } else {
                    if question.wordClass == .verb {
                        Text("\(Text(AttributedString(marked: question.prompt, size: 40, weight: .semibold))) \(Text(blank(width: 10)).font(Theme.sans(40, .semibold)))")
                            .environment(\.locale, Locale(identifier: "fr"))
                    } else {
                        MarkedText(marked: nil, plain: question.prompt, size: 40, weight: .semibold)
                    }
                    translationText(question)
                }
            }
            .overlay(alignment: .topTrailing) {
                if progress.chosen != nil { SpeakButton(text: question.solution.marked, kind: .glass).padding(16) }
            }
        }
    }

    @ViewBuilder private func translationText(_ question: DrillQuestion) -> some View {
        if let translation = translation(of: question) {
            Text(translation)
                .font(Theme.sans(19, .medium, relativeTo: .title3))
                .accessibilityIdentifier("drill-translation")
        }
    }
}

/// Gap-fill sentences to go through in one sitting.
struct GapRequest: Identifiable {
    let id = UUID()
    let title: String
    let questions: [GapQuestion]
}

/// «Вставь слово»: a sentence with one preposition or conjunction taken out, and four to choose from.
struct GapSessionView: View {
    let request: GapRequest

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var progress = QuizProgress()

    var body: some View {
        let questions = request.questions
        let isOver = progress.index >= questions.count
        SessionFrame(title: request.title, current: progress.index + 1, total: questions.count,
                     done: progress.index + (progress.chosen == nil ? 0 : 1)) {
            if isOver {
                ScoreSummary(right: progress.right, total: questions.count, mistakes: progress.mistakes)
            } else {
                question(questions[progress.index]).padding(.vertical, 16)
            }
        } bottom: {
            if isOver {
                Button("Готово") { dismiss() }.buttonStyle(.pill(.primary, wide: true))
            } else {
                let question = questions[progress.index]
                ChoiceGrid(options: question.options, answer: question.answer, chosen: $progress.chosen)
                NextButton(isEnabled: progress.chosen != nil) {
                    progress.next(answer: question.answer) {
                        Mistake(marked: marks(question.gap.answer), plain: question.gap.answer,
                                answered: progress.chosen.map { question.options[$0] } ?? "")
                    }
                }
            }
        }
        .sensoryFeedback(trigger: progress.chosen) { _, picked in
            guard let picked, progress.index < questions.count else { return nil }
            return picked == questions[progress.index].answer ? .success : .error
        }
        .sensoryFeedback(.success, trigger: isOver)
    }

    private func question(_ question: GapQuestion) -> some View {
        let gap = question.gap
        return VStack(spacing: 0) {
            Instruction(text: "Вставьте пропущенное слово").padding(.bottom, 16)
            QuestionCard {
                Text(sentence(gap))
                    .lineSpacing(10)
                    .environment(\.locale, Locale(identifier: "fr"))
                    .accessibilityIdentifier("gap-sentence")
                Text(gap.ru).foregroundStyle(Theme.t2)
                if let chosen = progress.chosen {
                    Verdict(isRight: chosen == question.answer, answer: chosen == question.answer ? nil : gap.answer)
                    if let meaning = library.translation(of: gap.answer) {
                        Text("\(gap.answer) — \(meaning)").font(Theme.subhead).foregroundStyle(Theme.t2)
                    }
                    SpeakButton(text: gap.before + gap.answer + gap.after).padding(.top, 4)
                }
            }
        }
    }

    /// The sentence with the gap, or with the answer in place once chosen.
    private func sentence(_ gap: Gap) -> AttributedString {
        var before = AttributedString(gap.before)
        var after = AttributedString(gap.after)
        before.swiftUI.font = Theme.sans(28, .medium, relativeTo: .title)
        after.swiftUI.font = Theme.sans(28, .medium, relativeTo: .title)
        var middle: AttributedString
        if progress.chosen == nil {
            middle = blank(width: 9)
            middle.swiftUI.font = Theme.sans(28, .medium, relativeTo: .title)
        } else {
            middle = marks(gap.answer).map { AttributedString(marked: $0, size: 28, weight: .semibold) } ?? AttributedString(gap.answer)
            middle.swiftUI.foregroundColor = Theme.acc
            if marks(gap.answer) == nil { middle.swiftUI.font = Theme.sans(28, .semibold, relativeTo: .title) }
        }
        return before + middle + after
    }

    /// Marks of a single word, if the dictionary knows it.
    private func marks(_ word: String) -> String? {
        let words = library.reader.read(word)
        return words.allSatisfy(\.isKnown) ? words.marked : nil
    }
}
