import '../../data/game_repository.dart';
import '../../game_models.dart';

class GameReadUseCases {
  GameReadUseCases(this._repository);

  final GameRepository _repository;

  Stream<List<RoomModel>> watchRooms() => _repository.watchRooms();

  Stream<List<RoomModel>> watchRoomsLimited({required int limit}) =>
      _repository.watchRoomsLimited(limit: limit);

  Future<RoomsPageModel> fetchRoomsPage({
    required int limit,
    int? startAfterCreatedAtMs,
  }) => _repository.fetchRoomsPage(
    limit: limit,
    startAfterCreatedAtMs: startAfterCreatedAtMs,
  );

  Stream<RoomModel?> watchRoom(String roomId) => _repository.watchRoom(roomId);

  Stream<List<PlayerModel>> watchPlayers(String roomId) =>
      _repository.watchPlayers(roomId);

  Stream<List<QuestionModel>> watchQuestions(String roomId) =>
      _repository.watchQuestions(roomId);

  Stream<List<GameEventModel>> watchEvents(String roomId) =>
      _repository.watchEvents(roomId);
}
