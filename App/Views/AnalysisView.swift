import FrenchCore
import SwiftUI

/// «Разбор»: a text read word by word, or one word looked up in the dictionary.
struct AnalysisView: View {
    private enum Part: String, CaseIterable {
        case reader = "Читалка"
        case word = "Слово"
    }

    @Environment(Library.self) private var library

    @State private var part = Part.reader
    @State private var phrase = ""
    @State private var word = ""
    @State private var analysed = ""
    /// Bumped when another screen asks the reader to read a word.
    @State private var readRequest = 0

    var body: some View {
        Group {
            switch part {
            case .reader:
                ReaderView(phrase: $phrase, request: readRequest)
            case .word:
                WordTool(word: $word, analysed: $analysed) { text in
                    phrase = text
                    readRequest += 1
                    part = .reader
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavSegments(options: Part.allCases.map { (value: $0, title: $0.rawValue) }, selection: $part)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if part == .word, let favoriteWord {
                    FavoriteButton(word: favoriteWord)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The word the «Слово» tool is showing, as a card for «Избранное».
    private var favoriteWord: Word? {
        guard !analysed.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let entry = library.entry(for: analysed) { return entry.word }
        guard let lemma = library.grammar.analyses(of: analysed).first?.analysis.lemma else { return nil }
        let pronunciation = library.lexicon.entry(for: lemma)?.pronunciations.first
        return Word(fr: lemma, m: pronunciation?.marked, ipa: pronunciation?.ipa ?? "",
                    ru: library.translation(of: lemma) ?? "")
    }
}

// MARK: - Reader

private struct ReaderView: View {
    @Binding var phrase: String
    let request: Int

    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
    @State private var words: [ReadWord] = []
    @State private var picked: Picked?
    @State private var anchor = CGRect.zero
    @State private var selectedRule: DisplayRule?
    @FocusState private var isEditing: Bool

    private static let samples: [(fr: String, ru: String)] = [
        ("Les enfants habitent à Paris.", "Дети живут в Париже."),
        ("Je ne parle pas français.", "Я не говорю по-французски."),
        ("Nous avons un petit jardin.", "У нас есть маленький сад."),
    ]

    var body: some View {
        Screen {
            VStack(spacing: 0) {
                TextField("Введите или вставьте французский текст", text: $phrase, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isEditing)
                    .onSubmit(read)
                    .modifier(FieldBackground(isFocused: isEditing))
                    .accessibilityIdentifier("reader-field")
                    .onChange(of: phrase) { _, new in
                        guard new.contains("\n") else { return }
                        phrase = new.replacingOccurrences(of: "\n", with: " ")
                        read()
                    }

                Button("Разобрать", action: read)
                    .buttonStyle(.pill(.primary))
                    .disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.top, 12)

                if words.isEmpty {
                    legend
                    examples
                } else {
                    phraseCard
                    stats
                    rules
                }
            }
        }
        .onChange(of: request) { _, _ in read() }
        .onAppear {
            if words.isEmpty, !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                read()
            }
        }
        .popover(item: $picked, attachmentAnchor: .rect(.rect(anchor)), arrowEdge: .bottom) { item in
            WordPopover(picked: item, onLeave: { picked = nil })
        }
    }

    private func read() {
        isEditing = false
        picked = nil
        selectedRule = nil
        let text = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        words = text.isEmpty ? [] : library.reader.read(text)
    }

    // MARK: Empty state

    private var legend: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Обозначения", top: 24)
            Card {
                legendRow("parl(ent)", "Немая буква", "Пишется, но не произносится")
                legendRow("mat[in]", "Носовой гласный", "Произносится в нос")
                legendRow("le{s}", "Согласный в связывании", "Слышен только перед гласным")
                legendRow("les‿amis", "Связывание", "Слова читаются слитно")
            }
        }
    }

    private func legendRow(_ sample: String, _ title: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            MarkedText(marked: sample, plain: Markup.plain(sample), size: 19, weight: .medium)
                .frame(width: 92, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.bodyMedium)
                Text(text).font(Theme.subhead).foregroundStyle(Theme.t2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var examples: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Примеры")
            Card {
                ForEach(Self.samples, id: \.fr) { sample in
                    Button {
                        phrase = sample.fr
                        read()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.fr).font(Theme.sans(19, .medium))
                                Text(sample.ru).font(Theme.subhead).foregroundStyle(Theme.t2)
                            }
                            Spacer(minLength: 0)
                            Chevron()
                        }
                        .row()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(sample.fr)
                }
            }
        }
    }

    // MARK: Analysed phrase

    private var phraseCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SelectableWords(
                    words: words.map {
                        TextWord(marked: $0.marked, plain: $0.text,
                                 ipa: $0.isKnown ? $0.ipa : "", link: $0.link,
                                 isTied: !$0.link.isEmpty)
                    },
                    picked: picked?.range,
                    hit: Set(selectedRule?.words ?? [])
                ) { range, rect in
                    anchor = rect
                    picked = pickedWords(range)
                }

                Divider().overlay(Theme.line)

                HStack(spacing: 8) {
                    if !unknownNote.isEmpty {
                        Text(unknownNote).font(Theme.subhead).foregroundStyle(Theme.t3)
                    }
                    Spacer(minLength: 0)
                    SpeakButton(text: Markup.plain(phrase), kind: .plain)
                }

                if let selectedRule {
                    Divider().overlay(Theme.line)
                    Text("\(selectedRule.title) · \(plural(selectedRule.words.count, "слово", "слова", "слов"))")
                        .font(Theme.footnote)
                        .foregroundStyle(Theme.acc)
                }
            }
            .padding(16)
        }
        .padding(.top, 16)
    }

    private var unknownNote: String {
        let unknown = words.filter { !$0.isKnown }.map(\.text)
        return unknown.isEmpty ? "" : unknown.joined(separator: ", ") + " — нет в словаре"
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat(words.silentLetters.count, "немых букв")
            stat(words.liaisons.count, "связываний")
            stat(words.nasalVowels.count, "носовых гласных")
        }
        .padding(.top, 8)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(Theme.mono(15, .medium)).foregroundStyle(Theme.t2)
            Text(label).font(Theme.caption1.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.s1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line) }
    }

    private var rules: some View {
        let subjects = words.ruleSubjects
        let applied = library.content.rulesApplying(to: subjects.map(\.subject)).map {
            let indices = $0.words.map { subjects[$0].index }
            return DisplayRule(id: "reading-\($0.rule.rule)", ruleID: $0.rule.rule,
                               title: $0.rule.label, examples: examples(of: indices),
                               words: indices, kind: "Чтение", isReading: true)
        }
        let triggered = library.content.rulesTriggered(by: words, lexicon: library.lexicon).map {
            DisplayRule(id: $0.rule.id, ruleID: $0.rule.id, title: $0.rule.title,
                        examples: examples(of: $0.words), words: $0.words,
                        kind: $0.rule.kind, isReading: false)
        }
        let grammar = triggered.filter { $0.kind == "Грамматика" }
        let sounds = triggered.filter { $0.kind == "Произношение" }
        let reading = applied + triggered.filter { $0.kind == "Чтение" }
        return VStack(spacing: 0) {
            if !grammar.isEmpty { ruleSection("Грамматика в этой фразе", grammar) }
            if !reading.isEmpty { ruleSection("Чтение", reading) }
            if !sounds.isEmpty { ruleSection("Произношение", sounds) }
        }
    }

    private func examples(of indices: [Int]) -> String {
        indices.compactMap { words.indices.contains($0) ? words[$0].text : nil }
            .joined(separator: ", ")
    }

    private func ruleSection(_ title: String, _ items: [DisplayRule]) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: title, trailing: "\(items.count)")
            Card {
                ForEach(items) { item in
                    ruleRow(item)
                }
            }
        }
    }

    @ViewBuilder private func ruleRow(_ item: DisplayRule) -> some View {
        if item.isReading {
            HStack(spacing: 8) {
                Button {
                    if selectedRule?.id == item.id {
                        selectedRule = nil
                    } else {
                        selectedRule = item
                    }
                } label: {
                    ruleLabel(item)
                }
                .buttonStyle(.plain)

                if selectedRule?.id == item.id {
                    Button {
                        navigator.push(.rule(item.ruleID))
                    } label: {
                        HStack(spacing: 2) {
                            Text("Правило")
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                        }
                        .font(Theme.sans(13, .medium, relativeTo: .footnote))
                        .foregroundStyle(Theme.acc)
                        .padding(.leading, 8)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { navigator.push(.rule(item.ruleID)) } label: { Chevron() }
                        .buttonStyle(.plain)
                }
            }
            .background(selectedRule?.id == item.id ? Theme.accSoft : .clear)
        } else {
            Button { navigator.push(.rule(item.ruleID)) } label: {
                HStack(spacing: 12) {
                    ruleLabel(item)
                    Chevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func ruleLabel(_ item: DisplayRule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title).font(Theme.bodyMedium)
                .foregroundStyle(.primary)
            if !item.examples.isEmpty {
                Text(item.examples).font(Theme.subhead).foregroundStyle(Theme.t2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func pickedWords(_ range: ClosedRange<Int>) -> Picked {
        let chosen = Array(words[range])
        let plain = Markup.plain(chosen.map(\.text).joined(separator: " ")).withoutOuterPunctuation
        let marked = chosen.allSatisfy(\.isKnown) ? chosen.marked : nil
        let ipa = chosen.count == 1 ? chosen[0].ipa : chosen.ipa
        let translation = chosen.count == 1 ? library.translation(of: plain) : nil
        var rule: ReadingRule?
        if chosen.count == 1,
           let subject = words.ruleSubjects.first(where: { $0.index == range.lowerBound })?.subject,
           let ruleIndex = library.content.readingRule(for: subject) {
            rule = library.content.readingRules[ruleIndex]
        }
        let word = chosen.count == 1 && chosen[0].isKnown
            ? Word(fr: plain, m: marked, ipa: ipa, ru: translation ?? "")
            : nil
        return Picked(range: range, marked: marked, plain: plain, ipa: ipa,
                      translation: translation, isPhrase: chosen.count > 1,
                      rule: rule, word: word)
    }
}

/// A rule as the reader lists it: the same row navigates, and a reading rule also selects its words.
private struct DisplayRule: Identifiable {
    let id: String
    let ruleID: String
    let title: String
    let examples: String
    let words: [Int]
    let kind: String
    let isReading: Bool
}

// MARK: - Word tool

private struct WordTool: View {
    @Binding var word: String
    @Binding var analysed: String
    let onRead: (String) -> Void

    @Environment(Library.self) private var library
    @FocusState private var isEditing: Bool

    private static let samples = ["buvons", "petites", "l'enfant", "nous allons"]

    var body: some View {
        Screen {
            VStack(spacing: 0) {
                TextField("Любая форма: buvons, petites", text: $word)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isEditing)
                    .onSubmit(analyse)
                    .modifier(FieldBackground(isFocused: isEditing))
                    .accessibilityIdentifier("word-field")

                Button("Разобрать", action: analyse)
                    .buttonStyle(.pill(.primary))
                    .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.top, 12)

                if analysed.isEmpty {
                    empty
                } else if library.grammar.analyses(of: analysed).isEmpty && library.entry(for: analysed) == nil {
                    missing
                } else {
                    WordAnalysisBody(query: analysed)
                        .padding(.top, 16)
                }
            }
        }
    }

    private func analyse() {
        isEditing = false
        let text = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { analysed = text }
    }

    private var empty: some View {
        EmptyState(systemImage: "text.book.closed", title: "Введите слово",
                   text: "Подойдёт любая форма: глагол в любом времени, существительное во множественном числе.") {
            FlowLayout(spacing: 7, lineSpacing: 10) {
                ForEach(Self.samples, id: \.self) { sample in
                    FilterChip(title: sample, isOn: false) {
                        word = sample
                        analysed = sample
                    }
                }
            }
        }
    }

    private var missing: some View {
        EmptyState(systemImage: "magnifyingglass",
                   title: "«\(analysed)» нет в словаре",
                   text: "Его нет ни в уроках, ни в Lexique. Можно разобрать его в читалке по буквам.") {
            Button("Разобрать в читалке") { onRead(analysed) }
                .buttonStyle(.pill(.quiet, small: true))
        }
    }
}
