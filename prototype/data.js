'use strict';
// Sample content for the prototype. Nothing here is computed: transcriptions are written by hand.
//
// Pronunciation markup inside French strings:
//   (x) silent letters   [x] nasal vowel   {x} consonant heard only in a liaison   ‿ liaison
// Text token: "marked|ipa|gloss|liaison consonant|rule id". A string without "|" is
// punctuation and attaches to the word before it.

const LESSONS = [
  { id: 1, fr: 'Bonjour !', ru: 'Приветствие и алфавит', progress: 1 },
  { id: 2, fr: 'Qui est-ce ?', ru: 'Знакомство', progress: 1 },
  { id: 3, fr: 'Les nombres', ru: 'Числа и возраст', progress: 1 },
  { id: 4, fr: 'Ma ville', ru: 'Город', progress: 1 },
  { id: 5, fr: 'Ma famille', ru: 'Семья', progress: 1 },
  { id: 6, fr: 'La maison', ru: 'Дом', progress: 1 },
  { id: 7, fr: 'Une journée à Paris', ru: 'Распорядок дня', progress: 0.6 },
  { id: 8, fr: 'Au café', ru: 'В кафе', progress: 0 },
  { id: 9, fr: 'Les courses', ru: 'Покупки', progress: 0 },
  { id: 10, fr: 'Le temps libre', ru: 'Свободное время', progress: 0 },
  { id: 11, fr: 'En voyage', ru: 'Путешествия', progress: 0 },
  { id: 12, fr: 'Les saisons', ru: 'Времена года', progress: 0 },
];

// lesson id → "marked|ipa|translation"
const WORD_ROWS = {
  1: ['b[on]jour|bɔ̃ʒuʁ|здравствуйте', 'merci|mɛʁsi|спасибо', 'au revoir|o ʁəvwaʁ|до свидания', 'salu(t)|saly|привет'],
  2: ["l'ami|lami|друг", 'la femm(e)|la fam|женщина, жена', "l'(h)omm(e)|lɔm|мужчина, человек", "je m'appell(e)|ʒə mapɛl|меня зовут", 'êtr(e)|ɛtʁ|быть'],
  3: ['[un]|œ̃|один', 'deu(x)|dø|два', 'troi(s)|tʁwa|три', 'v[in](gt)|vɛ̃|двадцать', "l'âg(e)|lɑʒ|возраст"],
  4: ['la vill(e)|la vil|город', 'la ru(e)|la ʁy|улица', 'le magas[in]|lə magazɛ̃|магазин', 'la gar(e)|la gaʁ|вокзал'],
  5: [
    'la famill(e)|la famij|семья', 'le pèr(e)|lə pɛʁ|отец', 'la mèr(e)|la mɛʁ|мать', 'le frèr(e)|lə fʁɛʁ|брат',
    'la sœur|la sœʁ|сестра', "l'[en]f[an](t)|lɑ̃fɑ̃|ребёнок", 'le(s) par[en](ts)|le paʁɑ̃|родители', '(h)abite(r)|abite|жить',
  ],
  6: ['la mais[on]|la mɛzɔ̃|дом', 'la ch[am]br(e)|la ʃɑ̃bʁ|комната, спальня', 'la cuisin(e)|la kɥizin|кухня', 'la fenêtr(e)|la fənɛtʁ|окно', 'le jard[in]|lə ʒaʁdɛ̃|сад'],
  7: [
    'le mat[in]|lə matɛ̃|утро', 'le soir|lə swaʁ|вечер', 'le peti(t) déjeune(r)|lə pəti deʒœne|завтрак', 'boir(e)|bwaʁ|пить',
    'm[an]ge(r)|mɑ̃ʒe|есть, кушать', 'le p[ain]|lə pɛ̃|хлеб', 'le beurr(e)|lə bœʁ|масло', '[en]s[em]bl(e)|ɑ̃sɑ̃bl|вместе',
    'beaucou(p)|boku|много', 'tar(d)|taʁ|поздно', 'parle(r)|paʁle|говорить', 'peti(t)|pəti|маленький',
  ],
  8: ['le serveur|lə sɛʁvœʁ|официант', "l'additi[on]|ladisjɔ̃|счёт", 'le croiss[an](t)|lə kʁwasɑ̃|круассан', 'le t(h)é|lə te|чай', "s'il vou(s) plaî(t)|sil vu plɛ|пожалуйста"],
  9: ['le marché|lə maʁʃe|рынок', 'le fromag(e)|lə fʁɔmaʒ|сыр', 'le(s) légum(es)|le legym|овощи', 'c[om]bi[en]|kɔ̃bjɛ̃|сколько', 'cher|ʃɛʁ|дорогой'],
  10: ['le t[em](ps) libr(e)|lə tɑ̃ libʁ|свободное время', 'le livr(e)|lə livʁ|книга', 'la musiq(ue)|la myzik|музыка', 'le spor(t)|lə spɔʁ|спорт', 'souv[en](t)|suvɑ̃|часто'],
  11: ['le voyag(e)|lə vwajaʒ|путешествие', 'le tr[ain]|lə tʁɛ̃|поезд', 'le bille(t)|lə bijɛ|билет', "l'(h)ôtel|lotɛl|гостиница"],
  12: ['le pr[in]t[em](ps)|lə pʁɛ̃tɑ̃|весна', "l'été|lete|лето", "l'auto(m)n(e)|lotɔn|осень", "l'(h)iver|livɛʁ|зима"],
};

