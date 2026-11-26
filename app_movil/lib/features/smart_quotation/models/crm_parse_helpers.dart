// Función global de seguridad para parsear JSON numéricos desde SQLite
double parseCrmDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
