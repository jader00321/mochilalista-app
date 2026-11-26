part of '../pdf_preview_screen.dart';

mixin _PdfConfigFooterChipsSectionMixin on _PdfPreviewScreenStateBase {
  @override
  Widget _buildValiditySection({
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 14,
              color: isDark ? Colors.blue[300] : Colors.blue[800],
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                "1. Tiempo de Validez",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Selección única",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              [
                ("Válida por 3 días", 3),
                ("Válida por 7 días", 7),
                ("Válida por 15 días", 15),
                ("Válida por 30 días", 30),
              ].map((item) {
                final cleanText = item.$1;
                final daysNum = item.$2;
                final currentText = _footerNoteCtrl.text;
                final isSelected = RegExp(
                  r'v[áa]lida\s+por\s+' + daysNum.toString() + r'\s+d[íi]as',
                  caseSensitive: false,
                ).hasMatch(currentText);

                return FilterChip(
                  visualDensity: VisualDensity.compact,
                  selected: isSelected,
                  showCheckmark: true,
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.blue.shade700,
                  backgroundColor: isDark
                      ? const Color(0xFF1E1E2C)
                      : Colors.grey.shade100,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.blue
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  label: Text(
                    cleanText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onSelected: (_) {
                    updateConfig(() {
                      final fullValidityPattern = RegExp(
                        r'(?:Cotizaci[óo]n\s+)?v[áa]lida\s+por\s+\d+\s+d[íi]as',
                        caseSensitive: false,
                      );
                      if (isSelected) {
                        String updated = currentText.replaceAll(
                          fullValidityPattern,
                          '',
                        );
                        updated = updated
                            .replaceAll(RegExp(r'\.\s*\.'), '.')
                            .trim();
                        if (updated.startsWith('.')) {
                          updated = updated.substring(1).trim();
                        }
                        if (updated.endsWith('.')) {
                          updated = updated
                              .substring(0, updated.length - 1)
                              .trim();
                        }
                        updated = updated.replaceAll(RegExp(r'\s+'), ' ');
                        _footerNoteCtrl.text = updated;
                        _config.footerNote = updated.isEmpty ? null : updated;
                      } else {
                        if (fullValidityPattern.hasMatch(currentText)) {
                          final match = fullValidityPattern.firstMatch(
                            currentText,
                          );
                          final hadCotizacionPrefix =
                              match != null &&
                              match
                                  .group(0)!
                                  .toLowerCase()
                                  .startsWith('cotizaci');
                          final replacement = hadCotizacionPrefix
                              ? "Cotización ${cleanText.toLowerCase()}"
                              : cleanText;
                          final updated = currentText.replaceFirst(
                            fullValidityPattern,
                            replacement,
                          );
                          _footerNoteCtrl.text = updated;
                          _config.footerNote = updated;
                        } else {
                          String current = currentText.trim();
                          if (current.endsWith('.')) {
                            current = current
                                .substring(0, current.length - 1)
                                .trim();
                          }
                          final newText = current.isEmpty
                              ? cleanText
                              : "$current. $cleanText";
                          _footerNoteCtrl.text = newText;
                          _config.footerNote = newText;
                        }
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  @override
  Widget _buildConditionsSection({
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 14,
              color: isDark ? Colors.orange[300] : Colors.orange[800],
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                "2. Condiciones y Cierre",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Múltiple",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.orange[300] : Colors.orange[800],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              [
                "Entrega inmediata",
                "Precios incluyen IGV",
                "Sujeto a stock",
                "Garantía de tienda",
                "¡Gracias por su compra!",
              ].map((cleanText) {
                final currentText = _footerNoteCtrl.text;
                final isSelected =
                    currentText.toLowerCase().contains(
                      cleanText.toLowerCase(),
                    ) ||
                    (cleanText.contains("¡Gracias") &&
                        currentText.toLowerCase().contains(
                          "gracias por su compra",
                        ));

                return FilterChip(
                  visualDensity: VisualDensity.compact,
                  selected: isSelected,
                  showCheckmark: true,
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.orange.shade700,
                  backgroundColor: isDark
                      ? const Color(0xFF1E1E2C)
                      : Colors.grey.shade100,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.orange
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  label: Text(
                    cleanText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onSelected: (_) {
                    updateConfig(() {
                      if (isSelected) {
                        String updated = currentText.replaceAll(cleanText, '');
                        if (cleanText.contains("¡Gracias")) {
                          updated = updated.replaceAll(
                            RegExp(
                              r'¡?Gracias por su compra!?',
                              caseSensitive: false,
                            ),
                            '',
                          );
                        }
                        updated = updated
                            .replaceAll(RegExp(r'\.\s*\.'), '.')
                            .trim();
                        if (updated.startsWith('.')) {
                          updated = updated.substring(1).trim();
                        }
                        if (updated.endsWith('.')) {
                          updated = updated
                              .substring(0, updated.length - 1)
                              .trim();
                        }
                        updated = updated.replaceAll(RegExp(r'\s+'), ' ');
                        _footerNoteCtrl.text = updated;
                        _config.footerNote = updated.isEmpty ? null : updated;
                      } else {
                        String current = currentText.trim();
                        if (current.endsWith('.')) {
                          current = current
                              .substring(0, current.length - 1)
                              .trim();
                        }
                        final newText = current.isEmpty
                            ? cleanText
                            : "$current. $cleanText";
                        _footerNoteCtrl.text = newText;
                        _config.footerNote = newText;
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  @override
  Widget _buildPaymentAccountsSection({
    required AuthProvider authProv,
    required GlobalKey paymentAccountsKey,
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Mostrar Cuentas de Cobro (Yape/Plin)",
            style: TextStyle(color: textColor, fontSize: 14),
          ),
          subtitle: Text(
            "Imprime tus números de pago al pie",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          value: _config.showPaymentAccounts,
          activeThumbColor: Colors.orange,
          onChanged: (v) {
            updateConfig(() {
              _config.showPaymentAccounts = v;
              if (v) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (paymentAccountsKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      paymentAccountsKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.8,
                    );
                  }
                });
              }
            });
          },
        ),
        AnimatedSize(
          key: paymentAccountsKey,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: !_config.showPaymentAccounts
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _paymentAccountsCtrl,
                        maxLines: 2,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "Cuentas de Cobro / Instrucciones de Pago",
                          hintText:
                              "Ej: Yape/Plin: 999-888-777 | BCP: 191-xxxx...",
                          labelStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1E1E2C)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (v) => updateConfig(
                          () => _config.customPaymentInfo = v.trim().isEmpty
                              ? null
                              : v.trim(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            [
                              ("Yape", Icons.smartphone_rounded),
                              ("Plin", Icons.smartphone_rounded),
                              ("BCP", Icons.account_balance_rounded),
                              ("CCI", Icons.account_balance_rounded),
                            ].map((item) {
                              final rawType = item.$1;
                              final chipIcon = item.$2;
                              final current = _paymentAccountsCtrl.text;
                              final isSelected = RegExp(
                                r'\b' + rawType + r'\b',
                                caseSensitive: false,
                              ).hasMatch(current);

                              return FilterChip(
                                visualDensity: VisualDensity.compact,
                                selected: isSelected,
                                showCheckmark: true,
                                checkmarkColor: Colors.white,
                                selectedColor: Colors.orange.shade700,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E1E2C)
                                    : Colors.grey.shade100,
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.orange
                                      : (isDark
                                            ? Colors.white24
                                            : Colors.grey.shade300),
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      chipIcon,
                                      size: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700]),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rawType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[800]),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                onSelected: (_) {
                                  updateConfig(() {
                                    if (isSelected) {
                                      final pattern = RegExp(
                                        r'(?:^|[|\n])\s*(?:[^\w\s]*\s*)?' +
                                            rawType +
                                            r'[:\s][^|\n]*',
                                        caseSensitive: false,
                                      );
                                      String updated = current.replaceAll(
                                        pattern,
                                        '',
                                      );
                                      updated = updated.replaceAll(
                                        RegExp(r'\|\s*\|'),
                                        '|',
                                      );
                                      updated = updated.replaceAll(
                                        RegExp(r'\n\s*\n'),
                                        '\n',
                                      );
                                      updated = updated.trim();
                                      if (updated.startsWith('|')) {
                                        updated = updated.substring(1).trim();
                                      }
                                      if (updated.endsWith('|')) {
                                        updated = updated
                                            .substring(0, updated.length - 1)
                                            .trim();
                                      }
                                      _paymentAccountsCtrl.text = updated;
                                      _config.customPaymentInfo =
                                          updated.isEmpty ? null : updated;
                                    } else {
                                      final userPhone =
                                          authProv.user?.phone?.trim() ?? "";
                                      final bizPaymentInfo =
                                          authProv
                                              .user
                                              ?.business
                                              ?.paymentInfo ??
                                          "";
                                      String accountNum = "";
                                      final m = RegExp(
                                        rawType + r'[:\s]+([0-9\s-]+)',
                                        caseSensitive: false,
                                      ).firstMatch(bizPaymentInfo);
                                      if (m != null &&
                                          m.group(1) != null &&
                                          m.group(1)!.trim().isNotEmpty) {
                                        accountNum = m.group(1)!.trim();
                                      } else if (rawType == 'Yape' ||
                                          rawType == 'Plin') {
                                        accountNum = userPhone;
                                      }

                                      final entry = accountNum.isNotEmpty
                                          ? "$rawType: $accountNum"
                                          : "$rawType: ";
                                      final text = current.trim();
                                      final String newText;
                                      if (text.isEmpty) {
                                        newText = entry;
                                      } else if (text.contains('\n')) {
                                        newText = "$text\n$entry";
                                      } else {
                                        newText = "$text | $entry";
                                      }
                                      _paymentAccountsCtrl.text = newText;
                                      _config.customPaymentInfo = newText;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
