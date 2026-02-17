import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../game/application/game_providers.dart';
import '../game/game_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Своя игра онлайн'),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('UID: $uid', textAlign: TextAlign.center),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.profile),
                  child: const Text('Профиль'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.rooms),
                  child: const Text('Доступные комнаты'),
                ),
                const SizedBox(height: 8),
                FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    final roomId = snapshot.data?.getString('last_room_id');
                    final roleRaw = snapshot.data?.getString('last_room_role');
                    final role = PlayerRole.fromValue(roleRaw);
                    return ElevatedButton(
                      onPressed: roomId == null
                          ? null
                          : () => Navigator.of(context).pushNamed(
                              AppRoutes.room,
                              arguments: RoomRouteArgs(
                                roomId: roomId,
                                role: role,
                              ),
                            ),
                      child: Text(
                        roomId == null
                            ? 'Нет комнаты для ре-коннекта'
                            : 'Перезайти в последнюю комнату',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Турнирный рейтинг',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ref
                      .watch(leaderboardProvider)
                      .when(
                        data: (entries) {
                          if (entries.isEmpty) {
                            return const Center(
                              child: Text('Рейтинг пока пуст'),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final e = entries[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${index + 1}. ${e.nickname}',
                                ),
                                subtitle: Text(
                                  'Игр: ${e.games} | Побед: ${e.wins} | Очки: ${e.totalScore}',
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Text('Ошибка рейтинга: $error'),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
