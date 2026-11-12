import FrenchCore
import SwiftUI

/// The frame shared by card and drill sessions: close button, title, counter, progress.
private struct SessionFrame<Content: View>: View {
    let title: String
    let done: Int
    let total: Int
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Закрыть")
                Spacer()
                Text(title).font(.headline).lineLimit(1)
                Spacer()
                Text("\(min(done, total)) / \(total)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 44, alignment: .trailing)
            }
            ProgressView(value: Double(min(done, total)), total: Double(max(total, 1)))
            content
        }
        .padding(16)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

/// Cards in the Anki manner: look at the word, recall, turn it over, grade yourself.
struct CardSessionView: View {
    let request: SessionRequest

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [Entry] = []
    @State private var total = 0
    @State private var isFlipped = false
    @State private var counts: [Grade: Int] = [:]
    /// The soonest a card of this session comes back.
    @State private var nextReview: TimeInterval?

    private static let grades: [(grade: Grade, label: String, color: Color)] = [
        (.again, "Снова", Theme.again), (.hard, "Трудно", Theme.hard), (.good, "Хорошо", Theme.good), (.easy, "Легко", .accentColor),
    ]

    var body: some View {
        SessionFrame(title: request.title, done: total - queue.count, total: total) {
            if let entry = queue.first {
                card(entry)
                if isFlipped { gradeButtons(entry) } else { showAnswerButton }
            } else {
                summary
            }
        }
        .onAppear {
            guard total == 0 else { return }
            queue = Session.queue(from: request.entries, cards: store.data.cards, now: .now)
            total = queue.count
        }
    }

    private func card(_ entry: Entry) -> some View {
        Button {
            isFlipped = true
        } label: {
            VStack(spacing: 14) {
                Spacer()
                if isFlipped {
                    MarkedText(marked: entry.word.m, plain: entry.word.fr, style: .largeTitle)
                    if !entry.word.ipa.isEmpty { Text("[\(entry.word.ipa)]").font(.body).foregroundStyle(.secondary) }
                    Divider().frame(width: 60)
                    Text(entry.word.ru).font(.title3).multilineTextAlignment(.center)
                } else {
                    Text(entry.word.fr).font(Theme.french(.largeTitle))
                    Text("Вспомните перевод и произношение").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.primary)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { SpeakButton(text: entry.word.fr).padding(14) }
        .accessibilityIdentifier("card")
    }

    private var showAnswerButton: some View {
        Button { isFlipped = true } label: {
            Text("Показать ответ").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
    }

    private func gradeButtons(_ entry: Entry) -> some View {
        HStack(spacing: 8) {
            ForEach(CardSessionView.grades, id: \.grade) { item in
                Button {
                    grade(entry, item.grade)
                } label: {
                    VStack(spacing: 2) {
                        Text(item.label).font(.subheadline.weight(.semibold))
                        Text(Scheduler.delay(store.data.cards[entry.id], grade: item.grade, now: .now).shortDelay).font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(item.color)
            }
        }
    }

    private func grade(_ entry: Entry, _ grade: Grade) {
        let delay = Scheduler.delay(store.data.cards[entry.id], grade: grade, now: .now)
        store.grade(entry, grade)
        counts[grade, default: 0] += 1
        nextReview = min(nextReview ?? delay, delay)
        queue.removeFirst()
        // «Снова» puts the card back at the end of the queue.
        if grade == .again { queue.append(entry) }
        isFlipped = false
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Theme.good)
            Text(total == 0 ? "В этом наборе нет карточек" : "Сессия пройдена").font(.title2.bold())
            if total > 0 {
                HStack(spacing: 18) {
                    ForEach(CardSessionView.grades, id: \.grade) { item in
                        VStack(spacing: 2) {
                            Text("\(counts[item.grade] ?? 0)").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(item.color)
                            Text(item.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let nextReview {
                    Text("Следующее повторение через \(nextReview.shortDelay)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Готово").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }
}

/// A drill of word forms: pick the right one out of four.
struct DrillSessionView: View {
    let request: DrillRequest

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var chosen: Int?
    @State private var right = 0

    var body: some View {
        SessionFrame(title: request.title, done: index, total: request.questions.count) {
            if index < request.questions.count {
                question(request.questions[index])
            } else {
                summary
            }
        }
    }

    private func question(_ question: DrillQuestion) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                Spacer()
                if question.wordClass == .verb {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        MarkedText(marked: question.prompt, style: .largeTitle)
                        Text("…").font(Theme.french(.largeTitle)).foregroundStyle(.secondary)
                    }
                    Text("\(question.lemma) · \(question.task)").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(question.prompt).font(Theme.french(.largeTitle))
                    Text(question.task).font(.subheadline).foregroundStyle(.secondary)
                }
                if let chosen {
                    let isRight = chosen == question.answer
                    Label(isRight ? "Верно" : "Правильный ответ", systemImage: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isRight ? Theme.good : Theme.again)
                        .padding(.top, 6)
                    HStack(spacing: 10) {
                        VStack(spacing: 2) {
                            MarkedText(marked: question.solution.marked, style: .title2)
                            Text("[\(question.solution.ipa)]").font(Theme.ipa).foregroundStyle(.secondary)
                        }
                        SpeakButton(text: question.solution.marked)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { option, text in
                    Button {
                        guard chosen == nil else { return }
                        chosen = option
                        if option == question.answer { right += 1 }
                    } label: {
                        Text(text).font(Theme.french(.title3)).frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint(for: option, in: question))
                    .accessibilityIdentifier("option-\(option)")
                }
            }

            Button {
                chosen = nil
                index += 1
            } label: {
                Text("Дальше").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(chosen == nil)
        }
    }

    /// After an answer the right option turns green and a wrong pick red; the verdict is also written out.
    private func tint(for option: Int, in question: DrillQuestion) -> Color {
        guard let chosen else { return .accentColor }
        if option == question.answer { return Theme.good }
        return option == chosen ? Theme.again : .secondary
    }

    private var summary: some View {
        let total = request.questions.count
        return VStack(spacing: 14) {
            Spacer()
            Text("\(right) из \(total)").font(.system(size: 54, weight: .bold)).monospacedDigit()
            Text(right == total ? "Без ошибок" : plural(total - right, "ошибка", "ошибки", "ошибок")).font(.title3).foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: {
                Text("Готово").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }
}
