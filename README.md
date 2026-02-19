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
- [ ] Полный e2e прогон через Firebase Emulator Suite без `SKIP` в текущем окружении

### Что осталось до 100% паритета

- Запустить и стабилизировать весь `functions/tests/gameCommand.emulator.test.js` в окружении с поднятыми эмуляторами Firestore/Auth/Functions.
- Добавить дополнительные Flutter UI-тесты для экранов игры с реальным мокингом `FirebaseAuth.currentUser` и потоков room/players/events.
