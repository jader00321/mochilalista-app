part of '../backup_screen.dart';

class SmartBackupSection extends StatefulWidget {
  final bool isDark;
  final Color cardColor;

  const SmartBackupSection({
    super.key,
    required this.isDark,
    required this.cardColor,
  });

  @override
  State<SmartBackupSection> createState() => _SmartBackupSectionState();
}

class _SmartBackupSectionState extends State<SmartBackupSection> {
  bool _includeSecurityPin = false;
  bool _isExportExpanded = false;

  void _handleImport(
    BuildContext context,
    AuthProvider auth, {
    bool isReplace = false,
  }) async {
    Map<String, dynamic>? result;
    try {
      result = await BusinessBackupService.pickBackupFile();
    } catch (e) {
      if (context.mounted) {
        AppFeedbackHelper.showError(context, e.toString());
      }
      return;
    }
    if (result == null) return;

    if (!context.mounted) return;

    final bool hasPin = result['has_security_pin'];
    bool applyPin = false;

    if (hasPin) {
      bool? confirmPin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark
              ? const Color(0xFF23232F)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Clave Detectada",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            "El archivo de backup incluye una clave de seguridad.\n\n¿Deseas ${isReplace ? 'actualizar tu clave actual con' : 'usar'} la clave del backup?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                "Ignorar",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Sí, usar clave",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmPin == null) return;
      applyPin = confirmPin;
    }

    if (isReplace) {
      if (!context.mounted) return;
      bool? confirmReplace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark
              ? const Color(0xFF23232F)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "¿Reemplazar Negocio?",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Se borrarán TODOS los datos de ESTE negocio y serán reemplazados por los del archivo .mlb. ¡No afectará a tus otros perfiles!\n\n¿Estás seguro?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                "Cancelar",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Sí, Reemplazar",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmReplace != true) return;
    }

    if (!context.mounted) return;
    AppFeedbackHelper.showInfo(
      context,
      isReplace ? "Reemplazando datos..." : "Importando negocio...",
    );

    bool ok = await BusinessBackupService.importBusiness(
      auth.activeUserId!,
      result['filePath'],
      replaceTargetNegocioId: isReplace ? auth.activeBusinessId : null,
      applyPin: applyPin,
    );

    if (context.mounted) {
      if (ok) {
        AppFeedbackHelper.showSuccess(
          context,
          isReplace
              ? "¡Negocio reemplazado! Reiniciando..."
              : "Negocio importado como nuevo perfil. ¡Cierra sesión y entra al nuevo!",
        );
        if (isReplace) {
          await auth.logout();
          await auth.checkInitialState();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
            (route) => false,
          );
        } else {
          await auth.checkInitialState();
        }
      } else {
        AppFeedbackHelper.showError(
          context,
          "Error al importar negocio. Revisa el archivo.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider?>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white10
              : Colors.purple.withValues(alpha: 0.2),
        ),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExportExpanded = !_isExportExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      color: Colors.purple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      "Exportar Negocio Actual (.mlb)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    _isExportExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 24,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                _Divider(isDark: widget.isDark),
                _ActionSubButton(
                  icon: Icons.chat_bubble_outline,
                  label: "Enviar por WhatsApp",
                  color: Colors.green,
                  isDark: widget.isDark,
                  onTap: () async {
                    if (auth?.activeBusinessId == null) return;
                    AppFeedbackHelper.showInfo(
                      context,
                      "Generando archivo .mlb...",
                    );
                    bool ok = await BusinessBackupService.exportBusiness(
                      auth!.activeBusinessId!,
                      auth.businessName,
                      includeSecurityPin: _includeSecurityPin,
                    );
                    if (context.mounted) {
                      if (ok) {
                        AppFeedbackHelper.showSuccess(
                          context,
                          "Menú de compartir abierto.",
                        );
                      } else {
                        AppFeedbackHelper.showError(
                          context,
                          "Error al exportar negocio.",
                        );
                      }
                    }
                  },
                ),
                _Divider(isDark: widget.isDark),
                _ActionSubButton(
                  icon: Icons.folder_open_rounded,
                  label: "Guardar en Descargas",
                  color: Colors.orange,
                  isDark: widget.isDark,
                  onTap: () async {
                    if (auth?.activeBusinessId == null) return;
                    AppFeedbackHelper.showInfo(
                      context,
                      "Guardando en descargas...",
                    );
                    bool ok = await BusinessBackupService.exportBusinessToFile(
                      auth!.activeBusinessId!,
                      auth.businessName,
                      includeSecurityPin: _includeSecurityPin,
                    );
                    if (context.mounted) {
                      if (ok) {
                        AppFeedbackHelper.showSuccess(
                          context,
                          "¡Guardado en Descargas!",
                        );
                      } else {
                        AppFeedbackHelper.showError(
                          context,
                          "Error al exportar negocio.",
                        );
                      }
                    }
                  },
                ),
                _Divider(isDark: widget.isDark),
                _ActionSubButton(
                  icon: Icons.folder_special_rounded,
                  label: "Elegir carpeta personalizada",
                  color: Colors.blueAccent,
                  isDark: widget.isDark,
                  onTap: () async {
                    if (auth?.activeBusinessId == null) return;
                    String? customPath = await FilePicker.platform
                        .getDirectoryPath();
                    if (customPath == null) return;
                    if (!context.mounted) return;
                    AppFeedbackHelper.showInfo(
                      context,
                      "Guardando en ruta elegida...",
                    );
                    bool ok = await BusinessBackupService.exportBusinessToFile(
                      auth!.activeBusinessId!,
                      auth.businessName,
                      includeSecurityPin: _includeSecurityPin,
                      targetDirectory: customPath,
                    );
                    if (context.mounted) {
                      if (ok) {
                        AppFeedbackHelper.showSuccess(
                          context,
                          "¡Guardado en la carpeta elegida!",
                        );
                      } else {
                        AppFeedbackHelper.showError(
                          context,
                          "Error al exportar negocio.",
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            crossFadeState: _isExportExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          _Divider(isDark: widget.isDark),
          SwitchListTile(
            title: Text(
              "Incluir Clave de Seguridad",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: (auth?.hasPinCache ?? false) ? null : Colors.grey,
              ),
            ),
            subtitle: Text(
              (auth?.hasPinCache ?? false)
                  ? "El backup requerirá esta clave al importarse."
                  : "Este perfil no tiene clave configurada.",
              style: const TextStyle(fontSize: 12),
            ),
            value: (auth?.hasPinCache ?? false) ? _includeSecurityPin : false,
            onChanged: (auth?.hasPinCache ?? false)
                ? (val) {
                    setState(() {
                      _includeSecurityPin = val;
                    });
                  }
                : null,
            activeTrackColor: Colors.purple.withValues(alpha: 0.5),
            activeThumbColor: Colors.purple,
          ),
          _Divider(isDark: widget.isDark),
          _ActionButton(
            icon: Icons.post_add,
            label: "Importar como Nuevo Negocio",
            color: Colors.teal,
            isDark: widget.isDark,
            onTap: () {
              if (auth?.activeUserId == null) return;
              _handleImport(context, auth!, isReplace: false);
            },
          ),
          _Divider(isDark: widget.isDark),
          _ActionButton(
            icon: Icons.system_update_alt,
            label: "Reemplazar Negocio Actual",
            color: Colors.redAccent,
            isDark: widget.isDark,
            isBottom: true,
            onTap: () {
              if (auth?.activeUserId == null ||
                  auth?.activeBusinessId == null) {
                return;
              }
              _handleImport(context, auth!, isReplace: true);
            },
          ),
        ],
      ),
    );
  }
}
