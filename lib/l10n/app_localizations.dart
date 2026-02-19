import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SiGame Online'**
  String get appTitle;

  /// No description provided for @routeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Route not found'**
  String get routeNotFound;

  /// No description provided for @initializationError.
  ///
  /// In en, this message translates to:
  /// **'Initialization error: {error}'**
  String initializationError(Object error);

  /// No description provided for @firebaseNotConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured.\n\nCreate local file config/firebase.web.json (example: config/firebase.web.example.json), then run:\n\nflutter run -d chrome --dart-define-from-file=config/firebase.web.json\n\nAfter that rooms, sync, reconnect and online game will be available.'**
  String get firebaseNotConfiguredMessage;

  /// No description provided for @homeCreateRoom.
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get homeCreateRoom;

  /// No description provided for @homeFindRoom.
  ///
  /// In en, this message translates to:
  /// **'Find room'**
  String get homeFindRoom;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsNameLabel;

  /// No description provided for @settingsVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume: {percent}%'**
  String settingsVolume(int percent);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @changeAvatarError.
  ///
  /// In en, this message translates to:
  /// **'Could not pick avatar: {error}'**
  String changeAvatarError(Object error);

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameCannotBeEmpty;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Save error: {error}'**
  String saveError(Object error);

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get profileSetupTitle;

  /// No description provided for @nicknameRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Nickname (required)'**
  String get nicknameRequiredHint;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @nicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Nickname is required'**
  String get nicknameRequired;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNickLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get profileNickLabel;

  /// No description provided for @profileAvatarUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Avatar URL'**
  String get profileAvatarUrlLabel;

  /// No description provided for @roomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get roomsTitle;

  /// No description provided for @newGameDefault.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGameDefault;

  /// No description provided for @roomNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomNameLabel;

  /// No description provided for @roomNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Room name is required'**
  String get roomNameRequired;

  /// No description provided for @createRoomDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get createRoomDialogTitle;

  /// No description provided for @roomPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get roomPasswordLabel;

  /// No description provided for @invalidRoomPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid room password.'**
  String get invalidRoomPassword;

  /// No description provided for @roomPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Room password is required.'**
  String get roomPasswordRequired;

  /// No description provided for @packFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Pack file is required'**
  String get packFileRequired;

  /// No description provided for @enterRoomPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter password for: {roomName}'**
  String enterRoomPasswordTitle(Object roomName);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createAndUploadPack.
  ///
  /// In en, this message translates to:
  /// **'Create and upload pack from file'**
  String get createAndUploadPack;

  /// No description provided for @packEditor.
  ///
  /// In en, this message translates to:
  /// **'Pack editor'**
  String get packEditor;

  /// No description provided for @packEditorCreate.
  ///
  /// In en, this message translates to:
  /// **'Create pack'**
  String get packEditorCreate;

  /// No description provided for @packEditorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit pack'**
  String get packEditorEdit;

  /// No description provided for @packSelectFilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a pack file'**
  String get packSelectFilePrompt;

  /// No description provided for @packSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get packSelectFile;

  /// No description provided for @packInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Invalid pack file'**
  String get packInvalidFile;

  /// No description provided for @errorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithDetails(Object error);

  /// No description provided for @noRoomsYet.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet'**
  String get noRoomsYet;

  /// No description provided for @roomStatusPhase.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} | Phase: {phase}'**
  String roomStatusPhase(Object status, Object phase);

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @spectator.
  ///
  /// In en, this message translates to:
  /// **'Spectator'**
  String get spectator;

  /// No description provided for @roomDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomDefaultName;

  /// No description provided for @createRoomError.
  ///
  /// In en, this message translates to:
  /// **'Room creation failed: {error}'**
  String createRoomError(Object error);

  /// No description provided for @noQuestionsInFile.
  ///
  /// In en, this message translates to:
  /// **'No questions in file'**
  String get noQuestionsInFile;

  /// No description provided for @questionsLoaded.
  ///
  /// In en, this message translates to:
  /// **'Questions loaded: {count}'**
  String questionsLoaded(int count);

  /// No description provided for @packUploadError.
  ///
  /// In en, this message translates to:
  /// **'Pack upload error: {error}'**
  String packUploadError(Object error);

  /// No description provided for @appFailurePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Not enough permissions for this action.'**
  String get appFailurePermissionDenied;

  /// No description provided for @appFailureNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network problem. Check your connection and try again.'**
  String get appFailureNetworkError;

  /// No description provided for @gameStatusLobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get gameStatusLobby;

  /// No description provided for @gameStatusInGame.
  ///
  /// In en, this message translates to:
  /// **'In game'**
  String get gameStatusInGame;

  /// No description provided for @gameStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get gameStatusPaused;

  /// No description provided for @gameStatusFinalRound.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get gameStatusFinalRound;

  /// No description provided for @gameStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get gameStatusCompleted;

  /// No description provided for @gamePhaseLobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get gamePhaseLobby;

  /// No description provided for @gamePhaseBoardSelect.
  ///
  /// In en, this message translates to:
  /// **'Question selection'**
  String get gamePhaseBoardSelect;

  /// No description provided for @gamePhaseQuestionReveal.
  ///
  /// In en, this message translates to:
  /// **'Question reveal'**
  String get gamePhaseQuestionReveal;

  /// No description provided for @gamePhaseCatTargeting.
  ///
  /// In en, this message translates to:
  /// **'Cat in a bag: choose player'**
  String get gamePhaseCatTargeting;

  /// No description provided for @gamePhaseWagerBidding.
  ///
  /// In en, this message translates to:
  /// **'Auction: wager'**
  String get gamePhaseWagerBidding;

  /// No description provided for @gamePhaseAnswering.
  ///
  /// In en, this message translates to:
  /// **'Answering'**
  String get gamePhaseAnswering;

  /// No description provided for @gamePhaseAnswerReview.
  ///
  /// In en, this message translates to:
  /// **'Host decision'**
  String get gamePhaseAnswerReview;

  /// No description provided for @gamePhaseFinalSetup.
  ///
  /// In en, this message translates to:
  /// **'Final: setup'**
  String get gamePhaseFinalSetup;

  /// No description provided for @gamePhaseFinalWagering.
  ///
  /// In en, this message translates to:
  /// **'Final: wagers'**
  String get gamePhaseFinalWagering;

  /// No description provided for @gamePhaseFinalAnswering.
  ///
  /// In en, this message translates to:
  /// **'Final: voice answers'**
  String get gamePhaseFinalAnswering;

  /// No description provided for @gamePhaseFinalReveal.
  ///
  /// In en, this message translates to:
  /// **'Final: reveal'**
  String get gamePhaseFinalReveal;

  /// No description provided for @gamePhaseGameOver.
  ///
  /// In en, this message translates to:
  /// **'Game over'**
  String get gamePhaseGameOver;

  /// No description provided for @questionTypeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get questionTypeNormal;

  /// No description provided for @questionTypeCat.
  ///
  /// In en, this message translates to:
  /// **'Cat in a bag'**
  String get questionTypeCat;

  /// No description provided for @questionTypeWager.
  ///
  /// In en, this message translates to:
  /// **'Auction question'**
  String get questionTypeWager;

  /// No description provided for @questionTypeClosestNumber.
  ///
  /// In en, this message translates to:
  /// **'Closest number'**
  String get questionTypeClosestNumber;

  /// No description provided for @questionMediaNone.
  ///
  /// In en, this message translates to:
  /// **'No media'**
  String get questionMediaNone;

  /// No description provided for @questionMediaImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get questionMediaImage;

  /// No description provided for @questionMediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get questionMediaAudio;

  /// No description provided for @questionMediaVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get questionMediaVideo;

  /// No description provided for @roleHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get roleHost;

  /// No description provided for @rolePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get rolePlayer;

  /// No description provided for @roleSpectator.
  ///
  /// In en, this message translates to:
  /// **'Spectator'**
  String get roleSpectator;

  /// No description provided for @roleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get roleEditor;

  /// No description provided for @finalResultPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get finalResultPending;

  /// No description provided for @finalResultCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get finalResultCorrect;

  /// No description provided for @finalResultWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get finalResultWrong;

  /// No description provided for @finalResultNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get finalResultNoAnswer;

  /// No description provided for @themeFallback.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeFallback;

  /// No description provided for @noThemeFallback.
  ///
  /// In en, this message translates to:
  /// **'No theme'**
  String get noThemeFallback;

  /// No description provided for @serverNoRoomId.
  ///
  /// In en, this message translates to:
  /// **'Server did not return roomId'**
  String get serverNoRoomId;

  /// No description provided for @playerFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerFallbackName;

  /// No description provided for @serverErrorDefault.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get serverErrorDefault;

  /// No description provided for @showPanels.
  ///
  /// In en, this message translates to:
  /// **'Show panels'**
  String get showPanels;

  /// No description provided for @broadcastMode.
  ///
  /// In en, this message translates to:
  /// **'Broadcast mode'**
  String get broadcastMode;

  /// No description provided for @roundLabel.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get roundLabel;

  /// No description provided for @questionChooser.
  ///
  /// In en, this message translates to:
  /// **'Question chooser'**
  String get questionChooser;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @unpause.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get unpause;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @round2.
  ///
  /// In en, this message translates to:
  /// **'Round 2'**
  String get round2;

  /// No description provided for @finalRoundButton.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get finalRoundButton;

  /// No description provided for @timerSeconds.
  ///
  /// In en, this message translates to:
  /// **'Timer: {seconds} sec'**
  String timerSeconds(Object seconds);

  /// No description provided for @noQuestionsCurrentRound.
  ///
  /// In en, this message translates to:
  /// **'No questions for current round'**
  String get noQuestionsCurrentRound;

  /// No description provided for @activeQuestionHeader.
  ///
  /// In en, this message translates to:
  /// **'Active: {theme} | {type} | {cost}'**
  String activeQuestionHeader(Object cost, Object theme, Object type);

  /// No description provided for @mediaLabel.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get mediaLabel;

  /// No description provided for @mediaPreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio media'**
  String get mediaPreviewAudio;

  /// No description provided for @mediaPreviewVideo.
  ///
  /// In en, this message translates to:
  /// **'Video media'**
  String get mediaPreviewVideo;

  /// No description provided for @mediaPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Media preview unavailable'**
  String get mediaPreviewUnavailable;

  /// No description provided for @openAnswerButton.
  ///
  /// In en, this message translates to:
  /// **'Open answer button'**
  String get openAnswerButton;

  /// No description provided for @answeringNow.
  ///
  /// In en, this message translates to:
  /// **'Answering'**
  String get answeringNow;

  /// No description provided for @answeredByVoice.
  ///
  /// In en, this message translates to:
  /// **'Answered by voice'**
  String get answeredByVoice;

  /// No description provided for @buzzButton.
  ///
  /// In en, this message translates to:
  /// **'Buzz'**
  String get buzzButton;

  /// No description provided for @closestNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a number. The closest answer wins.'**
  String get closestNumberHint;

  /// No description provided for @numericAnswerFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Your answer (number)'**
  String get numericAnswerFieldLabel;

  /// No description provided for @submitNumericAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit number'**
  String get submitNumericAnswer;

  /// No description provided for @waitingHostDecision.
  ///
  /// In en, this message translates to:
  /// **'Waiting for host decision on voice answer'**
  String get waitingHostDecision;

  /// No description provided for @chooseNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Choose the next question on the board'**
  String get chooseNextQuestion;

  /// No description provided for @waitingCatSelection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for player selection for Cat in a bag'**
  String get waitingCatSelection;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer to: {name}'**
  String transferTo(Object name);

  /// No description provided for @wagerLabel.
  ///
  /// In en, this message translates to:
  /// **'Wager'**
  String get wagerLabel;

  /// No description provided for @confirmWager.
  ///
  /// In en, this message translates to:
  /// **'Confirm wager'**
  String get confirmWager;

  /// No description provided for @whoAnswered.
  ///
  /// In en, this message translates to:
  /// **'Who answered: {uid}'**
  String whoAnswered(Object uid);

  /// No description provided for @hostVoiceCheck.
  ///
  /// In en, this message translates to:
  /// **'The host validates voice answers'**
  String get hostVoiceCheck;

  /// No description provided for @acceptedAnswers.
  ///
  /// In en, this message translates to:
  /// **'Accepted answers: {aliases}'**
  String acceptedAnswers(Object aliases);

  /// No description provided for @finalRoundLabel.
  ///
  /// In en, this message translates to:
  /// **'Final round'**
  String get finalRoundLabel;

  /// No description provided for @eligiblePlayers.
  ///
  /// In en, this message translates to:
  /// **'Eligible players: {count}'**
  String eligiblePlayers(Object count);

  /// No description provided for @finalQuestionSetup.
  ///
  /// In en, this message translates to:
  /// **'Final question setup'**
  String get finalQuestionSetup;

  /// No description provided for @finalThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Final theme'**
  String get finalThemeLabel;

  /// No description provided for @finalQuestionFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Final question'**
  String get finalQuestionFieldLabel;

  /// No description provided for @finalControlAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Control answer (for host)'**
  String get finalControlAnswerLabel;

  /// No description provided for @saveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Save question'**
  String get saveQuestion;

  /// No description provided for @openWagers.
  ///
  /// In en, this message translates to:
  /// **'Open wagers'**
  String get openWagers;

  /// No description provided for @startVoiceAnswers.
  ///
  /// In en, this message translates to:
  /// **'Start voice answers'**
  String get startVoiceAnswers;

  /// No description provided for @revealFinal.
  ///
  /// In en, this message translates to:
  /// **'Reveal final'**
  String get revealFinal;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @questionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionLabel;

  /// No description provided for @yourFinalWager.
  ///
  /// In en, this message translates to:
  /// **'Your final wager'**
  String get yourFinalWager;

  /// No description provided for @placeWager.
  ///
  /// In en, this message translates to:
  /// **'Place wager'**
  String get placeWager;

  /// No description provided for @yourFinalAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your final answer'**
  String get yourFinalAnswerLabel;

  /// No description provided for @submitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get submitAnswer;

  /// No description provided for @finalThemesList.
  ///
  /// In en, this message translates to:
  /// **'Final themes: {themes}'**
  String finalThemesList(Object themes);

  /// No description provided for @finalCurrentDeleter.
  ///
  /// In en, this message translates to:
  /// **'Current deleter: {name}'**
  String finalCurrentDeleter(Object name);

  /// No description provided for @finalPickDeleterFrom.
  ///
  /// In en, this message translates to:
  /// **'Host must pick deleter from: {names}'**
  String finalPickDeleterFrom(Object names);

  /// No description provided for @finalSelectFirstDeleterTie.
  ///
  /// In en, this message translates to:
  /// **'Select first deleter (tie):'**
  String get finalSelectFirstDeleterTie;

  /// No description provided for @finalSelectNamed.
  ///
  /// In en, this message translates to:
  /// **'Select \"{name}\"'**
  String finalSelectNamed(Object name);

  /// No description provided for @finalDeleteTurn.
  ///
  /// In en, this message translates to:
  /// **'Delete turn: {name}'**
  String finalDeleteTurn(Object name);

  /// No description provided for @finalDeleteTheme.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{theme}\"'**
  String finalDeleteTheme(Object theme);

  /// No description provided for @currentAnsweringPlayer.
  ///
  /// In en, this message translates to:
  /// **'Current answering player: {name}'**
  String currentAnsweringPlayer(Object name);

  /// No description provided for @finalRevealStep.
  ///
  /// In en, this message translates to:
  /// **'Final reveal step: {current}/{total}'**
  String finalRevealStep(int current, int total);

  /// No description provided for @currentRevealPlayer.
  ///
  /// In en, this message translates to:
  /// **'Current reveal: {name}'**
  String currentRevealPlayer(Object name);

  /// No description provided for @nowAnswering.
  ///
  /// In en, this message translates to:
  /// **'Now answering'**
  String get nowAnswering;

  /// No description provided for @answerSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Answer submitted'**
  String get answerSubmitted;

  /// No description provided for @answerNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Answer not submitted'**
  String get answerNotSubmitted;

  /// No description provided for @answerText.
  ///
  /// In en, this message translates to:
  /// **'Answer text: {answer}'**
  String answerText(Object answer);

  /// No description provided for @revealed.
  ///
  /// In en, this message translates to:
  /// **'Revealed'**
  String get revealed;

  /// No description provided for @waitingReveal.
  ///
  /// In en, this message translates to:
  /// **'Waiting reveal'**
  String get waitingReveal;

  /// No description provided for @discordVoiceInfo.
  ///
  /// In en, this message translates to:
  /// **'Answers are given by voice in Discord. The host marks each result.'**
  String get discordVoiceInfo;

  /// No description provided for @playerWagerLine.
  ///
  /// In en, this message translates to:
  /// **'{name} | wager: {wager}'**
  String playerWagerLine(Object name, Object wager);

  /// No description provided for @decisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get decisionLabel;

  /// No description provided for @playersAndStats.
  ///
  /// In en, this message translates to:
  /// **'Players and stats'**
  String get playersAndStats;

  /// No description provided for @tabPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get tabPlayers;

  /// No description provided for @tabGameLog.
  ///
  /// In en, this message translates to:
  /// **'Game log'**
  String get tabGameLog;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get offline;

  /// No description provided for @scoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get scoreLabel;

  /// No description provided for @statsLine.
  ///
  /// In en, this message translates to:
  /// **'Stats: +{correct} / -{wrong} | Buzz: {buzz}'**
  String statsLine(Object buzz, Object correct, Object wrong);

  /// No description provided for @playersCountSummary.
  ///
  /// In en, this message translates to:
  /// **'Players: {total} | Active: {active} | Spectators: {spectators}'**
  String playersCountSummary(int total, int active, int spectators);

  /// No description provided for @manualAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Manual adjustment'**
  String get manualAdjustment;

  /// No description provided for @kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kick;

  /// No description provided for @ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get ban;

  /// No description provided for @unban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get unban;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get noEventsYet;

  /// No description provided for @eventQuestionAdd.
  ///
  /// In en, this message translates to:
  /// **'Question added'**
  String get eventQuestionAdd;

  /// No description provided for @eventQuestionAddBulk.
  ///
  /// In en, this message translates to:
  /// **'Questions added in bulk'**
  String get eventQuestionAddBulk;

  /// No description provided for @eventQuestionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Question updated'**
  String get eventQuestionUpdate;

  /// No description provided for @eventQuestionDelete.
  ///
  /// In en, this message translates to:
  /// **'Question deleted'**
  String get eventQuestionDelete;

  /// No description provided for @eventPackSave.
  ///
  /// In en, this message translates to:
  /// **'Pack saved'**
  String get eventPackSave;

  /// No description provided for @eventPackApply.
  ///
  /// In en, this message translates to:
  /// **'Pack applied to room'**
  String get eventPackApply;

  /// No description provided for @eventTimerExpire.
  ///
  /// In en, this message translates to:
  /// **'Timer expired'**
  String get eventTimerExpire;

  /// No description provided for @eventFinalRevealStart.
  ///
  /// In en, this message translates to:
  /// **'Final reveal started'**
  String get eventFinalRevealStart;

  /// No description provided for @eventFinalRevealEnd.
  ///
  /// In en, this message translates to:
  /// **'Final reveal finished'**
  String get eventFinalRevealEnd;

  /// No description provided for @eventFinalRevealStep.
  ///
  /// In en, this message translates to:
  /// **'Final reveal step'**
  String get eventFinalRevealStep;

  /// No description provided for @eventAnswerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Voice answer submitted'**
  String get eventAnswerSubmit;

  /// No description provided for @eventAnswerSubmitNumeric.
  ///
  /// In en, this message translates to:
  /// **'Numeric answer submitted'**
  String get eventAnswerSubmitNumeric;

  /// No description provided for @eventFinalStart.
  ///
  /// In en, this message translates to:
  /// **'Final round started'**
  String get eventFinalStart;

  /// No description provided for @eventJudge.
  ///
  /// In en, this message translates to:
  /// **'Host judged the answer'**
  String get eventJudge;

  /// No description provided for @eventAppealSubmit.
  ///
  /// In en, this message translates to:
  /// **'Appeal submitted'**
  String get eventAppealSubmit;

  /// No description provided for @eventAppealResolve.
  ///
  /// In en, this message translates to:
  /// **'Appeal resolved'**
  String get eventAppealResolve;

  /// No description provided for @eventScoreManual.
  ///
  /// In en, this message translates to:
  /// **'Manual score adjustment'**
  String get eventScoreManual;

  /// No description provided for @eventPause.
  ///
  /// In en, this message translates to:
  /// **'Game paused'**
  String get eventPause;

  /// No description provided for @eventResume.
  ///
  /// In en, this message translates to:
  /// **'Game resumed'**
  String get eventResume;

  /// No description provided for @eventFinalQuestionSet.
  ///
  /// In en, this message translates to:
  /// **'Final question set'**
  String get eventFinalQuestionSet;

  /// No description provided for @eventFinalThemeDeleterSelected.
  ///
  /// In en, this message translates to:
  /// **'Final theme deleter selected'**
  String get eventFinalThemeDeleterSelected;

  /// No description provided for @eventFinalThemeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Final theme deleted'**
  String get eventFinalThemeDeleted;

  /// No description provided for @eventFinalWagerOpen.
  ///
  /// In en, this message translates to:
  /// **'Final wagers opened'**
  String get eventFinalWagerOpen;

  /// No description provided for @eventFinalAnswersOpen.
  ///
  /// In en, this message translates to:
  /// **'Final answers stage opened'**
  String get eventFinalAnswersOpen;

  /// No description provided for @eventFinalAnswerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Final answer submitted'**
  String get eventFinalAnswerSubmit;

  /// No description provided for @eventFinalWager.
  ///
  /// In en, this message translates to:
  /// **'Final wager submitted'**
  String get eventFinalWager;

  /// No description provided for @eventFinalMark.
  ///
  /// In en, this message translates to:
  /// **'Final answer result marked'**
  String get eventFinalMark;

  /// No description provided for @eventStart.
  ///
  /// In en, this message translates to:
  /// **'Game started'**
  String get eventStart;

  /// No description provided for @eventQuestionPick.
  ///
  /// In en, this message translates to:
  /// **'Question picked'**
  String get eventQuestionPick;

  /// No description provided for @eventBuzzOpen.
  ///
  /// In en, this message translates to:
  /// **'Buzz button opened'**
  String get eventBuzzOpen;

  /// No description provided for @eventCatTarget.
  ///
  /// In en, this message translates to:
  /// **'Cat in a bag target selected'**
  String get eventCatTarget;

  /// No description provided for @eventWagerSet.
  ///
  /// In en, this message translates to:
  /// **'Wager set'**
  String get eventWagerSet;

  /// No description provided for @eventRoundNext.
  ///
  /// In en, this message translates to:
  /// **'Round advanced'**
  String get eventRoundNext;

  /// No description provided for @eventBuzz.
  ///
  /// In en, this message translates to:
  /// **'Player buzzed'**
  String get eventBuzz;

  /// No description provided for @eventRoomCreated.
  ///
  /// In en, this message translates to:
  /// **'Room created'**
  String get eventRoomCreated;

  /// No description provided for @eventJoin.
  ///
  /// In en, this message translates to:
  /// **'Player joined room'**
  String get eventJoin;

  /// No description provided for @eventRoleChange.
  ///
  /// In en, this message translates to:
  /// **'Player role changed'**
  String get eventRoleChange;

  /// No description provided for @eventKick.
  ///
  /// In en, this message translates to:
  /// **'Player kicked'**
  String get eventKick;

  /// No description provided for @eventBan.
  ///
  /// In en, this message translates to:
  /// **'Player banned'**
  String get eventBan;

  /// No description provided for @eventUnban.
  ///
  /// In en, this message translates to:
  /// **'Player unbanned'**
  String get eventUnban;

  /// No description provided for @eventRulesUpdate.
  ///
  /// In en, this message translates to:
  /// **'Room rules updated'**
  String get eventRulesUpdate;

  /// No description provided for @myPackDefault.
  ///
  /// In en, this message translates to:
  /// **'My pack'**
  String get myPackDefault;

  /// No description provided for @roomEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Themes and questions'**
  String get roomEditorTitle;

  /// No description provided for @roomIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Room: {id}'**
  String roomIdLabel(Object id);

  /// No description provided for @answerForHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer (for host)'**
  String get answerForHostLabel;

  /// No description provided for @answerAliasesLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer aliases (comma-separated)'**
  String get answerAliasesLabel;

  /// No description provided for @mediaUrlOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Media URL (optional)'**
  String get mediaUrlOptionalLabel;

  /// No description provided for @costLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get costLabel;

  /// No description provided for @round1.
  ///
  /// In en, this message translates to:
  /// **'Round 1'**
  String get round1;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get addQuestion;

  /// No description provided for @questionAdded.
  ///
  /// In en, this message translates to:
  /// **'Question added'**
  String get questionAdded;

  /// No description provided for @questionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Question updated'**
  String get questionUpdated;

  /// No description provided for @questionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Question deleted'**
  String get questionDeleted;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @deleteQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete question'**
  String get deleteQuestionTitle;

  /// No description provided for @exportPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Package export'**
  String get exportPackageTitle;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJson;

  /// No description provided for @importJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get importJson;

  /// No description provided for @noQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions'**
  String get noQuestions;

  /// No description provided for @packNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Pack name'**
  String get packNameLabel;

  /// No description provided for @packSavedVersion.
  ///
  /// In en, this message translates to:
  /// **'Pack saved v{version}'**
  String packSavedVersion(Object version);

  /// No description provided for @savePack.
  ///
  /// In en, this message translates to:
  /// **'Save pack'**
  String get savePack;

  /// No description provided for @packsCatalog.
  ///
  /// In en, this message translates to:
  /// **'Packs catalog'**
  String get packsCatalog;

  /// No description provided for @goToRoom.
  ///
  /// In en, this message translates to:
  /// **'Go to room'**
  String get goToRoom;

  /// No description provided for @packsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No packs'**
  String get packsEmpty;

  /// No description provided for @questionsCount.
  ///
  /// In en, this message translates to:
  /// **'Questions: {count}'**
  String questionsCount(Object count);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @importPackJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Import JSON pack'**
  String get importPackJsonTitle;

  /// No description provided for @pasteJsonQuestionsHint.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON with questions'**
  String get pasteJsonQuestionsHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import error: {error}'**
  String importError(Object error);

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get uploadFile;

  /// No description provided for @saveToFile.
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get saveToFile;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @bulkThemeOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Bulk theme (optional)'**
  String get bulkThemeOptionalLabel;

  /// No description provided for @bulkRoundAny.
  ///
  /// In en, this message translates to:
  /// **'Round: -'**
  String get bulkRoundAny;

  /// No description provided for @onlySelected.
  ///
  /// In en, this message translates to:
  /// **'Only selected'**
  String get onlySelected;

  /// No description provided for @packQuestionsSelectedReorder.
  ///
  /// In en, this message translates to:
  /// **'Questions: {questions} | Selected: {selected}. Drag rows to reorder.'**
  String packQuestionsSelectedReorder(int questions, int selected);

  /// No description provided for @packHasNoQuestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No questions in pack yet'**
  String get packHasNoQuestionsYet;

  /// No description provided for @themeQuestionAnswerRequired.
  ///
  /// In en, this message translates to:
  /// **'Theme, question and answer are required'**
  String get themeQuestionAnswerRequired;

  /// No description provided for @specifyThemeOrRoundForBulkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Specify theme and/or round for bulk update'**
  String get specifyThemeOrRoundForBulkUpdate;

  /// No description provided for @noSelectedQuestions.
  ///
  /// In en, this message translates to:
  /// **'No selected questions'**
  String get noSelectedQuestions;

  /// No description provided for @updatedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Updated questions: {count}'**
  String updatedQuestions(int count);

  /// No description provided for @packIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pack is empty'**
  String get packIsEmpty;

  /// No description provided for @newPackDefault.
  ///
  /// In en, this message translates to:
  /// **'New pack'**
  String get newPackDefault;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get fileSaved;

  /// No description provided for @saveCanceled.
  ///
  /// In en, this message translates to:
  /// **'Save canceled'**
  String get saveCanceled;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @answerHotkeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer key'**
  String get answerHotkeyLabel;

  /// No description provided for @answerHotkeyCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current key: {key}'**
  String answerHotkeyCurrent(Object key);

  /// No description provided for @answerHotkeyPressAny.
  ///
  /// In en, this message translates to:
  /// **'Press any key...'**
  String get answerHotkeyPressAny;

  /// No description provided for @keySpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get keySpace;

  /// No description provided for @popupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get popupErrorTitle;

  /// No description provided for @popupSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get popupSuccessTitle;

  /// No description provided for @popupInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get popupInfoTitle;

  /// No description provided for @popupOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get popupOk;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
