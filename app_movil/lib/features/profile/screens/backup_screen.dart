import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_movil/core/utils/backup_manager.dart';

class AutoBackupTimerWidget extends StatefulWidget {
  final BackupProvider provider;
  final bool isDark;
  
  const AutoBackupTimerWidget({super.key, required this.provider, required this.isDark});

  @override
  State<AutoBackupTimerWidget> createState() => _AutoBackupTimerWidgetState();
}

class _AutoBackupTimerWidgetState extends State<AutoBackupTimerWidget> {
  Timer? _timer;
  String _timeLeft = "Calculando...";

  @override
  void initState() {
    super.initState();
    _initAndCalculate();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _calculateTime();
    });
  }

  Future<void> _initAndCalculate() async {
    await widget.provider.reloadTimestamps();
    if (mounted) _calculateTime();
  }

  @override
  void didUpdateWidget(AutoBackupTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.lastRegisterTime != widget.provider.lastRegisterTime || 
        oldWidget.provider.lastRunTime != widget.provider.lastRunTime ||
        oldWidget.provider.autoBackupIntervalDays != widget.provider.autoBackupIntervalDays) {
      _calculateTime();
    }
  }

  void _calculateTime() {
    if (!mounted) return;
    
    final int baseTimeMs = widget.provider.lastRunTime > widget.provider.lastRegisterTime 
        ? widget.provider.lastRunTime 
        : widget.provider.lastRegisterTime;
        
    if (baseTimeMs == 0) {
      setState(() => _timeLeft = "Programado para iniciar...");
      return;
    }

    final baseDate = DateTime.fromMillisecondsSinceEpoch(baseTimeMs);
    final targetDate = baseDate.add(Duration(days: widget.provider.autoBackupIntervalDays));
    final now = DateTime.now();
    
    if (now.isAfter(targetDate)) {
      setState(() => _timeLeft = "A punto de ejecutarse...");
      return;
    }

    final diff = targetDate.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    
    if (days > 0) {
      setState(() => _timeLeft = "Faltan $days d y $hours h");
    } else if (hours > 0) {
      setState(() => _timeLeft = "Faltan $hours h y $minutes m");
    } else {
      setState(() => _timeLeft = "Faltan $minutes min");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.indigoAccent.withValues(alpha: 0.1) : Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigoAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, size: 20, color: Colors.indigoAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Próximo respaldo automático en:", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(height: 2),
                Text(_timeLeft, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.indigo[900])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class PinDelayConfigWidget extends StatefulWidget {
  final bool isDark;
  const PinDelayConfigWidget({super.key, required this.isDark});

  @override
  State<PinDelayConfigWidget> createState() => _PinDelayConfigWidgetState();
}

class _PinDelayConfigWidgetState extends State<PinDelayConfigWidget> {
  int _delayMinutes = 1;

  @override
  void initState() {
    super.initState();
    _loadDelay();
  }

  Future<void> _loadDelay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _delayMinutes = prefs.getInt('pin_delay_minutes') ?? 1;
    });
  }

  Future<void> _setDelay(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pin_delay_minutes', value);
    setState(() {
      _delayMinutes = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.teal.withValues(alpha: 0.3)),
        boxShadow: [if (!widget.isDark) BoxShadow(color: Colors.teal.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bloqueo automático", style: TextStyle(fontSize: 16, color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text("Tiempo inactivo antes de pedir PIN.", style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: widget.isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<int>(
                value: _delayMinutes,
                underline: const SizedBox(),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.teal),
                style: TextStyle(fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black87),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Inmediato")),
                  DropdownMenuItem(value: 1, child: Text("1 minuto")),
                  DropdownMenuItem(value: 2, child: Text("2 minutos")),
                  DropdownMenuItem(value: 5, child: Text("5 minutos")),
                  DropdownMenuItem(value: 10, child: Text("10 minutos")),
                  DropdownMenuItem(value: 15, child: Text("15 minutos")),
                  DropdownMenuItem(value: 30, child: Text("30 minutos")),
                  DropdownMenuItem(value: 60, child: Text("1 hora")),
                ],
                onChanged: (val) {
                  if (val != null) _setDelay(val);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SmartBackupSection extends StatefulWidget {
  final bool isDark;
  final Color cardColor;
  
  const SmartBackupSection({super.key, required this.isDark, required this.cardColor});

  @override
  State<SmartBackupSection> createState() => _SmartBackupSectionState();
}

class _SmartBackupSectionState extends State<SmartBackupSection> {
  bool _includeSecurityPin = false;
  bool _isExportExpanded = false;

  void _handleImport(BuildContext context, AuthProvider auth, {bool isReplace = false}) async {
    Map<String, dynamic>? result;
    try {
      result = await BusinessBackupService.pickBackupFile();
    } catch (e) {
      if (context.mounted) CustomSnackBar.show(context, message: e.toString(), isError: true);
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
          backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.lock_person_rounded, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("Clave Detectada", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            ],
          ),
          content: Text("El archivo de backup incluye una clave de seguridad.\n\n¿Deseas ${isReplace ? 'actualizar tu clave actual con' : 'usar'} la clave del backup?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Ignorar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Sí, usar clave", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
      );
      if (confirmPin == null) return; 
      applyPin = confirmPin;
    }

    if (isReplace) {
      if (!context.mounted) return;
      bool? confirmReplace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("¿Reemplazar Negocio?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.redAccent))),
            ],
          ),
          content: const Text("Se borrarán TODOS los datos de ESTE negocio y serán reemplazados por los del archivo .mlb. ¡No afectará a tus otros perfiles!\n\n¿Estás seguro?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Sí, Reemplazar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
      );
      if (confirmReplace != true) return;
    }

    if (!context.mounted) return;
    CustomSnackBar.show(context, message: isReplace ? "Reemplazando datos..." : "Importando negocio...", isError: false);
    
    bool ok = await BusinessBackupService.importBusiness(
      auth.activeUserId!, 
      result['filePath'], 
      replaceTargetNegocioId: isReplace ? auth.activeBusinessId : null,
      applyPin: applyPin
    );
    
    if (context.mounted) {
      if (ok) {
        CustomSnackBar.show(context, message: isReplace ? "¡Negocio reemplazado! Reiniciando..." : "Negocio importado como nuevo perfil. ¡Cierra sesión y entra al nuevo!", isError: false);
        if (isReplace) {
          await auth.logout();
          await auth.checkInitialState();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()), (route) => false);
        } else {
          await auth.checkInitialState();
        }
      } else {
        CustomSnackBar.show(context, message: "Error al importar negocio. Revisa el archivo.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.purple.withValues(alpha: 0.2)), boxShadow: [if (!widget.isDark) BoxShadow(color: Colors.purple.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
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
                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.upload_file, color: Colors.purple, size: 22),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: Text("Exportar Negocio Actual (.mlb)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                  Icon(_isExportExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 24, color: Colors.grey[400])
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
                  icon: Icons.chat_bubble_outline, label: "Enviar por WhatsApp", color: Colors.green, isDark: widget.isDark,
                  onTap: () async {
                    if (auth.activeBusinessId == null) return;
                    CustomSnackBar.show(context, message: "Generando archivo .mlb...", isError: false);
                    bool ok = await BusinessBackupService.exportBusiness(auth.activeBusinessId!, auth.businessName, includeSecurityPin: _includeSecurityPin);
                    if (context.mounted) {
                      if (ok) {
                        CustomSnackBar.show(context, message: "Menú de compartir abierto.", isError: false);
                      } else {
                        CustomSnackBar.show(context, message: "Error al exportar negocio.", isError: true);
                      }
                    }
                  },
                ),
                _Divider(isDark: widget.isDark),
                _ActionSubButton(
                  icon: Icons.folder_open_rounded, label: "Guardar en Descargas", color: Colors.orange, isDark: widget.isDark,
                  onTap: () async {
                    if (auth.activeBusinessId == null) return;
                    CustomSnackBar.show(context, message: "Guardando en descargas...", isError: false);
                    bool ok = await BusinessBackupService.exportBusinessToFile(auth.activeBusinessId!, auth.businessName, includeSecurityPin: _includeSecurityPin);
                    if (context.mounted) {
                      if (ok) {
                        CustomSnackBar.show(context, message: "¡Guardado en Descargas!", isError: false);
                      } else {
                        CustomSnackBar.show(context, message: "Error al exportar negocio.", isError: true);
                      }
                    }
                  },
                ),
                _Divider(isDark: widget.isDark),
                _ActionSubButton(
                  icon: Icons.folder_special_rounded, label: "Elegir carpeta personalizada", color: Colors.blueAccent, isDark: widget.isDark,
                  onTap: () async {
                    if (auth.activeBusinessId == null) return;
                    String? customPath = await FilePicker.platform.getDirectoryPath();
                    if (customPath == null) return;
                    if (!context.mounted) return;
                    CustomSnackBar.show(context, message: "Guardando en ruta elegida...", isError: false);
                    bool ok = await BusinessBackupService.exportBusinessToFile(auth.activeBusinessId!, auth.businessName, includeSecurityPin: _includeSecurityPin, targetDirectory: customPath);
                    if (context.mounted) {
                      if (ok) {
                        CustomSnackBar.show(context, message: "¡Guardado en la carpeta elegida!", isError: false);
                      } else {
                        CustomSnackBar.show(context, message: "Error al exportar negocio.", isError: true);
                      }
                    }
                  },
                ),
              ],
            ),
            crossFadeState: _isExportExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          _Divider(isDark: widget.isDark),
          SwitchListTile(
            title: Text("Incluir Clave de Seguridad", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: auth.hasPinCache ? null : Colors.grey)),
            subtitle: Text(auth.hasPinCache ? "El backup requerirá esta clave al importarse." : "Este perfil no tiene clave configurada.", style: const TextStyle(fontSize: 12)),
            value: auth.hasPinCache ? _includeSecurityPin : false,
            onChanged: auth.hasPinCache ? (val) {
              setState(() {
                _includeSecurityPin = val;
              });
            } : null,
            activeTrackColor: Colors.purple.withValues(alpha: 0.5),
            activeThumbColor: Colors.purple,
          ),
          _Divider(isDark: widget.isDark),
          _ActionButton(
            icon: Icons.post_add, label: "Importar como Nuevo Negocio", color: Colors.teal, isDark: widget.isDark,
            onTap: () {
              if (auth.activeUserId == null) return;
              _handleImport(context, auth, isReplace: false);
            },
          ),
          _Divider(isDark: widget.isDark),
          _ActionButton(
            icon: Icons.system_update_alt, label: "Reemplazar Negocio Actual", color: Colors.redAccent, isDark: widget.isDark, isBottom: true,
            onTap: () {
              if (auth.activeUserId == null || auth.activeBusinessId == null) return;
              _handleImport(context, auth, isReplace: true);
            },
          ),
        ],
      ),
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  void _confirmRestore(BuildContext context, BackupProvider backupProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text("Zona de Peligro", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))),
          ],
        ),
        content: Text(
          "Estás a punto de reemplazar TODA la información actual de tu negocio (inventario, clientes, ventas).\n\n"
          "Si continúas, la aplicación se reiniciará con los datos del archivo que elijas. Esta acción NO se puede deshacer.",
          style: TextStyle(fontSize: 15, height: 1.4, color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = await backupProvider.restoreDatabase();
              
              if (context.mounted) {
                if (success) {
                  CustomSnackBar.show(context, message: "¡Datos restaurados con éxito! Reiniciando...", isError: false);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  await auth.logout();
                  await auth.checkInitialState();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()), (route) => false);
                } else if (backupProvider.errorMessage.isNotEmpty) {
                  CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                }
              }
            },
            child: const Text("Sí, Restaurar Datos", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required String subtitle, required Color color, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5))),
          ],
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backupProvider = Provider.of<BackupProvider>(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Respaldos y Seguridad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // 1. BACKUP INTELIGENTE POR NEGOCIO
              _buildSectionHeader(
                icon: Icons.inventory_2_rounded,
                title: "Backup por Negocio",
                subtitle: "Archivo .mlb — Solo incluye los datos del negocio: ${Provider.of<AuthProvider>(context).businessName}.",
                color: Colors.purpleAccent,
                isDark: isDark
              ),
              const SizedBox(height: 16),
              SmartBackupSection(isDark: isDark, cardColor: cardColor),
              const SizedBox(height: 40),

              // 2. EXPORTACIÓN GLOBAL (.DB)
              _buildSectionHeader(
                icon: Icons.storage_rounded,
                title: "Exportación Global",
                subtitle: "Guarda una copia exacta de tu inventario y ventas de TODOS tus negocios.",
                color: Colors.blue,
                isDark: isDark
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.2)), boxShadow: [if (!isDark) BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    _ActionButton(
                      icon: Icons.chat_bubble_outline, label: "Enviar por WhatsApp", color: Colors.green, isDark: isDark, isTop: true,
                      onTap: () async {
                        bool ok = await backupProvider.backupToWhatsApp();
                        if (context.mounted && !ok && backupProvider.errorMessage.isNotEmpty) {
                          CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                        }
                      },
                    ),

                    _ActionButton(
                      icon: Icons.folder_open_rounded, label: "Guardar en Descargas", color: Colors.orange, isDark: isDark, isBottom: false,
                      onTap: () async {
                        bool ok = await backupProvider.backupToDownloads();
                        if (context.mounted) {
                          if (ok) {
                            CustomSnackBar.show(context, message: "¡Guardado en la carpeta de Descargas!", isError: false);
                          } else {
                            CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                          }
                        }
                      },
                    ),
                    _Divider(isDark: isDark),
                    _ActionSubButton(
                      icon: Icons.folder_special_rounded, label: "Elegir carpeta personalizada", color: Colors.blueAccent, isDark: isDark,
                      onTap: () async {
                        String? customPath = await FilePicker.platform.getDirectoryPath();
                        if (customPath == null) return;
                        if (!context.mounted) return;
                        CustomSnackBar.show(context, message: "Guardando en ruta elegida...", isError: false);
                        try {
                          bool ok = await BackupManager.exportToDirectory(customPath);
                          if (context.mounted) {
                            if (ok) {
                              CustomSnackBar.show(context, message: "¡Guardado en la carpeta elegida!", isError: false);
                            } else {
                              CustomSnackBar.show(context, message: "Error al exportar la base de datos.", isError: true);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackBar.show(context, message: e.toString(), isError: true);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 3. PROTECCIÓN AUTOMÁTICA
              _buildSectionHeader(
                icon: Icons.security_rounded,
                title: "Protección Automática",
                subtitle: "La aplicación creará un respaldo por ti de forma silenciosa e invisible.",
                color: Colors.indigoAccent,
                isDark: isDark
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.indigoAccent.withValues(alpha: 0.3)), boxShadow: [if (!isDark) BoxShadow(color: Colors.indigoAccent.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Activar Backups Automáticos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text("Se ejecutarán en segundo plano.", style: TextStyle(fontSize: 13)),
                      value: backupProvider.isAutoBackupEnabled,
                      activeTrackColor: Colors.indigoAccent.withValues(alpha: 0.5),
                      activeThumbColor: Colors.indigoAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onChanged: (val) => backupProvider.toggleAutoBackup(val),
                    ),
                    
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: !backupProvider.isAutoBackupEnabled 
                        ? const SizedBox.shrink() 
                        : _AutoBackupSettingsView(provider: backupProvider, isDark: isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 4. SEGURIDAD Y BLOQUEO
              _buildSectionHeader(
                icon: Icons.lock_outline_rounded,
                title: "Seguridad y Bloqueo",
                subtitle: "Protege tu app de accesos no autorizados.",
                color: Colors.teal,
                isDark: isDark
              ),
              const SizedBox(height: 16),
              PinDelayConfigWidget(isDark: isDark),
              const SizedBox(height: 50),

              // 5. ZONA DE PELIGRO
              _buildSectionHeader(
                icon: Icons.warning_rounded,
                title: "Zona de Peligro",
                subtitle: "Usa esta opción solo si cambiaste de celular o si necesitas recuperar una versión anterior global.",
                color: Colors.redAccent,
                isDark: isDark
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore_page_outlined, color: Colors.redAccent, size: 24),
                label: const Text("Cargar Backup Completo (.mlbg o .db)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _confirmRestore(context, backupProvider),
              ),
              const SizedBox(height: 50),
            ],
          ),

          if (backupProvider.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.blue),
                      const SizedBox(height: 20),
                      Text(backupProvider.statusMessage.isNotEmpty ? backupProvider.statusMessage : "Procesando...", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool isTop;
  final bool isBottom;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.isDark, this.isTop = false, this.isBottom = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(top: Radius.circular(isTop ? 20 : 0), bottom: Radius.circular(isBottom ? 20 : 0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400])
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 65, color: isDark ? Colors.white10 : Colors.grey[200]);
  }
}

class _ActionSubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionSubButton({required this.icon, required this.label, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400])
          ],
        ),
      ),
    );
  }
}
class _AutoBackupSettingsView extends StatefulWidget {
  final BackupProvider provider;
  final bool isDark;
  const _AutoBackupSettingsView({required this.provider, required this.isDark});

