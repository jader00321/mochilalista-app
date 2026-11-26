import 'package:flutter/material.dart';

class SmartRestockItem {
  final int presentationId;
  final int productId;
  final String productName;
  final String brandName;
  final String presentationName;
  final int currentStock;
  double cost;
  final double velocityPerDay;
  final String velocityDisplay;
  final int safetyStock;
  final int rop;
  final int suggestedQty;
  int orderQty;
  bool isSelected;
  final double daysToStockout;
  final String stockoutDate;
  final String status; // 'agotado', 'critico', 'preventivo', 'saludable'
  final Color statusColor;
  final String statusText;
  bool hasZeroCost;
  final bool isSharedPool;
  final String? sharedPresentationsBadge;
  final String? formatBreakAlert;
  final String? suggestedOrderRecommendation;
  final String modoStock;

  SmartRestockItem({
    required this.presentationId,
    required this.productId,
    required this.productName,
    required this.brandName,
    required this.presentationName,
    required this.currentStock,
    required this.cost,
    required this.velocityPerDay,
    required this.velocityDisplay,
    required this.safetyStock,
    required this.rop,
    required this.suggestedQty,
    required this.orderQty,
    this.isSelected = false,
    required this.daysToStockout,
    required this.stockoutDate,
    required this.status,
    required this.statusColor,
    required this.statusText,
    required this.hasZeroCost,
    this.isSharedPool = false,
    this.sharedPresentationsBadge,
    this.formatBreakAlert,
    this.suggestedOrderRecommendation,
    this.modoStock = 'INDEPENDIENTE',
  });
}
