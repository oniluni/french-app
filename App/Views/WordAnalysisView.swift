import FrenchCore
import os
import SwiftUI

/// The pushed «Разбор слова» screen.
struct WordAnalysisView: View {
    let query: String

    var body: some View {
        WordAnalysisBody(query: query)
            .navigationTitle("Разбор слова")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Everything about one word: base form, facts, every form with the typed one highlighted.
/// Shown both in the «Слово» tool and as a pushed screen.
struct WordAnalysisBody: View {
    let query: String

    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator
    @Environment(Speech.self) private var speech
    /// Which of the readings of the form is shown: "lit" is a verb form and a noun.
    @State private var choice = 0
    /// Nil until the learner picks a set: then the set holding the typed form is shown.
    @State private var tense: Int?
    @State private var drill: DrillRequest?

    private static let partsOfSpeech: [String: String] = [
        "NOM": "существительное", "VER": "глагол", "ADJ": "прилагательное", "ADV": "наречие", "PRE": "предлог",
        "CON": "союз", "ONO": "междометие", "ART:def": "определённый артикль", "ART:ind": "неопределённый артикль",
        "PRO:per": "личное местоимение", "PRO:dem": "указательное местоимение", "PRO:ind": "неопределённое местоимение",
        "PRO:pos": "притяжательное местоимение", "PRO:rel": "относительное местоимение", "PRO:int": "вопросительное местоимение",
        "ADJ:num": "числительное", "ADJ:pos": "притяжательное прилагательное", "ADJ:dem": "указательное прилагательное",
        "ADJ:ind": "неопределённое прилагательное", "ADJ:int": "вопросительное прилагательное",
    ]

    var body: some View {
        let found = library.grammar.analyses(of: query)
        if found.isEmpty {
            // A phrase from the lessons ("par cœur") has no forms, but it is still a known entry.
            if let entry = library.entry(for: query) {
                List { lessonSection(entry, heading: entry.word.m, ipa: entry.word.ipa) }
            } else {
                ContentUnavailableView("Нет в словаре", systemImage: "questionmark.circle",
                    description: Text("Слово «\(query)» не найдено. Проверьте написание и диакритические знаки: é, è, ç."))
            }
        } else {
            let current = found[min(choice, found.count - 1)]
            let paradigm = current.analysis.wordClass.flatMap { library.grammar.paradigm(lemma: current.analysis.lemma, as: $0) }
            List {
                if found.count > 1 {
                    Picker("Значение", selection: $choice) {
                        ForEach(Array(found.enumerated()), id: \.offset) { index, item in
                            Text("\(item.analysis.lemma) · \(WordAnalysisBody.partsOfSpeech[item.analysis.pos] ?? item.analysis.pos)").tag(index)
                        }
                    }
                }
                header(current.analysis, paradigm: paradigm)
                facts(current, paradigm: paradigm)
                if let paradigm, !paradigm.sets.isEmpty { forms(paradigm, typed: Lexicon.key(current.form)) }
                examplesSection(lemma: current.analysis.lemma, form: current.form)
                if let paradigm, !paradigm.sets.isEmpty {
                    Section {
                        Button {
                            var generator = SystemRandomNumberGenerator()
                            let questions = Drill.questions(from: [paradigm], count: 8, using: &generator)
                            if !questions.isEmpty { drill = DrillRequest(title: paradigm.lemma, questions: questions) }
                        } label: {
                            Label("Тренировать формы", systemImage: "square.grid.2x2")
                        }
                    }
                }
            }
            .fullScreenCover(item: $drill) { DrillSessionView(request: $0) }
            // The «Слово» tool reuses this view for the next word: start from its own defaults.
            .onChange(of: query) {
                choice = 0
                tense = nil
            }
            .onChange(of: choice) { tense = nil }
        }
    }

    private func header(_ analysis: Analysis, paradigm: Paradigm?) -> some View {
        let base = paradigm?.base ?? library.lexicon.entry(for: analysis.lemma)?.pronunciations.first ?? Pronunciation(marked: analysis.lemma, ipa: "")
        return Group {
            if let entry = library.entry(for: analysis.lemma) {
                lessonSection(entry, heading: base.marked, ipa: base.ipa)
            } else {
                Section {
                    title(base.marked, plain: analysis.lemma, ipa: base.ipa)
                    if let translation = library.translation(of: analysis.lemma) { Text(translation) }
                }
            }
        }
    }

    /// The word large, its sound and level, with the buttons to hear it and to star it.
    private func title(_ marked: String?, plain: String, ipa: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                MarkedText(marked: marked, plain: plain, style: .largeTitle)
                HStack(spacing: 8) {
                    if !ipa.isEmpty { Text("[\(ipa)]").font(.body).foregroundStyle(.secondary) }
                    if let level = library.level(of: plain) { LevelTag(level: level) }
                }
            }
            Spacer()
            SpeakButton(text: marked ?? plain)
            FavoriteButton(word: Word(fr: plain, m: marked, ipa: ipa, ru: library.translation(of: plain) ?? ""))
        }
        .padding(.vertical, 4)
    }

