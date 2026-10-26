import 'package:intl/intl.dart';

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
  });

  /// Titular sanitizado sin emojis invasivos ni caracteres basura de RSS
  String get cleanTitle {
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E0}-\u{1F1FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}]',
      unicode: true,
    );
    String t = title
        .replaceAll(emojiRegex, '')
        .replaceAll(RegExp(r'[🔴🔵👇🚨⚠️💥📢🔥📌⚡️🌧🌩⛈🌦⛅☀️🌊]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.startsWith(':') || t.startsWith('-')) {
      t = t.substring(1).trim();
    }
    return t.isEmpty ? title : t;
  }

  /// Antigüedad relativa en lenguaje natural en español
  String get timeAgoFormatted {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.isNegative || diff.inMinutes < 5) {
      return 'Hace unos instantes';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    } else if (diff.inDays < 2) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return DateFormat('dd MMM', 'es').format(publishedAt);
    }
  }

  /// Fecha formateada completa con antigüedad (ej: "24 oct. 2026 • Hace 3 horas")
  String get formattedDateWithTimeAgo {
    try {
      final dateStr = DateFormat('dd MMM yyyy', 'es').format(publishedAt);
      return '$dateStr • $timeAgoFormatted';
    } catch (_) {
      return timeAgoFormatted;
    }
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
    );
  }
}
