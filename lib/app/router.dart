import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../features/game/game_models.dart';
import '../features/game/presentation/screens/room_editor_screen.dart';
import '../features/game/presentation/screens/room_screen.dart';
import '../features/home/home_screen.dart';
import '../features/packs/edit_pack_loader_screen.dart';
import '../features/packs/pack_editor_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rooms/rooms_screen.dart';
import '../features/settings/settings_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const profile = '/profile';
  static const settings = '/settings';
  static const rooms = '/rooms';
  static const packEditor = '/pack-editor';
  static const packEditorCreate = '/pack-editor/create';
  static const packEditorEdit = '/pack-editor/edit';
  static const room = '/room';
  static const roomEditor = '/room-editor';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.rooms:
        return MaterialPageRoute(builder: (_) => const RoomsScreen());
      case AppRoutes.packEditor:
        return MaterialPageRoute(builder: (_) => const PackEditorScreen());
      case AppRoutes.packEditorCreate:
        return MaterialPageRoute(
          builder: (_) => const PackEditorScreen(startEmpty: true),
        );
      case AppRoutes.packEditorEdit:
        return MaterialPageRoute(builder: (_) => const EditPackLoaderScreen());
      case AppRoutes.room:
        final args = settings.arguments;
        if (args is RoomRouteArgs) {
          return MaterialPageRoute(
            builder: (_) => RoomScreen(roomId: args.roomId, role: args.role),
          );
        }
        final roomId = args! as String;
        return MaterialPageRoute(builder: (_) => RoomScreen(roomId: roomId));
      case AppRoutes.roomEditor:
        final roomId = settings.arguments! as String;
        return MaterialPageRoute(
          builder: (_) => RoomEditorScreen(roomId: roomId),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => Text(context.l10n.routeNotFound),
              ),
            ),
          ),
        );
    }
  }
}

class RoomRouteArgs {
  const RoomRouteArgs({required this.roomId, this.role = PlayerRole.player});

  final String roomId;
  final PlayerRole role;
}
