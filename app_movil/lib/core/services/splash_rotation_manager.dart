import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/services/splash_prewarm_coordinator.dart';

/// Configuración completa de la experiencia visual del Splash
class SplashVariantConfig {
  final String token; // ej: "3A"
  final int archetypeIndex; // 1 a 6
  final String variationLetter; // "A", "B" o "C"
  final String archetypeTitle;
  final String capsuleText;
  final IconData capsuleIcon;
  final Color accentColor;

  const SplashVariantConfig({
    required this.token,
    required this.archetypeIndex,
    required this.variationLetter,
    required this.archetypeTitle,
    required this.capsuleText,
    required this.capsuleIcon,
    required this.accentColor,
  });
}

/// 🎰 SplashRotationManager - Mobile Awards Standard
/// 
/// Administrador del algoritmo "Shuffle-Bag" de Doble Nivel persistido en SharedPreferences:
/// 1. Nivel 1: Cada ciclo de 6 aperturas muestra los 6 Arquetipos Base sin repetición.
/// 2. Nivel 2: Cada ciclo de 18 aperturas muestra las 18 variaciones únicas (1A a 6C) con 100% de cobertura.
/// 3. Reglas con Propósito Operativo Real: Prioriza arquetipos según alertas de stock, cotizaciones y ventas.
class SplashRotationManager {
  SplashRotationManager._();

  static final SplashRotationManager instance = SplashRotationManager._();

  static const String _prefKeyDeck = 'unseen_splash_deck_v1';
  static const String _prefKeyArchetypes = 'unseen_archetypes_cycle_v1';
  static const String _prefKeyLastArchetype = 'last_played_archetype_v1';

  static const List<String> all18Tokens = [
    "1A", "1B", "1C",
    "2A", "2B", "2C",
    "3A", "3B", "3C",
    "4A", "4B", "4C",
    "5A", "5B", "5C",
    "6A", "6B", "6C",
  ];

  static const List<String> all6Archetypes = ["1", "2", "3", "4", "5", "6"];

