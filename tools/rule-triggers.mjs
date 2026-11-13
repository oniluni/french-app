// When a rule of the lessons applies to a phrase in the reader: one trigger per rule, by rule id,
// with the title the rule must have, so that a changed vault fails the import instead of
// linking the wrong rule.
//
// Rules of the «Правила чтения» pages are linked row by row through `readingRules` and need no
// trigger here; «Примечания» (remarks on words and common mistakes) are not rules of their own.
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
  // Произношение: the sounds of the lesson, how they are spelled, syllables and length
  '1-r1': { title: 'Звуки [a], [l], [ʁ], [f], [v], [k], [ɡ], [t], [d], [s], [z]', trigger: { ipa: ['a', 'l', 'ʁ', 'f', 'v', 'k', 'ɡ', 't', 'd', 's', 'z'] } },
  '2-r1': { title: 'Звуки [ɛ], [ʃ], [ʒ], [p], [b], [m], [n]', trigger: { ipa: ['ɛ', 'ʃ', 'ʒ', 'p', 'b', 'm', 'n'] } },
  '2-r2': { title: 'Как пишется [ɛ]', trigger: { ipa: ['ɛ'] } },
  // The quality of e, o and eu depends on whether the syllable is open or closed.
  '2-r3': { title: 'Открытый и закрытый слог', trigger: { ipa: ['e', 'ɛ', 'o', 'ɔ', 'ø', 'œ'] } },
  // Rhythmic length is not in the reader's sound; historical length is spelled with a circumflex.
  '2-r4': { title: 'Долгота гласных', trigger: { letters: ['â', 'ê', 'î', 'ô', 'û'] } },
  '3-r1': { title: 'Звук [e]', trigger: { ipa: ['e'] } },
  '3-r2': { title: 'Как пишется [e]', trigger: { ipa: ['e'] } },
  '4-r1': { title: 'Звуки [i], [j]', trigger: { ipa: ['i', 'j'] } },
  '4-r2': { title: 'Как пишутся [i] и [j]', trigger: { ipa: ['i', 'j'] } },
  // French keeps a final voiced consonant voiced, unlike Russian: rose [ʁoz].
  '4-r3': { title: 'Согласные на конце слова и на стыке слов', trigger: { any: [{ doubled: true }, { finalSound: ['b', 'd', 'ɡ', 'v', 'z', 'ʒ'] }] } },
  '5-r1': { title: 'Звуки [œ], [ə]', trigger: { ipa: ['œ', 'ə'] } },
  '5-r2': { title: 'Как пишутся [œ] и [ə]', trigger: { ipa: ['œ', 'ə'] } },
  '5-r3': { title: 'Когда беглое [ə] выпадает', trigger: { droppedSchwa: true } },
  '6-r1': { title: 'Звук [ø]', trigger: { ipa: ['ø'] } },
  '6-r2': { title: '[ø] или [œ]', trigger: { ipa: ['ø', 'œ'] } },
  '7-r1': { title: 'Звук [y]', trigger: { ipa: ['y'] } },
  '8-r1': { title: 'Звук [ɔ]', trigger: { ipa: ['ɔ'] } },
  '9-r1': { title: 'Звук [o]', trigger: { ipa: ['o'] } },
  '9-r2': { title: '[o] или [ɔ]', trigger: { ipa: ['o', 'ɔ'] } },
  '10-r1': { title: 'Звуки [u], [ɲ]', trigger: { ipa: ['u', 'ɲ'] } },
  '11-r1': { title: 'Звук [ɔ̃]', trigger: { ipa: ['ɔ̃'] } },
  '12-r1': { title: 'Звук [ɛ̃]', trigger: { ipa: ['ɛ̃'] } },
  '13-r1': { title: 'Звук [œ̃]', trigger: { ipa: ['œ̃'] } },
  '14-r1': { title: 'Звуки [ɑ], [ɑ̃]', trigger: { ipa: ['ɑ', 'ɑ̃'] } },
  '15-r1': { title: 'Звук [w]', trigger: { ipa: ['w'] } },

  // Чтение: pages whose rows give no reading rule, or that say more than their rows
  '1-r3': { title: 'Речевой поток', trigger: { minWords: 3 } },
  '8-r2': { title: 'Правила чтения', trigger: { spelling: { letters: 'ti', sound: 'sj' } } },

  // Грамматика
  '1-r4': { title: 'Порядок слов', trigger: { token: { pos: ['VER'] } } },
  '1-r5': { title: 'Знаменательные и служебные слова', trigger: { minWords: 3 } },
  '1-r6': { title: 'Артикль la', trigger: { token: { words: ['la'], pos: ['ART:def'] } } },
  '2-r6': { title: 'Местоимённые прилагательные: ma, ta, sa, cette', trigger: { token: { pos: ['ADJ:pos', 'ADJ:dem'] } } },
  '2-r7': { title: 'Глагол-связка être', trigger: { token: BE } },
  '2-r8': { title: "Оборот c'est и вопрос est-ce…?", trigger: { text: ["c'est", 'est-ce'] } },
  '3-r4': { title: 'Глаголы I группы', trigger: { token: { group: 1 } } },
  '3-r5': { title: 'Множественное число существительных', trigger: { token: { pos: ['NOM'], number: 'p' } } },
  '4-r6': { title: 'Порядок слов', trigger: { token: { pos: ['VER'] } } },
  '4-r7': { title: 'Названия городов без артикля', trigger: { properName: true } },
  '4-r8': { title: 'Глаголы III группы: 3-е лицо', trigger: { token: { group: 3, tags: ['ind:pre:3s', 'ind:pre:3p'] } } },
  '4-r9': { title: 'Вопрос к подлежащему: qui', trigger: { all: [{ question: true }, { token: { words: ['qui'] } }] } },
  '5-r5': { title: 'Притяжательные прилагательные и русское «свой»', trigger: { token: { pos: ['ADJ:pos'] } } },
  '5-r6': { title: 'Выпадение гласных (элизия)', trigger: { elision: true } },
  '5-r7': { title: 'Определённый артикль', trigger: { token: { pos: ['ART:def'] } } },
  '5-r8': { title: 'Профессия без артикля', trigger: { sequence: [BE, { pos: ['NOM'] }] } },
  '5-r9': { title: '1-е лицо единственного числа', trigger: { sequence: [{ words: ['je', "j'"] }, { pos: ['VER'], tags: ['ind:pre:1s'] }] } },
  '5-r10': { title: 'Отрицание ne… pas', trigger: { any: [
    { sequence: [{ words: ['ne', "n'"] }, { pos: ['VER'] }, { words: ['pas', 'jamais', 'plus', 'rien'] }] },
    { sequence: [{ words: ['ne', "n'"] }, { pos: ['PRO:per'] }, { pos: ['VER'] }, { words: ['pas', 'jamais', 'plus', 'rien'] }] },
  ] } },
  '5-r11': { title: 'Предлог de', trigger: { token: { words: ['de', "d'"] } } },
  '5-r12': { title: 'Предлог à', trigger: { token: { words: ['à'] } } },
  '6-r4': { title: 'Время: il est', trigger: { text: ['il est', 'est-il'] } },
  '6-r5': { title: 'Прилагательные: род и число', trigger: { token: { pos: ['ADJ'] } } },
  '6-r6': { title: 'Место прилагательного', trigger: { any: [{ sequence: [{ pos: ['NOM'] }, { pos: ['ADJ'] }] }, { sequence: [{ pos: ['ADJ'] }, { pos: ['NOM'] }] }] } },
  '7-r2': { title: "Артикль после c'est", trigger: { any: [
    { sequence: [{ words: ["c'"] }, { words: ['est'] }, { pos: ['ART:def', 'ART:ind'] }] },
    { sequence: [{ words: ['ce'] }, { words: ['sont'] }, { pos: ['ART:def', 'ART:ind'] }] },
  ] } },
  '7-r3': { title: '2-е лицо единственного числа', trigger: { sequence: [{ words: ['tu'] }, { pos: ['VER'], tags: ['ind:pre:2s'] }] } },
  '7-r4': { title: 'Национальность без артикля', trigger: { sequence: [BE, { words: NATIONALITIES }] } },
  '7-r5': { title: 'Вопрос', trigger: { question: true } },
  '7-r6': { title: 'Глаголы III группы в единственном числе', trigger: { token: { group: 3, tags: ['ind:pre:1s', 'ind:pre:2s', 'ind:pre:3s'] } } },
  '8-r3': { title: 'Вопрос «что?» к прямому дополнению', trigger: { all: [{ question: true }, { token: { words: ['que', "qu'"] } }] } },
  '8-r4': { title: 'Профессия с определением', trigger: { sequence: [BE, { pos: ['ART:def', 'ART:ind'] }, { pos: ['NOM'] }] } },
  '8-r5': { title: 'Слитный артикль du, des', trigger: { token: { words: ['du', 'des'] } } },
  '9-r4': { title: 'Слитный артикль au, aux', trigger: { token: { words: ['au', 'aux'] } } },
  '9-r5': { title: 'Безличные глаголы', trigger: { text: ['il faut', 'il fait', 'il pleut', 'il neige', 'faut-il'] } },
  '9-r6': { title: 'Местоимения le, la, les', trigger: { sequence: [{ words: ['le', 'la', 'les', "l'"], pos: ['PRO:per'] }, { pos: ['VER'] }] } },
  '9-r7': { title: 'Место наречия', trigger: { token: { pos: ['ADV'] } } },
  '9-r8': { title: 'Предлог jusque «до»', trigger: { token: { words: ['jusque', "jusqu'"] } } },
  '9-r9': { title: 'Инверсия после прямой речи', trigger: { token: { lemma: ['dire', 'demander', 'répondre', 'répliquer'], afterPunctuation: true } } },
  '10-r3': { title: '2-е лицо множественного числа', trigger: { any: [
    { sequence: [{ words: ['vous'] }, { pos: ['VER'], tags: ['ind:pre:2p'] }] },
    { token: { pos: ['VER'], tags: ['imp:pre:2p'], first: true } },
  ] } },
  '10-r4': { title: 'Вопрос с où «где, куда»', trigger: { token: { words: ['où'] } } },
  '10-r5': { title: 'Когда нужен определённый артикль', trigger: { token: { pos: ['ART:def'] } } },
  '10-r6': { title: 'tout «весь»', trigger: { token: { words: ['tout', 'toute', 'tous', 'toutes'] } } },
  '10-r7': { title: 'à — куда, de — откуда', trigger: { all: [{ token: { words: ['à', 'au', 'aux'] } }, { token: { words: ['de', "d'", 'du', 'des'] } }] } },
  '11-r3': { title: "c'est — ce sont", trigger: { text: ["c'est", 'ce sont'] } },
  '11-r4': { title: 'Местоимение on', trigger: { token: { words: ['on'] } } },
  '11-r5': { title: 'Глаголы I группы в настоящем времени', trigger: { token: { group: 1, tags: ['ind:pre'] } } },
  '11-r6': { title: 'Повелительное наклонение I группы', trigger: { token: { group: 1, tags: ['imp:pre'], first: true } } },
  '12-r2': { title: 'Притяжательные прилагательные', trigger: { token: { pos: ['ADJ:pos'] } } },
  '12-r3': { title: 'Указательные прилагательные', trigger: { token: { words: ['ce', 'cet', 'cette', 'ces'], pos: ['ADJ:dem'] } } },
  '12-r4': { title: 'Глаголы III группы: общие сведения', trigger: { token: { group: 3 } } },
  '12-r5': { title: 'lire и écrire', trigger: { token: { lemma: ['lire', 'écrire', 'relire', 'décrire'] } } },
  '12-r6': { title: 'Ближайшее будущее: aller + инфинитив', trigger: { sequence: [{ lemma: ['aller'], tags: ['ind:pre'] }, { pos: ['VER'], tags: ['inf'] }] } },
  '13-r2': { title: 'Неопределённый артикль', trigger: { token: { pos: ['ART:ind'] } } },
  '13-r3': { title: 'Оборот il y a', trigger: { text: ['il y a', "il n'y a", 'y a-t-il'] } },
  '13-r4': { title: 'être или il y a', trigger: { text: ['il y a', "il n'y a", 'y a-t-il'] } },
  '13-r5': { title: 'aller и глаголы типа venir', trigger: { token: { lemma: [
    'aller', 'venir', 'revenir', 'devenir', 'tenir', 'obtenir', 'retenir', 'prévenir', 'appartenir', 'soutenir', 'contenir',
  ] } } },
  '13-r6': { title: 'Вежливое желание: je voudrais', trigger: { text: ['je voudrais', 'voudriez-vous', 'nous voudrions'] } },
  '14-r3': { title: 'Наречия en «оттуда» и y «туда, там»', trigger: { sequence: [{ words: ['en', 'y'] }, { pos: ['VER'] }] } },
  '14-r4': { title: 'Вопросы с quand и comment', trigger: { token: { words: ['quand', 'comment'] } } },
  '14-r5': { title: 'Глагол faire', trigger: { token: { lemma: ['faire'] } } },
  '15-r2': { title: 'Местоимение cela', trigger: { token: { words: ['cela', 'ça'] } } },
  '15-r3': { title: 'de после отрицания', trigger: { sequence: [{ words: ['pas', 'jamais', 'plus'] }, { words: ['de', "d'"] }] } },
  '15-r4': { title: 'de после слов количества', trigger: { sequence: [{ words: ['beaucoup', 'peu', 'assez', 'trop', 'combien', 'tant', 'autant'] }, { words: ['de', "d'"] }] } },
  '15-r5': { title: 'Вопрос с combien', trigger: { token: { words: ['combien'] } } },
  '15-r6': { title: 'Глагол avoir', trigger: { token: { lemma: ['avoir'] } } },
  '15-r7': { title: "C'est… qui", trigger: { all: [{ text: ["c'est", 'ce sont'] }, { token: { words: ['qui'] } }] } },
};

/**
 * Puts each trigger on its rule. Every rule of kind Произношение, Грамматика, or a «Чтение»
 * page without rows of its own, must have one with the right title: a vault that changed fails loudly.
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