const STATUS_LABELS = { new: 'Новое', learning: 'Учу', due: 'Пора повторить', known: 'Знаю' };

// Card statuses are seeded so the prototype opens mid-course: early lessons learned, later ones untouched.
function seedStatus(lesson, index) {
  if (lesson <= 4) return index % 3 === 0 ? 'due' : 'known';
  if (lesson <= 6) return index % 2 === 0 ? 'learning' : 'due';
  return 'new';
}

const WORDS = Object.entries(WORD_ROWS).flatMap(([lessonId, rows]) =>
  rows.map((row, index) => {
    const [fr, ipa, ru] = row.split('|');
    const lesson = Number(lessonId);
    return { lesson, fr, ipa, ru, status: seedStatus(lesson, index) };
  }));

const TEXTS = {
  5: {
    sentences: [
      { ru: 'Меня зовут Люси.', tokens: ['Je|ʒə|я', "m'appell(e)|mapɛl|зовусь", 'Luci(e)|lysi|Люси', '.'] },
      { ru: 'У меня есть брат и сестра.', tokens: ["J'ai|ʒe|у меня есть", '[un]|œ̃|артикль', 'frèr(e)|fʁɛʁ|брат', 'e(t)|e|и||r5-1', 'un(e)|yn|артикль', 'sœur|sœʁ|сестра', '.'] },
      {
        ru: 'Мой отец врач, моя мать преподаватель.',
        tokens: ['M[on]|mɔ̃|мой||r5-3', 'pèr(e)|pɛʁ|отец', 'es(t)|ɛ|есть, является||r5-1', 'méd(e)c[in]|medsɛ̃|врач', ',', 'ma|ma|моя||r5-3', 'mèr(e)|mɛʁ|мать', 'es(t)|ɛ|есть, является||r5-1', 'professeur|pʁɔfɛsœʁ|преподаватель', '.'],
      },
      { ru: 'Мы живём в Лионе.', tokens: ['Nou{s}|nu|мы', '(h)abit[on](s)|abitɔ̃|живём|z|r5-2', 'à|a|в', 'Ly[on]|ljɔ̃|Лион', '.'] },
      {
        ru: 'Мои бабушка и дедушка живут рядом с нами.',
        tokens: ['Me(s)|me|мои||r5-3', 'gr[an](ds)-par[en](ts)|gʁɑ̃paʁɑ̃|бабушка и дедушка', '(h)abit(ent)|abit|живут||r5-2', 'prè(s)|pʁɛ|рядом||r5-1', 'de|də|от, с', 'nou(s)|nu|нами||r5-1', '.'],
      },
    ],
  },
  7: {
    sentences: [
      { ru: 'Клер и Тома живут в Париже.', tokens: ['Clair(e)|klɛʁ|Клер', 'e(t)|e|и||r5-1', 'T(h)oma(s)|tɔma|Тома||r5-2', '(h)abit(ent)|abit|живут||r7-1', 'à|a|в', 'Pari(s)|paʁi|Париж||r5-1', '.'] },
      {
        ru: 'Утром они вместе завтракают.',
        tokens: ['Le|lə|артикль', 'mat[in]|matɛ̃|утро', ',', 'il(s)|il|они||r5-1', 'prenn(ent)|pʁɛn|берут||r7-1', 'le|lə|артикль', 'peti(t)|pəti|маленький||r5-1', 'déjeune(r)|deʒœne|завтрак', '[en]s[em]bl(e)|ɑ̃sɑ̃bl|вместе', '.'],
      },
      {
        ru: 'Клер пьёт кофе, Тома ест хлеб с маслом.',
        tokens: ['Clair(e)|klɛʁ|Клер', 'boi(t)|bwa|пьёт||r5-1', '[un]|œ̃|артикль', 'café|kafe|кофе', ',', 'T(h)oma(s)|tɔma|Тома||r5-2', 'm[an]g(e)|mɑ̃ʒ|ест', 'du|dy|частичный артикль', 'p[ain]|pɛ̃|хлеб', 'avec|avɛk|с', 'du|dy|частичный артикль', 'beurr(e)|bœʁ|масло', '.'],
      },
      { ru: 'У них двое детей.', tokens: ['Il{s}|il|они', '[on](t)|ɔ̃|имеют|z|r7-2', 'deu{x}|dø|два', '[en]f[an](ts)|ɑ̃fɑ̃|дети|z|r7-2', '.'] },
      { ru: 'Дети возвращаются в три часа.', tokens: ['Le{s}|le|артикль мн. ч.', '[en]f[an](ts)|ɑ̃fɑ̃|дети|z|r7-2', 'r[en]tr(ent)|ʁɑ̃tʁ|возвращаются||r7-1', 'à|a|в', 'troi{s}|tʁwa|три', '(h)eur(es)|œʁ|часа|z|r7-2', '.'] },
      {
        ru: 'Вечером семья ужинает поздно и много разговаривает.',
        tokens: ['Le|lə|артикль', 'soir|swaʁ|вечер', ',', 'la|la|артикль', 'famill(e)|famij|семья', 'dîn(e)|din|ужинает', 'tar(d)|taʁ|поздно||r5-1', 'e(t)|e|и||r5-1', 'parl(e)|paʁl|говорит||r7-3', 'beaucou(p)|boku|много||r5-1', '.'],
      },
    ],
  },
};

