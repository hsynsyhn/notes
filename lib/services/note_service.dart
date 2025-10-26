import 'package:hive_flutter/hive_flutter.dart';
import '../models/note_model.dart';
import '../models/reminder_model.dart';

class NoteService {
  static const boxName = 'notesBox';
  static const reminderBoxName = 'remindersBox';

  static Box<NoteModel>? _notesBox;
  static Box<ReminderModel>? _remindersBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteModelAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ReminderModelAdapter());
    }

    _notesBox ??= await _safeOpenBox<NoteModel>(boxName);
    _remindersBox ??= await _safeOpenBox<ReminderModel>(reminderBoxName);
  }

  // 🔒 Güvenli Box açıcı (lock hatasına karşı)
  static Future<Box<T>> _safeOpenBox<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name);
    }
  }

  // ✅ Getter’lar — eğer null ise yeniden açar
  static Box<NoteModel> get notesBox {
    if (_notesBox == null || !_notesBox!.isOpen) {
      throw Exception(
        'NoteService not initialized! Call NoteService.init() first.',
      );
    }
    return _notesBox!;
  }

  static Box<ReminderModel> get remindersBox {
    if (_remindersBox == null || !_remindersBox!.isOpen) {
      throw Exception(
        'Reminder box not initialized! Call NoteService.init() first.',
      );
    }
    return _remindersBox!;
  }
}
