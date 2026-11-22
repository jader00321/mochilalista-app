import 'package:flutter/material.dart';

/// Modelo de un paso individual dentro de un recorrido interactivo (Spotlight / Coach Mark)
class TourStep {
  /// Identificador único del paso dentro de la pantalla
  final String id;

  /// GlobalKey del widget objetivo que se iluminará en pantalla
  final GlobalKey targetKey;

  /// Título conciso del paso
  final String title;

  /// Descripción clara en lenguaje comercial sin jerga técnica
  final String description;

  /// Consejo o recomendación práctica opcional
  final String? tip;

  /// Icono representativo del elemento explicado
  final IconData icon;

  /// Hook ejecutado antes de enfocar el paso (p. ej. desplegar una sección colapsable)
  final Future<void> Function()? onBeforeStep;

  /// Hook ejecutado al salir del paso (p. ej. restaurar o contraer la sección)
  final Future<void> Function()? onAfterStep;

  /// Margen adicional alrededor del widget objetivo recortado
  final EdgeInsets spotlightPadding;

  /// Radio de curvatura del recorte redondeado sobre el elemento
  final double borderRadius;

  const TourStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.description,
    this.tip,
    this.icon = Icons.info_outline_rounded,
    this.onBeforeStep,
    this.onAfterStep,
    this.spotlightPadding = const EdgeInsets.all(6.0),
    this.borderRadius = 14.0,
  });
}

/// Configuración integral de la Guía Turística para una pantalla específica
class ScreenTourConfig {
  /// Identificador único de la pantalla (p. ej. 'home_screen', 'profile_screen')
  final String screenId;

  /// Título humano de la pantalla
  final String screenTitle;

  /// Resumen conciso de 1 a 2 frases del objetivo y valor de la pantalla
  final String welcomeSummary;

  /// Icono característico de la pantalla
  final IconData icon;

  /// Lista ordenada de pasos que conforman el recorrido
  final List<TourStep> steps;

  const ScreenTourConfig({
    required this.screenId,
    required this.screenTitle,
    required this.welcomeSummary,
    this.icon = Icons.explore_rounded,
    required this.steps,
  });
}
