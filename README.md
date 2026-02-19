# SiGameFlutter

Онлайн-версия игры «Своя игра» на Flutter Web + Firebase.

## Быстрый старт

1. Установить зависимости:

```bash
flutter pub get
```

2. Убедиться, что заполнен локальный Firebase-конфиг:

- Файл: `config/firebase.web.json`
- Пример: `config/firebase.web.example.json`

3. Запустить web:

```bash
flutter run -d chrome --dart-define-from-file=config/firebase.web.json
```

4. Собрать web:

```bash
flutter build web --dart-define-from-file=config/firebase.web.json
```

## Runtime флаги

- `E2E_BYPASS_PROFILE_UPSERT=true` — не отправлять `upsertProfile` в backend (для E2E).
- `E2E_AUTO_FLOW=true` — включить автопилот игровых переходов в комнате (для E2E/демо). По умолчанию выключен.

Пример:

```bash
flutter run -d chrome \
  --dart-define-from-file=config/firebase.web.json \
  --dart-define=E2E_AUTO_FLOW=true
```

## Firebase

### Требования в консоли Firebase

- `Authentication -> Sign-in method -> Anonymous` включен.
- Firestore создан в `Native mode`.

### Деплой правил/индексов Firestore

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Деплой web в Firebase Hosting

```bash
flutter build web --dart-define-from-file=config/firebase.web.json
firebase deploy --only hosting
```

## Файлы конфигурации Firebase

- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`
- `config/firebase.web.example.json`
- `config/firebase.web.json` (локальный, в git не коммитится)

## Паритет с оригинальной игрой (чеклист)

- [x] Базовые фазы игры: lobby -> board_select -> question/answer -> final -> game_over
- [x] Поддержка спецтипов вопросов: `cat_in_bag`, `wager`, `closest_number`, legacy-синонимы
- [x] Финал: удаление тем, ставки, порядок ответов, reveal, начисление/списание
- [x] Роли: host/player/editor/spectator, смена ролей и ограничения команд
- [x] Таймерные автопереходы (включая auto-heal на отключениях)
- [x] Поддержка разного числа участников (1..N активных игроков + зрители) в серверной логике
- [x] Локализация ключевых игровых экранов и событий
- [x] Полный e2e прогон через Firebase Emulator Suite без `SKIP` (`functions/tests/gameCommand.emulator.test.js`)

### Статус паритета

- [x] Расширены Flutter UI-тесты экранов игры с мокингом `room/players/questions/events` потоков и user uid через провайдеры.
- [x] Покрыты unit-тестами ключевые ветки `RoomAutoFlowController` (board/cat/wager/answer/final/timer/anti-duplication).
- [x] Добавлены e2e-регрессии final-команд, включая запрет `open_final_answers` до получения ставок от всех eligible игроков.

### Команда полного emulator e2e прогона

Требуется JDK 21+.

```bash
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
firebase emulators:exec --only firestore,auth "cd functions && node --test tests/gameCommand.emulator.test.js"
```
