part of '../profile_screen.dart';

mixin _ProfileHeaderAndLegalMixin on _ProfileStateBase {
  @override
  Widget _buildLegalCopyrightCard(
    BuildContext context,
    bool isDark,
    LicenseProvider? licenseProv,
  ) {
    final planName = licenseProv?.currentPlanName ?? 'TRIAL';
    final statusName = licenseProv?.license?.estadoActual ?? 'ACTIVA';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Colors.blue),
              Text(
                "${OwnerLegalIdentity.appCommercialName} v${OwnerLegalIdentity.currentAppVersion}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$planName ($statusName)",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Desarrollado y Distribuido por ${OwnerLegalIdentity.authorFullName}",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Todos los derechos reservados © 2026. ${OwnerLegalIdentity.legalFrameworkNotice}.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () =>
                    EulaAcceptanceModal.show(context, isReadOnly: true),
                icon: const Icon(Icons.description_outlined, size: 15),
                label: const Text(
                  "Ver Contrato EULA",
                  style: TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LicenseStatusAndActivationScreen(),
                  ),
                ),
                icon: const Icon(Icons.verified_outlined, size: 15),
                label: const Text(
                  "Gestionar Licencia",
                  style: TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: () => PostUpdateWelcomeModal.show(
                  context,
                  appVersion: AppChangelogRegistry.currentVersion,
                  mode:
                      (licenseProv?.isPerpetual == true ||
                          (licenseProv?.isActive == true &&
                              licenseProv?.isTrial == false))
                      ? PostUpdateMode.activeCommercialOrPerpetual
                      : PostUpdateMode.trialOrGrace,
                  onActivatePlanPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LicenseStatusAndActivationScreen(),
                    ),
                  ),
                  barrierDismissible: true,
                  isManualPreview: true,
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 15),
                label: Text(
                  "Novedades v${OwnerLegalIdentity.currentAppVersion}",
                  style: const TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget _buildHeader(BuildContext context, AuthProvider auth, bool isDark) {
    final String? validLogoPath = _getValidLocalImagePath(
      auth.currentBusiness?.logoUrl,
    );

    final invProv = Provider.of<InventoryProvider>(context);
    final workbench = Provider.of<WorkbenchProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);

    final int productsCount = invProv.totalProductsCount;
    final int draftsCount = workbench.inProcessList.length;

    final double salesDouble = salesProv.todaySalesTotal;
    final String salesTotal = salesDouble == 0
        ? "Sin ventas"
        : AppCurrency.format(salesDouble);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D47A1), const Color(0xFF001633)]
              : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30, top: 10),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 10,
                top: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(_hasPendingHomeRefresh),
                ),
              ),
              // 🔧 TAREA 3.4: Info Tooltip en el perfil
              Positioned(
                right: 10,
                top: 0,
                child: InfoTooltipButton(
                  iconColor: Colors.white60,
                  title: 'Tu Perfil',
                  description:
                      'Desde aquí gestionas toda la información de tu cuenta y negocio. Puedes actualizar tus datos personales, configurar tu negocio, gestionar respaldos y personalizar la app.',
                  tips: const [
                    InfoTip(
                      icon: Icons.person,
                      text:
                          'Edita tu nombre, teléfono y correo electrónico en "Editar Datos Personales".',
                    ),
                    InfoTip(
                      icon: Icons.store,
                      text:
                          'Actualiza la información de tu negocio (nombre, RUC, dirección, logo) con "Editar Datos".',
                    ),
                    InfoTip(
                      icon: Icons.security,
                      text:
                          'En "Respaldos y Seguridad" puedes exportar e importar toda tu información.',
                    ),
                    InfoTip(
                      icon: Icons.camera_alt,
                      text:
                          'Toca el ícono de cámara sobre tu logo para cambiarlo.',
                    ),
                    InfoTip(
                      icon: Icons.swap_horiz_rounded,
                      text:
                          'Alterna entre negocios o cierra sesión desde "Sesión Activa".',
                    ),
                  ],
                  onStartInteractiveTour: () =>
                      InteractiveTourService.startManualTour(
                        context,
                        _buildTourConfig(),
                      ),
                ),
              ),
              KeyedSubtree(
                key: _tourKeys.businessCardKey,
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (validLogoPath != null &&
                                    !validLogoPath.startsWith('http'))
                                ? FileImage(File(validLogoPath))
                                : null,
                            child: validLogoPath == null
                                ? _buildBusinessAvatarFallback(
                                    auth.businessName,
                                  )
                                : null,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _showPhotoOptions(context, auth, validLogoPath),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          auth.userName,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (auth.currentBusiness != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            auth.businessName,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        "DUEÑO DE NEGOCIO",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildMicroKpi("Productos", "$productsCount"),
                        ),
                        Expanded(
                          child: _buildMicroKpi("Borradores", "$draftsCount"),
                        ),
                        Expanded(
                          child: _buildMicroKpi("Ventas Hoy", salesTotal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMicroKpi(String label, String value) {
    bool isEmpty = value == "Sin ventas" || value == "0";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: isEmpty
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white,
                fontSize: isEmpty ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessAvatarFallback(String name) {
    String initials = "NG";
    final cleanName = name.trim();
    if (cleanName.isNotEmpty) {
      final parts = cleanName.split(RegExp(r'\s+'));
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        initials = cleanName
            .substring(0, cleanName.length > 1 ? 2 : 1)
            .toUpperCase();
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
