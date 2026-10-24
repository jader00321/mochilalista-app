class CommercialNewsItem {
  final String id;
  final String title;
  final String summary;
  final String actionableAdvice;
  final String category; // 'Clima y Rutas', 'Mi Región', 'Leyes y SUNAT', 'Campañas'
  final String sourceName;
  final String sourceUrl;
  final String? imageUrl;
  final DateTime publishedAt;
  final String region;

  CommercialNewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.actionableAdvice,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    this.imageUrl,
    required this.publishedAt,
    required this.region,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
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
