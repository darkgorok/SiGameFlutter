// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Своя гра онлайн';

  @override
  String get routeNotFound => 'Маршрут не знайдено';

  @override
  String initializationError(Object error) {
    return 'Помилка ініціалізації: $error';
  }

  @override
  String get firebaseNotConfiguredMessage =>
      'Firebase не налаштовано.\n\nСтвори локальний файл config/firebase.web.json (приклад: config/firebase.web.example.json), потім запусти:\n\nflutter run -d chrome --dart-define-from-file=config/firebase.web.json\n\nПісля цього будуть доступні кімнати, синхронізація, ре-конект та онлайн-гра.';

  @override
  String get homeCreateRoom => 'Створити кімнату';

  @override
  String get homeFindRoom => 'Знайти кімнату';

  @override
  String get homeSettings => 'Налаштування';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get settingsNameLabel => 'Ім\'я';

  @override
  String settingsVolume(int percent) {
    return 'Гучність: $percent%';
  }

  @override
  String get save => 'Зберегти';

  @override
  String changeAvatarError(Object error) {
    return 'Не вдалося вибрати аватар: $error';
  }

  @override
  String get nameCannotBeEmpty => 'Ім\'я не може бути порожнім';

  @override
  String get settingsSaved => 'Налаштування збережено';

  @override
  String saveError(Object error) {
    return 'Помилка збереження: $error';
  }

  @override
  String get profileSetupTitle => 'Створення профілю';

  @override
  String get nicknameRequiredHint => 'Нікнейм (обов\'язково)';

  @override
  String get continueButton => 'Продовжити';

  @override
  String get nicknameRequired => 'Потрібно вказати нікнейм';

  @override
  String get profileSaved => 'Профіль збережено';

  @override
  String get profileTitle => 'Профіль';

  @override
  String get profileNickLabel => 'Нік';

  @override
  String get profileAvatarUrlLabel => 'Посилання на аватар';

  @override
  String get roomsTitle => 'Кімнати';

  @override
  String get newGameDefault => 'Нова гра';

  @override
  String get roomNameLabel => 'Назва кімнати';

  @override
  String get roomNameRequired => 'Назва кімнати обов\'язкова';

  @override
  String get createRoomDialogTitle => 'Створення кімнати';

  @override
  String get roomPasswordLabel => 'Пароль (необов\'язково)';

  @override
  String get packFileRequired => 'Файл пака обов\'язковий';

  @override
  String enterRoomPasswordTitle(Object roomName) {
    return 'Введіть пароль для: $roomName';
  }

  @override
  String get create => 'Створити';

  @override
  String get createAndUploadPack => 'Створити і завантажити пак із файлу';

  @override
  String get packEditor => 'Редактор пака';

  @override
  String get packEditorCreate => 'Створити пак';

  @override
  String get packEditorEdit => 'Редагувати пак';

  @override
  String get packSelectFilePrompt => 'Виберіть файл пака';

  @override
  String get packSelectFile => 'Вибрати файл';

  @override
  String get packInvalidFile => 'Невірний файл пака';

  @override
  String errorWithDetails(Object error) {
    return 'Помилка: $error';
  }

  @override
  String get noRoomsYet => 'Кімнат поки немає';

  @override
  String roomStatusPhase(Object status, Object phase) {
    return 'Статус: $status | Етап: $phase';
  }

  @override
  String get player => 'Гравець';

  @override
  String get spectator => 'Глядач';

  @override
  String get roomDefaultName => 'Кімната';

  @override
  String createRoomError(Object error) {
    return 'Помилка створення кімнати: $error';
  }

  @override
  String get noQuestionsInFile => 'У файлі немає питань';

  @override
  String questionsLoaded(int count) {
    return 'Завантажено питань: $count';
  }

  @override
  String packUploadError(Object error) {
    return 'Помилка завантаження пака: $error';
  }

  @override
  String get appFailurePermissionDenied => 'Недостатньо прав для дії.';

  @override
  String get appFailureNetworkError =>
      'Проблема з мережею. Перевірте інтернет і спробуйте знову.';

  @override
  String get gameStatusLobby => 'Лобі';

  @override
  String get gameStatusInGame => 'Гра';

  @override
  String get gameStatusPaused => 'Пауза';

  @override
  String get gameStatusFinalRound => 'Фінал';

  @override
  String get gameStatusCompleted => 'Завершено';

  @override
  String get gamePhaseLobby => 'Лобі';

  @override
  String get gamePhaseBoardSelect => 'Вибір питання';

  @override
  String get gamePhaseQuestionReveal => 'Озвучення питання';

  @override
  String get gamePhaseCatTargeting => 'Кіт у мішку: вибір гравця';

  @override
  String get gamePhaseWagerBidding => 'Аукціон: ставка';

  @override
  String get gamePhaseAnswering => 'Відповіді';

  @override
  String get gamePhaseAnswerReview => 'Рішення ведучого';

  @override
  String get gamePhaseFinalSetup => 'Фінал: налаштування';

  @override
  String get gamePhaseFinalWagering => 'Фінал: ставки';

  @override
  String get gamePhaseFinalAnswering => 'Фінал: голосові відповіді';

  @override
  String get gamePhaseFinalReveal => 'Фінал: розкриття';

  @override
  String get gamePhaseGameOver => 'Гру завершено';

  @override
  String get questionTypeNormal => 'Звичайний';

  @override
  String get questionTypeCat => 'Кіт у мішку';

  @override
  String get questionTypeWager => 'Питання-аукціон';

  @override
  String get questionTypeClosestNumber => 'Найближче число';

  @override
  String get questionMediaNone => 'Без медіа';

  @override
  String get questionMediaImage => 'Зображення';

  @override
  String get questionMediaAudio => 'Аудіо';

  @override
  String get questionMediaVideo => 'Відео';

  @override
  String get roleHost => 'Ведучий';

  @override
  String get rolePlayer => 'Гравець';

  @override
  String get roleSpectator => 'Глядач';

  @override
  String get roleEditor => 'Редактор';

  @override
  String get finalResultPending => 'Очікує рішення';

  @override
  String get finalResultCorrect => 'Правильно';

  @override
  String get finalResultWrong => 'Неправильно';

  @override
  String get finalResultNoAnswer => 'Без відповіді';

  @override
  String get themeFallback => 'Тема';

  @override
  String get noThemeFallback => 'Без теми';

  @override
  String get serverNoRoomId => 'Сервер не повернув roomId';

  @override
  String get playerFallbackName => 'Гравець';

  @override
  String get serverErrorDefault => 'Помилка сервера';

  @override
  String get showPanels => 'Показати панелі';

  @override
  String get broadcastMode => 'Режим трансляції';

  @override
  String get roundLabel => 'Раунд';

  @override
  String get questionChooser => 'Вибір питання';

  @override
  String get start => 'Старт';

  @override
  String get unpause => 'Зняти паузу';

  @override
  String get pause => 'Пауза';

  @override
  String get round2 => 'Раунд 2';

  @override
  String get finalRoundButton => 'Фінал';

  @override
  String timerSeconds(Object seconds) {
    return 'Таймер: $seconds сек';
  }

  @override
  String get noQuestionsCurrentRound => 'Немає питань для поточного раунду';

  @override
  String activeQuestionHeader(Object cost, Object theme, Object type) {
    return 'Активне: $theme | $type | $cost';
  }

  @override
  String get mediaLabel => 'Медіа';

  @override
  String get openAnswerButton => 'Відкрити кнопку відповіді';

  @override
  String get answeringNow => 'Відповідає';

  @override
  String get answeredByVoice => 'Відповів голосом';

  @override
  String get buzzButton => 'Тисну кнопку';

  @override
  String get closestNumberHint =>
      'Введіть число. Перемагає найближча відповідь.';

  @override
  String get numericAnswerFieldLabel => 'Ваша відповідь (число)';

  @override
  String get submitNumericAnswer => 'Надіслати число';

  @override
  String get waitingHostDecision =>
      'Очікується рішення ведучого щодо голосової відповіді';

  @override
  String get chooseNextQuestion => 'Оберіть наступне питання на табло';

  @override
  String get waitingCatSelection => 'Очікується вибір гравця для Кота в мішку';

  @override
  String transferTo(Object name) {
    return 'Передати: $name';
  }

  @override
  String get wagerLabel => 'Ставка';

  @override
  String get confirmWager => 'Підтвердити ставку';

  @override
  String whoAnswered(Object uid) {
    return 'Хто відповів: $uid';
  }

  @override
  String get hostVoiceCheck =>
      'Перевірка відповіді виконується ведучим голосом';

  @override
  String acceptedAnswers(Object aliases) {
    return 'Допустимі варіанти: $aliases';
  }

  @override
  String get finalRoundLabel => 'Фінальний раунд';

  @override
  String eligiblePlayers(Object count) {
    return 'Допущено: $count гравців';
  }

  @override
  String get finalQuestionSetup => 'Налаштування фінального питання';

  @override
  String get finalThemeLabel => 'Тема фіналу';

  @override
  String get finalQuestionFieldLabel => 'Питання фіналу';

  @override
  String get finalControlAnswerLabel => 'Контрольна відповідь (для ведучого)';

  @override
  String get saveQuestion => 'Зберегти питання';

  @override
  String get openWagers => 'Відкрити ставки';

  @override
  String get startVoiceAnswers => 'Почати голосові відповіді';

  @override
  String get revealFinal => 'Розкрити фінал';

  @override
  String get themeLabel => 'Тема';

  @override
  String get questionLabel => 'Питання';

  @override
  String get yourFinalWager => 'Ваша фінальна ставка';

  @override
  String get placeWager => 'Поставити';

  @override
  String get discordVoiceInfo =>
      'Відповіді даються лише голосом у Discord. Ведучий відмічає результат кожної відповіді.';

  @override
  String playerWagerLine(Object name, Object wager) {
    return '$name | ставка: $wager';
  }

  @override
  String get decisionLabel => 'Рішення';

  @override
  String get playersAndStats => 'Гравці та статистика';

  @override
  String get tabPlayers => 'Гравці';

  @override
  String get tabGameLog => 'Лог партії';

  @override
  String get offline => 'offline';

  @override
  String get scoreLabel => 'Рахунок';

  @override
  String statsLine(Object buzz, Object correct, Object wrong) {
    return 'Стат: +$correct / -$wrong | Кнопка: $buzz';
  }

  @override
  String get manualAdjustment => 'Ручне коригування';

  @override
  String get kick => 'Кік';

  @override
  String get ban => 'Бан';

  @override
  String get unban => 'Розбан';

  @override
  String get noEventsYet => 'Подій поки немає';

  @override
  String get myPackDefault => 'Мій пак';

  @override
  String get roomEditorTitle => 'Теми і питання';

  @override
  String roomIdLabel(Object id) {
    return 'Кімната: $id';
  }

  @override
  String get answerForHostLabel => 'Відповідь (для ведучого)';

  @override
  String get answerAliasesLabel => 'Варіанти відповіді (через кому)';

  @override
  String get mediaUrlOptionalLabel => 'Посилання на медіа (опціонально)';

  @override
  String get costLabel => 'Вартість';

  @override
  String get round1 => 'Раунд 1';

  @override
  String get addQuestion => 'Додати питання';

  @override
  String get questionAdded => 'Питання додано';

  @override
  String get exportPackageTitle => 'Експорт пакета';

  @override
  String get exportJson => 'Експорт JSON';

  @override
  String get importJson => 'Імпорт JSON';

  @override
  String get noQuestions => 'Питань немає';

  @override
  String get packNameLabel => 'Назва пака';

  @override
  String packSavedVersion(Object version) {
    return 'Пак збережено v$version';
  }

  @override
  String get savePack => 'Зберегти пак';

  @override
  String get packsCatalog => 'Каталог паків';

  @override
  String get goToRoom => 'Перейти в кімнату';

  @override
  String get packsEmpty => 'Паків немає';

  @override
  String questionsCount(Object count) {
    return 'Питань: $count';
  }

  @override
  String get apply => 'Застосувати';

  @override
  String get close => 'Закрити';

  @override
  String get importPackJsonTitle => 'Імпорт JSON пакета';

  @override
  String get pasteJsonQuestionsHint => 'Вставте JSON з questions';

  @override
  String get cancel => 'Скасувати';

  @override
  String importError(Object error) {
    return 'Помилка імпорту: $error';
  }

  @override
  String get importAction => 'Імпортувати';

  @override
  String get uploadFile => 'Завантажити файл';

  @override
  String get saveToFile => 'Зберегти у файл';

  @override
  String get clear => 'Очистити';

  @override
  String get saveChanges => 'Зберегти зміни';

  @override
  String get bulkThemeOptionalLabel => 'Масова тема (опціонально)';

  @override
  String get bulkRoundAny => 'Раунд: -';

  @override
  String get onlySelected => 'Лише вибрані';

  @override
  String packQuestionsSelectedReorder(int questions, int selected) {
    return 'Питань: $questions | Вибрано: $selected. Перетягуйте рядки для зміни порядку.';
  }

  @override
  String get packHasNoQuestionsYet => 'У паку поки немає питань';

  @override
  String get themeQuestionAnswerRequired =>
      'Тема, питання та відповідь обов\'язкові';

  @override
  String get specifyThemeOrRoundForBulkUpdate =>
      'Вкажіть тему та/або раунд для масового оновлення';

  @override
  String get noSelectedQuestions => 'Немає вибраних питань';

  @override
  String updatedQuestions(int count) {
    return 'Оновлено питань: $count';
  }

  @override
  String get packIsEmpty => 'Пак порожній';

  @override
  String get newPackDefault => 'Новий пак';

  @override
  String get fileSaved => 'Файл збережено';

  @override
  String get saveCanceled => 'Збереження скасовано';

  @override
  String get languageLabel => 'Мова';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get change => 'Змінити';

  @override
  String get answerHotkeyLabel => 'Клавіша відповіді';

  @override
  String answerHotkeyCurrent(Object key) {
    return 'Поточна клавіша: $key';
  }

  @override
  String get answerHotkeyPressAny => 'Натисніть будь-яку клавішу...';

  @override
  String get keySpace => 'Пробіл';

  @override
  String get popupErrorTitle => 'Помилка';

  @override
  String get popupSuccessTitle => 'Готово';

  @override
  String get popupInfoTitle => 'Повідомлення';

  @override
  String get popupOk => 'ОК';
}
