import 'package:hive/hive.dart';

part 'reminder_model.g.dart';

@HiveType(typeId: 1)
class ReminderModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  DateTime time;

  @HiveField(2)
  String? repeatType; // 🔁 Yeni alan eklendi (Tek seferlik, Haftada bir, vs.)

  ReminderModel({required this.title, required this.time, this.repeatType});
}
