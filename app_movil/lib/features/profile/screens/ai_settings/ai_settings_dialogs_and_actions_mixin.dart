part of '../ai_settings_screen.dart';

mixin _AiSettingsDialogsAndActionsMixin on _AiSettingsScreenBase {
  @override
  Future<void> _showAddKeyDialog() async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    final aliasController = TextEditingController();
    final keyController = TextEditingController();
    bool showKeyText = false;
    bool isSavingKey = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            final theme = Theme.of(sbContext);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.vpn_key_rounded, color: Colors.blue, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Agregar Clave BYOK",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Asigna un nombre o alias para identificar la cuenta de Google a la que pertenece esta clave.",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de Alias obligatorio
                    TextField(
                      controller: aliasController,
                      decoration: InputDecoration(
                        labelText: "Nombre / Alias (obligatorio)",
                        hintText: "Ej. Gmail Principal, Tienda Centro",
                        prefixIcon: const Icon(
                          Icons.label_outline_rounded,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E1E28)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de API Key
                    TextField(
                      controller: keyController,
                      obscureText: !showKeyText,
                      decoration: InputDecoration(
                        labelText: "API Key de Google AI Studio",
                        hintText: "AIzaSy...",
                        prefixIcon: const Icon(Icons.key_rounded, size: 18),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                showKeyText
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setDialogState(
                                () => showKeyText = !showKeyText,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.paste_rounded, size: 18),
                              tooltip: "Pegar clave",
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                  Clipboard.kTextPlain,
                                );
                                if (data?.text != null) {
                                  keyController.text = data!.text!.trim();
                                }
                              },
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E1E28)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingKey
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: isSavingKey
                      ? null
                      : () async {
                          final alias = aliasController.text.trim();
                          final key = keyController.text.trim();

                          if (alias.isEmpty) {
                            AppFeedbackHelper.showError(
                              dialogContext,
                              "Ingresa un alias para tu clave (ej. 'Gmail Principal').",
                            );
                            return;
                          }
                          if (key.isEmpty) {
                            AppFeedbackHelper.showError(
                              dialogContext,
                              "Ingresa una API Key válida de Google AI Studio.",
                            );
                            return;
                          }

                          setDialogState(() => isSavingKey = true);
                          try {
                            await AiVaultService.instance.addKey(
                              alias: alias,
                              apiKey: key,
                            );
                            await licenseProv?.refreshAiScans();

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            await _loadVaultData();
                            if (mounted) {
                              AppFeedbackHelper.showSuccess(
                                context,
                                "Clave '$alias' guardada exitosamente en la bóveda.",
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSavingKey = false);
                            if (dialogContext.mounted) {
                              AppFeedbackHelper.showError(
                                dialogContext,
                                e.toString().replaceFirst("Exception: ", ""),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSavingKey
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Guardar Clave"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Future<void> _showEditAliasDialog(AiKeyModel key) async {
    final aliasController = TextEditingController(text: key.alias);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Editar Nombre / Alias",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: aliasController,
            decoration: InputDecoration(
              labelText: "Nuevo Alias",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newAlias = aliasController.text.trim();
                if (newAlias.isNotEmpty) {
                  await AiVaultService.instance.updateAlias(key.id, newAlias);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  await _loadVaultData();
                  if (mounted) {
                    AppFeedbackHelper.showSuccess(
                      context,
                      "Alias actualizado a '$newAlias'.",
                    );
                  }
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<void> _testKey(AiKeyModel key) async {
    setState(() => _testingKeyId = key.id);
    final result = await AiVaultService.instance.testApiKey(key.apiKey);
    await _loadVaultData();
    if (mounted) {
      setState(() => _testingKeyId = null);
      if (result.isSuccess) {
        AppFeedbackHelper.showSuccess(context, result.message);
      } else {
        AppFeedbackHelper.showError(context, result.message);
      }
    }
  }

  @override
  Future<void> _copyKey(AiKeyModel key) async {
    await ClipboardHelper.copyWithFeedback(
      context,
      key.apiKey,
      feedbackMessage:
          "Clave completa de '${key.alias}' copiada al portapapeles.",
    );
  }

  @override
  Future<void> _activateKey(AiKeyModel key) async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    await AiVaultService.instance.setActiveKey(key.id);
    await licenseProv?.refreshAiScans();
    await _loadVaultData();
    if (mounted) {
      AppFeedbackHelper.showSuccess(
        context,
        "Clave '${key.alias}' activada para procesar escaneos.",
      );
    }
  }

  @override
  Future<void> _confirmDeleteKey(AiKeyModel key) async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Eliminar Clave BYOK",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            "¿Deseas eliminar la clave '${key.alias}' de tu bóveda segura? Esta acción no se puede deshacer.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await AiVaultService.instance.deleteKey(key.id);
      await licenseProv?.refreshAiScans();
      await _loadVaultData();
      if (mounted) {
        AppFeedbackHelper.showSuccess(
          context,
          "Clave '${key.alias}' eliminada de la bóveda.",
        );
      }
    }
  }
}
