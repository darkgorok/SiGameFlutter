import '../game_models.dart';

class PlayerRosterSummary {
  const PlayerRosterSummary({
    required this.total,
    required this.active,
    required this.spectators,
  });

  final int total;
  final int active;
  final int spectators;
}

PlayerRosterSummary summarizeRoster(List<PlayerModel> players) {
  final total = players.length;
  final active = players.where((p) => p.role != PlayerRole.spectator).length;
  return PlayerRosterSummary(
    total: total,
    active: active,
    spectators: total - active,
  );
}

bool allFinalWagersSubmitted({
  required List<String> eligibleUids,
  required List<PlayerModel> players,
}) {
  if (eligibleUids.isEmpty) {
    return false;
  }
  for (final uid in eligibleUids) {
    var submitted = false;
    for (final player in players) {
      if (player.uid == uid) {
        submitted = player.finalWagerSubmitted;
        break;
      }
    }
    if (!submitted) {
      return false;
    }
  }
  return true;
}
