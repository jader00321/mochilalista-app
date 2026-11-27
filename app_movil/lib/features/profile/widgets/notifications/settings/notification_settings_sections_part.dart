part of '../notification_settings_modal.dart';

extension _NotificationSettingsSectionsPart on _NotificationSettingsModalState {
  List<Widget> _buildBodySections({
    required BuildContext context,
    required NotificationProvider prov,
    required bool isDark,
    required Color bgCardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return [
      Container(key: _bandejasKey),
      _buildSectionHeader("BANDEJAS DE RESGUARDO", isDark),
      _buildContainer(
        [
          _buildInboxAccessTile(
            title: "Notificaciones Archivadas",
            subtitle: "Alertas retiradas temporalmente de la lista activa",
            icon: Icons.inventory_2_outlined,
            iconBg: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
            iconColor: isDark ? Colors.amber[300]! : Colors.orange[800]!,
            count: prov.archivedCount,
            subtitleColor: subtitleColor,
            isDark: isDark,
            onTap: () =>
                ArchivedNotificationsModal.show(context, isDark: isDark),
          ),
          _buildCardDivider(isDark, indent: 64),
          _buildInboxAccessTile(
            title: "Ítems No Deseados / Silenciados",
            subtitle: "Cuotas, clientes o productos con alertas bloqueadas",
            icon: Icons.notifications_off_outlined,
            iconBg: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
            iconColor: isDark ? Colors.red[300]! : Colors.red[700]!,
            count: prov.silencedCount,
            subtitleColor: subtitleColor,
            isDark: isDark,
            onTap: () =>
                SilencedNotificationsModal.show(context, isDark: isDark),
          ),
        ],
        bgCardColor,
        isDark,
      ),
      const SizedBox(height: 24),

      Container(key: _cobranzasKey),
      _buildSectionHeader("ALERTAS DE COBRANZAS", isDark),
      _buildContainer(
        [
          _buildPremiumSwitchCard(
            title: "Cuotas Vencidas (Mora)",
            subtitle: "Avisos críticos de cuotas con fecha límite superada",
            value: _localPrefs.notifCuotasVencidas,
            onChanged: (v) =>
                _updatePreference(_localPrefs.copyWith(notifCuotasVencidas: v)),
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Avisos Preventivos de Vencimiento",
            subtitle: "Recordatorios anticipados de cuotas próximas a vencer",
            value: _localPrefs.notifCuotasPreventivas,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(notifCuotasPreventivas: v),
            ),
            icon: Icons.schedule_rounded,
            iconColor: Colors.orange,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Confirmación de Pagos y Abonos",
            subtitle: "Historial de cuotas canceladas con éxito",
            value: _localPrefs.notifConfirmacionPagos,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(notifConfirmacionPagos: v),
            ),
            icon: Icons.check_circle_outline_rounded,
            iconColor: Colors.green,
            isDark: isDark,
          ),
        ],
        bgCardColor,
        isDark,
      ),
      const SizedBox(height: 24),

      Container(key: _inventarioKey),
      _buildSectionHeader("ALERTAS DE INVENTARIO", isDark),
      _buildContainer(
        [
          _buildPremiumSwitchCard(
            title: "Productos Agotados (0 und.)",
            subtitle:
                "Aviso crítico inmediato al agotarse existencias por completo",
            value: _localPrefs.notifStockAgotado,
            onChanged: (v) =>
                _updatePreference(_localPrefs.copyWith(notifStockAgotado: v)),
            icon: Icons.remove_shopping_cart_rounded,
            iconColor: Colors.red,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Stock Bajo Preventivo",
            subtitle:
                "Alertas al alcanzar o caer por debajo del umbral mínimo configurado",
            value: _localPrefs.notifStockBajo,
            onChanged: (v) =>
                _updatePreference(_localPrefs.copyWith(notifStockBajo: v)),
            icon: Icons.inventory_2_outlined,
            iconColor: Colors.amber,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Stock Compartido Bajo",
            subtitle: "Vigilancia de presentaciones con stock común",
            value: _localPrefs.notifStockCompartido,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(notifStockCompartido: v),
            ),
            icon: Icons.alt_route_rounded,
            iconColor: Colors.purple,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Anti-Spam en Ventas Sucesivas",
            subtitle:
                "Actualiza el stock en la alerta existente sin duplicar ni reabrir alertas archivadas",
            value: _localPrefs.antiSpamStockSilencioso,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(antiSpamStockSilencioso: v),
            ),
            icon: Icons.mark_email_read_outlined,
            iconColor: Colors.blue,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildGraceRuleBlock(isDark, textColor, subtitleColor),
        ],
        bgCardColor,
        isDark,
      ),
      const SizedBox(height: 24),

