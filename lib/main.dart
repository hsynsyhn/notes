import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart'; // ✅ eklendi
import 'pages/home_page.dart';
import 'services/note_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Pencere ayarları (masaüstü)
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 980),
    center: false,
    title: 'Yapışkan Notlar',
    backgroundColor: Colors.transparent,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    final display = await screenRetriever
        .getPrimaryDisplay(); // ✅ doğru kullanım
    final screenSize = display.size;

    await windowManager.setPosition(
      Offset(screenSize.width - 405, 0), // ✅ sağ üst köşe hizalama
    );

    await windowManager.show();
    await windowManager.focus();
  });

  // ✅ Hive veritabanını başlat
  await NoteService.init();

  // ✅ Bildirim sistemi başlat
  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'note_reminder',
      channelName: 'Not Hatırlatıcıları',
      channelDescription: 'Zamanlanmış not hatırlatmaları',
      defaultColor: Colors.amber,
      ledColor: Colors.white,
      importance: NotificationImportance.High,
      playSound: true,
    ),
  ]);

  // 🔔 Bildirim izni kontrolü
  if (!await AwesomeNotifications().isNotificationAllowed()) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // 🔊 Bildirim tıklanınca ses çal
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: (action) async {
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/alert.wav'));
      } catch (e) {
        debugPrint('⚠️ Ses çalma hatası: $e');
      }
    },
  );

  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yapışkan Notlar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AppLoader(),
    );
  }
}

// 🌀 Uygulama açılışında kısa geçiş (animasyonlu)
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _ready
          ? const HomePage()
          : const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
    );
  }
}
