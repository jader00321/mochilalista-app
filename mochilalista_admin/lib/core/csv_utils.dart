/// Utilidad compartida para exportación CSV compatible con Microsoft Excel Windows y RFC-4180.
class CsvCellEscaper {
  CsvCellEscaper._();

  /// Prefijo BOM UTF-8 requerido para abrir tildes/ñ correctamente en Excel Windows.
  static const String utf8Bom = '\uFEFF';

  /// Escapa una celda bajo RFC-4180 normalizando saltos de línea (`\r\n`, `\r`, `\n`)
  /// a un espacio simple y duplicando comillas dobles internas (`"` -> `""`).
  static String escapeCell(dynamic value) {
    final clean = (value ?? '')
        .toString()
        .replaceAll('\r\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('"', '""');
    return '"$clean"';
  }

  /// Serializa una fila completa de celdas escapadas separadas por coma.
  static String encodeRow(Iterable<dynamic> cells) {
    return cells.map(escapeCell).join(',');
  }
}
