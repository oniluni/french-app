import FrenchCore
import SwiftUI

/// A word pushed from the dictionary or the reference: the same body as the «Слово» tool,
/// with the star of «Избранное» in the navigation bar.
struct WordAnalysisView: View {
    let query: String

    @Environment(Library.self) private var library

    var body: some View {
        Screen {
            WordAnalysisBody(query: query)
        }
        .navigationTitle("Разбор слова")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(word: favoriteWord)
            }
        }
    }

    private var favoriteWord: Word {
        let analyses = library.grammar.analyses(of: query)
        let lemma = analyses.first?.analysis.lemma ?? query
        let pronunciation = library.lexicon.entry(for: lemma)?.pronunciations.first
        return Word(fr: lemma, m: pronunciation?.marked, ipa: pronunciation?.ipa ?? "",
                    ru: library.translation(of: lemma) ?? "")
    }
}

/// The word card: meaning, what it is, its forms and examples.
struct WordAnalysisBody: View {
    let query: String

    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator
    @Environment(Speech.self) private var speech

    @State private var choice = 0
    @State private var tense: Int?
    @State private var drill: DrillRequest?

    private static let partsOfSpeech: [String: String] = [
        "NOM": "существительное", "VER": "глагол", "ADJ": "прилагательное",
        "ADV": "наречие", "PRE": "предлог", "CON": "союз", "ONO": "междометие",
        "ART:def": "артикль", "ART:ind": "артикль",
        "PRO:per": "местоимение", "PRO:dem": "местоимение", "PRO:ind": "местоимение",
        "PRO:pos": "местоимение", "PRO:rel": "местоимение", "PRO:int": "местоимение",
        "ADJ:num": "числительное", "ADJ:pos": "прилагательное", "ADJ:dem": "прилагательное",
        "ADJ:ind": "прилагательное", "ADJ:int": "прилагательное",
    ]

    var body: some View {
        let found = library.grammar.analyses(of: query)
        if found.isEmpty {
            if let entry = library.entry(for: query) {
                VStack(spacing: 0) {
                    header(entry: entry)
                    facts(entry: entry, analysis: nil, paradigm: nil)
                    openButton(entry: entry, category: nil)
                }
            }
        } else {
            let index = min(choice, found.count - 1)
            let current = found[index]
            let paradigm = current.analysis.wordClass.flatMap {
                library.grammar.paradigm(lemma: current.analysis.lemma, as: $0)
            }
            let entry = library.entry(for: current.form) ?? library.entry(for: current.analysis.lemma)
            let category = library.reference.categories.first {
                $0.words.contains { Lexicon.key($0.fr) == Lexicon.key(current.form) }
            }
            VStack(spacing: 0) {
                if found.count > 1 {
                    senses(found)
                }
                header(current: current, entry: entry, paradigm: paradigm)
                facts(entry: entry, analysis: current, paradigm: paradigm)
                use(analysis: current)
                openButton(entry: entry, category: category)
                forms(paradigm: paradigm, analysis: current.analysis)
                examples(analysis: current.analysis)
            }
            .onChange(of: query) { _, _ in
                choice = 0
                tense = nil
            }
            .onChange(of: choice) { _, _ in
                tense = nil
            }
        }
    }

    // MARK: Senses

