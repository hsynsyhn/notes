import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 0)
class NoteModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String content;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  DateTime createdAt;

  NoteModel({
    required this.title,
    required this.content,
    required this.colorValue,
    required this.createdAt,
  });
}
