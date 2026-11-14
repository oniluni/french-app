import FrenchCore
import SwiftUI

/// The frame shared by every session: close button, title, counter, progress bar; the question
/// in the middle and its buttons at the bottom.
struct SessionFrame<Content: View, Bottom: View>: View {
    let title: String
    /// The number of the current question or card, from 1; `total` once finished.
    let current: Int
    let total: Int
    /// Questions answered, for the bar.
    let done: Int
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ZStack {
                    Text(title).font(Theme.bodyMedium).lineLimit(1).padding(.horizontal, 72)
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .buttonStyle(IconButtonStyle(kind: .glass))
                            .accessibilityLabel("Закрыть")
                        Spacer()
                        Text("\(min(current, total)) / \(total)").font(Theme.mono(14)).foregroundStyle(Theme.t2)
                    }
                }
                ProgressBar(value: total == 0 ? 1 : Double(done) / Double(total))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            content
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
            VStack(spacing: 10) { bottom }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Theme.bg)
    }
}

/// The large card a question or a word is shown on.
struct QuestionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) { content }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .surface(radius: 32)
    }
}

/// What the learner has to do, over a question.
struct Instruction: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.footnote)
            .foregroundStyle(Theme.t2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("instruction")
    }
}

/// «Верно» or «Правильный ответ: …», with its icon.
struct Verdict: View {
    let isRight: Bool
    var answer: String?

    var body: some View {
        Label(isRight ? "Верно" : answer.map { "Правильный ответ: \($0)" } ?? "Правильный ответ",
              systemImage: isRight ? "checkmark.circle" : "xmark.circle")
            .font(Theme.sans(15, .semibold, relativeTo: .callout))
            .foregroundStyle(isRight ? Theme.green : Theme.red)
            .padding(.top, 8)
    }
}

/// The blank of a sentence or a form: an accent line.
func blank(width: Int = 8) -> AttributedString {
    var blank = AttributedString(String(repeating: "\u{00A0}", count: width))
    blank.underlineStyle = Text.LineStyle(pattern: .solid, color: Theme.acc)
    return blank
}

// MARK: - Cards

/// Cards to go through in one sitting.
struct SessionRequest: Identifiable {
    let id = UUID()
    let title: String
    let entries: [Entry]
}

/// Cards in the Anki manner: look at the word, recall, turn it over, grade yourself.
struct CardSessionView: View {
    let request: SessionRequest

    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [Entry] = []
    @State private var total = 0
    @State private var isFlipped = false
    @State private var counts: [Grade: Int] = [:]
    /// Cards graded in this session, for the summary.
    @State private var graded: [Entry] = []

    /// «Легко» is left out: the design has three grades.
    private static let grades: [(grade: Grade, label: String, color: Color, fill: Color)] = [
        (.again, "Снова", Theme.red, Theme.redSoft), (.hard, "Трудно", Theme.amber, Theme.amberSoft), (.good, "Хорошо", Theme.green, Theme.greenSoft),
    ]

    var body: some View {
        let done = total - queue.count
        SessionFrame(title: request.title, current: done + 1, total: total, done: done) {
            if let entry = queue.first {
                card(entry).padding(.vertical, 16)
            } else {
                summary
            }
        } bottom: {
            if let entry = queue.first {
                if isFlipped {
                    gradeButtons(entry)
                } else {
                    Button("Показать ответ") { flip() }.buttonStyle(.pill(.quiet, wide: true))
                }
            } else {
                Button("Готово") { dismiss() }.buttonStyle(.pill(.primary, wide: true))
            }
        }
        .onAppear {
            guard total == 0 else { return }
            queue = Session.queue(from: request.entries, cards: store.data.cards, now: .now)
            total = queue.count
        }
        // A light tap per grade, and success when the last card is done.
        .sensoryFeedback(.impact(weight: .light), trigger: counts)
        .sensoryFeedback(trigger: queue.isEmpty) { wasEmpty, isEmpty in !wasEmpty && isEmpty && total > 0 ? .success : nil }
    }