  /// Selecciona de forma persistente y contextual la siguiente experiencia visual
  Future<SplashVariantConfig> selectNextVariant({
    String? forcedToken,
    HomePrewarmSnapshot? snapshot,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Si hay un token forzado (ej. pruebas unitarias o visualizador de catálogo)
    if (forcedToken != null && all18Tokens.contains(forcedToken)) {
      return _buildConfigForToken(forcedToken, snapshot ?? SplashPrewarmCoordinator.instance.latestSnapshot);
    }

    // 1. Obtener y sanear mazo de 18 variaciones
    List<String> deck = prefs.getStringList(_prefKeyDeck) ?? [];
    if (deck.isEmpty || !deck.every((t) => all18Tokens.contains(t))) {
      deck = List<String>.from(all18Tokens)..shuffle(math.Random());
    }

    // 2. Obtener y sanear ciclo de 6 arquetipos
    List<String> archetypesCycle = prefs.getStringList(_prefKeyArchetypes) ?? [];
    if (archetypesCycle.isEmpty || !archetypesCycle.every((a) => all6Archetypes.contains(a))) {
      archetypesCycle = List<String>.from(all6Archetypes)..shuffle(math.Random());
      
      // Evitar que el primer arquetipo del nuevo ciclo sea idéntico al último mostrado
      final lastArchetype = prefs.getString(_prefKeyLastArchetype);
      if (lastArchetype != null && archetypesCycle.first == lastArchetype && archetypesCycle.length > 1) {
        final first = archetypesCycle.removeAt(0);
        archetypesCycle.add(first);
      }
    }

    final prewarm = snapshot ?? SplashPrewarmCoordinator.instance.latestSnapshot;

    // 3. Selección prioritaria por contexto operativo del negocio
    final chosenArchetype = _pickContextualArchetype(archetypesCycle, prewarm);

    // 4. Seleccionar una variación del mazo de 18 que pertenezca al arquetipo elegido
    final availableVariationsForArchetype = deck.where((t) => t.startsWith(chosenArchetype)).toList();

    String chosenToken;
    if (availableVariationsForArchetype.isNotEmpty) {
      chosenToken = availableVariationsForArchetype.first;
    } else {
      // Fallback de seguridad: si las 3 variaciones de este arquetipo ya salieron en este ciclo de 18
      chosenToken = deck.first;
    }

    // 5. Actualizar y persistir estado en SharedPreferences
    deck.remove(chosenToken);
    archetypesCycle.remove(chosenArchetype);

    await prefs.setStringList(_prefKeyDeck, deck);
    await prefs.setStringList(_prefKeyArchetypes, archetypesCycle);
    await prefs.setString(_prefKeyLastArchetype, chosenArchetype);

    return _buildConfigForToken(chosenToken, prewarm);
  }

  String _pickContextualArchetype(List<String> availableArchetypes, HomePrewarmSnapshot snapshot) {
    // Regla 1: Alertas de Stock críticas -> Arquetipo 3 (Matriz Logística) o 1 (Radar)
    if (snapshot.activeAlertCount > 0) {
      if (availableArchetypes.contains("3")) return "3";
      if (availableArchetypes.contains("1")) return "1";
    }

    // Regla 2: Cotizaciones pendientes en Mesa de Trabajo -> Arquetipo 6 (Ecosistema) o 4 (Escáner IA)
    if (snapshot.pendingQuotesCount > 0) {
      if (availableArchetypes.contains("6")) return "6";
      if (availableArchetypes.contains("4")) return "4";
    }

    // Regla 3: Horario pico de ventas comercial (10h-14h o 17h-21h) con ventas hoy -> Arquetipo 5 (Finanzas)
    final hour = DateTime.now().hour;
    final isPeakSalesHour = (hour >= 10 && hour <= 14) || (hour >= 17 && hour <= 21);
    if (isPeakSalesHour && snapshot.todaySalesTotal > 0) {
      if (availableArchetypes.contains("5")) return "5";
    }

    // Regla 4: Modo Invitado / Exploración -> Arquetipo 2 (Bóveda Local-First)
    if (!snapshot.hasActiveContext) {
      if (availableArchetypes.contains("2")) return "2";
    }

    // Fallback: Siguiente disponible en el ciclo de 6
    return availableArchetypes.first;
  }

  SplashVariantConfig _buildConfigForToken(String token, HomePrewarmSnapshot snapshot) {
    final archetypeIndex = int.parse(token[0]);
    final variationLetter = token[1];

    String archetypeTitle;
    String capsuleText;
    IconData capsuleIcon;
    Color accentColor;

    switch (archetypeIndex) {
      case 1:
        archetypeTitle = "Radar Comercial";
        accentColor = const Color(0xFF38BDF8); // Cian
        if (snapshot.activeAlertCount > 0) {
          capsuleText = "Verificando inventario • ${snapshot.activeAlertCount} alertas de stock activas";
          capsuleIcon = Icons.warning_amber_rounded;
        } else {
          capsuleText = "Sintonizando radar comercial y demanda local";
          capsuleIcon = Icons.radar_rounded;
        }
        break;

      case 2:
        archetypeTitle = "Bóveda Local-First";
        accentColor = const Color(0xFF10B981); // Esmeralda
        capsuleText = "Bóveda local segura • Base de datos SQLite sincronizada";
        capsuleIcon = Icons.shield_outlined;
        break;

      case 3:
        archetypeTitle = "Matriz Logística";
        accentColor = const Color(0xFFF59E0B); // Ámbar
        if (snapshot.activeAlertCount > 0) {
          capsuleText = "Control de inventario • ${snapshot.activeAlertCount} alertas de stock críticas";
          capsuleIcon = Icons.inventory_2_outlined;
        } else {
          capsuleText = "Matriz de stock lista • Inventario equilibrado";
          capsuleIcon = Icons.check_circle_outline_rounded;
        }
        break;

      case 4:
        archetypeTitle = "Escáner Visión IA";
        accentColor = const Color(0xFF8B5CF6); // Púrpura
        if (snapshot.pendingQuotesCount > 0) {
          capsuleText = "Visión IA lista • ${snapshot.pendingQuotesCount} cotizaciones en espera";
          capsuleIcon = Icons.document_scanner_outlined;
        } else {
          capsuleText = "Calibrando escáner de visión computacional...";
          capsuleIcon = Icons.auto_awesome_rounded;
        }
        break;

      case 5:
        archetypeTitle = "Impulso Financiero";
        accentColor = const Color(0xFF10B981); // Verde
        if (snapshot.todaySalesTotal > 0) {
          capsuleText = "Caja activa • Impulsando tus ventas del día";
          capsuleIcon = Icons.trending_up_rounded;
        } else {
          capsuleText = "Panel financiero preparado • Listo para registrar ventas";
          capsuleIcon = Icons.point_of_sale_rounded;
        }
        break;

      case 6:
      default:
        archetypeTitle = "Ecosistema Comercial";
        accentColor = const Color(0xFF0284C7); // Zafiro
        if (snapshot.pendingQuotesCount > 0) {
          capsuleText = "Mesa de trabajo lista • ${snapshot.pendingQuotesCount} cotizaciones por revisar";
          capsuleIcon = Icons.receipt_long_outlined;
        } else {
          capsuleText = "MochilaLista está lista para impulsar tu negocio";
          capsuleIcon = Icons.storefront_outlined;
        }
        break;
    }

    return SplashVariantConfig(
      token: token,
      archetypeIndex: archetypeIndex,
      variationLetter: variationLetter,
      archetypeTitle: archetypeTitle,
      capsuleText: capsuleText,
      capsuleIcon: capsuleIcon,
      accentColor: accentColor,
    );
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyDeck);
    await prefs.remove(_prefKeyArchetypes);
    await prefs.remove(_prefKeyLastArchetype);
  }
}
