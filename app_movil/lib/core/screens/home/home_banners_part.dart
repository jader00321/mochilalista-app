part of '../home_screen.dart';

extension _HomeBannersPart on _HomeDashboardViewState {
  Widget _buildGuestBanner(BuildContext context, bool isDark) {
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    return Material(
      elevation: isDark ? 0 : 10,
      shadowColor: isDark
          ? Colors.transparent
          : Colors.orange.withValues(alpha: 0.3),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: isDark
            ? BorderSide(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1.5,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ScanScreen(mode: ScanMode.quotation),
          ),
        ),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "MODO EXPLORACIÓN",
                        style: TextStyle(
                          color: isDark
                              ? Colors.orange[300]
                              : Colors.orange[800],
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Conoce la IA",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ingresa aquí para ver cómo funciona el escáner de listas escolares. Regístrate para usarlo en tu negocio.",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.orange[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: isDark ? Colors.orange[300] : Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banners proactivos de licencia (POR_VENCER y BLOQUEO_SUAVE).
  Widget _buildLicenseBanner(BuildContext context, bool isDark) {
    final licenseProv = Provider.of<LicenseProvider?>(context);
    if (licenseProv == null || licenseProv.license == null) {
      return const SizedBox.shrink();
    }

    if (licenseProv.isSoftLock) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1C14) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Modo Lectura / Cobranza Activo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isDark ? Colors.orange[200] : Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Periodo culminado. Renueva tu suscripción para registrar nuevas operaciones.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LicenseStatusAndActivationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Renovar",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (licenseProv.isExpiringSoon) {
      final days = licenseProv.daysRemaining;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242014) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Suscripción por Vencer ($days ${days == 1 ? 'día' : 'días'})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                    ),
                  ),
                  Text(
                    "Renueva a tiempo para mantener todas tus funciones activas.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LicenseStatusAndActivationScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber[800],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Renovar",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Recordatorio amigable de PIN de seguridad con snooze de 7 días.
  Widget _buildSecurityPinBanner(
    BuildContext context,
    bool isDark,
    AuthProvider auth,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Protege tu negocio con un PIN",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.blue[200] : Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Evita accesos no deseados configurando un PIN de 4 dígitos.",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 74),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Activar",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            tooltip: "Recordar en 7 días",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
            ),
            onPressed: () async {
              await auth.snoozePinReminder(days: 7);
              if (context.mounted) {
                AppFeedbackHelper.showSuccess(
                  context,
                  "Recordatorio pospuesto por 7 días. Puedes activarlo cuando gustes desde tu Perfil.",
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