    private func flip() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.82)) { isFlipped = true }
    }

    private func card(_ entry: Entry) -> some View {
        let status = store.status(of: entry)
        return ZStack {
            QuestionCard {
                MarkedText(marked: nil, plain: entry.word.fr, size: 44, weight: .semibold)
                Text("Вспомните перевод и коснитесь карточки").font(Theme.subhead).foregroundStyle(Theme.t2)
            }
            .opacity(isFlipped ? 0 : 1)
            QuestionCard { back(entry) }
                .opacity(isFlipped ? 1 : 0)
                // Turned with the card, so that it reads the right way round once flipped.
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFlipped && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .overlay(alignment: .topLeading) { Chip(text: status.label, tone: status.tone).padding(20) }
        .contentShape(Rectangle())
        .onTapGesture { if !isFlipped { flip() } }
        // The face is one button until it is turned; the back holds a button of its own.
        .accessibilityElement(children: isFlipped ? .contain : .combine)
        .accessibilityAddTraits(isFlipped ? [] : .isButton)
        .accessibilityIdentifier("card")
        .overlay(alignment: .topTrailing) { SpeakButton(text: entry.word.m ?? entry.word.fr, kind: .glass).padding(16) }
    }

    @ViewBuilder private func back(_ entry: Entry) -> some View {
        MarkedText(marked: entry.word.m, plain: entry.word.fr, size: 44, weight: .semibold)
        if !entry.word.ipa.isEmpty { IPAText(ipa: entry.word.ipa, size: 17) }
        Theme.line2.frame(width: 40, height: 1).padding(.vertical, 8)
        Text(entry.word.ru).font(Theme.sans(22, .medium, relativeTo: .title2))
        if !entry.word.pos.isEmpty { Text(entry.word.pos).font(Theme.subhead).foregroundStyle(Theme.t2) }
        if let rule = readingRule(of: entry.word.fr) {
            Spacer().frame(height: 52)
            Button {
                dismiss()
                navigator.push(.rule(rule.rule))
            } label: {
                Text("Почему так читается · \(rule.label)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.tinted, small: true, wide: true))
        }
    }

    /// The reading rule of the lessons that explains the word, as the reader finds it.
    private func readingRule(of word: String) -> ReadingRule? {
        let content = library.content
        return library.reader.read(word).ruleSubjects.lazy.compactMap { content.readingRule(for: $0.subject) }.first.map { content.readingRules[$0] }
    }

    private func gradeButtons(_ entry: Entry) -> some View {
        VStack(spacing: 10) {
            Text("Насколько легко вспомнили?").font(Theme.footnote).foregroundStyle(Theme.t2)
            HStack(spacing: 10) {
                ForEach(CardSessionView.grades, id: \.grade) { item in
                    let delay = Scheduler.delay(store.data.cards[entry.id], grade: item.grade, now: .now).shortDelay
                    Button {
                        grade(entry, item.grade)
                    } label: {
                        VStack(spacing: 4) {
                            Text(item.label).font(Theme.sans(15, .semibold, relativeTo: .callout))
                            Text(delay).font(Theme.mono(12))
                        }
                        .foregroundStyle(item.color)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(item.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.label), \(delay)")
                }
            }
        }
        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
    }

    private func grade(_ entry: Entry, _ grade: Grade) {
        store.grade(entry, grade)
        counts[grade, default: 0] += 1
        if !graded.contains(entry) { graded.append(entry) }
        queue.removeFirst()
        // «Снова» puts the card back at the end of the queue.
        if grade == .again { queue.append(entry) }
        isFlipped = false
    }

    @ViewBuilder private var summary: some View {
        if total == 0 {
            EmptyState(systemImage: "checkmark", iconColor: Theme.green, iconFill: Theme.greenSoft,
                       title: "Повторять нечего", text: "В этом наборе нет карточек.")
        } else {
            let cards = store.data.cards
            let next = graded.compactMap { cards[$0.id]?.due }.min()
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
            let returning = graded.filter { cards[$0.id].map { calendar.isDate($0.due, inSameDayAs: tomorrow) } ?? false }.count
            let fresh = request.entries.filter { cards[$0.id] == nil }.count
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    EmptyIcon(systemImage: "checkmark", color: Theme.green, fill: Theme.greenSoft)
                    Text("Сессия окончена").font(Theme.title1)
                    Text("\(plural(total, "карточка", "карточки", "карточек")) из набора «\(request.title)»").foregroundStyle(Theme.t2)
                }
                .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    ForEach(CardSessionView.grades, id: \.grade) { item in
                        VStack(spacing: 4) {
                            Text("\(counts[item.grade] ?? 0)").font(Theme.mono(28, .medium, relativeTo: .title))
                            Text(item.label).font(Theme.sans(15, .semibold, relativeTo: .callout))
                        }
                        .foregroundStyle(item.color)
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(item.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
                Card {
                    if let next { summaryRow("Следующее повторение", next.dayAndTime) }
                    summaryRow("Завтра вернётся", plural(returning, "карточка", "карточки", "карточек"))
                    summaryRow("Осталось новых в наборе", "\(fresh)")
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.t2)
            Spacer(minLength: 12)
            Text(value).font(Theme.bodyMedium)
        }
        .row()
    }
}

extension Date {
    /// «сегодня, 21:40», «завтра, 14 ноября», «16 ноября».
    var dayAndTime: String {
        let calendar = Calendar.current
        let russian = Locale(identifier: "ru")
        if calendar.isDateInToday(self) { return "сегодня, \(formatted(.dateTime.hour().minute().locale(russian)))" }
        let day = formatted(.dateTime.day().month(.wide).locale(russian))
        return calendar.isDateInTomorrow(self) ? "завтра, \(day)" : day
    }
}

// MARK: - Parts shared by the quizzes: drills, gap-fill, rules

/// A wrong answer, listed at the end of a quiz.
struct Mistake: Identifiable {
    let id = UUID()
    /// The right answer: French with marks, or as written.
    let marked: String?
    let plain: String
    var ipa = ""
    var isFrench = true
    /// What the learner chose.
    let answered: String
}

/// Where a quiz is: which question, the pick on it, the mistakes so far.
struct QuizProgress {
    var index = 0
    var chosen: Int?
    var mistakes: [Mistake] = []

    var right: Int { index - mistakes.count }

    /// Counts the pick and moves to the next question.
    mutating func next(answer: Int, mistake: () -> Mistake) {
        if let chosen, chosen != answer { mistakes.append(mistake()) }
        chosen = nil
        index += 1
    }
}

/// The answers to pick one from. After the pick the right one turns green and a wrong pick red.
struct ChoiceGrid: View {
    let options: [String]
    let answer: Int
    @Binding var chosen: Int?
    /// Rules are Russian titles, a line each; forms and words are French, two to a row.
    var isFrench = true

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: isFrench ? 2 : 1)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.offset) { option, text in
                Button {
                    if chosen == nil { chosen = option }
                } label: {
                    label(text, option: option)
                }
                .buttonStyle(.plain)
                .disabled(chosen != nil)
                .accessibilityIdentifier("option-\(option)")
            }
        }
        .animation(.easeOut(duration: 0.15), value: chosen)
    }

    private func label(_ text: String, option: Int) -> some View {
        let state = state(of: option)
        return HStack(spacing: 8) {
            if state == .right { Image(systemName: "checkmark.circle").accessibilityLabel("Верно") }
            if state == .wrong { Image(systemName: "xmark.circle").accessibilityLabel("Неверно") }
            Text(text)
                .font(isFrench ? Theme.sans(18, relativeTo: .title3) : Theme.callout)
                .multilineTextAlignment(isFrench ? .center : .leading)
                .environment(\.locale, Locale(identifier: isFrench ? "fr" : "ru"))
        }
        .foregroundStyle(state == .right ? Theme.green : state == .wrong ? Theme.red : state == .dim ? Theme.t3 : Theme.t1)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: isFrench ? .center : .leading)
        .background(state == .right ? Theme.greenSoft : state == .wrong ? Theme.redSoft : Theme.s2,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(state == .right ? Theme.green : state == .wrong ? Theme.red : Theme.line))
    }

    private enum OptionState {
        case open, right, wrong, dim
    }

    private func state(of option: Int) -> OptionState {
        guard let chosen else { return .open }
        if option == answer { return .right }
        return option == chosen ? .wrong : .dim
    }
}