// Table cells by column kind: "fr" is marked French, "ipa" a transcription, "ru" plain text.
const RULES = [
  {
    id: 'r5-1', lesson: 5, kind: 'Чтение', title: 'Конечные согласные',
    short: 'Согласная на конце слова чаще всего не читается',
    body: [
      'Согласная на конце слова обычно молчит. Почти всегда это s, t, d, p, x и z.',
      'Чаще читаются c, r, f и l. Их удобно запомнить по английскому слову CaReFuL.',
      'В окончании -er у глаголов и многих существительных r не звучит: parler, déjeuner.',
    ],
    examples: ['Pari(s)|paʁi|Париж', 'peti(t)|pəti|маленький', 'beaucou(p)|boku|много', 'tar(d)|taʁ|поздно', 'avec|avɛk|с', 'soir|swaʁ|вечер'],
  },
  {
    id: 'r5-2', lesson: 5, kind: 'Чтение', title: 'Немая h',
    short: 'Буква h не произносится никогда',
    body: [
      'Во французском h не обозначает звука. Слово с h в начале читается так, будто начинается с гласной.',
      'Поэтому перед такой h возможны связывание и апостроф: l’homme, nous habitons.',
    ],
    examples: ['(h)abite(r)|abite|жить', "l'(h)omm(e)|lɔm|человек", 'T(h)oma(s)|tɔma|Тома', 'nou{s}‿(h)abit[on](s)|nu z‿abitɔ̃|мы живём'],
  },
  {
    id: 'r5-3', lesson: 5, kind: 'Грамматика', title: 'Притяжательные прилагательные',
    short: 'Mon, ma, mes согласуются с предметом, а не с владельцем',
    body: ['Род и число зависят от того, чем владеют. Ma mère скажет и мужчина, и женщина.'],
    table: {
      head: ['Чей', 'Мужской род', 'Женский род', 'Мн. число'],
      cols: ['ru', 'fr', 'fr', 'fr'],
      rows: [['мой', 'm[on]', 'ma', 'me(s)'], ['твой', 't[on]', 'ta', 'te(s)'], ['его, её', 's[on]', 'sa', 'se(s)']],
    },
    examples: ['m[on] pèr(e)|mɔ̃ pɛʁ|мой отец', 'ma mèr(e)|ma mɛʁ|моя мать', 'me(s) par[en](ts)|me paʁɑ̃|мои родители'],
  },
  {
    id: 'r7-1', lesson: 7, kind: 'Чтение', title: 'Окончание -ent в глаголах',
    short: 'В форме «они» окончание -ent не читается',
    body: [
      'В настоящем времени форма 3-го лица множественного числа оканчивается на -ent, и это окончание не произносится. Ils parlent звучит так же, как il parle.',
      'В других частях речи -ent читается как носовой звук: souvent, le moment.',
    ],
    examples: ['il(s) parl(ent)|il paʁl|они говорят', 'ell(es) m[an]g(ent)|ɛl mɑ̃ʒ|они едят', 'il(s) prenn(ent)|il pʁɛn|они берут', 'souv[en](t)|suvɑ̃|часто (наречие)'],
  },
  {
    id: 'r7-2', lesson: 7, kind: 'Чтение', title: 'Связывание',
    short: 'Немая согласная звучит перед гласной следующего слова',
    body: [
      'Конечная согласная, которая обычно молчит, произносится, если следующее слово начинается с гласной или немой h. Два слова читаются слитно.',
      'После союза et связывания не бывает: et un ami читается раздельно.',
    ],
    table: {
      head: ['Буква', 'Звук', 'Пример'],
      cols: ['fr', 'ipa', 'fr'],
      rows: [['s, x', 'z', 'le{s}‿ami(s)'], ['t, d', 't', 'un gr[an]{d}‿(h)omm(e)'], ['n', 'n', 'u{n}‿ami']],
    },
    examples: ['le{s}‿[en]f[an](ts)|le z‿ɑ̃fɑ̃|дети', 'il{s}‿[on](t)|il z‿ɔ̃|они имеют', 'troi{s}‿(h)eur(es)|tʁwa z‿œʁ|три часа', 'vou{s}‿êt(es)|vu z‿ɛt|вы есть'],
  },
  {
    id: 'r7-3', lesson: 7, kind: 'Грамматика', title: 'Глаголы на -er в настоящем времени',
    short: 'Четыре формы из шести звучат одинаково',
    body: ['Окончания -e, -es, -e и -ent не читаются. На слух je parle, tu parles, il parle и ils parlent совпадают, их различает только местоимение.'],
    table: {
      head: ['Лицо', 'Форма', 'Звучит'],
      cols: ['ru', 'fr', 'ipa'],
      rows: [
        ['я', 'je parl(e)', 'ʒə paʁl'], ['ты', 'tu parl(es)', 'ty paʁl'], ['он, она', 'il parl(e)', 'il paʁl'],
        ['мы', 'nou(s) parl[on](s)', 'nu paʁlɔ̃'], ['вы', 'vou(s) parle(z)', 'vu paʁle'], ['они', 'il(s) parl(ent)', 'il paʁl'],
      ],
    },
    examples: ['je parl(e)|ʒə paʁl|я говорю', 'nou(s) m[an]ge[on](s)|nu mɑ̃ʒɔ̃|мы едим', 'vou{s}‿(h)abite(z)|vu z‿abite|вы живёте'],
  },
];

