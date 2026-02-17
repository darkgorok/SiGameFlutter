import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../widgets/final_round_board.dart';
import '../widgets/question_flow_widgets.dart';
import '../widgets/room_side_panel.dart';
import '../widgets/room_top_bar.dart';
import 'room_editor_screen.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(gameActionsControllerProvider.notifier).joinRoom(widget.roomId);
  }

  @override
  void dispose() {
    ref
        .read(gameActionsControllerProvider.notifier)
        .markDisconnected(widget.roomId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text('Комната ${widget.roomId}')),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Ошибка: $error')),
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Комната не найдена'));
          }
          final isHost = room.hostUid == uid;
          final canResume = room.pausedByUid == uid || isHost;
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    RoomTopBar(
                      room: room,
                      isHost: isHost,
                      canResume: canResume,
                      roomId: widget.roomId,
                      onOpenEditor: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RoomEditorScreen(roomId: widget.roomId),
                        ),
                      ),
                    ),
                    Expanded(
                      child: room.currentRound == 3
                          ? FinalRoundBoard(room: room, roomId: widget.roomId)
                          : QuestionBoard(room: room, roomId: widget.roomId),
                    ),
                  ],
                ),
              ),
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
      ),
    );
  }
}
