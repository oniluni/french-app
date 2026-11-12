// When a rule of the lessons applies to a phrase in the reader: one trigger per rule, by rule id,
// with the title the rule must have, so that a changed vault fails the import instead of
// linking the wrong rule.
//
// Rules of the «Правила чтения» pages are linked item by item through `readingRules` and need no
// trigger here; «Примечания» (text notes and common mistakes) are not rules of their own.
//
// Trigger language (evaluated by FrenchCore/RuleTriggers.swift):
//   { any: [t…] } { all: [t…] }                  combinators
//   { ipa: ['ɔ̃'] }                               a word has one of these sounds
//   { finalSound: ['z'] }                        a word ends in one of these sounds
//   { doubled: true }                            a word ends in the consonant the next one begins with
//   { droppedSchwa: true }                       a word has an e that is not pronounced inside it
//   { spelling: { letters: 'qu', sound: 'k' } }  a word spells these letters and has this sound
//   { letters: ['â', 'ê'] }                      a word has one of these letters
//   { text: ['il y a'] }                         the phrase contains these words, in this order
//   { question: true } { minWords: 3 }           the phrase is a question / has that many words
//   { properName: true }                         a capitalised word inside the sentence
//   { elision: true } { inversion: true }        l', j'… / a pronoun joined by a hyphen: "dit-il"
//   { token: pred } { sequence: [pred, pred…] }  one word / adjacent words matching predicates
//   pred: { words, lemma, pos, tags (prefixes), number: 'p', group: 1 | 3, first, afterPunctuation }

const BE = { lemma: ['être'] };
const NATIONALITIES = [
  'français', 'française', 'russe', 'anglais', 'anglaise', 'allemand', 'allemande', 'italien', 'italienne',
  'espagnol', 'espagnole', 'américain', 'américaine', 'polonais', 'polonaise', 'chinois', 'chinoise',
  'japonais', 'japonaise', 'belge', 'suisse', 'canadien', 'canadienne',
];