  @override
  State<_AutoBackupSettingsView> createState() => _AutoBackupSettingsViewState();
}

class _AutoBackupSettingsViewState extends State<_AutoBackupSettingsView> {
  int? _initialFrequency;

  @override
  void initState() {
    super.initState();
    _initialFrequency = widget.provider.autoBackupIntervalDays;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final isDark = widget.isDark;
    final showWarning = _initialFrequency != null && provider.autoBackupIntervalDays != _initialFrequency;

    return Column(
      children: [
        _Divider(isDark: isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Tipo", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<String>(
                  value: provider.autoBackupType,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.indigoAccent),
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'global', child: Text("Global (.mlbg)")),
                    DropdownMenuItem(value: 'perfil', child: Text("Solo este negocio (.mlb)")),
                    DropdownMenuItem(value: 'ambos', child: Text("Ambos (.mlbg y .mlb)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      provider.setAutoBackupType(val, negocioId: auth.activeBusinessId, negocioNombre: auth.businessName);
                    }
                  },
                ),
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Frecuencia", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<int>(
                  value: provider.autoBackupIntervalDays,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.indigoAccent),
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Cada 1 Día")),
                    DropdownMenuItem(value: 7, child: Text("Cada 7 Días")),
                    DropdownMenuItem(value: 15, child: Text("Cada 15 Días")),
                    DropdownMenuItem(value: 30, child: Text("Cada 30 Días")),
                  ],
                  onChanged: (val) {
                    if (val != null) provider.setAutoBackupInterval(val);
                  },
                ),
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Destino", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<String>(
                  value: provider.autoBackupLocation,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.indigoAccent),
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'Local', child: Text("Descargas")),
                    DropdownMenuItem(value: 'Drive', child: Text("Guardar en Nube")),
                    DropdownMenuItem(value: 'custom', child: Text("Carpeta personalizada...")),
                  ],
                  onChanged: (val) async {
                    if (val == 'custom') {
                      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectory != null) {
                        provider.setAutoBackupLocation(val!, customPath: selectedDirectory);
                      }
                    } else if (val != null) {
                      provider.setAutoBackupLocation(val);
                    }
                  },
                ),
              )
            ],
          ),
        ),
        if (provider.autoBackupLocation == 'custom' && provider.autoBackupCustomPath != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.folder_special, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(provider.autoBackupCustomPath!, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        if (showWarning)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Frecuencia actualizada. Para que el nuevo tiempo surta efecto, desactiva y vuelve a activar la Protección Automática.",
                    style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[800], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        AutoBackupTimerWidget(provider: provider, isDark: isDark),
      ],
    );
  }
}

