import 'package:flutter/material.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

/// Modal amigable de aviso de Modo Lectura / Renovación cuando la suscripción está en BLOQUEO_SUAVE
class SoftLockRenewalModal extends StatelessWidget {
  const SoftLockRenewalModal({super.key});

  /// Muestra el modal si la app está en modo lectura (BLOQUEO_SUAVE)
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SoftLockRenewalModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock_rounded, size: 40, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Modo Lectura / Cobranza Activo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tu periodo de suscripción ha culminado. Para registrar nuevas operaciones, ventas o cotizaciones, renueva tu suscripción.\n\nTus clientes, inventario y registros comerciales están 100% seguros.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LicenseStatusAndActivationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.stars_rounded, size: 18),
                label: const Text(
                  "Renovar Ahora",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  "Continuar en Modo Lectura",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
