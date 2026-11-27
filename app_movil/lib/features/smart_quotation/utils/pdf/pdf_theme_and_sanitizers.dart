part of '../pdf_generator.dart';

Map<String, PdfColor> _getPdfThemeColors(PdfTheme theme) {
  switch (theme) {
    case PdfTheme.modern:
      return {
        'primary': const PdfColor.fromInt(0xFF1565C0), // Azul Moderno
        'accent': const PdfColor.fromInt(0xFFE3F2FD),
        'text': const PdfColor.fromInt(0xFF212121),
        'header_bg': const PdfColor.fromInt(0xFF1565C0),
        'header_txt': PdfColors.white,
        'savings': PdfColors.green700,
        'debt': PdfColors.red700,
        'avatar_bg': const PdfColor.fromInt(0xFFE3F2FD),
        'avatar_txt': const PdfColor.fromInt(0xFF1565C0),
      };
    case PdfTheme.emerald:
      return {
        'primary': const PdfColor.fromInt(0xFF00796B), // Esmeralda Comercial
        'accent': const PdfColor.fromInt(0xFFE0F2F1),
        'text': const PdfColor.fromInt(0xFF212121),
        'header_bg': const PdfColor.fromInt(0xFF00796B),
        'header_txt': PdfColors.white,
        'savings': PdfColors.teal800,
        'debt': PdfColors.red800,
        'avatar_bg': const PdfColor.fromInt(0xFFE0F2F1),
        'avatar_txt': const PdfColor.fromInt(0xFF00796B),
      };
    case PdfTheme.dark:
      return {
        'primary': const PdfColor.fromInt(0xFF263238), // Ejecutivo Oscuro
        'accent': const PdfColor.fromInt(0xFFECEFF1),
        'text': const PdfColor.fromInt(0xFF212121),
        'header_bg': const PdfColor.fromInt(0xFF263238),
        'header_txt': PdfColors.white,
        'savings': PdfColors.green800,
        'debt': PdfColors.red800,
        'avatar_bg': const PdfColor.fromInt(0xFFECEFF1),
        'avatar_txt': const PdfColor.fromInt(0xFF263238),
      };
    case PdfTheme.classic:
      return {
        'primary': PdfColors.black,
        'accent': const PdfColor.fromInt(0xFFF5F5F5),
        'text': PdfColors.black,
        'header_bg': const PdfColor.fromInt(0xFFEEEEEE),
        'header_txt': PdfColors.black,
        'savings': PdfColors.black,
        'debt': PdfColors.black,
        'avatar_bg': const PdfColor.fromInt(0xFFEEEEEE),
        'avatar_txt': PdfColors.black,
      };
    case PdfTheme.minimal:
      return {
        'primary': PdfColors.black,
        'accent': const PdfColor.fromInt(0xFFFAFAFA),
        'text': PdfColors.black,
        'header_bg': PdfColors.white,
        'header_txt': PdfColors.black,
        'savings': PdfColors.black,
        'debt': PdfColors.black,
        'avatar_bg': const PdfColor.fromInt(0xFFF0F0F0),
        'avatar_txt': PdfColors.black,
      };
    case PdfTheme.burgundy:
      return {
        'primary': const PdfColor.fromInt(0xFF880E4F), // Borgoña Elegante
        'accent': const PdfColor.fromInt(0xFFFCE4EC),
        'text': const PdfColor.fromInt(0xFF212121),
        'header_bg': const PdfColor.fromInt(0xFF880E4F),
        'header_txt': PdfColors.white,
        'savings': PdfColors.green800,
        'debt': const PdfColor.fromInt(0xFFC2185B),
        'avatar_bg': const PdfColor.fromInt(0xFFFCE4EC),
        'avatar_txt': const PdfColor.fromInt(0xFF880E4F),
      };
    case PdfTheme.indigo:
      return {
        'primary': const PdfColor.fromInt(0xFF1A237E), // Índigo Real
        'accent': const PdfColor.fromInt(0xFFE8EAF6),
        'text': const PdfColor.fromInt(0xFF212121),
        'header_bg': const PdfColor.fromInt(0xFF1A237E),
        'header_txt': PdfColors.white,
        'savings': PdfColors.teal800,
        'debt': PdfColors.red800,
        'avatar_bg': const PdfColor.fromInt(0xFFE8EAF6),
        'avatar_txt': const PdfColor.fromInt(0xFF1A237E),
      };
  }
}

String? _stripOptionalUnsupportedEmojis(String? text) {
  if (text == null) return null;
  final res = PdfGenerator.stripUnsupportedEmojis(text);
  return res.isEmpty ? null : res;
}

double _extractPdfMoraTotal(Map<String, dynamic> saleData) {
  double moraTotal = (saleData['mora_total'] as num?)?.toDouble() ?? 0.0;
  if (moraTotal <= 0 && saleData['cuotas'] != null) {
    final list = saleData['cuotas'] as List;
    moraTotal = list.fold(
      0.0,
      (acc, c) => acc + ((c['mora_monto'] as num?)?.toDouble() ?? 0.0),
    );
  }
  return moraTotal;
}

pw.Widget _buildPdfPaymentRow(
  String label,
  String value, {
  bool isBold = false,
  PdfColor? valueColor,
  required bool isTicket,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTicket ? 7.5 : 9,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTicket ? 7.5 : 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? PdfColors.black,
          ),
        ),
      ],
    ),
  );
}
