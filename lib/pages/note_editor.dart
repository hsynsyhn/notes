import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../models/note_model.dart';

class NoteEditorPage extends StatefulWidget {
  final NoteModel? note;
  final int? defaultColor;

  const NoteEditorPage({super.key, this.note, this.defaultColor});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController titleController;
  late TextEditingController contentController;
  late int colorValue;
  double fontSize = 14;
  Timer? _autoSaveTimer; // ⏳ Otomatik kaydetme zamanlayıcısı
  TimeOfDay? reminderTime; // ⏰ Hatırlatma saati

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?.title ?? '');
    contentController = TextEditingController(text: widget.note?.content ?? '');
    colorValue = widget.note?.colorValue ?? (widget.defaultColor ?? 0xFFFFF59D);
  }

  // 💾 Otomatik kaydetme
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () async {
      final note = widget.note;
      if (note != null) {
        note
          ..title = titleController.text
          ..content = contentController.text
          ..colorValue = colorValue;
        await note.save();
      }
    });
  }

  // ⏰ Hatırlatıcı oluştur
  Future<void> _setReminder() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      setState(() {
        reminderTime = selectedTime;
      });

      final now = DateTime.now();
      final reminderDate = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: Random().nextInt(10000),
          channelKey: 'note_reminder',
          title: "⏰ Hatırlatma Zamanı!",
          body: titleController.text.isEmpty
              ? "Bir notun seni bekliyor."
              : titleController.text,
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(date: reminderDate),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Hatırlatıcı ayarlandı: ${selectedTime.format(context)}",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  bool bulletMode = false; // üstte zaten var, bu açık kalacak

  void _addBullet() {
    final current = contentController.text;
    final selection = contentController.selection;

    // 🛡️ Güvenlik: imleç yoksa sona ekle
    final insertIndex = (selection.start < 0)
        ? current.length
        : selection.start;

    // 🔹 Eğer madde modu kapalıysa aç, ve ilk maddeyi ekle
    if (!bulletMode) {
      bulletMode = true;
      final newText = current.replaceRange(insertIndex, insertIndex, "• ");
      contentController.text = newText;
      contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: insertIndex + 2),
      );
    } else {
      // 🔹 Eğer zaten madde modundaysa, yeni satır eklendiğinde otomatik “• ”
      final newText = current.replaceRange(insertIndex, insertIndex, "\n• ");
      contentController.text = newText;
      contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: insertIndex + 3),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(colorValue),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Text(
          widget.note == null ? "Yeni Not" : "Notu Düzenle",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm, size: 26),
            tooltip: "Hatırlatıcı ekle",
            onPressed: _setReminder,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, size: 26),
            tooltip: "Kaydet",
            onPressed: () {
              Navigator.pop(
                context,
                NoteModel(
                  title: titleController.text,
                  content: contentController.text,
                  colorValue: colorValue,
                  createdAt: DateTime.now(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Başlık alanı
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "Başlık",
                hintStyle: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _scheduleAutoSave(),
            ),

            const SizedBox(height: 8),

            // 🛠️ Toolbar
            Row(
              children: [
                IconButton(
                  onPressed: _addBullet,
                  tooltip: "Madde ekle",
                  icon: const Icon(
                    Icons.format_list_bulleted,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Yazı boyutu:",
                  style: TextStyle(color: Colors.black87),
                ),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: 14,
                    max: 26,
                    divisions: 6,
                    activeColor: Colors.black87,
                    label: "${fontSize.toInt()}",
                    onChanged: (val) {
                      setState(() => fontSize = val);
                      _scheduleAutoSave();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 🔹 İçerik alanı
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Notunuzu yazın...",
                  hintStyle: TextStyle(color: Colors.black45),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: fontSize,
                  height: 1.5,
                ),
                onChanged: (_) => _scheduleAutoSave(),
              ),
            ),

            // 🔔 Alt kısımda hatırlatma bilgisi
            if (reminderTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "🔔 Hatırlatma: ${reminderTime!.format(context)}",
                  style: const TextStyle(
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