    /// Head of the screen for a word the lessons teach: translation, lesson, card status.
    private func lessonSection(_ entry: Entry, heading: String?, ipa: String) -> some View {
        Section {
            title(heading, plain: entry.word.fr, ipa: ipa)
            Text(entry.word.ru)
            LabeledContent("Карточка") { Text(store.status(of: entry).label).foregroundStyle(store.status(of: entry).color) }
            Button("Открыть урок \(entry.lesson)") {
                navigator.push(.lesson(entry.lesson))
            }
        }
    }

    private func facts(_ found: (form: String, analysis: Analysis), paradigm: Paradigm?) -> some View {
        let analysis = found.analysis
        var form: [String] = []
        if analysis.gender == "m" { form.append("мужской род") }
        if analysis.gender == "f" { form.append("женский род") }
        if analysis.number == "s" { form.append("ед. число") }
        if analysis.number == "p" { form.append("мн. число") }
        form += analysis.tags.sorted { WordAnalysisBody.rank($0) < WordAnalysisBody.rank($1) }.map(WordAnalysisBody.describe)
        return Section("О слове") {
            if let paradigm {
                ForEach(Array(paradigm.facts.enumerated()), id: \.offset) { _, fact in
                    LabeledContent(fact.label) {
                        if fact.isFrench { MarkedText(marked: fact.value) } else { Text(fact.value) }
                    }
                }
            } else {
                LabeledContent("Часть речи", value: WordAnalysisBody.partsOfSpeech[analysis.pos] ?? analysis.pos)
            }
            // "ses" is listed as "son" only when the form itself is not: try the form first.
            if let use = library.reference.use(of: found.form, pos: analysis.pos) ?? library.reference.use(of: analysis.lemma, pos: analysis.pos) {
                LabeledContent("Для чего") { Text(use).multilineTextAlignment(.trailing) }
            }
            if Lexicon.key(found.form) != Lexicon.key(analysis.lemma) || !form.isEmpty {
                LabeledContent("Форма «\(found.form)»", value: form.isEmpty ? "начальная" : form.joined(separator: "; "))
            }
            let marks = paradigm?.base.marked ?? ""
            let silent = Markup.letters(of: .silent, in: marks).joined(separator: ", ")
            let nasal = Markup.letters(of: .nasal, in: marks).joined(separator: ", ")
            if !silent.isEmpty { LabeledContent("Немые буквы", value: silent) }
            if !nasal.isEmpty { LabeledContent("Носовые гласные", value: nasal) }
        }
    }

    private static let moods = [("ind:pre", "Présent"), ("ind:imp", "Imparfait"), ("ind:fut", "Futur"), ("ind:pas", "Passé simple"),
                                ("cnd:pre", "Conditionnel"), ("sub:pre", "Subjonctif présent"), ("sub:imp", "Subjonctif imparfait"),
                                ("imp:pre", "Impératif")]

