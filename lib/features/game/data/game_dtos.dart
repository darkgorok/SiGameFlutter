import 'package:cloud_firestore/cloud_firestore.dart';

class RoomDto {
  RoomDto({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  factory RoomDto.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return RoomDto(id: snapshot.id, data: snapshot.data() ?? {});
  }
}

class QuestionDto {
  QuestionDto({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  factory QuestionDto.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return QuestionDto(id: snapshot.id, data: snapshot.data());
  }
}

class PlayerDto {
  PlayerDto({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  factory PlayerDto.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return PlayerDto(id: snapshot.id, data: snapshot.data());
  }
}

class GameEventDto {
  GameEventDto({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  factory GameEventDto.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return GameEventDto(id: snapshot.id, data: snapshot.data());
  }
}
