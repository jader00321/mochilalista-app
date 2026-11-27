part of '../dashboard_header.dart';

extension _DashboardHeaderProfileBarPart on _DashboardHeaderState {
  Widget _buildHeaderTopRow({
    required BuildContext context,
    required AuthProvider auth,
    required bool isGuest,
    required int unreadCount,
    required String? rawLogoUrl,
    required bool hasValidLogo,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildGreetingAndUserColumn(
                      userName: auth.userName,
                      isGuest: isGuest,
                    ),
                  ),
                  const SizedBox(width: 2),
                  _buildHeaderActionButtons(
                    context: context,
                    isGuest: isGuest,
                    unreadCount: unreadCount,
                  ),
                ],
              ),
              if (!isGuest) _buildBusinessSubtitleRow(auth),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildBusinessAvatar(
          auth: auth,
          rawLogoUrl: rawLogoUrl,
          hasValidLogo: hasValidLogo,
        ),
      ],
    );
  }

  Widget _buildGreetingAndUserColumn({
    required String userName,
    required bool isGuest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: MarqueeText(
                text: userName,
                enableGradientFade: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
                pauseDuration: const Duration(seconds: 3),
                scrollSpeed: 32.0,
              ),
            ),
            if (isGuest) ...[
              const SizedBox(width: 4),
              Flexible(
                flex: 2,
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Text(
                      "INVITADO",
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderActionButtons({
    required BuildContext context,
    required bool isGuest,
    required int unreadCount,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _loadData(forceRefresh: true, silentOnly: true),
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 22,
          ),
          tooltip: "Actualizar datos",
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 2),
        IconButton(
          onPressed: () {
            if (isGuest) {
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              "$unreadCount",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orangeAccent,
            offset: const Offset(4, -4),
            child: AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, child) {
                final double scale = unreadCount > 0
                    ? 1.0 + (_bgAnimController.value * 0.15)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Colors.white.withValues(alpha: isGuest ? 0.3 : 1.0),
                    size: 23,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 2),
        InfoTooltipButton(
          iconColor: Colors.white,
          iconSize: 21,
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          title: 'Pantalla de Inicio',
          description:
              'El centro neurálgico de tu negocio. Desde aquí supervisas tus ventas del día, buscas productos en OmniSearch y accedes a las funciones principales.',
          tips: const [
            InfoTip(
              icon: Icons.search_rounded,
              text:
                  'Usa la barra OmniSearch para buscar productos, precios y clientes al instante.',
            ),
            InfoTip(
              icon: Icons.qr_code_scanner_rounded,
              text:
                  'Toca el ícono de código de barras para escanear con la cámara.',
            ),
            InfoTip(
              icon: Icons.bolt_rounded,
              text:
                  'Los accesos rápidos te llevan directo a Venta Rápida, Inventario y Cotizaciones.',
            ),
          ],
          onStartInteractiveTour: () => InteractiveTourService.startManualTour(
            context,
            HomeScreenTour.buildConfig(keys: widget.tourKeys),
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessSubtitleRow(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, color: Colors.blue[200], size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: MarqueeText(
              text: auth.businessName.isEmpty
                  ? "Mi Negocio"
                  : auth.businessName,
              enableGradientFade: false,
              style: TextStyle(
                color: Colors.blue[100],
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              pauseDuration: const Duration(seconds: 3),
              scrollSpeed: 28.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessAvatar({
    required AuthProvider auth,
    required String? rawLogoUrl,
    required bool hasValidLogo,
  }) {
    final String fallbackLabel = auth.businessName.isEmpty
        ? "ML"
        : auth.businessName;

    return GestureDetector(
      onTap: () => _handleAvatarTap(auth),
      child: Container(
        key: widget.tourKeys?.licenseAlertKey,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: hasValidLogo
              ? UniversalImage(
                  path: rawLogoUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  productName: fallbackLabel,
                )
              : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
