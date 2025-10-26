// ignore_for_file: use_build_context_synchronously, duplicate_ignore

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/note_model.dart';
import '../models/reminder_model.dart';
import '../services/note_service.dart';
import 'note_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<int> noteColors = [
    0xFFFFF59D,
    0xFFB39DDB,
    0xFF80DEEA,
    0xFFA5D6A7,
    0xFFFFAB91,
  ];

  late final AudioPlayer _audioPlayer;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _startReminderCheck();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      debugPrint("Ses çalma hatası: $e");
    }
  }

  // 🔔 Hatırlatma zamanını kontrol eder (her 30 saniyede bir)
  void _startReminderCheck() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final reminders = NoteService.remindersBox.values
          .toList()
          .cast<ReminderModel>();
      final now = DateTime.now();

      for (final reminder in reminders) {
        if (reminder.time.isBefore(now) &&
            now.difference(reminder.time).inMinutes.abs() < 1) {
          debugPrint("⏰ Hatırlatma zamanı geldi: ${reminder.title}");

          await _playAlertSound(); // ✅ yeni ses sistemi

          if (context.mounted) {
            showDialog(
              // ignore: use_build_context_synchronously
              context: context,
              builder: (_) => AlertDialog(
                title: const Text(
                  "🔔 Hatırlatma Zamanı!",
                  style: TextStyle(fontSize: 16),
                ),
                content: Text(reminder.title),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await _audioPlayer.stop();
                      Navigator.pop(context);
                    },
                    child: const Text("Tamam"),
                  ),
                ],
              ),
            );
          }

          // 🔁 Tekrarlama varsa sonraki zamanı planla
          if (reminder.repeatType != null) {
            DateTime nextTime = reminder.time;
            if (reminder.repeatType == 'Haftada bir') {
              nextTime = reminder.time.add(const Duration(days: 7));
            } else if (reminder.repeatType == '2 haftada bir') {
              nextTime = reminder.time.add(const Duration(days: 14));
            } else if (reminder.repeatType == 'Ayda bir') {
              nextTime = DateTime(
                reminder.time.year,
                reminder.time.month + 1,
                reminder.time.day,
                reminder.time.hour,
                reminder.time.minute,
              );
            }
            reminder.time = nextTime;
            await reminder.save();
          }

          setState(() {});
        }
      }
    });
  }

  // 📒 Yeni not oluştur
  Future<void> _addNote() async {
    final random = Random();
    final color = noteColors[random.nextInt(noteColors.length)];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(defaultColor: color)),
    );
    if (result is NoteModel) {
      await NoteService.notesBox.add(result);
      setState(() {});
    }
  }

  // ✏️ Not düzenle
  Future<void> _editNote(NoteModel note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note)),
    );
    if (result is NoteModel) {
      note
        ..title = result.title
        ..content = result.content
        ..colorValue = result.colorValue;
      await note.save();
      setState(() {});
    }
  }

  // ➕ Hatırlatma ekle veya düzenle
  Future<void> _showReminderDialog({ReminderModel? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    String? repeatType = existing?.repeatType ?? 'Tek seferlik';
    TimeOfDay initialTime = TimeOfDay.fromDateTime(
      existing?.time ?? DateTime.now(),
    );

    // ⏰ sadece dijital mod
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input, // ✅ dijital görünüme sabit
    );

    if (selectedTime == null) return;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            existing == null ? "Hatırlatma Ekle" : "Hatırlatma Düzenle",
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: "Hatırlatma başlığı",
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: repeatType,
                decoration: const InputDecoration(labelText: "Tekrarlama"),
                items: const [
                  DropdownMenuItem(
                    value: 'Tek seferlik',
                    child: Text('Tek seferlik'),
                  ),
                  DropdownMenuItem(
                    value: 'Haftada bir',
                    child: Text('Haftada bir'),
                  ),
                  DropdownMenuItem(
                    value: '2 haftada bir',
                    child: Text('2 haftada bir'),
                  ),
                  DropdownMenuItem(value: 'Ayda bir', child: Text('Ayda bir')),
                ],
                onChanged: (val) => setStateDialog(() => repeatType = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                final now = DateTime.now();
                final date = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                if (existing == null) {
                  await NoteService.remindersBox.add(
                    ReminderModel(
                      title: titleController.text,
                      time: date,
                      repeatType: repeatType == 'Tek seferlik'
                          ? null
                          : repeatType,
                    ),
                  );
                } else {
                  existing
                    ..title = titleController.text
                    ..time = date
                    ..repeatType = repeatType == 'Tek seferlik'
                        ? null
                        : repeatType;
                  await existing.save();
                }

                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  // 🗑️ Hatırlatma sil
  Future<void> _deleteReminder(ReminderModel reminder) async {
    await reminder.delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notes = NoteService.notesBox.values.toList().cast<NoteModel>();
    final reminders =
        NoteService.remindersBox.values.toList().cast<ReminderModel>()
          ..sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      appBar: AppBar(title: const Text("Notlar"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "💭 Her sabah yeni bir başlangıçtır.",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 🟨 Notlar
            GridView.builder(
              itemCount: notes.length > 6 ? 6 : notes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final note = notes[index];
                return GestureDetector(
                  onTap: () => _editNote(note),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Color(note.colorValue),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(2, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.isEmpty ? "Başlıksız" : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            note.content.isEmpty
                                ? "Not içeriği..."
                                : note.content,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ❤️ Hatırlatmalar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "⏰ Hatırlatmalar",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => _showReminderDialog(),
                  icon: const Icon(Icons.add_alarm, color: Colors.white),
                ),
              ],
            ),

            if (reminders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "Henüz hatırlatma eklenmedi ⏰",
                  style: TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  final time =
                      "${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}";
                  final date =
                      "${reminder.time.day.toString().padLeft(2, '0')}.${reminder.time.month.toString().padLeft(2, '0')}.${reminder.time.year}";

                  return GestureDetector(
                    onTap: () => _showReminderDialog(existing: reminder),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListTile(
                        title: Text(
                          reminder.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          "📅 $date   ⏰ $time   🔁 ${reminder.repeatType ?? 'Tek seferlik'}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: "Sil",
                          onPressed: () => _deleteReminder(reminder),
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
