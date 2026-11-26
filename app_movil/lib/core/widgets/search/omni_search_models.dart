import 'package:flutter/material.dart';

enum OmniSortOption {
  relevance('Relevancia', Icons.auto_awesome_rounded),
  recent('Más Recientes', Icons.schedule_rounded),
  az('A - Z', Icons.sort_by_alpha_rounded),
  priceDesc('Mayor Precio', Icons.arrow_downward_rounded),
  priceAsc('Menor Precio', Icons.arrow_upward_rounded);

  final String label;
  final IconData icon;
  const OmniSortOption(this.label, this.icon);
}

// =========================================================================
// CLASES POLIMÓRFICAS PARA RENDERIZADO VIRTUALIZADO PLANO (60 FPS)
// =========================================================================

abstract class OmniListItem {
  const OmniListItem();
}

class OmniHeaderItem extends OmniListItem {
  final String title;
  final int count;
  final IconData? icon;
  const OmniHeaderItem(this.title, this.count, {this.icon});
}

class OmniProductItem extends OmniListItem {
  final Map<String, dynamic> data;
  const OmniProductItem(this.data);
}

class OmniClientItem extends OmniListItem {
  final Map<String, dynamic> data;
  const OmniClientItem(this.data);
}

class OmniQuoteItem extends OmniListItem {
  final Map<String, dynamic> data;
  const OmniQuoteItem(this.data);
}

class OmniSaleItem extends OmniListItem {
  final Map<String, dynamic> data;
  const OmniSaleItem(this.data);
}

class OmniSpacerItem extends OmniListItem {
  const OmniSpacerItem();
}

class OmniSearchCounts {
  final int products;
  final int clients;
  final int quotes;
  final int sales;

  const OmniSearchCounts({
    this.products = 0,
    this.clients = 0,
    this.quotes = 0,
    this.sales = 0,
  });

  int get total => products + clients + quotes + sales;
}

class OmniSearchResults {
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> quotes;
  final List<Map<String, dynamic>> sales;

  const OmniSearchResults({
    this.products = const [],
    this.clients = const [],
    this.quotes = const [],
    this.sales = const [],
  });

  int get totalMatches =>
      products.length + clients.length + quotes.length + sales.length;
}