    private func senses(_ found: [(form: String, analysis: Analysis)]) -> some View {
        VStack(spacing: 0) {
            Text("«\(query)» — это \(found.count) разных слова")
                .font(Theme.subhead)
                .foregroundStyle(Theme.t2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            InlineSegments(
                options: found.enumerated().map { index, item in
                    (value: index, title: senseTitle(item, index: index, of: found))
                },
                selection: $choice
            )
            .padding(.top, 8)
        }
    }

    private func senseTitle(_ item: (form: String, analysis: Analysis), index: Int, of found: [(form: String, analysis: Analysis)]) -> String {
        let translation = library.translation(of: item.analysis.lemma)
        var title = translation.map { "\(item.analysis.lemma) · \($0)" } ?? item.analysis.lemma
        if index > 0, found.first?.analysis.lemma == item.analysis.lemma {
            title += " · \(Self.partsOfSpeech[item.analysis.pos] ?? item.analysis.pos)"
        }
        return title
    }

    // MARK: Header

    private func header(current: (form: String, analysis: Analysis), entry: Entry?, paradigm: Paradigm?) -> some View {
        let base = paradigm?.base ?? library.lexicon.entry(for: current.analysis.lemma)?.pronunciations.first
            ?? Pronunciation(marked: current.analysis.lemma, ipa: "")
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        MarkedText(marked: base.marked, plain: current.analysis.lemma,
                                   size: 40, weight: .semibold)
                        if !base.ipa.isEmpty {
                            Text("[\(base.ipa)]").font(Theme.ipa(17)).foregroundStyle(Theme.t2)
                        }
                    }
                    Spacer(minLength: 0)
                    SpeakButton(text: base.marked, kind: .plain)
                }
                let translation = entry.flatMap { $0.word.ru.isEmpty ? nil : $0.word.ru }
                    ?? library.translation(of: current.analysis.lemma)
                if let translation, !translation.isEmpty {
                    Text(translation).font(Theme.bodyMedium).foregroundStyle(Theme.t2)
                }
                HStack(spacing: 6) {
                    Chip(text: Self.partsOfSpeech[current.analysis.pos] ?? current.analysis.pos, tone: .neutral)
                    if let level = library.level(of: current.analysis.lemma) {
                        LevelTag(level: level)
                    }
                    if let entry {
                        let status = store.status(of: entry)
                        Chip(text: status.label, tone: status.tone)
                    }
                }
            }
            .padding(16)
        }
    }

    private func header(entry: Entry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        MarkedText(marked: entry.word.m, plain: entry.word.fr, size: 40, weight: .semibold)
                        if !entry.word.ipa.isEmpty {
                            Text("[\(entry.word.ipa)]").font(Theme.ipa(17)).foregroundStyle(Theme.t2)
                        }
                    }
                    Spacer(minLength: 0)
                    SpeakButton(text: entry.word.m ?? entry.word.fr, kind: .plain)
                }
                if !entry.word.ru.isEmpty {
                    Text(entry.word.ru).font(Theme.bodyMedium).foregroundStyle(Theme.t2)
                }
                HStack(spacing: 6) {
                    if !entry.word.pos.isEmpty {
                        Chip(text: entry.word.pos, tone: .neutral)
                    }
                    if let level = library.level(of: entry.word.fr) {
                        LevelTag(level: level)
                    }
                    let status = store.status(of: entry)
                    Chip(text: status.label, tone: status.tone)
                }
            }
            .padding(16)
        }
    }

    // MARK: About

    @ViewBuilder private func facts(entry: Entry?, analysis: (form: String, analysis: Analysis)?, paradigm: Paradigm?) -> some View {
        let hasFacts = !(paradigm?.facts.isEmpty ?? true) || analysis != nil
        if hasFacts {
            SectionHeader(title: "О слове")
            Card {
                if let paradigm {
                    ForEach(Array(paradigm.facts.enumerated()), id: \.offset) { _, fact in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(fact.label).font(Theme.bodyMedium)
                            Spacer(minLength: 8)
                            if fact.isFrench {
                                MarkedText(marked: fact.value, plain: Markup.plain(fact.value),
                                           size: 16, weight: .medium)
                            } else {
                                Text(fact.value).font(Theme.bodyMedium)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                } else if let analysis {
                    infoRow("Часть речи", Self.partsOfSpeech[analysis.analysis.pos] ?? analysis.analysis.pos)
                }
                if let analysis, Lexicon.key(analysis.form) != Lexicon.key(analysis.analysis.lemma) {
                    infoRow("Форма", analysis.form)
                }
                if let paradigm {
                    let silent = Markup.letters(of: .silent, in: paradigm.base.marked)
                    if !silent.isEmpty { infoRow("Немые буквы", silent.joined(separator: ", ")) }
                    let nasal = Markup.letters(of: .nasal, in: paradigm.base.marked)
                    if !nasal.isEmpty { infoRow("Носовые гласные", nasal.joined(separator: ", ")) }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(Theme.bodyMedium)
            Spacer(minLength: 8)
            Text(value).font(Theme.bodyMedium).foregroundStyle(Theme.t2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Use

    @ViewBuilder private func use(analysis: (form: String, analysis: Analysis)) -> some View {
        let text = library.reference.use(of: analysis.form, pos: analysis.analysis.pos)
            ?? library.reference.use(of: analysis.analysis.lemma, pos: analysis.analysis.pos)
            ?? library.reference.categories.flatMap(\.words).first {
                Lexicon.key($0.fr) == Lexicon.key(analysis.form)
            }?.use
        if let text, !text.isEmpty {
            SectionHeader(title: "Для чего")
            Card {
                Text(text).font(Theme.subhead).foregroundStyle(Theme.t2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    // MARK: Lesson

    @ViewBuilder private func openButton(entry: Entry?, category: ReferenceCategory?) -> some View {
        if let entry {
            Button {
                navigator.push(.lesson(entry.lesson))
            } label: {
                HStack {
                    Text("Открыть урок \(entry.lesson)")
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }
            }
            .buttonStyle(.pill(.quiet))
            .padding(.top, 16)
        } else if let category {
            Button {
                navigator.push(.category(category.id))
            } label: {
                HStack {
                    Text("Открыть раздел «\(category.title)»")
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }
            }
            .buttonStyle(.pill(.quiet))
            .padding(.top, 16)
        }
    }

    // MARK: Forms

    @ViewBuilder private func forms(paradigm: Paradigm?, analysis: Analysis) -> some View {
        if let paradigm, !paradigm.sets.isEmpty {
            let typedSet = paradigm.sets.firstIndex { set in
                set.forms.contains {
                    Lexicon.key($0.bodyPlain) == Lexicon.key(query) || Lexicon.key($0.plain) == Lexicon.key(query)
                }
            }
            let shown = min(tense ?? typedSet ?? 0, paradigm.sets.count - 1)
            let set = paradigm.sets[shown]
            let typedForm = typedSet == shown ? query : ""
            VStack(spacing: 0) {
                SectionHeader(title: "Формы", trailing: formsNote(paradigm, analysis: analysis), trailingMono: false)
                if paradigm.sets.count > 1 {
                    InlineSegments(
                        options: paradigm.sets.enumerated().map { (value: $0.offset, title: $0.element.name) },
                        selection: Binding(get: { shown }, set: { tense = $0 })
                    )
                    .padding(.bottom, 8)
                }
                if paradigm.wordClass == .verb {
                    Card {
                        ForEach(Array(set.forms.enumerated()), id: \.offset) { _, form in
                            formRow(form, label: paradigm.wordClass.cellLabels[form.cell],
                                    isTyped: !typedForm.isEmpty && isTyped(form, key: typedForm))
                        }
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ], spacing: 8) {
                        ForEach(Array(set.forms.enumerated()), id: \.offset) { _, form in
                            formCell(form, label: paradigm.wordClass.cellLabels[form.cell],
                                     isTyped: !typedForm.isEmpty && isTyped(form, key: typedForm))
                        }
                    }
                }
                if paradigm.wordClass == .verb, let note = library.content.verbNotes[paradigm.lemma] {
                    Callout { Text(note) }.padding(.top, 8)
                }
                Button {
                    var generator = SystemRandomNumberGenerator()
                    let questions = Drill.questions(from: [paradigm], count: 8, using: &generator)
                    drill = DrillRequest(title: "Формы", questions: questions)
                } label: {
                    Label("Тренировать формы", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.pill(.primary))
                .padding(.top, 12)
            }
            .fullScreenCover(item: $drill) { DrillSessionView(request: $0) }
        }
    }

    private func formsNote(_ paradigm: Paradigm, analysis: Analysis) -> String? {
        if paradigm.wordClass == .verb {
            return paradigm.facts.first { $0.label == "Часть речи" }?.value
        }
        if paradigm.sets.count > 1 { return "род: мужской и женский" }
        if paradigm.wordClass == .adjective { return "род и число" }
        return nil
    }

    private func isTyped(_ form: Paradigm.Form, key: String) -> Bool {
        Lexicon.key(form.bodyPlain) == Lexicon.key(key) || Lexicon.key(form.plain) == Lexicon.key(key)
    }

    private func formRow(_ form: Paradigm.Form, label: String, isTyped: Bool) -> some View {
        Button {
            speech.speak(form.marked)
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(Theme.sans(13, .medium, relativeTo: .footnote))
                    .foregroundStyle(isTyped ? Theme.acc : Theme.t2)
                    .frame(width: 92, alignment: .leading)
                MarkedText(marked: form.marked, plain: form.plain, size: 19, weight: .medium)
                Spacer(minLength: 8)
                if !form.ipa.isEmpty {
                    Text("[\(form.ipa)]").font(Theme.ipa(13)).foregroundStyle(Theme.t2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(isTyped ? Theme.accSoft : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formCell(_ form: Paradigm.Form, label: String, isTyped: Bool) -> some View {
        Button {
            speech.speak(form.marked)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(Theme.caption1.weight(.medium)).foregroundStyle(Theme.t2)
                MarkedText(marked: form.marked, plain: form.plain, size: 19, weight: .medium)
                if !form.ipa.isEmpty {
                    Text("[\(form.ipa)]").font(Theme.ipa(13)).foregroundStyle(Theme.t2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isTyped ? Theme.accSoft : Theme.s1,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isTyped ? Theme.accLine : Theme.line)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Examples

    @ViewBuilder private func examples(analysis: Analysis) -> some View {
        let found = (try? library.examples.of(lemma: analysis.lemma, preferring: query)) ?? []
        let items = Array(found.prefix(6))
        if !items.isEmpty {
            SectionHeader(title: "Примеры", trailing: "\(items.count)")
            Card {
                ForEach(Array(items.enumerated()), id: \.offset) { _, example in
                    Button {
                        speech.speak(example.fr)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            MarkedText(marked: readerMarks(example.fr), plain: example.fr,
                                       size: 19, weight: .medium)
                            Text(example.ru).font(Theme.subhead).foregroundStyle(Theme.t2)
                            Text(example.src.hasPrefix("T") ? "Tatoeba" : example.src)
                                .font(Theme.caption1).foregroundStyle(Theme.t3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("example")
                    .accessibilityHint("Прослушать")
                }
            }
        }
    }

    private func readerMarks(_ sentence: String) -> String? {
        let words = library.reader.read(sentence)
        return words.allSatisfy(\.isKnown) ? words.marked : nil
    }

}
