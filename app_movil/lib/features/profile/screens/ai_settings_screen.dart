import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/models/ai_key_model.dart';
import 'package:app_movil/core/services/ai/ai_vault_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

/// Pantalla de Monitoreo de Cuota IA, Selector de Modo y Bóveda Segura Multi-Clave BYOK
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  List<AiKeyModel> _keys = [];
  String? _activeKeyId;
  bool _isLoadingVault = true;
  String? _testingKeyId;

  @override
  void initState() {
    super.initState();
    _loadVaultData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LicenseProvider?>()?.refreshAiScans();
      }
    });
  }

  Future<void> _loadVaultData() async {
    try {
      final keys = await AiVaultService.instance.getKeys();
      final activeId = await AiVaultService.instance.getActiveKeyId();
      if (mounted) {
        setState(() {
          _keys = keys;
          _activeKeyId = activeId ?? (keys.isNotEmpty ? keys.first.id : null);
          _isLoadingVault = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVault = false);
    }
  }

  Future<void> _switchMode(String mode) async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    if (licenseProv == null) return;

    await licenseProv.setAiSelectedMode(mode);

    if (mode == 'BYOK' && _keys.isEmpty && mounted) {
      CustomSnackBar.show(
        context,
        message: "Modo BYOK activado. Por favor, agrega una clave para comenzar a escanear.",
        isError: false,
      );
    }
  }

  Future<void> _launchAiStudio() async {
    final uri = Uri.parse('https://aistudio.google.com/apikey');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo abrir el navegador: $e",
          isError: true,
        );
      }
    }
  }

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.vpn_key_rounded, color: Colors.blue, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Agregar Clave BYOK",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                showKeyText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setDialogState(() => showKeyText = !showKeyText),
                            ),
                            IconButton(
                              icon: const Icon(Icons.paste_rounded, size: 18),
                              tooltip: "Pegar clave",
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                if (data?.text != null) {
                                  keyController.text = data!.text!.trim();
                                }
                              },
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingKey ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: isSavingKey
                      ? null
                      : () async {
                          final alias = aliasController.text.trim();
                          final key = keyController.text.trim();

                          if (alias.isEmpty) {
                            CustomSnackBar.show(
                              dialogContext,
                              message: "Ingresa un alias para tu clave (ej. 'Gmail Principal').",
                              isError: true,
                            );
                            return;
                          }
                          if (key.isEmpty) {
                            CustomSnackBar.show(
                              dialogContext,
                              message: "Ingresa una API Key válida de Google AI Studio.",
                              isError: true,
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
                              CustomSnackBar.show(
                                context,
                                message: "Clave '$alias' guardada exitosamente en la bóveda.",
                                isError: false,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSavingKey = false);
                            if (dialogContext.mounted) {
                              CustomSnackBar.show(
                                dialogContext,
                                message: e.toString().replaceFirst("Exception: ", ""),
                                isError: true,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSavingKey
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Future<void> _showEditAliasDialog(AiKeyModel key) async {
    final aliasController = TextEditingController(text: key.alias);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text("Editar Nombre / Alias", style: TextStyle(fontSize: 16)),
            ],
          ),
          content: TextField(
            controller: aliasController,
            decoration: InputDecoration(
              labelText: "Nuevo Alias",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    CustomSnackBar.show(
                      context,
                      message: "Alias actualizado a '$newAlias'.",
                      isError: false,
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

  Future<void> _testKey(AiKeyModel key) async {
    setState(() => _testingKeyId = key.id);
    final result = await AiVaultService.instance.testApiKey(key.apiKey);
    await _loadVaultData();
    if (mounted) {
      setState(() => _testingKeyId = null);
      CustomSnackBar.show(
        context,
        message: result.message,
        isError: !result.isSuccess,
      );
    }
  }

  Future<void> _copyKey(AiKeyModel key) async {
    await Clipboard.setData(ClipboardData(text: key.apiKey));
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Clave completa de '${key.alias}' copiada al portapapeles.",
        isError: false,
      );
    }
  }

  Future<void> _activateKey(AiKeyModel key) async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    await AiVaultService.instance.setActiveKey(key.id);
    await licenseProv?.refreshAiScans();
    await _loadVaultData();
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Clave '${key.alias}' activada para procesar escaneos.",
        isError: false,
      );
    }
  }

  Future<void> _confirmDeleteKey(AiKeyModel key) async {
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text("Eliminar Clave BYOK", style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text("¿Deseas eliminar la clave '${key.alias}' de tu bóveda segura? Esta acción no se puede deshacer."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
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
        CustomSnackBar.show(
          context,
          message: "Clave '${key.alias}' eliminada de la bóveda.",
          isError: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final license = licenseProv?.license;

    final isByokMode = licenseProv?.isUsingByokMode ?? false;
    final remainingScans = licenseProv?.remainingAiScans ?? 50;
    final accumulatedScans = licenseProv?.aiAccumulatedScans ?? remainingScans;
    final activeKey = _keys.where((k) => k.id == _activeKeyId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cotizador Universal IA y Cuota",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Selector Explícito de Modo de Procesamiento IA
              _buildModeSelector(
                isByokMode: isByokMode,
                accumulatedScans: accumulatedScans,
                activeKey: activeKey,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // 2. Tarjeta de Bolsa Acumulativa Compartida (Sin Reseteo Mensual)
              _buildCumulativeQuotaCard(
                isByokMode: isByokMode,
                accumulatedScans: accumulatedScans,
                license: license,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // 3. Bóveda Segura Multi-Clave BYOK
              _buildVaultCard(
                isDark: isDark,
                isByokMode: isByokMode,
              ),
              const SizedBox(height: 16),

              // 4. Guía Paso a Paso ¿Cómo obtener una API Key gratis?
              _buildStepByStepGuideCard(isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector({
    required bool isByokMode,
    required int accumulatedScans,
    required AiKeyModel? activeKey,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSelectorTile(
                title: "Bolsa MochilaLista",
                subtitle: "$accumulatedScans usos disponibles",
                icon: Icons.inventory_2_rounded,
                isSelected: !isByokMode,
                activeColor: Colors.blue[700]!,
                onTap: () => _switchMode('INCLUDED'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectorTile(
                title: "Clave Propia (BYOK)",
                subtitle: activeKey != null ? activeKey.alias : "Sin clave activa",
                icon: Icons.vpn_key_rounded,
                isSelected: isByokMode,
                activeColor: Colors.purple[700]!,
                onTap: () => _switchMode('BYOK'),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "El modo Clave Propia (BYOK) te permite usar el escaneo con IA libremente sin gastar tus usos acumulados de MochilaLista. La aplicación sigue requiriendo una licencia activa para operar todas sus funciones.",
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final bgColor = isSelected
        ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
        : (isDark ? const Color(0xFF1E1E28) : Colors.white);
    final borderColor = isSelected ? activeColor : (isDark ? Colors.white12 : Colors.black12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: isSelected ? activeColor : Colors.grey),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 18, color: activeColor)
                else
                  Icon(Icons.radio_button_unchecked_rounded, size: 18, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCumulativeQuotaCard({
    required bool isByokMode,
    required int accumulatedScans,
    required dynamic license,
    required bool isDark,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.blue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        "Bolsa Acumulativa de IA",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isByokMode
                              ? Colors.purple.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isByokMode ? "Bolsa Congelada (BYOK)" : "Bolsa Activa",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isByokMode ? Colors.purple : Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$accumulatedScans disponibles",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: accumulatedScans <= 5 ? Colors.red : Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Saldo compartido entre todos los perfiles de este equipo",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isByokMode
                    ? Colors.purple.withValues(alpha: 0.08)
                    : Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isByokMode
                      ? Colors.purple.withValues(alpha: 0.25)
                      : Colors.blue.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isByokMode ? Icons.pause_circle_outline_rounded : Icons.shield_outlined,
                    size: 18,
                    color: isByokMode ? Colors.purple : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isByokMode
                          ? "Tus $accumulatedScans usos acumulados están protegidos y no se gastan mientras uses tu propia clave."
                          : "Los escaneos son 100% acumulativos: no caducan ni se resetean al cambiar de mes. Cada canje suma a tu bolsa.",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[200] : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultCard({
    required bool isDark,
    required bool isByokMode,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        "Bóveda Segura Multi-Clave",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddKeyDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text("Agregar Clave", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Guarda tus API Keys gratuitas de Google AI Studio. Tus claves se almacenan cifradas en hardware mediante almacenamiento seguro.",
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 14),

            if (_isLoadingVault)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_keys.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.vpn_key_off_outlined, size: 36, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    const Text(
                      "No tienes claves registradas en la bóveda",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Presiona 'Agregar Clave' para registrar tu primera clave propia de Google AI Studio.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _keys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final keyModel = _keys[index];
                  final isActive = keyModel.id == _activeKeyId;
                  final isTestingThis = _testingKeyId == keyModel.id;

                  return _buildKeyVaultCardItem(
                    keyModel: keyModel,
                    isActive: isActive,
                    isTesting: isTestingThis,
                    isDark: isDark,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyVaultCardItem({
    required AiKeyModel keyModel,
    required bool isActive,
    required bool isTesting,
    required bool isDark,
  }) {
    final borderColor = isActive
        ? Colors.purple
        : (isDark ? Colors.white12 : Colors.black12);
    final bgColor = isActive
        ? Colors.purple.withValues(alpha: isDark ? 0.12 : 0.05)
        : (isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  keyModel.alias,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "En Uso",
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Clave enmascarada (jamás expuesta en texto plano)
          Text(
            keyModel.maskedKey,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),

          // Estado de verificación
          if (keyModel.lastTestedAt != null)
            Row(
              children: [
                Icon(
                  keyModel.isWorking == true
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 13,
                  color: keyModel.isWorking == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  keyModel.isWorking == true
                      ? "Verificada (${DateFormat('dd/MM HH:mm').format(keyModel.lastTestedAt!)})"
                      : "Error de Conexión (${DateFormat('dd/MM HH:mm').format(keyModel.lastTestedAt!)})",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: keyModel.isWorking == true ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),

          // Barra de acciones con iconos vectoriales
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!isActive)
                OutlinedButton.icon(
                  onPressed: () => _activateKey(keyModel),
                  icon: const Icon(Icons.radio_button_checked_rounded, size: 14),
                  label: const Text("Activar", style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: isTesting ? null : () => _testKey(keyModel),
                icon: isTesting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check_rounded, size: 14),
                label: const Text("Probar Clave", style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                onPressed: () => _copyKey(keyModel),
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: "Copiar Clave",
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _showEditAliasDialog(keyModel),
                icon: const Icon(Icons.edit_rounded, size: 16),
                tooltip: "Editar Nombre",
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _confirmDeleteKey(keyModel),
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                tooltip: "Eliminar",
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepByStepGuideCard(bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school_outlined, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "¿Cómo obtener una API Key gratis?",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStepTile("1", "Ingresa a aistudio.google.com con tu cuenta de Google habitual.", isDark),
            _buildStepTile("2", "Haz clic en 'Get API key' y luego en 'Create API key' en un nuevo proyecto.", isDark),
            _buildStepTile("3", "Copia la clave generada (inicia con AIzaSy...) y regístrala en la bóveda superior.", isDark),
            const SizedBox(height: 10),

            // Botón directo para abrir Google AI Studio
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _launchAiStudio,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text(
                  "Abrir Google AI Studio",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Google ofrece un nivel gratuito con miles de peticiones mensuales sin costo de tarjeta.",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.green[200] : Colors.green[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile(String stepNumber, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