    /// Tenses in the order of the forms table, so that "buvons" reads «Présent, мы; Impératif, мы».
    private static func rank(_ tag: String) -> Int {
        moods.firstIndex { tag.hasPrefix($0.0) } ?? moods.count
    }

    /// "ind:pre:1p" → «Présent, мы».
    private static func describe(_ tag: String) -> String {
        let moods = Dictionary(uniqueKeysWithValues: Self.moods)
        let persons = ["1s": "я", "2s": "ты", "3s": "он, она", "1p": "мы", "2p": "вы", "3p": "они"]
        let parts = tag.split(separator: ":").map(String.init)
        switch tag {
        case "inf": return "инфинитив"
        case "par:pas": return "причастие прошедшего времени"
        case "par:pre": return "причастие настоящего времени"
        default:
            guard parts.count == 3, let mood = moods["\(parts[0]):\(parts[1])"] else { return tag }
            return "\(mood), \(persons[parts[2]] ?? parts[2])"
        }
    }

    private static let log = Logger(subsystem: "io.github.oniluni.french", category: "examples")

    /// Sentences from Tatoeba, those with the typed form first.
    @ViewBuilder private func examplesSection(lemma: String, form: String) -> some View {
        let found: [Example] = {
            do {
                return Array(try library.examples.of(lemma: lemma, preferring: form).prefix(6))
            } catch {
                WordAnalysisBody.log.error("Broken examples line for \(lemma, privacy: .public): \(String(describing: error), privacy: .public)")
                return []
            }
        }()
        if !found.isEmpty {
            Section {
                ForEach(Array(found.enumerated()), id: \.offset) { _, example in
                    Button {
                        speech.speak(example.fr)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            MarkedText(marked: readerMarks(example.fr), plain: example.fr)
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                            Text(example.ru).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    // Plain: the translation keeps its own colour instead of the tint.
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("example")
                    .accessibilityHint("Прослушать")
                }
            } header: {
                Text("Примеры")
            }
        }
    }

    /// Marks for a sentence outside the lessons, if the dictionary knows every word of it.
    private func readerMarks(_ sentence: String) -> String? {
        let words = library.reader.read(sentence)
        return words.allSatisfy(\.isKnown) ? words.marked : nil
    }

    private func forms(_ paradigm: Paradigm, typed: String) -> some View {
        let holdingTyped = paradigm.sets.firstIndex { $0.forms.contains { Lexicon.key($0.bodyPlain) == typed } } ?? 0
        let shown = min(tense ?? holdingTyped, paradigm.sets.count - 1)
        let set = paradigm.sets[shown]
        let labels = paradigm.wordClass.cellLabels
        return Section {
            if paradigm.sets.count > 1 {
                Picker("Набор форм", selection: Binding { shown } set: { tense = $0 }) {
                    ForEach(Array(paradigm.sets.enumerated()), id: \.offset) { index, item in Text(item.name).tag(index) }
                }
                .pickerStyle(.segmented)
            }
            ForEach(Array(set.forms.enumerated()), id: \.offset) { _, form in
                let isTyped = Lexicon.key(form.bodyPlain) == typed
                Button {
                    speech.speak(form.marked)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(labels[form.cell]).font(.subheadline).foregroundStyle(.secondary).frame(width: 118, alignment: .leading)
                        MarkedText(marked: form.marked, style: .title3)
                        Spacer(minLength: 8)
                        Text("[\(form.ipa)]").font(Theme.ipa).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Color.primary)
                }
                .listRowBackground(isTyped ? Theme.accentSoft : nil)
                .accessibilityAddTraits(isTyped ? .isSelected : [])
            }
            if set.name == "Présent", let note = library.content.verbNotes[paradigm.lemma] {
                InlineText(md: note).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text(paradigm.sets.count > 1 ? "Формы" : set.name)
        }
    }
}