      Container(key: _cotizacionesKey),
      _buildSectionHeader("VENTAS, COTIZACIONES Y PREMIOS", isDark),
      _buildContainer(
        [
          _buildPremiumSwitchCard(
            title: "Cotizaciones por Vencer / Vencidas",
            subtitle: "Seguimiento para cerrar acuerdos pendientes",
            value: _localPrefs.notifCotizacionesVencidas,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(notifCotizacionesVencidas: v),
            ),
            icon: Icons.receipt_long_rounded,
            iconColor: Colors.indigo,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Metas y Fidelización",
            subtitle: "Avisos cuando un cliente alcanza puntos para un premio",
            value: _localPrefs.notifMetasFidelizacion,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(notifMetasFidelizacion: v),
            ),
            icon: Icons.military_tech_rounded,
            iconColor: Colors.amber,
            isDark: isDark,
          ),
        ],
        bgCardColor,
        isDark,
      ),
      const SizedBox(height: 24),

      Container(key: _tiemposKey),
      _buildSectionHeader("TIEMPOS Y CONDICIONES", isDark),
      _buildThresholdsSection(isDark, bgCardColor, textColor, subtitleColor),
      const SizedBox(height: 24),

      Container(key: _interaccionKey),
      _buildSectionHeader("INTERACCIÓN Y NAVEGACIÓN", isDark),
      _buildContainer(
        [
          _buildPremiumSwitchCard(
            title: "Smart Grouping por Cliente",
            subtitle:
                "Agrupa clientes con 2 o más cuotas en mora en tarjeta maestra",
            value: _localPrefs.activarSmartGrouping,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(activarSmartGrouping: v),
            ),
            icon: Icons.groups_rounded,
            iconColor: Colors.blue,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildPremiumSwitchCard(
            title: "Dashboard de Pulso Ejecutivo",
            subtitle: "Muestra KPIs rápidos de mora e inventario en Pendientes",
            value: _localPrefs.mostrarPulseDashboard,
            onChanged: (v) => _updatePreference(
              _localPrefs.copyWith(mostrarPulseDashboard: v),
            ),
            icon: Icons.analytics_outlined,
            iconColor: Colors.teal,
            isDark: isDark,
          ),
          _buildCardDivider(isDark),
          _buildSwipeModeBlock(isDark, textColor, subtitleColor),
        ],
        bgCardColor,
        isDark,
      ),
    ];
  }

  Widget _buildGraceRuleBlock(
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.teal[400],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Regla de Gracia para Nuevos Productos",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Evita alertar stock bajo al registrar un producto si aún no tiene ventas",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subtitleColor,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildGraceChip(0, "Solo tras 1ra venta", isDark),
              _buildGraceChip(3, "3 días de gracia", isDark),
              _buildGraceChip(7, "7 días de gracia", isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdsSection(
    bool isDark,
    Color bgCardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Anticipación de Avisos Preventivos",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "¿Con cuántos días de anticipación alertar cuotas por vencer?",
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildAnticipationChip(0, "Mismo día", isDark),
              _buildAnticipationChip(1, "1 día antes", isDark),
              _buildAnticipationChip(2, "2 días antes", isDark),
              _buildAnticipationChip(3, "3 días antes", isDark),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "Prioridad Mínima Visible",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Filtra la exigencia de las alertas mostradas en lista activa",
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPriorityChip("todas", "Mostrar todas", isDark),
              _buildPriorityChip(
                "preventivas_criticas",
                "Preventivas y Críticas",
                isDark,
              ),
              _buildPriorityChip("solo_criticas", "Solo Críticas", isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeModeBlock(
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Comportamiento al Deslizar (Swipe)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Elige la función al arrastrar horizontalmente sobre la pantalla",
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSwipeModeBtn(
                  id: 'tab_navigation',
                  label: "Navegar pestañas",
                  icon: Icons.swipe_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSwipeModeBtn(
                  id: 'card_actions',
                  label: "Cajón de tarjeta",
                  icon: Icons.view_headline_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