/// «Дальше», grey until an answer is picked.
struct NextButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button("Дальше", action: action)
            .buttonStyle(.pill(.primary, wide: true))
            .disabled(!isEnabled)
    }
}

/// «5 из 8» at the end of a quiz, and where the learner went wrong.
struct ScoreSummary: View {
    let right: Int
    let total: Int
    let mistakes: [Mistake]

    var body: some View {
        if total == 0 {
            EmptyState(systemImage: "questionmark", title: "Вопросов нет", text: "Для этого выбора нет вопросов. Выберите другие уроки или тему.")
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("\(Text("\(right)").font(Theme.mono(64, .medium, relativeTo: .largeTitle)))\(Text(" из \(total)").font(Theme.mono(28, relativeTo: .title)).foregroundStyle(Theme.t2))")
                        Text("Тренировка окончена").font(Theme.title1)
                        Text(mistakes.isEmpty ? "Без ошибок" : plural(mistakes.count, "ошибка", "ошибки", "ошибок")).foregroundStyle(Theme.t2)
                    }
                    if !mistakes.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Где ошиблись", top: 0)
                            Card {
                                ForEach(mistakes) { mistake in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            if mistake.isFrench {
                                                MarkedText(marked: mistake.marked, plain: mistake.plain)
                                            } else {
                                                Text(mistake.plain).font(Theme.bodyMedium)
                                            }
                                            Text("вы ответили: \(mistake.answered)").font(Theme.subhead).foregroundStyle(Theme.t2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        if !mistake.ipa.isEmpty { IPAText(ipa: mistake.ipa, isBracketed: false) }
                                    }
                                    .row()
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
    }
}
