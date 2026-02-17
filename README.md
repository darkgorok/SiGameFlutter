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
