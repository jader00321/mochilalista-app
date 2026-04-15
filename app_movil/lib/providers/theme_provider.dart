import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  final String _key = "is_dark_mode";

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
    notifyListeners();
  }

  // =========================================================================
  // 🔥 FASE 2: TEXT THEME MAESTRO (EVITA DESBORDAMIENTOS) 🔥
  // =========================================================================
  // Tamaños de fuente ajustados y reducidos globalmente para evitar 
  // problemas en pantallas medianas o celulares con zoom de texto activado.
  static const TextTheme appTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5), 
    displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5), 
    displaySmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), 
    
    // Títulos de AppBars o Secciones Mayores
    headlineMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
    headlineSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w700), 
    
    // Títulos de Tarjetas (Nombres de Productos, Cotizaciones)
    titleLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2), 
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2), 
    titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500), 
    
    // Textos Normales (Descripciones, subtítulos)
    bodyLarge: TextStyle(fontSize: 14, height: 1.4), 
    bodyMedium: TextStyle(fontSize: 13, height: 1.4), 
    bodySmall: TextStyle(fontSize: 11, height: 1.4), 
    
    // Textos Pequeños (Etiquetas de Stock, Fechas, Badges)
    labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5), 
    labelMedium: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5), 
    labelSmall: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5), 
  );
}