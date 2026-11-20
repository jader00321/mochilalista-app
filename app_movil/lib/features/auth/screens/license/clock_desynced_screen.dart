import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

/// Pantalla informativa ante inconsistencia temporal detectada (Anti-Manipulación de Reloj)
class ClockDesyncedScreen extends StatefulWidget {
  const ClockDesyncedScreen({super.key});

  @override
  State<ClockDesyncedScreen> createState() => _ClockDesyncedScreenState();
}

class _ClockDesyncedScreenState extends State<ClockDesyncedScreen> {
  bool _isExporting = false;

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);
    try {
      final success = await BackupManager.exportToDownloads();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: success
              ? "Copia exportada exitosamente en Descargas"
              : "No se pudo completar la exportación",
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al exportar: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final clockResult = licenseProv?.clockResult;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final phoneTimeStr = clockResult != null
        ? dateFormat.format(clockResult.currentPhoneTime)
        : dateFormat.format(DateTime.now());
    final lastTimeStr = clockResult != null
        ? dateFormat.format(clockResult.lastRecordedActivityTime)
        : "Registro previo";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ícono de reloj desfasado
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 2),
                      ),
                      child: const Icon(Icons.more_time_rounded, size: 56, color: Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  Text(
                    "Fecha u Hora Desajustada",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Explicación amigable
                  Text(
                    "La fecha y hora de tu dispositivo parecen estar desajustadas con respecto a la última actividad registrada en tu base de datos.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cuadro comparativo de fechas
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Column(
                      children: [
                        _buildRowInfo("Hora en tu teléfono:", phoneTimeStr, isDark),
                        const Divider(height: 14),
                        _buildRowInfo("Última actividad en BD:", lastTimeStr, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pasos de solución
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.help_outline_rounded, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "¿Cómo resolverlo?",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.lightBlue[200] : Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "1. Ve a los Ajustes de Android > Sistema > Fecha y Hora.\n"
                          "2. Activa 'Usar la hora de la red' (Hora automática).\n"
                          "3. Regresa a MochilaLista y presiona 'Reintentar Verificación'.",
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón de reintento
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (licenseProv != null) {
                        await licenseProv.checkLicense();
                        if (context.mounted && !licenseProv.isClockDesynced) {
                          CustomSnackBar.show(context, message: "Reloj sincronizado con éxito.", isError: false);
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Reintentar Verificación",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botón de Respaldo Defensivo
                  OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportBackup,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Exportar Copia de Seguridad (.mlbg)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowInfo(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
