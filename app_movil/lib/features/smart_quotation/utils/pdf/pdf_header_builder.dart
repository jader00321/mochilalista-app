part of '../pdf_generator.dart';

/// Construye la cabecera del documento (Logo, datos del negocio, título, fecha y cliente real).
pw.Widget _buildPdfHeader(
  SmartQuotationModel q,
  UserModel? user,
  PdfConfig config,
  pw.ImageProvider? logo,
  Map<String, PdfColor> colors,
  Map<String, dynamic>? saleData, {
  required bool isTicket,
}) {
  final bizName =
      user?.business?.commercialName ?? user?.fullName ?? "Mi Negocio";
  final bizRuc = user?.business?.ruc;
  final bizAddress = user?.business?.address;
  final bizPhone = user?.phone;

  final bool isSale = saleData != null;
  final bool isLoan = isSale && saleData['origen_venta'] == 'prestamo_personal';

  final String defaultTitle = isLoan
      ? "COMPROBANTE DE PRÉSTAMO"
      : (isSale ? "COMPROBANTE DE PAGO" : "COTIZACIÓN");
  final String docTitle = config.documentTitle ?? defaultTitle;
  final String docNumber = isSale
      ? (saleData['id'] ?? 0).toString().padLeft(6, '0')
      : q.id.toString().padLeft(6, '0');

  DateTime parsedDocDate;
  try {
    parsedDocDate = isSale && saleData['fecha_venta'] != null
        ? (CuotaDateHelper.parseFlexible(saleData['fecha_venta']) ??
              DateTime.parse(saleData['fecha_venta']))
        : (CuotaDateHelper.parseFlexible(q.createdAt) ??
              DateTime.parse(q.createdAt));
  } catch (_) {
    parsedDocDate = DateTime.now();
  }
  final String docDate = (parsedDocDate.hour == 0 && parsedDocDate.minute == 0)
      ? AppDateFormatter.formatDate(parsedDocDate)
      : AppDateFormatter.formatDateTime(parsedDocDate);

  String? rawClientName = config.customClientName;
  if (rawClientName == null || rawClientName.trim().isEmpty) {
    rawClientName = isSale ? saleData['cliente_nombre'] : q.clientName;
  }

  final String cleanClientName = PdfGenerator.cleanClientDisplayName(
    rawClientName,
  );
  final bool hasRealClient = cleanClientName.isNotEmpty;

  String? clientPhone;
  final String? rawPhone = isSale
      ? (saleData['cliente_telefono'] ??
                (saleData['cliente_info'] != null
                    ? saleData['cliente_info']['telefono']
                    : null))
            ?.toString()
      : null;
  if (rawPhone != null) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.replaceAll('0', '').isNotEmpty && digits.length >= 6) {
      clientPhone = rawPhone.trim();
    }
  }

  final bool isQuickSale = isSale && saleData['origen_venta'] == 'pos_rapido';
  final String? note =
      isSale &&
          saleData['notas'] != null &&
          saleData['notas'].toString().isNotEmpty
      ? saleData['notas']
      : (q.notas != null && q.notas!.isNotEmpty ? q.notas : null);

  final String? effectiveNote = _stripOptionalUnsupportedEmojis(
    (config.customNotes != null && config.customNotes!.trim().isNotEmpty)
        ? config.customNotes!.trim()
        : note,
  );
  final String? cleanNote = effectiveNote
      ?.replaceAll(RegExp(r'\[modo:\w+\]\s*'), '')
      .replaceAll(RegExp(r'\[mayorista\]\s*'), '')
      .trim();

  final String? effectiveInst = _stripOptionalUnsupportedEmojis(
    (config.customInstitutionName != null &&
            config.customInstitutionName!.trim().isNotEmpty)
        ? config.customInstitutionName!.trim()
        : q.institutionName,
  );
  final String? effectiveGrade = _stripOptionalUnsupportedEmojis(
    (config.customGradeLevel != null &&
            config.customGradeLevel!.trim().isNotEmpty)
        ? config.customGradeLevel!.trim()
        : q.gradeLevel,
  );

  final clientWidget = pw.Column(
    crossAxisAlignment: isTicket
        ? pw.CrossAxisAlignment.start
        : pw.CrossAxisAlignment.end,
    children: [
      if (config.showClientName && hasRealClient) ...[
        pw.Text(
          "CLIENTE: ${cleanClientName.toUpperCase()}",
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: isTicket ? 9 : 11,
          ),
        ),
        if (clientPhone != null && clientPhone.isNotEmpty)
          pw.Text(
            "Tel: $clientPhone",
            style: pw.TextStyle(
              fontSize: isTicket ? 8 : 9,
              color: PdfColors.grey700,
            ),
          ),
      ],
      if (config.showInstitutionInfo) ...[
        if (cleanNote != null && cleanNote.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              "Nota: $cleanNote",
              style: pw.TextStyle(
                fontSize: isTicket ? 8 : 9,
                color: PdfColors.grey800,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        if (!isQuickSale && !isLoan) ...[
          if (effectiveInst != null && effectiveInst.isNotEmpty)
            pw.Text(
              q.contextMode == QuotationContextMode.wholesale
                  ? "Empresa / RUC: $effectiveInst"
                  : effectiveInst,
              style: pw.TextStyle(fontSize: isTicket ? 8 : 9),
            ),
          if (effectiveGrade != null &&
              effectiveGrade.isNotEmpty &&
              q.contextMode == QuotationContextMode.school)
            pw.Text(
              effectiveGrade,
              style: pw.TextStyle(fontSize: isTicket ? 8 : 9),
            ),
        ],
      ],
    ],
  );

  if (isTicket) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (config.showBusinessInfo && config.includeLogo && logo != null)
          pw.Container(
            height: 40,
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        if (config.showBusinessInfo) ...[
          pw.Text(
            bizName.toUpperCase(),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
              color: colors['primary'],
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (config.includeShopRuc &&
              bizRuc != null &&
              bizRuc.trim().isNotEmpty)
            pw.Text("RUC: $bizRuc", style: const pw.TextStyle(fontSize: 8)),
          if (config.includeShopAddress && bizAddress != null)
            pw.Text(
              bizAddress,
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          if (config.includeOwnerPhone && bizPhone != null)
            pw.Text("Tel: $bizPhone", style: const pw.TextStyle(fontSize: 8)),
        ],
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Text(
          docTitle,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: colors['primary'],
          ),
        ),
        pw.Text(
          "N° #$docNumber  |  $docDate",
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        if ((config.showClientName && hasRealClient) ||
            config.showInstitutionInfo) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              color: colors['accent'],
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: clientWidget,
          ),
        ],
      ],
    );
  }

  final bool isCorporate =
      config.layoutTemplate == PdfLayoutTemplate.corporateFramed;

  final logoWidget =
      (config.showBusinessInfo && config.includeLogo && logo != null)
      ? pw.Container(
          constraints: const pw.BoxConstraints(maxWidth: 80, maxHeight: 60),
          margin: const pw.EdgeInsets.only(right: 14),
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        )
      : null;

  final businessContent = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logoWidget != null) logoWidget,
      if (config.showBusinessInfo)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                bizName.toUpperCase(),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                  color: colors['primary'],
                ),
              ),
              pw.SizedBox(height: 3),
              if (config.includeShopRuc &&
                  bizRuc != null &&
                  bizRuc.trim().isNotEmpty)
                pw.Text("RUC: $bizRuc", style: const pw.TextStyle(fontSize: 9)),
              if (config.includeShopAddress && bizAddress != null)
                pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 9)),
              if (config.includeOwnerPhone && bizPhone != null)
                pw.Text(
                  "Tel: $bizPhone",
                  style: const pw.TextStyle(fontSize: 9),
                ),
            ],
          ),
        ),
    ],
  );

  final docHeaderContent = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(
        docTitle,
        style: pw.TextStyle(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: colors['primary'],
        ),
      ),
      pw.Text(
        "N° #$docNumber",
        style: pw.TextStyle(fontSize: 13, color: PdfColors.grey800),
      ),
      pw.Text(
        docDate,
        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
      if ((config.showClientName && hasRealClient) ||
          config.showInstitutionInfo) ...[
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: colors['accent'],
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: isCorporate
                ? pw.Border.all(color: colors['primary']!, width: 0.5)
                : null,
          ),
          child: clientWidget,
        ),
      ],
    ],
  );

  if (isCorporate) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: businessContent,
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: colors['primary']!, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: colors['accent'],
            ),
            child: docHeaderContent,
          ),
        ),
      ],
    );
  }

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(flex: 6, child: businessContent),
      pw.Expanded(flex: 4, child: docHeaderContent),
    ],
  );
}