// Phrases the reader can analyse. A real app would transcribe any input.
const READER_SAMPLES = [
  { ru: 'Дети живут в Париже.', tokens: ['Le{s}|le|артикль мн. ч.', '[en]f[an](ts)|ɑ̃fɑ̃|дети|z|r7-2', '(h)abit(ent)|abit|живут||r7-1', 'à|a|в', 'Pari(s)|paʁi|Париж||r5-1', '.'] },
  { ru: 'У них много времени.', tokens: ['Il{s}|il|они', '[on](t)|ɔ̃|имеют|z|r7-2', 'beaucou(p)|boku|много||r5-1', 'de|də|частица', 't[em](ps)|tɑ̃|время||r5-1', '.'] },
  { ru: 'Вы очень любезны.', tokens: ['Vou{s}|vu|вы', 'êt(es)|ɛt|есть|z|r7-2', 'trè{s}|tʁɛ|очень', 'aimabl(es)|ɛmabl|любезны|z|r7-2', '.'] },
];

// Word paradigms for "Разбор слова" and the form drills.
// Form: "lead+body|ipa". The lead is a pronoun or article and carries its own trailing space,
// apostrophe or ‿. Forms follow the order of CELL_LABELS for the entry's kind.
const KIND_LABELS = { verb: 'глагол', noun: 'существительное', adjective: 'прилагательное' };
const CELL_LABELS = {
  verb: ['я', 'ты', 'он, она', 'мы', 'вы', 'они'],
  noun: ['определённый, ед. ч.', 'определённый, мн. ч.', 'неопределённый, ед. ч.', 'неопределённый, мн. ч.'],
  adjective: ['мужской, ед. ч.', 'женский, ед. ч.', 'мужской, мн. ч.', 'женский, мн. ч.'],
};

