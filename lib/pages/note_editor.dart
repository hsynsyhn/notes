import 'dart:async';
import 'package:flutter/material.dart';
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
  double fontSize = 16;
  Timer? _autoSaveTimer;
  bool bulletMode = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?.title ?? '');
    contentController = TextEditingController(text: widget.note?.content ?? '');
    colorValue = widget.note?.colorValue ?? (widget.defaultColor ?? 0xFFFFF59D);

    // 🔹 Enter tuşuna basıldığında otomatik "• " eklenmesi
    contentController.addListener(() {
      final text = contentController.text;
      if (text.endsWith('\n') && bulletMode) {
        final newText = '$text• ';
        contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    });
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

  void _toggleBulletMode() {
    setState(() => bulletMode = !bulletMode);
    if (bulletMode) {
      final current = contentController.text;
      final selection = contentController.selection;
      final insertIndex = (selection.start < 0)
          ? current.length
          : selection.start;

      final newText = current.replaceRange(insertIndex, insertIndex, "• ");
      contentController.text = newText;
      contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: insertIndex + 2),
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
                  onPressed: _toggleBulletMode,
                  tooltip: "Madde modu",
                  icon: Icon(
                    Icons.format_list_bulleted,
                    color: bulletMode ? Colors.amber : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Yazı boyutu:",
                  style: TextStyle(color: Colors.black87),
                ),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: 10,
                    max: 18,
                    divisions: 4,
                    activeColor: const Color.fromARGB(221, 48, 196, 255),
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
          ],
        ),
      ),
    );
  }
}
