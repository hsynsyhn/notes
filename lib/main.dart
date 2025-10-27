import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 🇹🇷 TAKVİM DESTEK
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'pages/home_page.dart';
import 'services/note_service.dart';

// 🔊 Global player – her yerden aynı ses kanalı kullanılacak
final AudioPlayer globalPlayer = AudioPlayer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Masaüstü pencere ayarları
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(400, 980),
    center: false,
    title: 'Notlar',
    backgroundColor: Colors.transparent,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    final display = await screenRetriever.getPrimaryDisplay();
    final screenSize = display.size;

    await windowManager.setPosition(
      Offset(screenSize.width - 405, 0), // sağ üst köşe hizalama
    );

    await windowManager.show();
    await windowManager.focus();
  });

  // ✅ Hive başlat
  await NoteService.init();

  // ✅ Bildirim kanalı ayarları
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

  // 🔊 Bildirim tıklanınca ses çal (tekil player ile)
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: (action) async {
      try {
        await globalPlayer.stop(); // önce mevcut sesi durdur
        await globalPlayer.play(AssetSource('sounds/alert.wav'));
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

      // 🇹🇷 Türkçe dil desteği (takvim/saat için)
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('tr', 'TR')],

      // 🎨 Sabit koyu tema
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
        ),
      ),

      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark, // ✅ her zaman koyu

      home: const AppLoader(),
    );
  }
}

// 🌀 Açılışta animasyonlu geçiş
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
