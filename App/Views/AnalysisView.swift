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
                            .autocorrectionDisabled()
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

    private static let samples = ["Les enfants habitent à Paris.", "Ils ont beaucoup de temps.", "Vous êtes très aimables."]

    var body: some View {
        List {
            Section {
                TextField("Фраза по-французски", text: $phrase, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .environment(\.locale, Locale(identifier: "fr"))
                    .accessibilityIdentifier("reader-field")
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
    }

    private func read(_ text: String) {
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
        let gloss = library.entry(for: plain)?.word.ru
        return Picked(
            range: range, marked: bare, plain: plain, ipa: word.ipa, translation: gloss, isPhrase: false, rule: nil,
            word: bare.map { Word(fr: plain, m: $0, ipa: word.ipa, ru: gloss ?? "") })
    }
}
