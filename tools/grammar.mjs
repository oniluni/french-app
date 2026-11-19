#!/usr/bin/env node
// The grammar track: short lessons with theory and a test, written by hand.
//
// Each workshop is one page in the app. `theory` is Markdown in the same subset as the lesson
// vault, so `build-grammar.mjs` can turn it into the blocks the app renders.

export const workshops = [
  {
    id: 'questions',
    title: 'Вопросительные предложения',
    subtitle: 'Интонация, est-ce que и инверсия',
    icon: 'questionmark.bubble.fill',
    level: 'A1–A2',
    theory: `
# Три способа задать вопрос

Один и тот же вопрос по-французски можно построить по-разному. Выбор зависит от ситуации: интонация — для друзей, est-ce que — в нейтральной речи, инверсия — в формальной.

| Способ | Пример | Когда уместен |
| --- | --- | --- |
| Интонация | *Tu parles français ?* | Разговорная речь, короткий вопрос |
| Est-ce que | *Est-ce que tu parles français ?* | Нейтрально, подходит почти везде |
| Инверсия | *Parles-tu français ?* | Книжно, формально, в письме |

## Вопросительные слова

Вопросительное слово ставят в начало фразы. Дальше порядок зависит от выбранного способа.

| Слово | Значение | Пример |
| --- | --- | --- |
| Qui | кто | *Qui parle ?* |
| Que / Qu'est-ce que | что | *Qu'est-ce que tu manges ?* |
| Où | где, куда | *Où est-ce que tu vas ?* |
| Quand | когда | *Quand arrives-tu ?* |
| Comment | как | *Comment tu t'appelles ?* |
| Pourquoi | почему | *Pourquoi est-ce que tu ris ?* |
| Combien | сколько | *Combien de frères as-tu ?* |

## Инверсия: три детали

1. Глагол и местоимение меняются местами, между ними ставится дефис: *Tu habites à Paris* → *Habites-tu à Paris ?*
2. Перед il, elle и on появляется вставное -t- для благозвучия: *Va-t-il au cinéma ?*
3. В сложном времени местоимение стоит перед вспомогательным глаголом: *As-tu fini ?*

> [!warning] Не путайте
> *Est-ce que* — это не вопросительное слово «что». Это служебный оборот, который просто вводит вопрос. «Что» — это *que* или *qu'est-ce que*.

## Вопрос к подлежащему и к дополнению

- К подлежащему: *Qui parle ?* — «Кто говорит?» После qui глагол стоит в 3-м лице единственного числа.
- К дополнению: *Qui est-ce que tu vois ?* — «Кого ты видишь?» Здесь qui — дополнение, поэтому порядок слов сохраняется.
- С вещью: *Qu'est-ce que tu regardes ?* — «Что ты смотришь?»
`,
    questions: [
      {
        prompt: 'Какой вариант — вопрос с инверсией?',
        translation: 'Tu habites à Paris.',
        options: ['Habites-tu à Paris ?', 'Tu habites à Paris ?', 'Est-ce que tu habites à Paris ?', 'Tu habites à Paris.'],
        answer: 0,
        explanation: 'При инверсии подлежащее-местоимение переносится после глагола, а между ними появляется дефис: *Habites-tu… ?*',
      },
      {
        prompt: '___ est-ce que tu vas ?',
        translation: 'Куда ты идёшь?',
        options: ['Où', 'Qui', 'Que', 'Quand'],
        answer: 0,
        explanation: '*Où* значит «где» или «куда». Остальные слова не подходят по смыслу: *qui* — кто, *que* — что, *quand* — когда.',
      },
      {
        prompt: '___ parle français dans ta classe ?',
        translation: 'Кто говорит по-французски в твоём классе?',
        options: ['Qui', 'Que', 'Où', 'Comment'],
        answer: 0,
        explanation: 'О человеке спрашивают *qui*. После *qui* глагол стоит в 3-м лице единственного числа: *Qui parle… ?*',
      },
      {
        prompt: 'Как правильно построить вопрос с инверсией?',
        translation: 'Он идёт в кино?',
        options: ['Va-t-il au cinéma ?', 'Vas-t-il au cinéma ?', 'Va-il au cinéma ?', 'Est-il va au cinéma ?'],
        answer: 0,
        explanation: 'У *aller* форма 3-го лица — *va*. Перед *il* добавляется вставное *-t-*: *Va-t-il… ?*',
      },
      {
        prompt: 'Какой вариант — формальный вопрос?',
        translation: 'Вы говорите по-французски?',
        options: ['Parlez-vous français ?', 'Vous parlez français ?', 'Est-ce que vous parlez ?', 'Parlez vous français ?'],
        answer: 0,
        explanation: 'Инверсия *vous parlez* → *parlez-vous*. Дефис обязателен, а *est-ce que* здесь не нужно.',
      },
      {
        prompt: 'Какой вопрос построен с est-ce que?',
        translation: 'Ты хочешь кофе?',
        options: ['Est-ce que tu veux du café ?', 'Veux-tu du café ?', 'Tu veux du café ?', 'Est-ce tu veux du café ?'],
        answer: 0,
        explanation: 'Оборот *est-ce que* пишется целиком и ставится перед подлежащим: *Est-ce que tu veux… ?*',
      },
    ],
  },
  {
    id: 'imperative',
    title: 'Повелительное наклонение',
    subtitle: 'Impératif: просьбы и команды',
    icon: 'hand.point.right.fill',
    level: 'A1–A2',
    theory: `
# Impératif

Повелительное наклонение говорит собеседнику, что делать. Во французском у него три формы: *tu*, *nous* и *vous*. Подлежащее не называется.

| Глагол | tu | nous | vous |
| --- | --- | --- | --- |
| parler | *parle* | *parlons* | *parlez* |
| finir | *finis* | *finissons* | *finissez* |
| aller | *va* | *allons* | *allez* |
| être | *sois* | *soyons* | *soyez* |
| avoir | *aie* | *ayons* | *ayez* |
| faire | *fais* | *faisons* | *faites* |

## Главное правило для глаголов I группы

В форме *tu* глаголы на -er теряют конечную -s: *tu parles* → *parle*, *tu manges* → *mange*. У остальных групп -s обычно остаётся: *finis*, *prends*.

## Отрицание и местоимения

Отрицание окружает глагол: *Ne parle pas !* Возвратное местоимение стоит перед глаголом: *Lève-toi !* В отрицании оно тоже перед глаголом: *Ne te lève pas !*

В утвердительной форме местоимения-дополнения ставятся после глагола через дефис: *Donne-le-moi !* В отрицательной — возвращаются перед глаголом: *Ne me le donne pas !*

> [!info] Вежливая просьба
> Повелительное наклонение может звучать резко. Для вежливости добавляют *s'il te plaît* или *s'il vous plaît*, а в инструкциях и меню часто используют инфинитив: *Ne pas fumer* — «Не курить».

## Запомните

- *Aller* в форме tu: **va**, а не *vas*.
- *Faire* в форме vous: **faites**, а не *faisez*.
- *Être* в форме tu: **sois**.
`,
    questions: [
      {
        prompt: 'Parler (tu), повелительное наклонение:',
        translation: 'Говори!',
        options: ['Parle', 'Parles', 'Parlez', 'Parler'],
        answer: 0,
        explanation: 'Глагол I группы в форме *tu* теряет -s: *parles* → *parle*.',
      },
      {
        prompt: 'Aller (nous), повелительное наклонение:',
        translation: 'Пойдём!',
        options: ['Allons', 'Allez', 'Va', 'Aller'],
        answer: 0,
        explanation: 'Форма *nous* у *aller* — *allons*. *Allez* — это форма *vous*.',
      },
      {
        prompt: 'Ne pas se lever (tu), повелительное наклонение:',
        translation: 'Не вставай!',
        options: ['Ne te lève pas.', 'Ne lève-toi pas.', 'Ne te lèves pas.', 'Ne se lève pas.'],
        answer: 0,
        explanation: 'В отрицании возвратное *te* стоит перед глаголом, а *ne* и *pas* окружают его: *Ne te lève pas.*',
      },
      {
        prompt: 'Donner le livre à moi, повелительное наклонение:',
        translation: 'Дай мне книгу!',
        options: ['Donne-le-moi.', 'Donne-moi-le.', 'Me le donne.', 'Donne-le me.'],
        answer: 0,
        explanation: 'В утвердительной форме местоимения идут после глагола: *donne* + *le* + *moi* → *Donne-le-moi.*',
      },
      {
        prompt: 'Faire (vous), повелительное наклонение:',
        translation: 'Сделайте!',
        options: ['Faites', 'Faisez', 'Fais', 'Fait'],
        answer: 0,
        explanation: 'У *faire* особая форма *vous*: *faites*. Форма *faisez* не существует.',
      },
      {
        prompt: 'Être (tu), повелительное наклонение:',
        translation: 'Будь!',
        options: ['Sois', 'Es', 'Soit', 'Soyez'],
        answer: 0,
        explanation: 'Повелительное наклонение *être* в форме tu — *sois*. *Soit* — это форма *il/elle*, *soyez* — *vous*.',
      },
    ],
  },
  {
    id: 'pronouns',
    title: 'Местоимения-дополнения',
    subtitle: 'le, la, les, lui, leur',
    icon: 'person.2.fill',
    level: 'A2',
    theory: `
# Кого? Кому?

Французские местоимения-дополнения заменяют существительное и ставятся **перед** глаголом. Сначала нужно понять, какое это дополнение: прямое (кого? что?) или косвенное (кому?).

| Прямое дополнение | Значение | Косвенное дополнение | Значение |
| --- | --- | --- | --- |
| le | его, это (м. р.) | lui | ему, ей |
| la | её, это (ж. р.) | leur | им |
| les | их | — | — |

## Прямое дополнение

*Je lis le livre.* → *Je le lis.* — «Я его читаю». Местоимение *le* заменяет *le livre* и стоит перед *lis*.

*Elle regarde les photos.* → *Elle les regarde.* — «Она их смотрит».

## Косвенное дополнение

Если глагол требует предлога *à* (parler à, téléphoner à, donner à), существительное заменяют на *lui* или *leur*:

*Je parle à Marie.* → *Je lui parle.* — «Я с ней говорю».

*Elle téléphone à ses parents.* → *Elle leur téléphone.* — «Она им звонит».

## Порядок местоимений

Если в предложении два местоимения, сначала идёт то, которое заменяет прямое дополнение, затем косвенное:

*Il donne les fleurs à Marie.* → *Il les lui donne.* — «Он их ей даёт».

Порядок: **me / te / nous / vous** → **le / la / les** → **lui / leur**. Например: *Il me les donne.* — «Он мне их даёт».

## Отрицание

В отрицании местоимение остаётся перед глаголом, а *ne* и *pas* окружают всю конструкцию:

*Je ne le vois pas.* — «Я его не вижу».

> [!warning] Не переводите предлог отдельно
> В русском «ему» и «ей» — разные слова, а во французском *lui* обозначает и то и другое. Смотрите на глагол: если он требует *à*, используйте *lui / leur*.
`,
    questions: [
      {
        prompt: 'Je lis le livre. Замените дополнение:',
        translation: 'Я читаю книгу.',
        options: ['Je le lis.', 'Je lui lis.', 'Je lis le.', 'Je les lis.'],
        answer: 0,
        explanation: '*Le livre* — прямое дополнение мужского рода единственного числа, поэтому *le*: *Je le lis.*',
      },
      {
        prompt: 'Elle téléphone à ses parents. Замените дополнение:',
        translation: 'Она звонит родителям.',
        options: ['Elle leur téléphone.', 'Elle les téléphone.', 'Elle lui téléphone.', 'Elle téléphone leur.'],
        answer: 0,
        explanation: '*Téléphoner à* требует косвенного дополнения. *Ses parents* — множественное число, поэтому *leur*.',
      },
      {
        prompt: 'Il donne les fleurs à Marie. Замените оба дополнения:',
        translation: 'Он даёт цветы Мари.',
        options: ['Il les lui donne.', 'Il lui les donne.', 'Il les donne lui.', 'Il la lui donne.'],
        answer: 0,
        explanation: 'Сначала прямое *les* (цветы), затем косвенное *lui* (Мари): *Il les lui donne.*',
      },
      {
        prompt: 'Nous regardons la télé. Замените дополнение:',
        translation: 'Мы смотрим телевизор.',
        options: ['Nous la regardons.', 'Nous le regardons.', 'Nous les regardons.', 'Nous lui regardons.'],
        answer: 0,
        explanation: '*La télé* — женский род единственного числа, значит *la*: *Nous la regardons.*',
      },
      {
        prompt: 'Tu parles à ton frère ? Замените дополнение:',
        translation: 'Ты говоришь со своим братом?',
        options: ['Tu lui parles ?', 'Tu le parles ?', 'Tu leur parles ?', 'Tu parles lui ?'],
        answer: 0,
        explanation: '*Parler à* + один человек → *lui*. Местоимение ставится перед глаголом: *Tu lui parles ?*',
      },
      {
        prompt: 'Je ne vois pas Marie. Замените дополнение:',
        translation: 'Я не вижу Мари.',
        options: ['Je ne la vois pas.', 'Je ne lui vois pas.', 'Je ne vois pas la.', 'Je ne les vois pas.'],
        answer: 0,
        explanation: '*Voir* — переходный глагол без предлога, поэтому прямое *la*. В отрицании оно остаётся перед глаголом.',
      },
    ],
  },
  {
    id: 'en-y',
    title: 'Местоимения en и y',
    subtitle: 'Заменяем места, вещи и количества',
    icon: 'arrow.left.arrow.right',
    level: 'A2',
    theory: `
# Два коротких местоимения

**Y** заменяет место или вещь с предлогом *à*: *à Paris*, *à la gare*, *à ce projet*. **En** заменяет место или количество с предлогом *de*: *de Paris*, *du café*, *des pommes*.

| Исходная фраза | С местоимением | Значение |
| --- | --- | --- |
| Je vais à Paris. | *J'y vais.* | Я туда иду. |
| Je reviens de Paris. | *J'en reviens.* | Я оттуда возвращаюсь. |
| Tu veux du café ? | *Tu en veux ?* | Ты хочешь кофе? |
| J'ai deux frères. | *J'en ai deux.* | У меня их два. |
| Nous pensons à ce voyage. | *Nous y pensons.* | Мы думаем об этом. |

## Y: куда и о чём

*Y* заменяет дополнение с *à*, когда речь о месте или предмете, а не о человеке:

- *Je vais à la gare.* → *J'y vais.*
- *Il pense à son travail.* → *Il y pense.*
- *Nous répondons à la question.* → *Nous y répondons.*

О людях чаще говорят *à lui / à elle*: *Je pense à Marie* → *Je pense à elle*, а не *Je lui pense*.

## En: откуда и сколько

*En* заменяет *de + существительное*:

- *Je reviens du travail.* → *J'en reviens.*
- *Elle mange des pommes.* → *Elle en mange.*
- *Tu as combien de frères ?* → *J'en ai deux.*

После *en* количество сохраняется: *J'en ai deux* — «У меня их два».

> [!warning] Место в предложении
> Оба местоимения стоят перед глаголом. В отрицании *ne* идёт перед местоимением, а *pas* — после глагола: *Je n'y vais pas.* *Je n'en ai pas.*

## Запомните

- *Y* → *à* + место или вещь.
- *En* → *de* + место, вещество или количество.
- *Il y a* — отдельный оборот, здесь *y* не заменяет ничего.
`,
    questions: [
      {
        prompt: 'Je vais à la gare. Замените дополнение:',
        translation: 'Я иду на вокзал.',
        options: ["J'y vais.", "J'en vais.", 'Je y vais.', 'Je vais y.'],
        answer: 0,
        explanation: '*À la gare* — место с предлогом *à*, поэтому *y*: *J\'y vais.*',
      },
      {
        prompt: 'Il rentre du travail. Замените дополнение:',
        translation: 'Он возвращается с работы.',
        options: ['Il en rentre.', 'Il y rentre.', 'Il rentre en.', 'Il le rentre.'],
        answer: 0,
        explanation: '*Du travail* = *de + le travail*, поэтому *en*: *Il en rentre.*',
      },
      {
        prompt: 'Elle mange des pommes. Замените дополнение:',
        translation: 'Она ест яблоки.',
        options: ['Elle en mange.', 'Elle y mange.', 'Elle les mange.', 'Elle mange en.'],
        answer: 0,
        explanation: '*Des pommes* — неопределённое количество с *de*, поэтому *en*. *Les* тоже возможно, но тогда речь о конкретных яблоках; в этом упражнении нужен *en*.',
      },
      {
        prompt: 'Nous pensons à ce voyage. Замените дополнение:',
        translation: 'Мы думаем об этой поездке.',
        options: ['Nous y pensons.', 'Nous en pensons.', 'Nous le pensons.', 'Nous pensons y.'],
        answer: 0,
        explanation: '*Penser à* + вещь → *y*: *Nous y pensons.*',
      },
      {
        prompt: 'Tu as combien de frères ? — У меня их два.',
        translation: 'Сколько у тебя братьев?',
        options: ["J'en ai deux.", "J'y ai deux.", "J'ai en deux.", 'Je les ai deux.'],
        answer: 0,
        explanation: 'Количество с *de* заменяется на *en*, а число остаётся: *J\'en ai deux.*',
      },
      {
        prompt: 'Je ne vais pas à l’école. Замените дополнение:',
        translation: 'Я не хожу в школу.',
        options: ["Je n'y vais pas.", "Je n'en vais pas.", 'Je ne y vais pas.', 'Je ne vais pas y.'],
        answer: 0,
        explanation: '*À l’école* → *y*. В отрицании *ne* стоит перед *y*: *Je n\'y vais pas.*',
      },
    ],
  },
  {
    id: 'il-y-a',
    title: 'Il y a и безличные обороты',
    subtitle: '«Есть», «нужно» и «стоит»',
    icon: 'mappin.and.ellipse',
    level: 'A1',
    theory: `
# Il y a

*Il y a* значит «есть», «имеется», «находится». Оборот не меняется по числам: *il y a un parc*, *il y a des parcs*.

| Утверждение | Отрицание | Вопрос |
| --- | --- | --- |
| *Il y a une boulangerie.* | *Il n'y a pas de boulangerie.* | *Y a-t-il une boulangerie ?* |

После отрицания *un / une / des* обычно заменяются на *de*: *Il n'y a pas de problème.*

## Il faut

*Il faut* + инфинитив значит «нужно», «надо»:

- *Il faut étudier.* — Нужно учиться.
- *Il faut partir.* — Пора уходить.
- *Il ne faut pas fumer.* — Нельзя курить.

## Il est, il fait

- *Il est* + прилагательное + *de* + инфинитив: *Il est important de pratiquer.* — Важно практиковаться.
- *Il fait* + погода: *Il fait froid.* — Холодно. *Il fait beau.* — Хорошая погода.
- *Il est* + время: *Il est huit heures.*

> [!info] Чем отличается от il est?
> *Il y a* сообщает о наличии: *Il y a un livre sur la table.* *Il est* описывает или оценивает: *Il est intéressant.* Не переводите оба оборота одним русским «есть».

## Запомните

- *Il y a* не согласуется с существительным: *il y a un / une / des*.
- В отрицании: *il n'y a pas de*.
- В вопросе: *Y a-t-il… ?* — с вставным *-t-*.
`,
    questions: [
      {
        prompt: '___ un parc près de chez moi.',
        translation: 'Рядом с моим домом есть парк.',
        options: ['Il y a', 'Il est', 'Il a', "C'est"],
        answer: 0,
        explanation: 'О наличии предмета говорит *il y a*: *Il y a un parc.*',
      },
      {
        prompt: 'Il y a une boulangerie ? — Нет, там нет булочной.',
        translation: 'Там нет булочной.',
        options: ["Non, il n'y a pas de boulangerie.", "Non, il n'y a pas une boulangerie.", "Non, il n'y a pas la boulangerie.", "Non, il y a pas de boulangerie."],
        answer: 0,
        explanation: 'После отрицания *une* заменяется на *de*: *il n\'y a pas de boulangerie.*',
      },
      {
        prompt: '___ une pharmacie près d’ici ?',
        translation: 'Здесь рядом есть аптека?',
        options: ['Y a-t-il', 'Il y a-t-il', 'Y a-t-elle', 'Est-il y a'],
        answer: 0,
        explanation: 'Вопросительная форма — *Y a-t-il… ?* Вставное *-t-* стоит между *a* и *il*.',
      },
      {
        prompt: '___ étudier pour réussir.',
        translation: 'Нужно учиться, чтобы добиться успеха.',
        options: ['Il faut', 'Il y a', 'Il est', 'Il fait'],
        answer: 0,
        explanation: '*Il faut* + инфинитив выражает необходимость: *Il faut étudier.*',
      },
      {
        prompt: '___ froid aujourd’hui.',
        translation: 'Сегодня холодно.',
        options: ['Il fait', 'Il est', 'Il y a', 'Il a'],
        answer: 0,
        explanation: 'О погоде говорят с *il fait*: *Il fait froid.*',
      },
      {
        prompt: '___ important de pratiquer.',
        translation: 'Важно практиковаться.',
        options: ['Il est', 'Il y a', 'Il fait', 'Il faut'],
        answer: 0,
        explanation: 'Конструкция *il est + прилагательное + de + инфинитив*: *Il est important de pratiquer.*',
      },
    ],
  },
  {
    id: 'articles',
    title: 'Артикли',
    subtitle: 'Определённый, неопределённый и частичный',
    icon: 'textformat.abc',
    level: 'A1–A2',
    theory: `
# Три вида артикля

Во французском артикль почти всегда стоит перед существительным. Он показывает, о конкретном предмете речь или о любом, а также выражает число и род.

| Артикль | Формы | Когда |
| --- | --- | --- |
| Определённый | le, la, l', les | Конкретный предмет или весь класс |
| Неопределённый | un, une, des | Один из многих, впервые упомянутый |
| Частичный | du, de la, de l', des | Вещество или неопределённое количество |

## Слияние с предлогами

*À* и *de* сливаются с определённым артиклем:

- *à + le* → **au**: *Je vais au cinéma.*
- *à + les* → **aux**: *Je parle aux enfants.*
- *de + le* → **du**: *Je parle du film.*
- *de + les* → **des**: *Il revient des vacances.*

## Отрицание

После *ne … pas* неопределённый и частичный артикль заменяются на *de*:

- *J'ai un frère.* → *Je n'ai pas de frère.*
- *Elle boit du café.* → *Elle ne boit pas de café.*

Определённый артикль сохраняется: *Je n'aime pas le café.*

> [!warning] Не путайте du и des
> *Du* — единственное число мужского рода (*du pain*), *des* — множественное число (*des livres*) или часть от *de + les* (*des vacances*). Смотрите на существительное.

## Запомните

- *Le / la / l' / les* — конкретный предмет.
- *Un / une / des* — один из многих.
- *Du / de la / de l' / des* — вещество или количество.
`,
    questions: [
      {
        prompt: 'Je vais ___ cinéma.',
        translation: 'Я иду в кино.',
        options: ['au', 'à le', 'du', 'le'],
        answer: 0,
        explanation: '*À + le* сливается в *au*: *Je vais au cinéma.*',
      },
      {
        prompt: 'Elle boit ___ eau.',
        translation: 'Она пьёт воду.',
        options: ["de l'", 'du', 'la', 'des'],
        answer: 0,
        explanation: 'Перед гласной частичный артикль *de la* сокращается до *de l\'*: *de l\'eau.*',
      },
      {
        prompt: 'Je n’ai pas ___ frère.',
        translation: 'У меня нет брата.',
        options: ['de', 'un', 'le', 'des'],
        answer: 0,
        explanation: 'После *ne … pas* неопределённый *un* заменяется на *de*: *Je n\'ai pas de frère.*',
      },
      {
        prompt: '___ livres sont intéressants.',
        translation: 'Книги интересные.',
        options: ['Les', 'Des', 'Le', 'Un'],
        answer: 0,
        explanation: 'Речь о конкретных книгах, множественное число: *Les livres sont intéressants.*',
      },
      {
        prompt: 'C’est ___ ami.',
        translation: 'Это друг.',
        options: ['un', 'le', 'des', 'du'],
        answer: 0,
        explanation: 'Один из многих, мужской род: *un ami.*',
      },
      {
        prompt: 'Nous parlons ___ professeur.',
        translation: 'Мы говорим о преподавателе.',
        options: ['du', 'au', 'le', 'des'],
        answer: 0,
        explanation: '*Parler de + le professeur* → *du professeur*: *Nous parlons du professeur.*',
      },
    ],
  },
  {
    id: 'passe-compose',
    title: 'Passé composé',
    subtitle: 'Прошедшее время с avoir и être',
    icon: 'clock.arrow.circlepath',
    level: 'A2',
    theory: `
# Как образуется passé composé

Passé composé = вспомогательный глагол (*avoir* или *être*) в настоящем времени + причастие прошедшего времени.

| Инфинитив | Причастие | Пример |
| --- | --- | --- |
| parler | parlé | *J'ai parlé.* |
| finir | fini | *J'ai fini.* |
| attendre | attendu | *J'ai attendu.* |
| aller | allé | *Je suis allé.* |
| venir | venu | *Je suis venu.* |
| faire | fait | *J'ai fait.* |

## Avoir или être?

Большинство глаголов спрягается с *avoir*. С *être* идут глаголы движения и изменения состояния (aller, venir, partir, arriver, entrer, sortir, naître, mourir) и все возвратные глаголы.

С *être* причастие согласуется с подлежащим:

- *Marie est arrivée.* — Мари приехала.
- *Ils sont partis.* — Они уехали.
- *Elles sont venues.* — Они пришли.

С *avoir* согласование с подлежащим не нужно: *Marie a mangé une pomme.*

## Отрицание и вопросы

Отрицание окружает вспомогательный глагол: *Je n'ai pas vu le film.* *Elle n'est pas venue.*

Вопрос с инверсией: *As-tu fini ?* *Est-elle partie ?*

> [!info] Слова-маркеры
> *Hier*, *avant-hier*, *la semaine dernière*, *déjà* часто подсказывают passé composé: действие завершено.

## Запомните

- *Avoir* + причастие — большинство глаголов.
- *Être* + причастие — движение и возвратные глаголы.
- С *être* причастие согласуется с подлежащим.
`,
    questions: [
      {
        prompt: 'Hier, j’___ mangé une pomme.',
        translation: 'Вчера я съел яблоко.',
        options: ['ai', 'suis', 'as', 'a'],
        answer: 0,
        explanation: '*Manger* спрягается с *avoir*. Форма *je*: *j\'ai mangé.*',
      },
      {
        prompt: 'Elle ___ allée à Paris.',
        translation: 'Она поехала в Париж.',
        options: ['est', 'a', 'es', 'sont'],
        answer: 0,
        explanation: '*Aller* — глагол движения, спрягается с *être*: *Elle est allée.*',
      },
      {
        prompt: 'Nous avons ___ nos devoirs.',
        translation: 'Мы сделали домашнее задание.',
        options: ['fini', 'finis', 'finir', 'finissons'],
        answer: 0,
        explanation: 'Причастие *finir* — *fini*. С *avoir* согласование с подлежащим не нужно.',
      },
      {
        prompt: 'Ils ___ partis à midi.',
        translation: 'Они уехали в полдень.',
        options: ['sont', 'ont', 'est', 'avez'],
        answer: 0,
        explanation: '*Partir* спрягается с *être*. Для *ils*: *Ils sont partis.*',
      },
      {
        prompt: 'Je n’ai pas ___ le film.',
        translation: 'Я не смотрел фильм.',
        options: ['vu', 'voir', 'voyais', 'verrai'],
        answer: 0,
        explanation: 'После *avoir* нужно причастие *vu*: *Je n\'ai pas vu le film.*',
      },
      {
        prompt: 'Marie est ___ à huit heures.',
        translation: 'Мари пришла в восемь часов.',
        options: ['arrivée', 'arrivé', 'arrivés', 'arriver'],
        answer: 0,
        explanation: 'С *être* причастие согласуется с подлежащим: *Marie* — женский род, поэтому *arrivée*.',
      },
    ],
  },
  {
    id: 'imparfait',
    title: 'Imparfait и passé composé',
    subtitle: 'Описание, привычка и завершённое действие',
    icon: 'hourglass',
    level: 'A2–B1',
    theory: `
# Два прошедших времени

Passé composé называет завершённое действие: *Hier, j'ai mangé une pomme.* Imparfait описывает фон, привычку или состояние: *Quand j'étais petit, je mangeais souvent des pommes.*

## Как образуется imparfait

Берём основу *nous* в настоящем времени, отбрасываем -ons и прибавляем окончания:

| Лицо | Окончание | Пример с parler |
| --- | --- | --- |
| je | -ais | *je parlais* |
| tu | -ais | *tu parlais* |
| il / elle | -ait | *il parlait* |
| nous | -ions | *nous parlions* |
| vous | -iez | *vous parliez* |
| ils / elles | -aient | *ils parlaient* |

У *être* основа особая: *ét-* → *j'étais*, *il était*, *nous étions*.

## Когда что выбирать

| Imparfait | Passé composé |
| --- | --- |
| Описание: *Il faisait beau.* | Завершённое действие: *Il a plu.* |
| Привычка: *Je me levais à sept heures.* | Один раз: *Je me suis levé à sept heures.* |
| Фон: *Nous dînions quand il a appelé.* | Событие: *Il a appelé.* |

## Сигналы

- *Souvent*, *toujours*, *chaque jour*, *quand j'étais petit* обычно требуют imparfait.
- *Hier*, *soudain*, *une fois*, *l'année dernière* часто требуют passé composé.
- В одном предложении могут встретиться оба: *Je lisais quand le téléphone a sonné.*

> [!warning] Не переводите механически
> Русское прошедшее время не различает эти оттенки. Смотрите, закончилось ли действие и есть ли у него граница: если да — passé composé, если это фон или привычка — imparfait.

## Запомните

- Imparfait: основа *nous* + -ais, -ait, -ions, -iez, -aient.
- Passé composé: avoir/être + причастие.
- Фон и привычка — imparfait; завершённое событие — passé composé.
`,
    questions: [
      {
        prompt: 'Quand j’étais petit, je ___ souvent au parc.',
        translation: 'Когда я был маленьким, я часто ходил в парк.',
        options: ['allais', 'suis allé', 'allait', 'irai'],
        answer: 0,
        explanation: '*Souvent* и *quand j\'étais petit* описывают привычку, поэтому imparfait: *j\'allais.*',
      },
      {
        prompt: 'Hier, il ___ un livre.',
        translation: 'Вчера он прочитал книгу.',
        options: ['a lu', 'lisait', 'lit', 'lira'],
        answer: 0,
        explanation: '*Hier* и завершённое действие требуют passé composé: *Il a lu un livre.*',
      },
      {
        prompt: 'Nous ___ quand le téléphone a sonné.',
        translation: 'Мы ужинали, когда зазвонил телефон.',
        options: ['dînions', 'avons dîné', 'dînons', 'dînerons'],
        answer: 0,
        explanation: 'Ужин был фоном, а звонок — событием. Фон выражает imparfait: *Nous dînions.*',
      },
      {
        prompt: 'Elle ___ toujours à huit heures.',
        translation: 'Она всегда вставала в восемь часов.',
        options: ['se levait', "s'est levée", 'se lève', 'se lèvera'],
        answer: 0,
        explanation: '*Toujours* указывает на привычку, поэтому imparfait: *Elle se levait.*',
      },
      {
        prompt: 'Ils ___ le film hier soir.',
        translation: 'Вчера вечером они посмотрели фильм.',
        options: ['ont regardé', 'regardaient', 'regardent', 'regarderont'],
        answer: 0,
        explanation: '*Hier soir* и завершённое действие: passé composé *ont regardé.*',
      },
      {
        prompt: 'Il ___ beau ce matin.',
        translation: 'Сегодня утром была хорошая погода.',
        options: ['faisait', 'a fait', 'fait', 'fera'],
        answer: 0,
        explanation: 'Погода здесь — описание фона, поэтому imparfait: *Il faisait beau.*',
      },
    ],
  },
];
