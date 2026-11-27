part of '../google_drive_backup_sheet.dart';

mixin _GoogleDriveConnectedAndBackupsMixin on _GoogleDriveBackupSheetStateBase {
  @override
  List<Widget> _buildDriveConnectedSection({
    required GoogleDriveBackupProvider prov,
    required GoogleDriveUser user,
    required DriveBackupConfig config,
    required List<GoogleDriveBackupMetadata> backups,
    required bool isBackingUp,
    required bool isRestoring,
    required bool isDark,
    required Color cardColor,
  }) {
    return [
      Container(
        key: widget.statusCardKey,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white12
                : Colors.blue.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Aviso discreto de error de sincronización no destructivo
            if (prov.lastError != null && prov.isConnected) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "No se pudieron sincronizar las copias más recientes. Mostrando copia guardada.",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => prov.syncBackupsSilently(force: true),
                      child: const Text(
                        "Reintentar",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tarjeta de Usuario Conectado (3 Filas Limpias y Responsivas)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Avatar + Nombre de Usuario + Botón Desvincular a la derecha
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.blue,
                              size: 20,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user.displayName ?? "Cuenta Conectada",
                        maxLines: 1,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 108),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: isBackingUp || isRestoring
                            ? null
                            : () => _handleSignOut(prov),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Desvincular",
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Fila 2: Correo electrónico al 100% del ancho, sin truncamiento
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.blueGrey[800],
                  ),
                  maxLines: 2,
                  softWrap: true,
                ),
                const SizedBox(height: 6),
                // Fila 3: Semáforo visual de salud de respaldo (Óptimo / Atención / Sin Copias)
                Builder(
                  builder: (context) {
                    final health = GoogleDriveBackupProvider.computeHealthInfo(
                      backups: backups,
                      isDark: isDark,
                    );
                    return Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: health.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(health.icon, size: 13, color: health.color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  health.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: health.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (config.lastBackupAt != null)
                          Text(
                            "Última copia: ${_formatDateTime(config.lastBackupAt!)}",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Botón Respaldar Ahora
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: isBackingUp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      isBackingUp ? "Subiendo..." : "Respaldar Ahora",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isBackingUp || isRestoring
                        ? null
                        : () => _handleBackupNow(prov),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Modo de Operación: Automático vs Manual
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Respaldo Automático en Google Drive",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                config.isEnabled
                    ? "Sincronización en segundo plano con tu cuenta de Google."
                    : "Modo manual (se respaldará únicamente al presionar 'Respaldar Ahora').",
                style: const TextStyle(fontSize: 11),
              ),
              value: config.isEnabled,
              activeThumbColor: Colors.blue,
              activeTrackColor: Colors.blue.withValues(alpha: 0.4),
              onChanged: (val) async {
                await prov.updateConfig(config.copyWith(isEnabled: val));
              },
            ),
            const SizedBox(height: 8),

            // Selector de Frecuencia (visible solo si automático está activado)
            if (config.isEnabled) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Frecuencia de Respaldo Automático",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A3A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BackupFrequency>(
                        value: config.frequency == BackupFrequency.manual
                            ? BackupFrequency.daily
                            : config.frequency,
                        isExpanded: true,
                        dropdownColor: cardColor,
                        items:
                            [
                              BackupFrequency.daily,
                              BackupFrequency.weekly,
                              BackupFrequency.monthly,
                            ].map((f) {
                              return DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f.label,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                        onChanged: (f) {
                          if (f != null) _updateFrequency(prov, f);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Interruptor Solo con Wi-Fi
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Solo con Wi-Fi",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                "Ahorra datos móviles al respaldar automáticamente",
                style: TextStyle(fontSize: 11),
              ),
              value: config.wifiOnly,
              activeThumbColor: Colors.blue,
              activeTrackColor: Colors.blue.withValues(alpha: 0.4),
              onChanged: (val) => _toggleWifiOnly(prov, val),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  @override
  List<Widget> _buildDriveBackupsListSection({
    required GoogleDriveBackupProvider prov,
    required List<GoogleDriveBackupMetadata> backups,
    required bool isBackingUp,
    required bool isRestoring,
    required bool isDark,
    required Color cardColor,
  }) {
    return [
      // Lista Cronológica de hasta 5 Copias Fechadas
      Row(
        children: [
          const Icon(Icons.history_rounded, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Copias en Google Drive (Últimas 5)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "${backups.length}/5 copias",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          if (prov.isSyncingSilently)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: "Actualizar lista de copias",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              onPressed: isRestoring || isBackingUp
                  ? null
                  : () => prov.syncBackupsSilently(force: true),
            ),
        ],
      ),
      const SizedBox(height: 10),

      if (backups.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            "No hay copias de seguridad en Google Drive aún.\nPresiona 'Respaldar Ahora' para generar la primera.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        )
      else
        ...backups.asMap().entries.map((entry) {
          final index = entry.key;
          final backup = entry.value;
          final isLatest = (index == 0);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLatest
                    ? Colors.green.withValues(alpha: 0.4)
                    : (isDark
                          ? Colors.white10
                          : Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Icono y Fecha Completa al 100% de ancho disponible (Cero truncamiento)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isLatest
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        size: 16,
                        color: isLatest ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        backup.formattedDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Fila 2: Tamaño, Badge 'Más reciente' y Botón 'Restaurar'
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            backup.formattedSize,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          if (isLatest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "Más reciente",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.restore_rounded, size: 14),
                      label: const Text(
                        "Restaurar",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: isRestoring
                          ? null
                          : () => _confirmAndRestore(prov, backup),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
    ];
  }
}
