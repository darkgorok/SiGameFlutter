// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SiGame Online';

  @override
  String get routeNotFound => 'Route not found';

  @override
  String initializationError(Object error) {
    return 'Initialization error: $error';
  }

  @override
  String get firebaseNotConfiguredMessage =>
      'Firebase is not configured.\n\nCreate local file config/firebase.web.json (example: config/firebase.web.example.json), then run:\n\nflutter run -d chrome --dart-define-from-file=config/firebase.web.json\n\nAfter that rooms, sync, reconnect and online game will be available.';

  @override
  String get homeCreateRoom => 'Create room';

  @override
  String get homeFindRoom => 'Find room';

  @override
  String get homeSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNameLabel => 'Name';

  @override
  String settingsVolume(int percent) {
    return 'Volume: $percent%';
  }

  @override
  String get save => 'Save';

  @override
  String changeAvatarError(Object error) {
    return 'Could not pick avatar: $error';
  }

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String saveError(Object error) {
    return 'Save error: $error';
  }

  @override
  String get profileSetupTitle => 'Create profile';

  @override
  String get nicknameRequiredHint => 'Nickname (required)';

  @override
  String get continueButton => 'Continue';

  @override
  String get nicknameRequired => 'Nickname is required';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNickLabel => 'Nickname';

  @override
  String get profileAvatarUrlLabel => 'Avatar URL';

  @override
  String get roomsTitle => 'Rooms';

  @override
  String get newGameDefault => 'New game';

  @override
  String get roomNameLabel => 'Room name';

  @override
  String get roomNameRequired => 'Room name is required';

  @override
  String get createRoomDialogTitle => 'Create room';

  @override
  String get roomPasswordLabel => 'Password (optional)';

  @override
  String get invalidRoomPassword => 'Invalid room password.';

  @override
  String get roomPasswordRequired => 'Room password is required.';

  @override
  String get packFileRequired => 'Pack file is required';

  @override
  String enterRoomPasswordTitle(Object roomName) {
    return 'Enter password for: $roomName';
  }

  @override
  String get create => 'Create';

  @override
  String get createAndUploadPack => 'Create and upload pack from file';

  @override
  String get packEditor => 'Pack editor';

  @override
  String get packEditorCreate => 'Create pack';

  @override
  String get packEditorEdit => 'Edit pack';

  @override
  String get packSelectFilePrompt => 'Select a pack file';

  @override
  String get packSelectFile => 'Select file';

  @override
  String get packInvalidFile => 'Invalid pack file';

  @override
  String errorWithDetails(Object error) {
    return 'Error: $error';
  }

  @override
  String get noRoomsYet => 'No rooms yet';

  @override
  String roomStatusPhase(Object status, Object phase) {
    return 'Status: $status | Phase: $phase';
  }

  @override
  String get player => 'Player';

  @override
  String get spectator => 'Spectator';

  @override
  String get roomDefaultName => 'Room';

  @override
  String createRoomError(Object error) {
    return 'Room creation failed: $error';
  }

  @override
  String get noQuestionsInFile => 'No questions in file';

  @override
  String questionsLoaded(int count) {
    return 'Questions loaded: $count';
  }

  @override
  String packUploadError(Object error) {
    return 'Pack upload error: $error';
  }

  @override
  String get appFailurePermissionDenied =>
      'Not enough permissions for this action.';

  @override
  String get appFailureNetworkError =>
      'Network problem. Check your connection and try again.';

  @override
  String get gameStatusLobby => 'Lobby';

  @override
  String get gameStatusInGame => 'In game';

  @override
  String get gameStatusPaused => 'Paused';

  @override
  String get gameStatusFinalRound => 'Final';

  @override
  String get gameStatusCompleted => 'Completed';

  @override
  String get gamePhaseLobby => 'Lobby';

  @override
  String get gamePhaseBoardSelect => 'Question selection';

  @override
  String get gamePhaseQuestionReveal => 'Question reveal';

  @override
  String get gamePhaseCatTargeting => 'Cat in a bag: choose player';

  @override
  String get gamePhaseWagerBidding => 'Auction: wager';

  @override
  String get gamePhaseAnswering => 'Answering';

  @override
  String get gamePhaseAnswerReview => 'Host decision';

  @override
  String get gamePhaseFinalSetup => 'Final: setup';

  @override
  String get gamePhaseFinalWagering => 'Final: wagers';

  @override
  String get gamePhaseFinalAnswering => 'Final: voice answers';

  @override
  String get gamePhaseFinalReveal => 'Final: reveal';

  @override
  String get gamePhaseGameOver => 'Game over';

  @override
  String get questionTypeNormal => 'Normal';

  @override
  String get questionTypeCat => 'Cat in a bag';

  @override
  String get questionTypeWager => 'Auction question';

  @override
  String get questionTypeClosestNumber => 'Closest number';

  @override
  String get questionMediaNone => 'No media';

  @override
  String get questionMediaImage => 'Image';

  @override
  String get questionMediaAudio => 'Audio';

  @override
  String get questionMediaVideo => 'Video';

  @override
  String get roleHost => 'Host';

  @override
  String get rolePlayer => 'Player';

  @override
  String get roleSpectator => 'Spectator';

  @override
  String get roleEditor => 'Editor';

  @override
  String get finalResultPending => 'Pending';

  @override
  String get finalResultCorrect => 'Correct';

  @override
  String get finalResultWrong => 'Wrong';

  @override
  String get finalResultNoAnswer => 'No answer';

  @override
  String get themeFallback => 'Theme';

  @override
  String get noThemeFallback => 'No theme';

  @override
  String get serverNoRoomId => 'Server did not return roomId';

  @override
  String get playerFallbackName => 'Player';

  @override
  String get serverErrorDefault => 'Server error';

  @override
  String get showPanels => 'Show panels';

  @override
  String get broadcastMode => 'Broadcast mode';

  @override
  String get roundLabel => 'Round';

  @override
  String get questionChooser => 'Question chooser';

  @override
  String get start => 'Start';

  @override
  String get unpause => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get round2 => 'Round 2';

  @override
  String get finalRoundButton => 'Final';

  @override
  String timerSeconds(Object seconds) {
    return 'Timer: $seconds sec';
  }

  @override
  String get noQuestionsCurrentRound => 'No questions for current round';

  @override
  String activeQuestionHeader(Object cost, Object theme, Object type) {
    return 'Active: $theme | $type | $cost';
  }

  @override
  String get mediaLabel => 'Media';

  @override
  String get mediaPreviewAudio => 'Audio media';

  @override
  String get mediaPreviewVideo => 'Video media';

  @override
  String get mediaPreviewUnavailable => 'Media preview unavailable';

  @override
  String get openAnswerButton => 'Open answer button';

  @override
  String get answeringNow => 'Answering';

  @override
  String get answeredByVoice => 'Answered by voice';

  @override
  String get buzzButton => 'Buzz';

  @override
  String get closestNumberHint => 'Enter a number. The closest answer wins.';

  @override
  String get numericAnswerFieldLabel => 'Your answer (number)';

  @override
  String get submitNumericAnswer => 'Submit number';

  @override
  String get waitingHostDecision => 'Waiting for host decision on voice answer';

  @override
  String get chooseNextQuestion => 'Choose the next question on the board';

  @override
  String get waitingCatSelection =>
      'Waiting for player selection for Cat in a bag';

  @override
  String transferTo(Object name) {
    return 'Transfer to: $name';
  }

  @override
  String get wagerLabel => 'Wager';

  @override
  String get confirmWager => 'Confirm wager';

  @override
  String whoAnswered(Object uid) {
    return 'Who answered: $uid';
  }

  @override
  String get hostVoiceCheck => 'The host validates voice answers';

  @override
  String acceptedAnswers(Object aliases) {
    return 'Accepted answers: $aliases';
  }

  @override
  String get finalRoundLabel => 'Final round';

  @override
  String eligiblePlayers(Object count) {
    return 'Eligible players: $count';
  }

  @override
  String get finalQuestionSetup => 'Final question setup';

  @override
  String get finalThemeLabel => 'Final theme';

  @override
  String get finalQuestionFieldLabel => 'Final question';

  @override
  String get finalControlAnswerLabel => 'Control answer (for host)';

  @override
  String get saveQuestion => 'Save question';

  @override
  String get openWagers => 'Open wagers';

  @override
  String get startVoiceAnswers => 'Start voice answers';

  @override
  String get revealFinal => 'Reveal final';

  @override
  String get themeLabel => 'Theme';

  @override
  String get questionLabel => 'Question';

  @override
  String get yourFinalWager => 'Your final wager';

  @override
  String get placeWager => 'Place wager';

  @override
  String get yourFinalAnswerLabel => 'Your final answer';

  @override
  String get submitAnswer => 'Submit answer';

  @override
  String finalThemesList(Object themes) {
    return 'Final themes: $themes';
  }

  @override
  String finalCurrentDeleter(Object name) {
    return 'Current deleter: $name';
  }

  @override
  String finalPickDeleterFrom(Object names) {
    return 'Host must pick deleter from: $names';
  }

  @override
  String get finalSelectFirstDeleterTie => 'Select first deleter (tie):';

  @override
  String finalSelectNamed(Object name) {
    return 'Select \"$name\"';
  }

  @override
  String finalDeleteTurn(Object name) {
    return 'Delete turn: $name';
  }

  @override
  String finalDeleteTheme(Object theme) {
    return 'Delete \"$theme\"';
  }

  @override
  String currentAnsweringPlayer(Object name) {
    return 'Current answering player: $name';
  }

  @override
  String finalRevealStep(int current, int total) {
    return 'Final reveal step: $current/$total';
  }

  @override
  String currentRevealPlayer(Object name) {
    return 'Current reveal: $name';
  }

  @override
  String get nowAnswering => 'Now answering';

  @override
  String get answerSubmitted => 'Answer submitted';

  @override
  String get answerNotSubmitted => 'Answer not submitted';

  @override
  String answerText(Object answer) {
    return 'Answer text: $answer';
  }

  @override
  String get revealed => 'Revealed';

  @override
  String get waitingReveal => 'Waiting reveal';

  @override
  String get discordVoiceInfo =>
      'Answers are given by voice in Discord. The host marks each result.';

  @override
  String playerWagerLine(Object name, Object wager) {
    return '$name | wager: $wager';
  }

  @override
  String get decisionLabel => 'Decision';

  @override
  String get playersAndStats => 'Players and stats';

  @override
  String get tabPlayers => 'Players';

  @override
  String get tabGameLog => 'Game log';

  @override
  String get offline => 'offline';

  @override
  String get scoreLabel => 'Score';

  @override
  String statsLine(Object buzz, Object correct, Object wrong) {
    return 'Stats: +$correct / -$wrong | Buzz: $buzz';
  }

  @override
  String playersCountSummary(int total, int active, int spectators) {
    return 'Players: $total | Active: $active | Spectators: $spectators';
  }

  @override
  String get manualAdjustment => 'Manual adjustment';

  @override
  String get kick => 'Kick';

  @override
  String get ban => 'Ban';

  @override
  String get unban => 'Unban';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get eventQuestionAdd => 'Question added';

  @override
  String get eventQuestionAddBulk => 'Questions added in bulk';

  @override
  String get eventQuestionUpdate => 'Question updated';

  @override
  String get eventQuestionDelete => 'Question deleted';

  @override
  String get eventPackSave => 'Pack saved';

  @override
  String get eventPackApply => 'Pack applied to room';

  @override
  String get eventTimerExpire => 'Timer expired';

  @override
  String get eventFinalRevealStart => 'Final reveal started';

  @override
  String get eventFinalRevealEnd => 'Final reveal finished';

  @override
  String get eventFinalRevealStep => 'Final reveal step';

  @override
  String get eventAnswerSubmit => 'Voice answer submitted';

  @override
  String get eventAnswerSubmitNumeric => 'Numeric answer submitted';

  @override
  String get eventFinalStart => 'Final round started';

  @override
  String get eventJudge => 'Host judged the answer';

  @override
  String get eventAppealSubmit => 'Appeal submitted';

  @override
  String get eventAppealResolve => 'Appeal resolved';

  @override
  String get eventScoreManual => 'Manual score adjustment';

  @override
  String get eventPause => 'Game paused';

  @override
  String get eventResume => 'Game resumed';

  @override
  String get eventFinalQuestionSet => 'Final question set';

  @override
  String get eventFinalThemeDeleterSelected => 'Final theme deleter selected';

  @override
  String get eventFinalThemeDeleted => 'Final theme deleted';

  @override
  String get eventFinalWagerOpen => 'Final wagers opened';

  @override
  String get eventFinalAnswersOpen => 'Final answers stage opened';

  @override
  String get eventFinalAnswerSubmit => 'Final answer submitted';

  @override
  String get eventFinalWager => 'Final wager submitted';

  @override
  String get eventFinalMark => 'Final answer result marked';

  @override
  String get eventStart => 'Game started';

  @override
  String get eventQuestionPick => 'Question picked';

  @override
  String get eventBuzzOpen => 'Buzz button opened';

  @override
  String get eventCatTarget => 'Cat in a bag target selected';

  @override
  String get eventWagerSet => 'Wager set';

  @override
  String get eventRoundNext => 'Round advanced';

  @override
  String get eventBuzz => 'Player buzzed';

  @override
  String get eventRoomCreated => 'Room created';

  @override
  String get eventJoin => 'Player joined room';

  @override
  String get eventRoleChange => 'Player role changed';

  @override
  String get eventKick => 'Player kicked';

  @override
  String get eventBan => 'Player banned';

  @override
  String get eventUnban => 'Player unbanned';

  @override
  String get eventRulesUpdate => 'Room rules updated';

  @override
  String get myPackDefault => 'My pack';

  @override
  String get roomEditorTitle => 'Themes and questions';

  @override
  String roomIdLabel(Object id) {
    return 'Room: $id';
  }

  @override
  String get answerForHostLabel => 'Answer (for host)';

  @override
  String get answerAliasesLabel => 'Answer aliases (comma-separated)';

  @override
  String get mediaUrlOptionalLabel => 'Media URL (optional)';

  @override
  String get costLabel => 'Cost';

  @override
  String get round1 => 'Round 1';

  @override
  String get addQuestion => 'Add question';

  @override
  String get questionAdded => 'Question added';

  @override
  String get questionUpdated => 'Question updated';

  @override
  String get questionDeleted => 'Question deleted';

  @override
  String get editAction => 'Edit';

  @override
  String get deleteAction => 'Delete';

  @override
  String get deleteQuestionTitle => 'Delete question';

  @override
  String get exportPackageTitle => 'Package export';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get importJson => 'Import JSON';

  @override
  String get noQuestions => 'No questions';

  @override
  String get packNameLabel => 'Pack name';

  @override
  String packSavedVersion(Object version) {
    return 'Pack saved v$version';
  }

  @override
  String get savePack => 'Save pack';

  @override
  String get packsCatalog => 'Packs catalog';

  @override
  String get goToRoom => 'Go to room';

  @override
  String get packsEmpty => 'No packs';

  @override
  String questionsCount(Object count) {
    return 'Questions: $count';
  }

  @override
  String get apply => 'Apply';

  @override
  String get close => 'Close';

  @override
  String get importPackJsonTitle => 'Import JSON pack';

  @override
  String get pasteJsonQuestionsHint => 'Paste JSON with questions';

  @override
  String get cancel => 'Cancel';

  @override
  String importError(Object error) {
    return 'Import error: $error';
  }

  @override
  String get importAction => 'Import';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get saveToFile => 'Save to file';

  @override
  String get clear => 'Clear';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get bulkThemeOptionalLabel => 'Bulk theme (optional)';

  @override
  String get bulkRoundAny => 'Round: -';

  @override
  String get onlySelected => 'Only selected';

  @override
  String packQuestionsSelectedReorder(int questions, int selected) {
    return 'Questions: $questions | Selected: $selected. Drag rows to reorder.';
  }

  @override
  String get packHasNoQuestionsYet => 'No questions in pack yet';

  @override
  String get themeQuestionAnswerRequired =>
      'Theme, question and answer are required';

  @override
  String get specifyThemeOrRoundForBulkUpdate =>
      'Specify theme and/or round for bulk update';

  @override
  String get noSelectedQuestions => 'No selected questions';

  @override
  String updatedQuestions(int count) {
    return 'Updated questions: $count';
  }

  @override
  String get packIsEmpty => 'Pack is empty';

  @override
  String get newPackDefault => 'New pack';

  @override
  String get fileSaved => 'File saved';

  @override
  String get saveCanceled => 'Save canceled';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageUkrainian => 'Ukrainian';

  @override
  String get change => 'Change';

  @override
  String get answerHotkeyLabel => 'Answer key';

  @override
  String answerHotkeyCurrent(Object key) {
    return 'Current key: $key';
  }

  @override
  String get answerHotkeyPressAny => 'Press any key...';

  @override
  String get keySpace => 'Space';

  @override
  String get popupErrorTitle => 'Error';

  @override
  String get popupSuccessTitle => 'Done';

  @override
  String get popupInfoTitle => 'Message';

  @override
  String get popupOk => 'OK';
}
