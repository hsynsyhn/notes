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
        // 🔁 Eğer geçmişte kalmış tekrarlı hatırlatma varsa ileriye al
        if (reminder.time.isBefore(now) && reminder.repeatType != null) {
          while (reminder.time.isBefore(now)) {
            if (reminder.repeatType == 'Haftada bir') {
              reminder.time = reminder.time.add(const Duration(days: 7));
            } else if (reminder.repeatType == '2 haftada bir') {
              reminder.time = reminder.time.add(const Duration(days: 14));
            } else if (reminder.repeatType == 'Ayda bir') {
              reminder.time = DateTime(
                reminder.time.year,
                reminder.time.month + 1,
                reminder.time.day,
                reminder.time.hour,
                reminder.time.minute,
              );
            }
          }
          await reminder.save();
        }

        // 🔔 Hatırlatma zamanı geldi mi kontrol et
        final difference = reminder.time.difference(now).inSeconds.abs();

        if (difference < 30) {
          debugPrint("⏰ Hatırlatma zamanı geldi: ${reminder.title}");

          await _playAlertSound();

          if (!context.mounted) return;

          // ✅ Diyaloğu bekle (kullanıcı kapatana kadar)
          await showDialog(
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

          // 🔁 Eğer tekrar edecekse sonraki zamanı planla
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

          // ✅ Popup kapandıktan sonra ekranı yenile
          if (mounted) setState(() {});
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

  Future<void> _showReminderDialog({ReminderModel? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    String? repeatType = existing?.repeatType ?? 'Tek seferlik';
    DateTime selectedDateTime = existing?.time ?? DateTime.now();

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
              // 📝 Başlık alanı
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Başlık",
                  hintText: "Hatırlatma başlığı girin",
                ),
              ),
              const SizedBox(height: 16),

              // 📅 Tarih seçici (🇹🇷 Türkçe takvim)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "📅 Tarih: ${selectedDateTime.day.toString().padLeft(2, '0')}.${selectedDateTime.month.toString().padLeft(2, '0')}.${selectedDateTime.year}",
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('tr', 'TR'), // 🇹🇷 Türkçe takvim
                        helpText: "Tarih Seç", // üst başlık
                        cancelText: "İptal",
                        confirmText: "Tamam",
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          selectedDateTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            selectedDateTime.hour,
                            selectedDateTime.minute,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),

              // ⏰ Saat seçici (yalnızca dijital mod)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "⏰ Saat: ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}",
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        initialEntryMode:
                            TimePickerEntryMode.input, // ⏱ sadece dijital
                        helpText: "Saat Seç",
                        cancelText: "İptal",
                        confirmText: "Tamam",
                      );
                      if (pickedTime != null) {
                        setStateDialog(() {
                          selectedDateTime = DateTime(
                            selectedDateTime.year,
                            selectedDateTime.month,
                            selectedDateTime.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🔁 Tekrarlama seçici
              DropdownButtonFormField<String>(
                initialValue: repeatType,
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

                if (existing == null) {
                  await NoteService.remindersBox.add(
                    ReminderModel(
                      title: titleController.text,
                      time: selectedDateTime,
                      repeatType: repeatType == 'Tek seferlik'
                          ? null
                          : repeatType,
                    ),
                  );
                } else {
                  existing
                    ..title = titleController.text
                    ..time = selectedDateTime
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

    // 🌅 30 günlük motivasyon sözleri
    final List<String> motivasyonSozleri = [
      "💭 Her sabah yeni bir başlangıçtır.",
      "🌞 Bugün, hayallerini gerçekleştirmeye bir adım daha yaklaş.",
      "🔥 Küçük adımlar büyük değişimlerin başlangıcıdır.",
      "💪 Zor günler, seni daha güçlü yapar.",
      "🌈 Her karanlığın sonunda bir umut ışığı vardır.",
      "🌿 Başlamak için mükemmel olmayı bekleme, başladığında mükemmel olursun.",
      "✨ Başarı, pes etmeyenlerin ödülüdür.",
      "🌻 Her gün yeniden doğ, tıpkı güneş gibi.",
      "🚀 Hedefin varsa yol her zaman bulunur.",
      "☕ Bir nefes al, sonra kaldığın yerden devam et.",
      "💎 Başarısızlık değil, denememek kaybettirir.",
      "🌟 Hayat bir prova değil, şimdi oyna.",
      "🕊️ Bugün, dünün pişmanlıklarını bırakma günü.",
      "💫 En iyi zaman ‘şimdi’.",
      "🌍 Değişim seninle başlar.",
      "🔥 Cesaret, korkunun yokluğu değil; ona rağmen ilerlemektir.",
      "🌺 Kendine inan, yeter.",
      "⚡ Fırtınalar geçer, gökyüzü hep oradadır.",
      "🌅 Her gün biraz daha iyi ol.",
      "💬 Hedefini sessizce gerçekleştir, başarı konuşsun.",
      "🌸 Bir gülümseme bile günü güzelleştirir.",
      "🪴 Her gün bir tohum ek, bir umut büyüt.",
      "🎯 Hedefini unutma, odağını kaybetme.",
      "💡 Zihnini temizle, enerjini yeniden yükle.",
      "🧭 Ne kadar uzak olursa olsun, ilk adım bugün atılır.",
      "⏳ Sabır, büyük işlerin gizli anahtarıdır.",
      "🌤️ Her gün bir fırsattır, yeter ki fark et.",
      "🧠 Güçlü olmak bazen sadece devam etmektir.",
      "🌕 Bugün için minnettar ol.",
      "❤️ En iyi yatırım kendinedir.",
    ];

    // 📅 Gün sayısına göre motivasyon sözü seç
    final int gunIndex = DateTime.now().day % motivasyonSozleri.length;
    final String bugunkuSoz = motivasyonSozleri[gunIndex];

    return Scaffold(
      appBar: AppBar(title: const Text("Notlar"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🌞 Günlük motivasyon sözü
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                bugunkuSoz,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
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