const ANALYSIS = [
  {
    lemma: 'parler', kind: 'verb',
    facts: [['Часть речи', 'глагол, 1-я группа'], ['Participe passé', 'parlé'], ['Вспом. глагол', 'avoir']],
    sets: [
      {
        name: 'Présent', note: 'Je, tu, il и ils звучат одинаково. На слух их различает только местоимение.',
        forms: ['je +parl(e)|ʒə paʁl', 'tu +parl(es)|ty paʁl', 'il +parl(e)|il paʁl', 'nou(s) +parl[on](s)|nu paʁlɔ̃', 'vou(s) +parle(z)|vu paʁle', 'il(s) +parl(ent)|il paʁl'],
      },
      {
        name: 'Imparfait', note: 'Окончания -ais, -ait и -aient читаются одинаково.',
        forms: ['je +parlai(s)|ʒə paʁlɛ', 'tu +parlai(s)|ty paʁlɛ', 'il +parlai(t)|il paʁlɛ', 'nou(s) +parli[on](s)|nu paʁljɔ̃', 'vou(s) +parlie(z)|vu paʁlje', 'il(s) +parlai(ent)|il paʁlɛ'],
      },
      {
        name: 'Futur', note: 'Основа будущего времени совпадает с инфинитивом: parler + окончание.',
        forms: ['je +parlerai|ʒə paʁləʁe', 'tu +parlera(s)|ty paʁləʁa', 'il +parlera|il paʁləʁa', 'nou(s) +parler[on](s)|nu paʁləʁɔ̃', 'vou(s) +parlere(z)|vu paʁləʁe', 'il(s) +parler[on](t)|il paʁləʁɔ̃'],
      },
    ],
  },
  {
    lemma: 'boire', kind: 'verb',
    facts: [['Часть речи', 'глагол, 3-я группа'], ['Participe passé', 'bu'], ['Вспом. глагол', 'avoir']],
    sets: [
      {
        name: 'Présent', note: 'Основа меняется: boi- в единственном числе, buv- с nous и vous, boiv- с ils.',
        forms: ['je +boi(s)|ʒə bwa', 'tu +boi(s)|ty bwa', 'il +boi(t)|il bwa', 'nou(s) +buv[on](s)|nu byvɔ̃', 'vou(s) +buve(z)|vu byve', 'il(s) +boiv(ent)|il bwav'],
      },
      {
        name: 'Imparfait', note: 'Все формы строятся от основы buv-.',
        forms: ['je +buvai(s)|ʒə byvɛ', 'tu +buvai(s)|ty byvɛ', 'il +buvai(t)|il byvɛ', 'nou(s) +buvi[on](s)|nu byvjɔ̃', 'vou(s) +buvie(z)|vu byvje', 'il(s) +buvai(ent)|il byvɛ'],
      },
      {
        name: 'Futur', note: 'Основа boir-: инфинитив без конечной e.',
        forms: ['je +boirai|ʒə bwaʁe', 'tu +boira(s)|ty bwaʁa', 'il +boira|il bwaʁa', 'nou(s) +boir[on](s)|nu bwaʁɔ̃', 'vou(s) +boire(z)|vu bwaʁe', 'il(s) +boir[on](t)|il bwaʁɔ̃'],
      },
    ],
  },
  {
    lemma: 'être', kind: 'verb',
    facts: [['Часть речи', 'глагол, неправильный'], ['Participe passé', 'été'], ['Вспом. глагол', 'avoir']],
    sets: [
      {
        name: 'Présent', note: 'Все шесть форм разные, их нужно запомнить.',
        forms: ['je +sui(s)|ʒə sɥi', 'tu +e(s)|ty ɛ', 'il +es(t)|il ɛ', 'nou(s) +somm(es)|nu sɔm', 'vou{s}‿+êt(es)|vu z‿ɛt', 'il(s) +s[on](t)|il sɔ̃'],
      },
      {
        name: 'Imparfait', note: 'Основа ét- начинается с гласной, поэтому je сокращается до j’, а nous, vous и ils связываются.',
        forms: ["j'+étai(s)|ʒetɛ", 'tu +étai(s)|ty etɛ', 'il +étai(t)|il etɛ', 'nou{s}‿+éti[on](s)|nu z‿etjɔ̃', 'vou{s}‿+étie(z)|vu z‿etje', 'il{s}‿+étai(ent)|il z‿etɛ'],
      },
      {
        name: 'Futur', note: 'Основа ser- неправильная.',
        forms: ['je +serai|ʒə səʁe', 'tu +sera(s)|ty səʁa', 'il +sera|il səʁa', 'nou(s) +ser[on](s)|nu səʁɔ̃', 'vou(s) +sere(z)|vu səʁe', 'il(s) +ser[on](t)|il səʁɔ̃'],
      },
    ],
  },
  {
    lemma: 'petit', kind: 'adjective',
    facts: [['Часть речи', 'прилагательное'], ['Место', 'перед существительным']],
    sets: [{
      name: 'Род и число', note: 'В женском роде добавляется e, и буква t начинает звучать.',
      forms: ['+peti(t)|pəti', '+petit(e)|pətit', '+peti(ts)|pəti', '+petit(es)|pətit'],
    }],
  },
  {
    lemma: 'cher', kind: 'adjective',
    facts: [['Часть речи', 'прилагательное'], ['Место', 'после существительного']],
    sets: [{
      name: 'Род и число', note: 'Все четыре формы звучат одинаково, меняется только написание.',
      forms: ['+cher|ʃɛʁ', '+chèr(e)|ʃɛʁ', '+cher(s)|ʃɛʁ', '+chèr(es)|ʃɛʁ'],
    }],
  },
  {
    lemma: 'famille', kind: 'noun',
    facts: [['Часть речи', 'существительное'], ['Род', 'женский']],
    sets: [{
      name: 'Артикль и число', note: 'Множественное число на слух отличается только артиклем: la и les.',
      forms: ['la +famill(e)|la famij', 'le(s) +famill(es)|le famij', 'un(e) +famill(e)|yn famij', 'de(s) +famill(es)|de famij'],
    }],
  },
  {
    lemma: 'enfant', kind: 'noun',
    facts: [['Часть речи', 'существительное'], ['Род', 'мужской']],
    sets: [{
      name: 'Артикль и число', note: 'Слово начинается с гласной: le сокращается до l’, а les, un и des связываются.',
      forms: ["l'+[en]f[an](t)|lɑ̃fɑ̃", 'le{s}‿+[en]f[an](ts)|le z‿ɑ̃fɑ̃', 'u{n}‿+[en]f[an](t)|œ̃ n‿ɑ̃fɑ̃', 'de{s}‿+[en]f[an](ts)|de z‿ɑ̃fɑ̃'],
    }],
  },
  {
    lemma: 'pain', kind: 'noun',
    facts: [['Часть речи', 'существительное'], ['Род', 'мужской']],
    sets: [{
      name: 'Артикль и число', note: 'Конечная s во множественном числе не читается.',
      forms: ['le +p[ain]|lə pɛ̃', 'le(s) +p[ain](s)|le pɛ̃', '[un] +p[ain]|œ̃ pɛ̃', 'de(s) +p[ain](s)|de pɛ̃'],
    }],
  },
];

// Notes by screen key. `range` is the first and last word index of the quoted fragment.
const SEED_NOTES = {
  'text-7': [{ text: 'В prennent двойная n, а читается [pʁɛn]. Не путать с prend [pʁɑ̃].', quote: 'ils prennent', range: [8, 9] }],
  'rule-r7-2': [{ text: 'Спросить на занятии, когда связывание обязательно, а когда можно без него.', quote: '', range: null }],
};
