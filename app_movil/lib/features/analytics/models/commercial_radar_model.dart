import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum RadarActionType {
  workbench,
  restock,
  promotions,
  quickSale,
}

class RadarAction {
  final String label;
  final IconData icon;
  final Color color;
  final RadarActionType type;

  const RadarAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class CommercialNewsItem {
  final String id;
  final String title;
  final String summary;
  final String impactAnalysis;
  final String actionableAdvice;
  final String category; // 'Clima y Rutas', 'Mi Región', 'Leyes y SUNAT', 'Proveedores y Abastecimiento', 'Campañas'
  final String sourceName;
  final String sourceUrl;
  final String? imageUrl;
  final DateTime publishedAt;
  final String region;
  final bool isLive;

  CommercialNewsItem({
    required this.id,
    required this.title,
    required this.summary,
    this.impactAnalysis = '',
    required this.actionableAdvice,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    this.imageUrl,
    required this.publishedAt,
    required this.region,
    this.isLive = false,
  });

  /// Sanitiza cualquier texto removiendo emojis Unicode
  static String sanitizeNoEmoji(String text) {
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E0}-\u{1F1FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}]',
      unicode: true,
    );
    String t = text
        .replaceAll(emojiRegex, '')
        .replaceAll(RegExp(r'[🔴🔵👇🚨⚠️💥📢🔥📌⚡️🌧🌩⛈🌦⛅☀️🌊🏷️📦💰📋🔗🔖🟢📘]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.startsWith(':') || t.startsWith('-')) {
      t = t.substring(1).trim();
    }
    return t;
  }

  /// Construye una URL de búsqueda contextual verificada en Google News Perú o portal de prensa oficial
  static String buildVerifiedSearchUrl(String topic, {String? mediaDomain}) {
    final cleanTopic = sanitizeNoEmoji(topic)
        .replaceAll(RegExp(r'["'':;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final query = mediaDomain != null && mediaDomain.isNotEmpty 
        ? 'site:$mediaDomain $cleanTopic' 
        : cleanTopic;
    return 'https://news.google.com/search?q=${Uri.encodeComponent(query)}&hl=es-419&gl=PE&ceid=PE:es-419';
  }

  /// Titular sanitizado sin emojis invasivos ni caracteres basura de RSS
  String get cleanTitle {
    final t = sanitizeNoEmoji(title);
    return t.isEmpty ? title : t;
  }

  /// Resumen limpio sin emojis
  String get cleanSummary {
    final s = sanitizeNoEmoji(summary);
    return s.isEmpty ? summary : s;
  }

  /// Impacto limpio sin emojis
  String get cleanImpact {
    final imp = sanitizeNoEmoji(impactAnalysis);
    return imp.isEmpty ? impactAnalysis : imp;
  }

  /// Recomendación limpia sin emojis
  String get cleanAdvice {
    final adv = sanitizeNoEmoji(actionableAdvice);
    return adv.isEmpty ? actionableAdvice : adv;
  }

  /// Resolutor inteligente de la acción operativa según las Medidas y Recomendaciones Clave
  RadarAction get resolvedAction {
    final adv = cleanAdvice.toLowerCase();
    final cat = category.toLowerCase();

    // 1. Promociones, Combos, Ofertas y Campañas
    if (adv.contains('promocion') ||
        adv.contains('promoción') ||
        adv.contains('oferta') ||
        adv.contains('campaña') ||
        adv.contains('campana') ||
        adv.contains('pack') ||
        adv.contains('combo') ||
        adv.contains('descuento') ||
        adv.contains('calendario') ||
        adv.contains('festiv') ||
        adv.contains('feriado') ||
        adv.contains('madre') ||
        adv.contains('navid') ||
        adv.contains('escolar')) {
      return const RadarAction(
        label: "Ir a Promociones y Ofertas",
        icon: Icons.local_offer_outlined,
        color: Color(0xFFE11D48),
        type: RadarActionType.promotions,
      );
    }

    // 2. Cotizaciones, Comparador y Mesa de Trabajo
    if (adv.contains('comparador') ||
        adv.contains('cotiza') ||
        adv.contains('cotización') ||
        adv.contains('cotizacion') ||
        adv.contains('mesa de trabajo') ||
        adv.contains('presupuesto') ||
        adv.contains('evaluar alternativas') ||
        adv.contains('lista') ||
        adv.contains('preparar pedido')) {
      return const RadarAction(
        label: "Ir a Mesa de Trabajo",
        icon: Icons.checklist_rounded,
        color: Color(0xFF4F46E5),
        type: RadarActionType.workbench,
      );
    }

    // 3. Abastecimiento y Stock Crítico
    if (adv.contains('stock') ||
        adv.contains('inventario') ||
        adv.contains('reposición') ||
        adv.contains('reposicion') ||
        adv.contains('seguridad') ||
        adv.contains('demora') ||
        adv.contains('quiebre') ||
        adv.contains('primera necesidad') ||
        adv.contains('almacén') ||
        adv.contains('almacen') ||
        adv.contains('holgura') ||
        adv.contains('abastecer')) {
      return const RadarAction(
        label: "Revisar Stock Crítico",
        icon: Icons.inventory_2_outlined,
        color: Colors.blueAccent,
        type: RadarActionType.restock,
      );
    }

    // 4. Ventas, POS, Billeteras Digitales y Cobros
    if (adv.contains('código qr') ||
        adv.contains('codigo qr') ||
        adv.contains('qr') ||
        adv.contains('billetera') ||
        adv.contains('yape') ||
        adv.contains('plin') ||
        adv.contains('pos') ||
        adv.contains('cobro') ||
        adv.contains('mostrador') ||
        adv.contains('ticket') ||
        adv.contains('caja rápida') ||
        adv.contains('caja rapida')) {
      return const RadarAction(
        label: "Ir al Punto de Venta",
        icon: Icons.point_of_sale_rounded,
        color: Color(0xFF059669),
        type: RadarActionType.quickSale,
      );
    }

    // 5. Fallback determinístico según la categoría temática
    if (cat.contains('clima') || cat.contains('ruta')) {
      return const RadarAction(
        label: "Revisar Stock Crítico",
        icon: Icons.inventory_2_outlined,
        color: Colors.blueAccent,
        type: RadarActionType.restock,
      );
    } else if (cat.contains('campaña') || cat.contains('campana') || cat.contains('fecha')) {
      return const RadarAction(
        label: "Ir a Promociones y Ofertas",
        icon: Icons.local_offer_outlined,
        color: Color(0xFFE11D48),
        type: RadarActionType.promotions,
      );
    } else if (cat.contains('proveedor') || cat.contains('abastecimiento')) {
      return const RadarAction(
        label: "Ir a Mesa de Trabajo",
        icon: Icons.checklist_rounded,
        color: Color(0xFF4F46E5),
        type: RadarActionType.workbench,
      );
    }

    return const RadarAction(
      label: "Ir a Mesa de Trabajo",
      icon: Icons.checklist_rounded,
      color: Color(0xFF4F46E5),
      type: RadarActionType.workbench,
    );
  }

  /// Antigüedad relativa compacta para evitar saltos o desbordamientos en pantallas móviles
  String get timeAgoFormatted {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.isNegative || diff.inMinutes < 5) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else if (diff.inDays < 2) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays}d';
    } else {
      return DateFormat('dd MMM', 'es').format(publishedAt);
    }
  }

  /// Fecha formateada completa con antigüedad compacta (ej: "26 oct. 2026 • Hace 3h")
  String get formattedDateWithTimeAgo {
    try {
      final dateStr = DateFormat('dd MMM yyyy', 'es').format(publishedAt);
      return '$dateStr • $timeAgoFormatted';
    } catch (_) {
      return timeAgoFormatted;
    }
  }

  /// Fecha relativa compacta para tarjetas móviles sin desbordes (ej: "26 oct • Hace 3h")
  String get compactTimeAgo {
    try {
      final dateStr = DateFormat('dd MMM', 'es').format(publishedAt).replaceAll('.', '');
      return '$dateStr • $timeAgoFormatted';
    } catch (_) {
      return timeAgoFormatted;
    }
  }

  CommercialNewsItem copyWith({
    String? id,
    String? title,
    String? summary,
    String? impactAnalysis,
    String? actionableAdvice,
    String? category,
    String? sourceName,
    String? sourceUrl,
    String? imageUrl,
    DateTime? publishedAt,
    String? region,
    bool? isLive,
  }) {
    return CommercialNewsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      impactAnalysis: impactAnalysis ?? this.impactAnalysis,
      actionableAdvice: actionableAdvice ?? this.actionableAdvice,
      category: category ?? this.category,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      region: region ?? this.region,
      isLive: isLive ?? this.isLive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'impactAnalysis': impactAnalysis,
    'actionableAdvice': actionableAdvice,
    'category': category,
    'sourceName': sourceName,
    'sourceUrl': sourceUrl,
    'imageUrl': imageUrl,
    'publishedAt': publishedAt.toIso8601String(),
    'region': region,
    'isLive': isLive,
  };

  factory CommercialNewsItem.fromJson(Map<String, dynamic> json) {
    return CommercialNewsItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      impactAnalysis: json['impactAnalysis'] ?? '',
      actionableAdvice: json['actionableAdvice'] ?? '',
      category: json['category'] ?? 'Mi Región',
      sourceName: json['sourceName'] ?? 'Fuente Oficial',
      sourceUrl: json['sourceUrl'] ?? '',
      imageUrl: json['imageUrl'],
      publishedAt: json['publishedAt'] != null 
          ? DateTime.tryParse(json['publishedAt']) ?? DateTime.now() 
          : DateTime.now(),
      region: json['region'] ?? 'Perú',
      isLive: json['isLive'] == true,
    );
  }
}
