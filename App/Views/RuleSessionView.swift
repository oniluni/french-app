import FrenchCore
import SwiftUI

/// Rule questions to go through in one sitting.
struct RuleRequest: Identifiable {
    let id = UUID()
    let title: String
    let questions: [RuleQuestion]
}

/// A phrase of a lesson and four rules: pick the one that works in it. The answer then shows the
/// words it applies to and what the rule says.
struct RuleSessionView: View {
    let request: RuleRequest

    @State private var index = 0
    @State private var chosen: Int?
    @State private var right = 0

    var body: some View {
        SessionFrame(title: request.title, done: index, total: request.questions.count) {
            if index < request.questions.count {
                question(request.questions[index])
            } else {
                ScoreSummary(right: right, total: request.questions.count)
            }
        }
        .sensoryFeedback(trigger: chosen) { _, picked in
            guard let picked, index < request.questions.count else { return nil }
            return picked == request.questions[index].answer ? .success : .error
        }
        .sensoryFeedback(.success, trigger: index == request.questions.count)
    }

    private func question(_ question: RuleQuestion) -> some View {
        let rule = question.options[question.answer]
        return VStack(spacing: 14) {
            ScrollView {
                VStack(spacing: 12) {
                    Instruction(text: "Какое правило работает в этой фразе?")
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(phrase(question))
                            .font(Theme.french(.title3))
                            .multilineTextAlignment(.center)
                            .environment(\.locale, Locale(identifier: "fr"))
                            .accessibilityIdentifier("rule-phrase")
                        SpeakButton(text: question.phrase)
                    }
                    Text(question.ru).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if let chosen {
                        let isRight = chosen == question.answer
                        Label(isRight ? "Верно" : "Правильный ответ", systemImage: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isRight ? Theme.good : Theme.again)
                            .padding(.top, 6)
                        VStack(spacing: 4) {
                            Text(rule.title).font(.headline)
                            Text("Урок \(rule.lesson) · \(rule.summary)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))

            ChoiceGrid(options: question.options.map(\.title), answer: question.answer, chosen: $chosen, isFrench: false)
            NextButton(chosen: $chosen, answer: question.answer, index: $index, right: $right)
        }
    }

    /// Once answered, the words the rule applies to stand out.
    private func phrase(_ question: RuleQuestion) -> AttributedString {
        var text = AttributedString()
        for (index, word) in question.words.enumerated() {
            if index > 0 { text += AttributedString(" ") }
            var part = AttributedString(word)
            if chosen != nil, question.highlighted.contains(index) {
                part.swiftUI.foregroundColor = .accentColor
                part.swiftUI.font = Theme.french(.title3).bold()
            }
            text += part
        }
        return text
    }
}