export const TRIGGERS = {
  // Произношение
  '1-1': { title: 'Гласный [a]', trigger: { ipa: ['a'] } },
  '1-2': { title: 'Согласный [l]', trigger: { ipa: ['l'] } },
  '1-3': { title: 'Согласный [ʁ] (в учебнике [r])', trigger: { ipa: ['ʁ'] } },
  '1-4': { title: 'Согласные [f], [v]', trigger: { ipa: ['f', 'v'] } },
  '1-5': { title: 'Согласные [k], [g]', trigger: { ipa: ['k', 'ɡ'] } },
  '1-6': { title: 'Согласные [t], [d]', trigger: { ipa: ['t', 'd'] } },
  '1-7': { title: 'Согласные [s], [z]', trigger: { ipa: ['s', 'z'] } },
  '2-1': { title: 'Гласный [ɛ]', trigger: { ipa: ['ɛ'] } },
  // The quality of e, o and eu depends on whether the syllable is open or closed.
  '2-2': { title: 'Открытый и закрытый слог', trigger: { ipa: ['e', 'ɛ', 'o', 'ɔ', 'ø', 'œ'] } },
  '2-3': { title: 'Историческая долгота', trigger: { letters: ['â', 'ê', 'î', 'ô', 'û'] } },
  '2-4': { title: 'Согласные [ʃ], [ʒ]', trigger: { ipa: ['ʃ', 'ʒ'] } },
  '2-5': { title: 'Согласные [p], [b]', trigger: { ipa: ['p', 'b'] } },
  '2-6': { title: 'Согласные [m], [n]', trigger: { ipa: ['m', 'n'] } },
  '3-1': { title: 'Гласный [e]', trigger: { ipa: ['e'] } },
  '4-1': { title: 'Гласный [i]', trigger: { ipa: ['i'] } },
  '4-2': { title: 'Полугласный [j]', trigger: { ipa: ['j'] } },
  '4-3': { title: 'Сдвоенные согласные на стыке слов', trigger: { doubled: true } },
  // French keeps a final voiced consonant voiced, unlike Russian: rose [ʁoz].
  '4-4': { title: 'Оглушение конечных согласных', trigger: { finalSound: ['b', 'd', 'ɡ', 'v', 'z', 'ʒ'] } },
  '5-1': { title: 'Гласный [œ]', trigger: { ipa: ['œ'] } },
  '5-2': { title: 'Гласный [ə] (беглое e)', trigger: { ipa: ['ə'] } },
  '5-3': { title: 'Когда [ə] выпадает и когда произносится', trigger: { droppedSchwa: true } },
  '6-1': { title: 'Гласный [ø]', trigger: { ipa: ['ø'] } },
  '7-1': { title: 'Гласный [y]', trigger: { ipa: ['y'] } },
  '8-1': { title: 'Гласный [ɔ]', trigger: { ipa: ['ɔ'] } },
  '9-1': { title: 'Гласный [o]', trigger: { ipa: ['o'] } },
  '10-1': { title: 'Гласный [u]', trigger: { ipa: ['u'] } },
  '10-2': { title: 'Согласный [ɲ]', trigger: { ipa: ['ɲ'] } },
  '11-1': { title: 'Носовой гласный [ɔ̃]', trigger: { ipa: ['ɔ̃'] } },
  '12-1': { title: 'Носовой гласный [ɛ̃]', trigger: { ipa: ['ɛ̃'] } },
  '13-1': { title: 'Носовой гласный [œ̃]', trigger: { ipa: ['œ̃'] } },
  '14-1': { title: 'Гласный [ɑ]', trigger: { ipa: ['ɑ'] } },
  '14-2': { title: 'Носовой гласный [ɑ̃]', trigger: { ipa: ['ɑ̃'] } },
  '15-1': { title: 'Полугласный [w]', trigger: { ipa: ['w'] } },

  // Чтение: pages without items of their own
  '1-9': { title: 'Речевой поток', trigger: { minWords: 3 } },
  '4-6': { title: 'Сочетание qu', trigger: { spelling: { letters: 'qu', sound: 'k' } } },
  '8-2': { title: 't в группе ti + гласный', trigger: { spelling: { letters: 'ti', sound: 'sj' } } },

  // Грамматика
  '1-10': { title: 'Строй французского предложения', trigger: { token: { pos: ['VER'] } } },
  '1-11': { title: 'Виды слов во французском языке', trigger: { minWords: 3 } },
  '1-12': { title: 'Артикль', trigger: { token: { pos: ['ART:def', 'ART:ind'] } } },
  '2-8': { title: 'Местоимённые прилагательные', trigger: { token: { pos: ['ADJ:pos', 'ADJ:dem'] } } },
  '2-9': { title: 'Глагол être «быть»', trigger: { token: BE } },
  '2-10': { title: "Оборот c'est", trigger: { text: ["c'est", 'est-ce'] } },
  '3-3': { title: 'Глаголы I группы', trigger: { token: { group: 1 } } },
  '3-4': { title: 'Множественное число существительных', trigger: { token: { pos: ['NOM'], number: 'p' } } },
  '4-7': { title: 'Порядок слов во французском предложении', trigger: { token: { pos: ['VER'] } } },
  '4-8': { title: 'Отсутствие артикля перед именами собственными', trigger: { properName: true } },
  '4-9': { title: '3-е лицо ед. и мн. числа глаголов III группы', trigger: { token: { group: 3, tags: ['ind:pre:3s', 'ind:pre:3p'] } } },
  '4-10': { title: 'Вопрос к подлежащему', trigger: { all: [{ question: true }, { token: { words: ['qui'] } }] } },
  '5-5': { title: 'Притяжательные прилагательные', trigger: { token: { pos: ['ADJ:pos'] } } },
  '5-6': { title: 'Выпадение гласных (элизия)', trigger: { elision: true } },
  '5-7': { title: 'Определённый артикль', trigger: { token: { pos: ['ART:def'] } } },
  '5-8': { title: 'Опущение артикля при существительном в роли именной части сказуемого', trigger: { sequence: [BE, { pos: ['NOM'] }] } },
  '5-9': { title: '1-е лицо единственного числа настоящего времени (I и III группа)', trigger: { sequence: [{ words: ['je', "j'"] }, { pos: ['VER'], tags: ['ind:pre:1s'] }] } },
  '5-10': { title: 'Отрицательная форма глагола', trigger: { any: [
    { sequence: [{ words: ['ne', "n'"] }, { pos: ['VER'] }, { words: ['pas', 'jamais', 'plus', 'rien'] }] },
    { sequence: [{ words: ['ne', "n'"] }, { pos: ['PRO:per'] }, { pos: ['VER'] }, { words: ['pas', 'jamais', 'plus', 'rien'] }] },
  ] } },
  '5-11': { title: 'Предлог de', trigger: { token: { words: ['de', "d'"] } } },
  '5-12': { title: 'Предлог à', trigger: { token: { words: ['à'] } } },
  '6-3': { title: 'Безличный оборот il est', trigger: { sequence: [{ words: ['il'] }, { words: ['est'] }, { pos: ['ADJ'] }] } },
  '6-4': { title: 'Имя прилагательное', trigger: { token: { pos: ['ADJ'] } } },
  '7-2': { title: "Употребление артикля после оборота c'est", trigger: { any: [
    { sequence: [{ words: ["c'"] }, { words: ['est'] }, { pos: ['ART:def', 'ART:ind'] }] },
    { sequence: [{ words: ['ce'] }, { words: ['sont'] }, { pos: ['ART:def', 'ART:ind'] }] },
  ] } },
  '7-3': { title: '2-е лицо единственного числа настоящего времени (I и III группа)', trigger: { sequence: [{ words: ['tu'] }, { pos: ['VER'], tags: ['ind:pre:2s'] }] } },
  '7-4': { title: 'Опущение артикля перед существительным, обозначающим национальность', trigger: { sequence: [BE, { words: NATIONALITIES }] } },
  '7-5': { title: 'Вопросительное предложение', trigger: { question: true } },
  '7-6': { title: 'Спряжение глаголов III группы в единственном числе', trigger: { token: { group: 3, tags: ['ind:pre:1s', 'ind:pre:2s', 'ind:pre:3s'] } } },
  '8-3': { title: 'Вопрос к прямому дополнению', trigger: { all: [{ question: true }, { token: { words: ['que', "qu'"] } }] } },
  '8-4': { title: 'Артикль перед существительным в роли именной части сказуемого', trigger: { sequence: [BE, { pos: ['ART:def', 'ART:ind'] }, { pos: ['NOM'] }] } },
  '8-5': { title: 'Слитный артикль с предлогом de', trigger: { token: { words: ['du', 'des'] } } },
  '9-3': { title: 'Слияние определённого артикля с предлогом à', trigger: { token: { words: ['au', 'aux'] } } },
  '9-4': { title: 'Безличные глаголы', trigger: { text: ['il faut', 'il fait', 'il pleut', 'il neige', 'faut-il'] } },
  '9-5': { title: 'Личные местоимения le, la, les', trigger: { sequence: [{ words: ['le', 'la', 'les', "l'"], pos: ['PRO:per'] }, { pos: ['VER'] }] } },
  '9-6': { title: 'Место наречия', trigger: { token: { pos: ['ADV'] } } },
  '9-7': { title: 'Предлог jusque', trigger: { token: { words: ['jusque', "jusqu'"] } } },
  '9-8': { title: 'Инверсия во вводном предложении', trigger: { token: { lemma: ['dire', 'demander', 'répondre', 'répliquer'], afterPunctuation: true } } },
  '10-4': { title: '2-е лицо множественного числа настоящего времени', trigger: { any: [
    { sequence: [{ words: ['vous'] }, { pos: ['VER'], tags: ['ind:pre:2p'] }] },
    { token: { pos: ['VER'], tags: ['imp:pre:2p'], first: true } },
  ] } },
  '10-5': { title: 'Вопросительное наречие où', trigger: { token: { words: ['où'] } } },
  '10-6': { title: 'Определённый артикль', trigger: { token: { pos: ['ART:def'] } } },
  '10-7': { title: 'Неопределённое прилагательное tout', trigger: { token: { words: ['tout', 'toute', 'tous', 'toutes'] } } },
  '10-8': { title: 'Предлоги à — de', trigger: { all: [{ token: { words: ['à', 'au', 'aux'] } }, { token: { words: ['de', "d'", 'du', 'des'] } }] } },
  '11-3': { title: "Конструкция c'est — ce sont", trigger: { text: ["c'est", 'ce sont'] } },
  '11-4': { title: 'Неопределённо-личное местоимение on', trigger: { token: { words: ['on'] } } },
  '11-5': { title: 'Спряжение глаголов I группы в настоящем времени', trigger: { token: { group: 1, tags: ['ind:pre'] } } },
  '11-6': { title: 'Повелительное наклонение глаголов I группы', trigger: { token: { group: 1, tags: ['imp:pre'], first: true } } },
  '12-2': { title: 'Притяжательные прилагательные', trigger: { token: { pos: ['ADJ:pos'] } } },
  '12-3': { title: 'Указательные прилагательные', trigger: { token: { words: ['ce', 'cet', 'cette', 'ces'], pos: ['ADJ:dem'] } } },
  '12-4': { title: 'Глаголы III группы', trigger: { token: { group: 3 } } },
  '12-5': { title: 'Спряжение глаголов lire и écrire', trigger: { token: { lemma: ['lire', 'écrire', 'relire', 'décrire'] } } },
  '13-2': { title: 'Неопределённый артикль', trigger: { token: { pos: ['ART:ind'] } } },
  '13-3': { title: 'Безличный оборот il y a', trigger: { text: ['il y a', "il n'y a", 'y a-t-il'] } },
  '13-4': { title: 'Спряжение глагола aller', trigger: { token: { lemma: ['aller'] } } },
  '13-5': { title: 'Спряжение глаголов типа venir', trigger: { token: { lemma: ['venir', 'revenir', 'devenir', 'tenir', 'obtenir', 'retenir', 'prévenir', 'appartenir', 'soutenir', 'contenir'] } } },
  '13-6': { title: 'Вежливое желание: je voudrais', trigger: { text: ['je voudrais', 'voudriez-vous', 'nous voudrions'] } },
  '14-4': { title: 'Наречия en, y', trigger: { sequence: [{ words: ['en', 'y'] }, { pos: ['VER'] }] } },
  '14-5': { title: 'Вопросительные наречия quand, comment', trigger: { token: { words: ['quand', 'comment'] } } },
  '14-6': { title: 'Спряжение глагола faire', trigger: { token: { lemma: ['faire'] } } },
  '15-2': { title: 'Местоимение cela', trigger: { token: { words: ['cela', 'ça'] } } },
  '15-3': { title: 'Опущение неопределённого артикля после отрицания', trigger: { sequence: [{ words: ['pas', 'jamais', 'plus'] }, { words: ['de', "d'"] }] } },
  '15-4': { title: 'Неупотребление артикля после количественных наречий', trigger: { sequence: [{ words: ['beaucoup', 'peu', 'assez', 'trop', 'combien', 'tant', 'autant'] }, { words: ['de', "d'"] }] } },
  '15-5': { title: 'Порядок слов в вопросе с combien', trigger: { token: { words: ['combien'] } } },
  '15-6': { title: 'Спряжение глагола avoir', trigger: { token: { lemma: ['avoir'] } } },
  '15-7': { title: "Самостоятельные местоимения moi, toi; конструкция c'est… qui", trigger: { any: [
    { token: { words: ['moi', 'toi', 'eux'] } },
    { text: ["c'est moi", "c'est toi", "c'est lui", "c'est elle"] },
  ] } },
};

/**
 * Puts each trigger on its rule. Every rule of kind Произношение, Грамматика, or a «Чтение»
 * page without items, must have one with the right title: a vault that changed fails loudly.
 */
export function attachTriggers(lessons, readingRules, triggers = TRIGGERS) {
  const itemized = new Set(readingRules.map((entry) => entry.rule));
  const missing = [];
  for (const rule of lessons.flatMap((lesson) => lesson.rules)) {
    const known = triggers[rule.id];
    if (known && known.title !== rule.title) {
      throw new Error(`Rule ${rule.id} is now «${rule.title}», but its trigger is for «${known.title}». Update tools/rule-triggers.mjs.`);
    }
    if (known) rule.trigger = known.trigger;
    else if (rule.kind !== 'Примечания' && !(rule.kind === 'Чтение' && itemized.has(rule.id))) missing.push(`${rule.id} «${rule.title}»`);
  }
  if (missing.length > 0) throw new Error(`Rules without a trigger in tools/rule-triggers.mjs: ${missing.join(', ')}`);
}
