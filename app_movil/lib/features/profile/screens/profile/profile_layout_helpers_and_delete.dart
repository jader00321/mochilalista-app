part of '../profile_screen.dart';

mixin _ProfileLayoutHelpersAndDeleteMixin on _ProfileStateBase {
  @override
  Widget _buildSectionHeader(
    String title,
    Color? color, {
    String? actionLabel,
    IconData? iconData,
    VoidCallback? onAction,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isNarrow ? 14.5 : 15.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconData != null) ...[
                        Icon(iconData, size: 15, color: Colors.blue),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget _buildSettingsContainer(Color color, List<Widget> children) =>
      Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      );

  @override
  Widget _buildDivider(bool isDark) => Divider(
    height: 1,
    indent: 65,
    endIndent: 20,
    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
  );

  @override
  void _showDeleteBusinessModal(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) async {
    final bool? deleted = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteBusinessModal(
        userId: auth.activeUserId!,
        hasPin: auth.hasPinCache,
      ),
    );

    if (deleted == true) {
      if (!context.mounted) return;
      _clearVolatileMemory(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }


  @override
  Future<void> _openDirectGpsPicker(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final isGpsReady = await HardwareValidator.checkGPS(context);
    if (!isGpsReady) return;
    if (!context.mounted) return;

    final biz = auth.currentBusiness;
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: biz?.latitud,
          initialLng: biz?.longitud,
        ),
      ),
    );

    if (result != null && biz != null) {
      bool success = await auth.updateBusinessProfile(
        biz.commercialName,
        biz.ruc ?? '',
        biz.address ?? '',
        biz.paymentInfo,
        result.latitude,
        result.longitude,
        biz.printerConfig != null &&
                biz.printerConfig!.contains('"show_address":false')
            ? false
            : true,
        biz.printerConfig != null &&
                biz.printerConfig!.contains('"show_ruc":false')
            ? false
            : true,
      );
      if (!context.mounted) return;
      if (success) {
        _markProfileMutated();
        await auth.refreshActiveUser();
        if (context.mounted) {
          CustomSnackBar.show(
            context,
            message: "Ubicación GPS actualizada",
            isError: false,
          );
        }
      } else {
        if (context.mounted) {
          CustomSnackBar.show(
            context,
            message: auth.errorMessage,
            isError: true,
          );
        }
      }
    }
  }

  @override
  Future<void> _confirmResetTours(BuildContext context, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restart_alt_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Reiniciar Guías",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          "¿Deseas reiniciar las guías de aprendizaje? Volverás a ver las explicaciones interactivas paso a paso en las pantallas principales de la app.",
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Reiniciar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await InteractiveTourService.resetAllTours(userInitiated: true);
      if (!context.mounted) return;
      setState(() => _automaticToursEnabled = true);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      CustomSnackBar.show(
        context,
        message: "Guías interactivas reiniciadas. Disfruta tu recorrido.",
        isError: false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        await InteractiveTourService.maybeStartAutomaticTour(
          context,
          _buildTourConfig(),
        );
      });
    }
  }

  @override
  void _confirmLogout(BuildContext context, AuthProvider auth, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Cambiar de Negocio",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "Al cerrar este negocio, serás redirigido a la pantalla principal para seleccionar otro o crear uno nuevo. Todo tu progreso sin guardar (carritos y ventas en curso) se limpiará.",
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _clearVolatileMemory(context);
              await auth.logout();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileSelectionScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Sí, salir",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

}
