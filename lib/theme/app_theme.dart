import 'package:flutter/material.dart';

class AppTheme {
  // 🌞 Açık tema
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.grey[100],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black87,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    fontFamily: 'Poppins', // ✅ Yerel font
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black87)),
  );

  // 🌙 Koyu tema
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    fontFamily: 'Poppins', // ✅ Yerel font
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white70)),
  );
}
