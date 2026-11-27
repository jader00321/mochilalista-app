part of '../ai_settings_screen.dart';

mixin _AiSettingsQuotaAndModeMixin on _AiSettingsScreenBase {
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
                subtitle: activeKey != null
                    ? activeKey.alias
                    : "Sin clave activa",
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
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.blue,
              ),
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
    final borderColor = isSelected
        ? activeColor
        : (isDark ? Colors.white12 : Colors.black12);

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
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : Colors.grey,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 18, color: activeColor)
                else
                  Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white : Colors.black87),
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
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.blue,
                  size: 22,
                ),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isByokMode
                              ? Colors.purple.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isByokMode
                              ? "Bolsa Congelada (BYOK)"
                              : "Bolsa Activa",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isByokMode
                                ? Colors.purple
                                : Colors.blue[800],
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
                          color: accumulatedScans <= 5
                              ? Colors.red
                              : Colors.blue[900],
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
                    isByokMode
                        ? Icons.pause_circle_outline_rounded
                        : Icons.shield_outlined,
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
}
