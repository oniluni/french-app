import FrenchCore
import SwiftUI

/// Rule questions to go through in one sitting.
struct RuleRequest: Identifiable {
    let id = UUID()
    let title: String
    let questions: [RuleQuestion]
}

/// A sentence with words of the lessons and four rules: pick the one that works in it. The answer then shows the
/// words it applies to and what the rule says.
struct RuleSessionView: View {
    let request: RuleRequest

    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
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
                ChoiceGrid(options: question.options.map(\.title), answer: question.answer, chosen: $progress.chosen, isFrench: false)
                NextButton(isEnabled: progress.chosen != nil) {
                    progress.next(answer: question.answer) {
                        Mistake(marked: nil, plain: question.options[question.answer].title, isFrench: false,
                                answered: progress.chosen.map { question.options[$0].title } ?? "")
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

    private func question(_ question: RuleQuestion) -> some View {
        let rule = question.options[question.answer]
        let read = library.reader.read(question.phrase)
        return VStack(spacing: 0) {
            Instruction(text: "Какое правило работает в этой фразе?").padding(.bottom, 16)
            QuestionCard {
                ScrollView {
                    VStack(spacing: 10) {
                        Text(phrase(question, read: read))
                            .lineSpacing(6)
                            .environment(\.locale, Locale(identifier: "fr"))
                            .accessibilityIdentifier("rule-phrase")
                        if progress.chosen != nil, read.allSatisfy(\.isKnown) { IPAText(ipa: read.ipa, size: 15) }
                        Text(question.ru).foregroundStyle(Theme.t2)
                        if let chosen = progress.chosen {
                            Verdict(isRight: chosen == question.answer)
                            if chosen != question.answer { Text(rule.title).font(Theme.headline) }
                            Text(rule.summary.isEmpty ? "Урок \(rule.lesson)" : rule.summary).font(Theme.subhead).foregroundStyle(Theme.t2)
                            Button("Открыть правило") {
                                dismiss()
                                navigator.push(.rule(rule.id))
                            }
                            .buttonStyle(.pill(.tinted, small: true))
                            .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.center)
            }
            .overlay(alignment: .topTrailing) {
                if progress.chosen != nil { SpeakButton(text: question.phrase, kind: .glass).padding(16) }
            }
        }
    }

    /// The phrase with its marks, when the reader split it the same way; once answered, the
    /// words the rule applies to stand out.
    private func phrase(_ question: RuleQuestion, read: [ReadWord]) -> AttributedString {
        let isMarked = progress.chosen != nil && read.count == question.words.count
        var text = AttributedString()
        for (index, word) in question.words.enumerated() {
            if index > 0 { text += AttributedString(" ") }
            var part: AttributedString
            if isMarked, let marked = read[index].marked {
                part = AttributedString(marked: marked, size: 28, weight: .medium)
            } else {
                part = AttributedString(word)
                part.swiftUI.font = Theme.sans(28, .medium, relativeTo: .title)
            }
            if progress.chosen != nil, question.highlighted.contains(index) {
                part.swiftUI.backgroundColor = Theme.accSoft
            }
            text += part
        }
        return text
    }
}
