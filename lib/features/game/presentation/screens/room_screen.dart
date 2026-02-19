import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/hotkeys.dart';
import '../../../../core/l10n.dart';
import '../../../../core/providers.dart';
import '../../../../core/runtime_flags.dart';
import '../../application/game_providers.dart';
import '../../game_models.dart';
import '../controllers/game_ui_permissions.dart';
import '../controllers/room_auto_flow_controller.dart';
import '../widgets/final_round_board.dart';
import '../widgets/question_flow_widgets.dart';
import '../widgets/room_side_panel.dart';
import '../widgets/room_top_bar.dart';
import 'room_editor_screen.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({
    super.key,
    required this.roomId,
    this.role = PlayerRole.player,
  });

  final String roomId;
  final PlayerRole role;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  bool _cleanView = false;
  final _autoFlowController = RoomAutoFlowController(
    enabled: e2eAutoFlowEnabled,
  );
  LogicalKeyboardKey _answerHotkey = AppHotkeys.defaultAnswerHotkey;
  late final RoomActions _roomActions;

  @override
  void initState() {
    super.initState();
    _roomActions = ref.read(roomActionsProvider);
    _loadAnswerHotkey();
  }

  @override
  void dispose() {
    _autoFlowController.dispose();
    _roomActions.markDisconnected(widget.roomId);
    super.dispose();
  }

  Future<void> _loadAnswerHotkey() async {
    final key = await AppHotkeys.loadAnswerHotkey();
    if (!mounted) return;
    setState(() => _answerHotkey = key);
  }

  bool _isTextInputFocused() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) {
      return false;
    }
    return focusedContext.widget is EditableText;
  }

  bool _isFinalUi(RoomModel room) {
    if (room.status == GameStatus.finalRound ||
        room.status == GameStatus.completed) {
      return true;
    }
    return room.phase == GamePhase.finalSetup ||
        room.phase == GamePhase.finalWagering ||
        room.phase == GamePhase.finalAnswering ||
        room.phase == GamePhase.finalReveal ||
        room.phase == GamePhase.gameOver;
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final playersAsync = ref.watch(playersStreamProvider(widget.roomId));
    final questionsAsync = ref.watch(questionsStreamProvider(widget.roomId));
    final uid = ref.watch(currentUserUidProvider) ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.l10n.roomDefaultName} ${widget.roomId}',
          key: const ValueKey('room_screen_title'),
        ),
      ),
      body: roomAsync.when(
        loading: () => const Center(child: LoadingPane()),
        error: (error, stackTrace) => Center(
          child: Text(context.l10n.errorWithDetails(error.toString())),
        ),
        data: (room) {
          if (room == null) {
            return Center(child: Text(context.l10n.routeNotFound));
          }
          return playersAsync.when(
            loading: () => const Center(child: LoadingPane()),
            error: (error, stackTrace) => Center(
              child: Text(context.l10n.errorWithDetails(error.toString())),
            ),
            data: (players) {
              final questions =
                  questionsAsync.valueOrNull ?? const <QuestionModel>[];
              PlayerModel? me;
              for (final p in players) {
                if (p.uid == uid) {
                  me = p;
                  break;
                }
              }
              final myRole = me?.role ?? widget.role;
              final isHost = room.hostUid == uid;
              final canResume = room.pausedByUid == uid || isHost;
              final canEdit = isHost || myRole == PlayerRole.editor;
              final canPause = myRole != PlayerRole.spectator || isHost;
              final isPaused = room.status == GameStatus.paused;
              final isLobby =
                  room.status == GameStatus.lobby &&
                  room.phase == GamePhase.lobby;
              final isFinalState =
                  room.status == GameStatus.finalRound ||
                  room.phase == GamePhase.finalSetup ||
                  room.phase == GamePhase.finalWagering ||
                  room.phase == GamePhase.finalAnswering ||
                  room.phase == GamePhase.finalReveal;
              final isCompletedState =
                  room.status == GameStatus.completed ||
                  room.phase == GamePhase.gameOver;
              final canStartGame = isHost && isLobby;
              final canAdvanceRound2 =
                  isHost &&
                  !isPaused &&
                  !isFinalState &&
                  !isCompletedState &&
                  room.currentRound < 2;
              final canStartFinalRound =
                  isHost && !isPaused && !isFinalState && !isCompletedState;
              final canPauseByState = canPause && !isCompletedState;
              final effectiveCleanView = myRole == PlayerRole.spectator
                  ? !_cleanView
                  : _cleanView;
              final roomActions = ref.read(roomActionsProvider);
              final questionActions = ref.read(questionActionsProvider);
              final finalActions = ref.read(finalActionsProvider);
              _autoFlowController.drive(
                mounted: mounted,
                uid: uid,
                room: room,
                players: players,
                questions: questions,
                myRole: myRole,
                isHost: isHost,
                roomId: widget.roomId,
                roomActions: roomActions,
                questionActions: questionActions,
                finalActions: finalActions,
              );
              final shortcuts = <ShortcutActivator, Intent>{
                const SingleActivator(LogicalKeyboardKey.keyS):
                    const _HostIntent(_HostAction.start),
                const SingleActivator(LogicalKeyboardKey.keyP):
                    const _HostIntent(_HostAction.pauseToggle),
                const SingleActivator(LogicalKeyboardKey.keyF):
                    const _HostIntent(_HostAction.finalRound),
                const SingleActivator(LogicalKeyboardKey.keyR):
                    const _HostIntent(_HostAction.round2),
                SingleActivator(_answerHotkey): const _BuzzIntent(),
              };
              return Shortcuts(
                shortcuts: shortcuts,
                child: Actions(
                  actions: {
                    _HostIntent: CallbackAction<_HostIntent>(
                      onInvoke: (intent) {
                        if (!isHost) return null;
                        switch (intent.action) {
                          case _HostAction.start:
                            if (canStartGame) {
                              roomActions.startGame(widget.roomId);
                            }
                          case _HostAction.pauseToggle:
                            if (room.status == GameStatus.paused) {
                              if (canResume) {
                                roomActions.resumeGame(widget.roomId);
                              }
                            } else if (canPauseByState) {
                              roomActions.pauseGame(widget.roomId);
                            }
                          case _HostAction.finalRound:
                            if (canStartFinalRound) {
                              roomActions.startFinalRound(widget.roomId);
                            }
                          case _HostAction.round2:
                            if (canAdvanceRound2) {
                              roomActions.advanceToRound2(widget.roomId);
                            }
                        }
                        return null;
                      },
                    ),
                    _BuzzIntent: CallbackAction<_BuzzIntent>(
                      onInvoke: (_) {
                        if (_isTextInputFocused()) {
                          return null;
                        }
                        if (room.activeQuestion?.type ==
                            QuestionType.closestNumber) {
                          return null;
                        }
                        if (GameUiPermissions.canBuzz(room, uid) &&
                            myRole != PlayerRole.spectator) {
                          questionActions.buzz(widget.roomId);
                        }
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    autofocus: true,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF040A1D), Color(0xFF03050F)],
                        ),
                      ),
                      child: Column(
                        children: [
                          if (!effectiveCleanView)
                            RoomTopBar(
                              room: room,
                              isHost: isHost,
                              canResume: canResume,
                              canPause: canPause,
                              canEdit: canEdit,
                              roomId: widget.roomId,
                              onOpenEditor: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RoomEditorScreen(roomId: widget.roomId),
                                ),
                              ),
                            ),
                          if (myRole == PlayerRole.spectator)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 12,
                                  bottom: 4,
                                ),
                                child: TextButton.icon(
                                  key: const ValueKey(
                                    'room_clean_view_toggle_button',
                                  ),
                                  onPressed: () =>
                                      setState(() => _cleanView = !_cleanView),
                                  icon: const Icon(Icons.tv),
                                  label: Text(
                                    effectiveCleanView
                                        ? context.l10n.showPanels
                                        : context.l10n.broadcastMode,
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 1260;
                                final sideWidth = !effectiveCleanView && isWide
                                    ? 360.0
                                    : 0.0;

                                Widget buildStage() {
                                  final sceneKey =
                                      'scene_${room.phase.value}_${room.activeQuestion?.id ?? 'none'}_${room.finalRevealIndex}_${room.finalAnswerIndex}';
                                  return Container(
                                    margin: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF0A1536),
                                          Color(0xFF040A1E),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF2D4EA3),
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x99000000),
                                          blurRadius: 28,
                                          offset: Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 420,
                                          ),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder:
                                              (child, animation) {
                                                final offset =
                                                    Tween<Offset>(
                                                      begin: const Offset(
                                                        0,
                                                        0.03,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(
                                                      CurvedAnimation(
                                                        parent: animation,
                                                        curve:
                                                            Curves.easeOutCubic,
                                                      ),
                                                    );
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: SlideTransition(
                                                    position: offset,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          child: KeyedSubtree(
                                            key: ValueKey(sceneKey),
                                            child: _isFinalUi(room)
                                                ? FinalRoundBoard(
                                                    room: room,
                                                    roomId: widget.roomId,
                                                    myRole: myRole,
                                                  )
                                                : QuestionBoard(
                                                    room: room,
                                                    roomId: widget.roomId,
                                                    myRole: myRole,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final mainScene = Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1340,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: buildStage(),
                                    ),
                                  ),
                                );

                                if (effectiveCleanView) {
                                  return mainScene;
                                }

                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(child: mainScene),
                                      SizedBox(
                                        width: sideWidth,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            0,
                                            12,
                                            12,
                                            12,
                                          ),
                                          child: Card(
                                            clipBehavior:
                                                Clip.antiAliasWithSaveLayer,
                                            child: RoomSidePanel(
                                              room: room,
                                              roomId: widget.roomId,
                                              isHost: isHost,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    Expanded(child: mainScene),
                                    SizedBox(
                                      height: 280,
                                      child: Card(
                                        margin: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        clipBehavior:
                                            Clip.antiAliasWithSaveLayer,
                                        child: RoomSidePanel(
                                          room: room,
                                          roomId: widget.roomId,
                                          isHost: isHost,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _HostAction { start, pauseToggle, finalRound, round2 }

class _HostIntent extends Intent {
  const _HostIntent(this.action);

  final _HostAction action;
}

class _BuzzIntent extends Intent {
  const _BuzzIntent();
}
