import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

/// Motor centralizado, reactivo e inteligente de nombramiento de cotizaciones.
/// Unifica la generación de títulos humanos, legibles y descriptivos tanto para
/// cotizaciones manuales, escáner IA y packs escolares, eliminando códigos crípticos
/// y asegurando una sincronización 100% reactiva en vinculación, edición y desvinculación.
class QuotationNamingEngine {
  static const List<String> _monthsEs = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'
  ];

  /// Formatea una fecha de forma humana y concisa en español (ej. "26 Oct")
  static String formatShortDate(DateTime dt) {
    final month = (dt.month >= 1 && dt.month <= 12) ? _monthsEs[dt.month - 1] : '';
    return '${dt.day} $month'.trim();
  }

  /// Construye el sujeto principal a partir de cliente, colegio y grado
  static String buildSubject({
    ClientModel? selectedClient,
    String? typedClientName,
    String? schoolName,
    String? gradeLevel,
  }) {
    final client = selectedClient?.fullName.trim() ?? typedClientName?.trim() ?? '';
    final school = (schoolName ?? '').trim();
    final grade = (gradeLevel ?? '').trim();

    String schoolPart = '';
    if (school.isNotEmpty && grade.isNotEmpty) {
      schoolPart = '$school ($grade)';
    } else if (school.isNotEmpty) {
      schoolPart = school;
    } else if (grade.isNotEmpty) {
      schoolPart = '($grade)';
    }

    if (client.isNotEmpty && schoolPart.isNotEmpty) {
      return '$client · $schoolPart';
    } else if (client.isNotEmpty) {
      return client;
    } else if (schoolPart.isNotEmpty) {
      return schoolPart.startsWith('(') ? 'Cotización $schoolPart' : schoolPart;
    }

    return 'Cotización';
  }

  /// Resuelve la etiqueta de origen de forma limpia y moderna
  static String resolveTypeLabel(String quotationType) {
    switch (quotationType.toLowerCase()) {
      case 'ai_scan':
      case 'scanner_ia':
      case 'ia':
        return '[IA]';
      case 'pack':
        return '[Pack Escolar]';
      case 'manual':
      default:
        return '[Manual]';
    }
  }

  /// Genera un título humano, reactivo y profesional.
  /// Formato estándar:
  /// "[Sujeto] (Lista N) #[Seq] · [Fecha] [[Tipo]]"
  /// Ejemplos:
  /// - "Freddy · 26 Oct [Manual]"
  /// - "Freddy #042 · 26 Oct [Manual]"
  /// - "Freddy · San Pedro (3° Prim) #042 · 26 Oct [Manual]"
  /// - "San Pedro (3° Prim) · 26 Oct [IA]"
  /// - "Cotización · 26 Oct [Manual]"
  static String generateTitle({
    ClientModel? selectedClient,
    String? typedClientName,
    String? schoolName,
    String? gradeLevel,
    required String quotationType,
    int? sequentialNumber,
    DateTime? date,
    int? clientListIndex,
    bool isClientRole = false,
    String? clientUserName,
  }) {
    final effectiveDate = date ?? DateTime.now();
    final dateStr = formatShortDate(effectiveDate);
    final typeLabel = resolveTypeLabel(quotationType);

    // Flujo especial para rol cliente comunitario (pedidos directos)
    if (isClientRole) {
      final name = (clientUserName != null && clientUserName.trim().isNotEmpty)
          ? clientUserName.trim()
          : (typedClientName != null && typedClientName.trim().isNotEmpty)
              ? typedClientName.trim()
              : 'Cliente';
      final seqStr = sequentialNumber != null
          ? ' #${sequentialNumber.toString().padLeft(3, '0')}'
          : '';
      final cleanType = typeLabel.replaceAll(RegExp(r'[\[\]]'), '');
      return '$name - Pedido $cleanType$seqStr · $dateStr';
    }

    final subject = buildSubject(
      selectedClient: selectedClient,
      typedClientName: typedClientName,
      schoolName: schoolName,
      gradeLevel: gradeLevel,
    );

    final buffer = StringBuffer(subject);

    // Si el cliente tiene múltiples cotizaciones activas previas
    if (clientListIndex != null && clientListIndex > 1) {
      buffer.write(' ($clientListIndex)');
    }

    // Número correlativo oficial si está asignado o proyectado
    if (sequentialNumber != null && sequentialNumber > 0) {
      buffer.write(' #${sequentialNumber.toString().padLeft(3, '0')}');
    }

    // Fecha limpia
    buffer.write(' · $dateStr');

    // Etiqueta de tipo de cotización
    buffer.write(' $typeLabel');

    return buffer.toString().trim();
  }

  /// Limpia y formatea el título de una cotización clonada, evitando la
  /// acumulación aberrante de "(Copia) (Copia)".
  /// Ejemplo:
  /// "Freddy · 26 Oct [Manual]" -> "Freddy · 26 Oct (Copia de #042) [Manual]"
  static String cleanCloneTitle(
    String originalTitle, {
    int? newSequentialNumber,
    int? originalSequentialNumber,
  }) {
    String clean = originalTitle.trim();

    // Elimina repeticiones previas de (Copia) o (Copia de #...)
    clean = clean.replaceAll(RegExp(r'\s*\(\s*Copia(?:\s+de\s+#?\d+)?\s*\)', caseSensitive: false), '');
    // Elimina espacios múltiples
    clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    final copySuffix = originalSequentialNumber != null && originalSequentialNumber > 0
        ? '(Copia de #${originalSequentialNumber.toString().padLeft(3, '0')})'
        : '(Copia)';

    // Si tiene etiqueta de tipo al final ([Manual], [IA], etc.), insertar la copia justo antes
    final typeMatch = RegExp(r'(\s*\[(?:Manual|IA|Pack Escolar)\])\s*$', caseSensitive: false).firstMatch(clean);
    if (typeMatch != null) {
      final base = clean.substring(0, typeMatch.start).trim();
      final typeTag = typeMatch.group(1)!.trim();
      return '$base $copySuffix $typeTag';
    }

    return '$clean $copySuffix';
  }

  /// Detecta si un título sigue una plantilla automática del sistema o si fue
  /// personalizado libremente por el usuario.
  static bool isAutoGeneratedTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return true;
    if (t.startsWith('Cotización')) return true;
    if (t.contains('- Pedido')) return true;
    if (t == 'Cliente General') return true;

    // Detectar patrones con terminación [Manual], [IA], [Pack Escolar] o #dd-HHmm
    if (RegExp(r'\[(?:Manual|IA|Pack Escolar)\]\s*$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'#\d{2}-\d{4}', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'#\d{3,6}', caseSensitive: false).hasMatch(t)) {
      return true;
    }

    return false;
  }
}
