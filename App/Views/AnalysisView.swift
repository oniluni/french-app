import FrenchCore
import SwiftUI

/// Analysis tools: the reader for any phrase, and the forms of any word.
struct AnalysisView: View {
    private enum Part: String, CaseIterable {
        case reader = "Читалка", word = "Слово"
    }

    @State private var part = Part.reader
    @State private var word = ""
    @State private var analysed = ""

    var body: some View {
        Group {
            switch part {
            case .reader:
                ReaderView()
            case .word:
                VStack(spacing: 0) {
                    HStack {
                        TextField("Любая форма: buvons, petites", text: $word)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { analysed = word }
                            .accessibilityIdentifier("word-field")
                        Button("Разобрать") { analysed = word }
                            .buttonStyle(.borderedProminent)
                            .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(16)
                    if analysed.isEmpty {
                        ContentUnavailableView("Разбор слова", systemImage: "character.book.closed",
                            description: Text("Введите слово в любой форме, чтобы увидеть начальную форму, часть речи и таблицу всех форм."))
                    } else {
                        WordAnalysisBody(query: analysed)
                    }
                }
            }
        }
        .navigationTitle("Разбор")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Инструмент", selection: $part) {
                    ForEach(Part.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 200)
            }
        }
    }
}

/// Type a phrase, get its pronunciation marks, its sounds and what to notice in it.
private struct ReaderView: View {
    @Environment(Library.self) private var library
    @State private var phrase = ""
    @State private var words: [ReadWord] = []
    @State private var picked: Picked?
    @State private var anchor = CGRect.zero
    @FocusState private var isEditing: Bool

    private static let samples = ["Les enfants habitent à Paris.", "Ils ont beaucoup de temps.", "Vous êtes très aimables."]

    var body: some View {
        List {
            Section {
                TextField("Фраза по-французски", text: $phrase, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .focused($isEditing)
                    .submitLabel(.done)
                    .accessibilityIdentifier("reader-field")
                    // A multi-line field takes Return as a new line; here Return means «Разобрать».
                    .onChange(of: phrase) { _, typed in
                        guard typed.contains("\n") else { return }
                        phrase = typed.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                        read(phrase)
                    }
                Button("Разобрать") { read(phrase) }
                    .disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !words.isEmpty {
                Section {
                    SelectableWords(
                        words: words.map { TextWord(marked: $0.marked, plain: $0.text, ipa: $0.isKnown ? $0.ipa : "?", link: $0.link, isTied: !$0.link.isEmpty) },
                        showsPronunciation: true, picked: picked?.range
                    ) { range, rect in
                        anchor = rect
                        picked = pickedWords(range)
                    }
                    .popover(item: $picked, attachmentAnchor: .rect(.rect(anchor))) { item in
                        WordPopover(picked: item, onLeave: { picked = nil })
                    }
                    .padding(.vertical, 6)
                    HStack {
                        Text("[\(words.ipa)]").font(Theme.ipa).foregroundStyle(.secondary).textSelection(.enabled)
                        Spacer()
                        SpeakButton(text: words.map(\.text).joined(separator: " "))
                    }
                    HStack {
                        counter(words.silentLetters, "немых букв")
                        counter(words.liaisons, "связываний")
                        counter(words.nasalVowels, "носовых")
                    }
                    if words.contains(where: { !$0.isKnown }) {
                        Text("Слов, отмеченных знаком «?», нет в словаре: они показаны без разметки.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                rulesSection
            }

            Section("Обозначения") {
                legend("peti(t)", "Немые буквы: пишутся, но не произносятся")
                legend("mat[in]", "Носовой гласный")
                legend("le{s}‿ami(s)", "Связывание: согласная звучит перед гласной следующего слова")
            }

            Section("Примеры") {
                ForEach(ReaderView.samples, id: \.self) { sample in
                    Button {
                        phrase = sample
                        read(sample)
                    } label: {
                        Text(sample).font(Theme.french(.body)).foregroundStyle(Color.primary)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// One rule found in the phrase: where it leads, its name, and the words it is about.
    private struct FoundRule: Identifiable {
        let id: String
        let rule: String
        let title: String
        let words: [Int]
    }

    /// Every rule of the lessons that applies to the phrase: grammar, reading (item by item, as
    /// in the lesson texts), and the sounds the phrase has.
    @ViewBuilder private var rulesSection: some View {
        let subjects = words.ruleSubjects
        let items = library.content.rulesApplying(to: subjects.map(\.subject)).map { item in
            FoundRule(id: "item-\(item.rule.label)", rule: item.rule.rule, title: item.rule.label, words: item.words.map { subjects[$0].index })
        }
        let triggered = library.content.rulesTriggered(by: words, lexicon: library.lexicon)
        let byKind = { (kind: String) in
            triggered.filter { $0.rule.kind == kind }.map { FoundRule(id: $0.rule.id, rule: $0.rule.id, title: $0.rule.title, words: $0.words) }
        }
        rulesGroup("Грамматика в этой фразе", byKind("Грамматика"))
        rulesGroup("Чтение", items + byKind("Чтение"))
        rulesGroup("Произношение", byKind("Произношение"))
    }

    @ViewBuilder private func rulesGroup(_ title: String, _ rules: [FoundRule]) -> some View {
        if !rules.isEmpty {
            Section(title) {
                ForEach(rules) { item in
                    NavigationLink(value: Route.rule(item.rule)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline).multilineTextAlignment(.leading)
                            // Two lessons may name a rule alike («Определённый артикль»): the lesson tells them apart.
                            let lesson = "Урок \(item.rule.prefix { $0 != "-" })"
                            let said = item.words.map { words[$0].text.withoutOuterPunctuation }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                            Text(([lesson] + said).joined(separator: " · "))
                                .font(Theme.french(.subheadline))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func read(_ text: String) {
        isEditing = false
        picked = nil
        words = library.reader.read(text)
    }

    private func counter(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func legend(_ marked: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            MarkedText(marked: marked, style: .title3).frame(minWidth: 96, alignment: .leading)
            Text(meaning).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func pickedWords(_ range: ClosedRange<Int>) -> Picked {
        let chosen = Array(words[range])
        let isMarked = chosen.allSatisfy(\.isKnown)
        let plain = chosen.map(\.text).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        guard chosen.count == 1, let word = chosen.first else {
            return Picked(range: range, marked: isMarked ? chosen.marked.withoutOuterPunctuation : nil, plain: plain,
                ipa: chosen.ipa, translation: nil, isPhrase: true, rule: nil, word: nil)
        }
        let bare = word.marked?.withoutOuterPunctuation
        let gloss = library.translation(of: plain)
        let content = library.content
        let rule = words.ruleSubjects.first { $0.index == range.lowerBound }
            .flatMap { content.readingRule(for: $0.subject) }
            .map { content.readingRules[$0] }
        return Picked(
            range: range, marked: bare, plain: plain, ipa: word.ipa, translation: gloss, isPhrase: false, rule: rule,
            word: bare.map { Word(fr: plain, m: $0, ipa: word.ipa, ru: gloss ?? "") })
    }
}
