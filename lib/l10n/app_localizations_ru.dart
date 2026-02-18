// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Своя игра онлайн';

  @override
  String get routeNotFound => 'Маршрут не найден';

  @override
  String initializationError(Object error) {
    return 'Ошибка инициализации: $error';
  }

  @override
  String get firebaseNotConfiguredMessage =>
      'Firebase не настроен.\n\nСоздай локальный файл config/firebase.web.json (пример: config/firebase.web.example.json), затем запусти:\n\nflutter run -d chrome --dart-define-from-file=config/firebase.web.json\n\nТогда будут доступны комнаты, синхронизация, ре-коннект и онлайн-игра.';

  @override
  String get homeCreateRoom => 'Создать комнату';

  @override
  String get homeFindRoom => 'Найти комнату';

  @override
  String get homeSettings => 'Настройки';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsNameLabel => 'Имя';

  @override
  String settingsVolume(int percent) {
    return 'Громкость: $percent%';
  }

  @override
  String get save => 'Сохранить';

  @override
  String changeAvatarError(Object error) {
    return 'Не удалось выбрать аватарку: $error';
  }

  @override
  String get nameCannotBeEmpty => 'Имя не может быть пустым';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String saveError(Object error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get profileSetupTitle => 'Создание профиля';

  @override
  String get nicknameRequiredHint => 'Никнейм (обязательно)';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get nicknameRequired => 'Нужно указать никнейм';

  @override
  String get profileSaved => 'Профиль сохранён';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileNickLabel => 'Ник';

  @override
  String get profileAvatarUrlLabel => 'Ссылка на аватар';

  @override
  String get roomsTitle => 'Комнаты';

  @override
  String get newGameDefault => 'Новая игра';

  @override
  String get roomNameLabel => 'Название комнаты';

  @override
  String get roomNameRequired => 'Название комнаты обязательно';

  @override
  String get createRoomDialogTitle => 'Создание комнаты';

  @override
  String get roomPasswordLabel => 'Пароль (необязательно)';

  @override
  String get packFileRequired => 'Файл пака обязателен';

  @override
  String enterRoomPasswordTitle(Object roomName) {
    return 'Введите пароль для: $roomName';
  }

  @override
  String get create => 'Создать';

  @override
  String get createAndUploadPack => 'Создать и загрузить пак из файла';

  @override
  String get packEditor => 'Редактор пака';

  @override
  String get packEditorCreate => 'Создать пак';

  @override
  String get packEditorEdit => 'Редактировать пак';

  @override
  String get packSelectFilePrompt => 'Выберите файл пака';

  @override
  String get packSelectFile => 'Выбрать файл';

  @override
  String get packInvalidFile => 'Неверный файл пака';

  @override
  String errorWithDetails(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get noRoomsYet => 'Комнат пока нет';

  @override
  String roomStatusPhase(Object status, Object phase) {
    return 'Статус: $status | Этап: $phase';
  }

  @override
  String get player => 'Игрок';

  @override
  String get spectator => 'Зритель';

  @override
  String get roomDefaultName => 'Комната';

  @override
  String createRoomError(Object error) {
    return 'Ошибка создания комнаты: $error';
  }

  @override
  String get noQuestionsInFile => 'В файле нет вопросов';

  @override
  String questionsLoaded(int count) {
    return 'Загружено вопросов: $count';
  }

  @override
  String packUploadError(Object error) {
    return 'Ошибка загрузки пака: $error';
  }

  @override
  String get appFailurePermissionDenied => 'Недостаточно прав для действия.';

  @override
  String get appFailureNetworkError =>
      'Проблема с сетью. Проверьте интернет и попробуйте снова.';

  @override
  String get gameStatusLobby => 'Лобби';

  @override
  String get gameStatusInGame => 'Игра';

  @override
  String get gameStatusPaused => 'Пауза';

  @override
  String get gameStatusFinalRound => 'Финал';

  @override
  String get gameStatusCompleted => 'Завершена';

  @override
  String get gamePhaseLobby => 'Лобби';

  @override
  String get gamePhaseBoardSelect => 'Выбор вопроса';

  @override
  String get gamePhaseQuestionReveal => 'Озвучивание вопроса';

  @override
  String get gamePhaseCatTargeting => 'Кот в мешке: выбор игрока';

  @override
  String get gamePhaseWagerBidding => 'Аукцион: ставка';

  @override
  String get gamePhaseAnswering => 'Ответы';

  @override
  String get gamePhaseAnswerReview => 'Решение ведущего';

  @override
  String get gamePhaseFinalSetup => 'Финал: настройка';

  @override
  String get gamePhaseFinalWagering => 'Финал: ставки';

  @override
  String get gamePhaseFinalAnswering => 'Финал: голосовые ответы';

  @override
  String get gamePhaseFinalReveal => 'Финал: вскрытие';

  @override
  String get gamePhaseGameOver => 'Игра завершена';

  @override
  String get questionTypeNormal => 'Обычный';

  @override
  String get questionTypeCat => 'Кот в мешке';

  @override
  String get questionTypeWager => 'Вопрос-аукцион';

  @override
  String get questionTypeClosestNumber => 'Ближайшее число';

  @override
  String get questionMediaNone => 'Без медиа';

  @override
  String get questionMediaImage => 'Изображение';

  @override
  String get questionMediaAudio => 'Аудио';

  @override
  String get questionMediaVideo => 'Видео';

  @override
  String get roleHost => 'Ведущий';

  @override
  String get rolePlayer => 'Игрок';

  @override
  String get roleSpectator => 'Зритель';

  @override
  String get roleEditor => 'Редактор';

  @override
  String get finalResultPending => 'Ожидает решения';

  @override
  String get finalResultCorrect => 'Верно';

  @override
  String get finalResultWrong => 'Неверно';

  @override
  String get finalResultNoAnswer => 'Без ответа';

  @override
  String get themeFallback => 'Тема';

  @override
  String get noThemeFallback => 'Без темы';

  @override
  String get serverNoRoomId => 'Сервер не вернул roomId';

  @override
  String get playerFallbackName => 'Игрок';

  @override
  String get serverErrorDefault => 'Ошибка сервера';

  @override
  String get showPanels => 'Показать панели';

  @override
  String get broadcastMode => 'Режим трансляции';

  @override
  String get roundLabel => 'Раунд';

  @override
  String get questionChooser => 'Выбор вопроса';

  @override
  String get start => 'Старт';

  @override
  String get unpause => 'Снять паузу';

  @override
  String get pause => 'Пауза';

  @override
  String get round2 => 'Раунд 2';

  @override
  String get finalRoundButton => 'Финал';

  @override
  String timerSeconds(Object seconds) {
    return 'Таймер: $seconds сек';
  }

  @override
  String get noQuestionsCurrentRound => 'Нет вопросов для текущего раунда';

  @override
  String activeQuestionHeader(Object cost, Object theme, Object type) {
    return 'Активный: $theme | $type | $cost';
  }

  @override
  String get mediaLabel => 'Медиа';

  @override
  String get openAnswerButton => 'Открыть кнопку ответа';

  @override
  String get answeringNow => 'Отвечает';

  @override
  String get answeredByVoice => 'Ответ дал голосом';

  @override
  String get buzzButton => 'Жму кнопку';

  @override
  String get closestNumberHint =>
      'Введите число. Побеждает самый близкий ответ.';

  @override
  String get numericAnswerFieldLabel => 'Ваш ответ (число)';

  @override
  String get submitNumericAnswer => 'Отправить число';

  @override
  String get waitingHostDecision =>
      'Ожидается решение ведущего по голосовому ответу';

  @override
  String get chooseNextQuestion => 'Выберите следующий вопрос на табло';

  @override
  String get waitingCatSelection => 'Ожидается выбор игрока для Кота в мешке';

  @override
  String transferTo(Object name) {
    return 'Передать: $name';
  }

  @override
  String get wagerLabel => 'Ставка';

  @override
  String get confirmWager => 'Подтвердить ставку';

  @override
  String whoAnswered(Object uid) {
    return 'Кто ответил: $uid';
  }

  @override
  String get hostVoiceCheck => 'Проверка ответа выполняется ведущим голосом';

  @override
  String acceptedAnswers(Object aliases) {
    return 'Допустимые варианты: $aliases';
  }

  @override
  String get finalRoundLabel => 'Финальный раунд';

  @override
  String eligiblePlayers(Object count) {
    return 'Допущены: $count игроков';
  }

  @override
  String get finalQuestionSetup => 'Настройка финального вопроса';

  @override
  String get finalThemeLabel => 'Тема финала';

  @override
  String get finalQuestionFieldLabel => 'Вопрос финала';

  @override
  String get finalControlAnswerLabel => 'Контрольный ответ (для ведущего)';

  @override
  String get saveQuestion => 'Сохранить вопрос';

  @override
  String get openWagers => 'Открыть ставки';

  @override
  String get startVoiceAnswers => 'Начать голосовые ответы';

  @override
  String get revealFinal => 'Вскрыть финал';

  @override
  String get themeLabel => 'Тема';

  @override
  String get questionLabel => 'Вопрос';

  @override
  String get yourFinalWager => 'Ваша финальная ставка';

  @override
  String get placeWager => 'Поставить';

  @override
  String get discordVoiceInfo =>
      'Ответы даются только голосом в Discord. Ведущий отмечает исход каждого ответа.';

  @override
  String playerWagerLine(Object name, Object wager) {
    return '$name | ставка: $wager';
  }

  @override
  String get decisionLabel => 'Решение';

  @override
  String get playersAndStats => 'Игроки и статистика';

  @override
  String get tabPlayers => 'Игроки';

  @override
  String get tabGameLog => 'Лог партии';

  @override
  String get offline => 'offline';

  @override
  String get scoreLabel => 'Счёт';

  @override
  String statsLine(Object buzz, Object correct, Object wrong) {
    return 'Стат: +$correct / -$wrong | Кнопка: $buzz';
  }

  @override
  String get manualAdjustment => 'Ручная корректировка';

  @override
  String get kick => 'Кик';

  @override
  String get ban => 'Бан';

  @override
  String get unban => 'Разбан';

  @override
  String get noEventsYet => 'Событий пока нет';

  @override
  String get myPackDefault => 'Мой пак';

  @override
  String get roomEditorTitle => 'Темы и вопросы';

  @override
  String roomIdLabel(Object id) {
    return 'Комната: $id';
  }

  @override
  String get answerForHostLabel => 'Ответ (для ведущего)';

  @override
  String get answerAliasesLabel => 'Варианты ответа (через запятую)';

  @override
  String get mediaUrlOptionalLabel => 'Ссылка на медиа (опционально)';

  @override
  String get costLabel => 'Стоимость';

  @override
  String get round1 => 'Раунд 1';

  @override
  String get addQuestion => 'Добавить вопрос';

  @override
  String get questionAdded => 'Вопрос добавлен';

  @override
  String get exportPackageTitle => 'Экспорт пакета';

  @override
  String get exportJson => 'Экспорт JSON';

  @override
  String get importJson => 'Импорт JSON';

  @override
  String get noQuestions => 'Вопросов нет';

  @override
  String get packNameLabel => 'Название пака';

  @override
  String packSavedVersion(Object version) {
    return 'Пак сохранен v$version';
  }

  @override
  String get savePack => 'Сохранить пак';

  @override
  String get packsCatalog => 'Каталог паков';

  @override
  String get goToRoom => 'Перейти в комнату';

  @override
  String get packsEmpty => 'Паков нет';

  @override
  String questionsCount(Object count) {
    return 'Вопросов: $count';
  }

  @override
  String get apply => 'Применить';

  @override
  String get close => 'Закрыть';

  @override
  String get importPackJsonTitle => 'Импорт пакета JSON';

  @override
  String get pasteJsonQuestionsHint => 'Вставьте JSON с questions';

  @override
  String get cancel => 'Отмена';

  @override
  String importError(Object error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get importAction => 'Импортировать';

  @override
  String get uploadFile => 'Загрузить файл';

  @override
  String get saveToFile => 'Сохранить в файл';

  @override
  String get clear => 'Очистить';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get bulkThemeOptionalLabel => 'Массовая тема (опционально)';

  @override
  String get bulkRoundAny => 'Раунд: -';

  @override
  String get onlySelected => 'Только выбранные';

  @override
  String packQuestionsSelectedReorder(int questions, int selected) {
    return 'Вопросов: $questions | Выбрано: $selected. Перетаскивайте строки для изменения порядка.';
  }

  @override
  String get packHasNoQuestionsYet => 'В паке пока нет вопросов';

  @override
  String get themeQuestionAnswerRequired => 'Тема, вопрос и ответ обязательны';

  @override
  String get specifyThemeOrRoundForBulkUpdate =>
      'Укажите тему и/или раунд для массового изменения';

  @override
  String get noSelectedQuestions => 'Нет выбранных вопросов';

  @override
  String updatedQuestions(int count) {
    return 'Обновлено вопросов: $count';
  }

  @override
  String get packIsEmpty => 'Пак пустой';

  @override
  String get newPackDefault => 'Новый пак';

  @override
  String get fileSaved => 'Файл сохранен';

  @override
  String get saveCanceled => 'Сохранение отменено';

  @override
  String get languageLabel => 'Язык';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get change => 'Изменить';

  @override
  String get answerHotkeyLabel => 'Клавиша ответа';

  @override
  String answerHotkeyCurrent(Object key) {
    return 'Текущая клавиша: $key';
  }

  @override
  String get answerHotkeyPressAny => 'Нажмите любую клавишу...';

  @override
  String get keySpace => 'Пробел';

  @override
  String get popupErrorTitle => 'Ошибка';

  @override
  String get popupSuccessTitle => 'Готово';

  @override
  String get popupInfoTitle => 'Сообщение';

  @override
  String get popupOk => 'ОК';
}
