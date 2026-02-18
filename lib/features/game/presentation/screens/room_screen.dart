import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/hotkeys.dart';
import '../../../../core/l10n.dart';
import '../../application/game_providers.dart';
import '../../game_models.dart';
import '../controllers/game_ui_permissions.dart';
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
  LogicalKeyboardKey _answerHotkey = AppHotkeys.defaultAnswerHotkey;

  @override
  void initState() {
    super.initState();
    _loadAnswerHotkey();
    ref
        .read(gameActionsControllerProvider.notifier)
        .joinRoom(widget.roomId, role: widget.role);
  }

  @override
  void dispose() {
    ref
        .read(gameActionsControllerProvider.notifier)
        .markDisconnected(widget.roomId);
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

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final playersAsync = ref.watch(playersStreamProvider(widget.roomId));
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text('${context.l10n.roomDefaultName} ${widget.roomId}'),
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
              PlayerModel? me;
              for (final p in players) {
                if (p.uid == uid) {
                  me = p;
                  break;
                }
              }
              final myRole = me?.role ?? PlayerRole.player;
              final isHost = room.hostUid == uid;
              final canResume = room.pausedByUid == uid || isHost;
              final canEdit = isHost || myRole == PlayerRole.editor;
              final canPause = myRole != PlayerRole.spectator || isHost;
              final effectiveCleanView =
                  _cleanView || myRole == PlayerRole.spectator;
              final actions = ref.read(gameActionsControllerProvider.notifier);
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
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Shortcuts(
                      shortcuts: shortcuts,
                      child: Actions(
                        actions: {
                          _HostIntent: CallbackAction<_HostIntent>(
                            onInvoke: (intent) {
                              if (!isHost) return null;
                              switch (intent.action) {
                                case _HostAction.start:
                                  actions.startGame(widget.roomId);
                                case _HostAction.pauseToggle:
                                  if (room.status == GameStatus.paused) {
                                    if (canResume) {
                                      actions.resumeGame(widget.roomId);
                                    }
                                  } else if (canPause) {
                                    actions.pauseGame(widget.roomId);
                                  }
                                case _HostAction.finalRound:
                                  actions.startFinalRound(widget.roomId);
                                case _HostAction.round2:
                                  actions.advanceToRound2(widget.roomId);
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
                                actions.buzz(widget.roomId);
                              }
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          autofocus: true,
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
                                  onOpenEditor: () =>
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RoomEditorScreen(
                                            roomId: widget.roomId,
                                          ),
                                        ),
                                      ),
                                ),
                              if (myRole == PlayerRole.spectator)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => setState(
                                      () => _cleanView = !_cleanView,
                                    ),
                                    icon: const Icon(Icons.tv),
                                    label: Text(
                                      effectiveCleanView
                                          ? context.l10n.showPanels
                                          : context.l10n.broadcastMode,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: room.currentRound == 3
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!effectiveCleanView)
                    Expanded(
                      flex: 2,
                      child: RoomSidePanel(
                        room: room,
                        roomId: widget.roomId,
                        isHost: isHost,
                      ),
                    ),
                ],
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
