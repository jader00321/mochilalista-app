part of '../ai_settings_screen.dart';

mixin _AiSettingsVaultAndGuideMixin on _AiSettingsScreenBase {
  Widget _buildVaultCard({required bool isDark, required bool isByokMode}) {
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
                  Icons.lock_outline_rounded,
                  color: Colors.purple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        "Bóveda Segura Multi-Clave",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddKeyDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          "Agregar Clave",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Guarda tus API Keys gratuitas de Google AI Studio. Tus claves se almacenan cifradas en hardware mediante almacenamiento seguro.",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 14),

            if (_isLoadingVault)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_keys.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF14141C)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.vpn_key_off_outlined,
                      size: 36,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "No tienes claves registradas en la bóveda",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Presiona 'Agregar Clave' para registrar tu primera clave propia de Google AI Studio.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _keys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final keyModel = _keys[index];
                  final isActive = keyModel.id == _activeKeyId;
                  final isTestingThis = _testingKeyId == keyModel.id;

                  return _buildKeyVaultCardItem(
                    keyModel: keyModel,
                    isActive: isActive,
                    isTesting: isTestingThis,
                    isDark: isDark,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyVaultCardItem({
    required AiKeyModel keyModel,
    required bool isActive,
    required bool isTesting,
    required bool isDark,
  }) {
    final borderColor = isActive
        ? Colors.purple
        : (isDark ? Colors.white12 : Colors.black12);
    final bgColor = isActive
        ? Colors.purple.withValues(alpha: isDark ? 0.12 : 0.05)
        : (isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  keyModel.alias,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "En Uso",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Clave enmascarada (jamás expuesta en texto plano)
          Text(
            keyModel.maskedKey,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),

          // Estado de verificación
          if (keyModel.lastTestedAt != null)
            Row(
              children: [
                Icon(
                  keyModel.isWorking == true
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 13,
                  color: keyModel.isWorking == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    keyModel.isWorking == true
                        ? "Verificada (${AppDateFormatter.ddMMHHmm.format(keyModel.lastTestedAt!)})"
                        : "Error de Conexión (${AppDateFormatter.ddMMHHmm.format(keyModel.lastTestedAt!)})",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: keyModel.isWorking == true
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),

          // Barra de acciones con iconos vectoriales
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!isActive)
                OutlinedButton.icon(
                  onPressed: () => _activateKey(keyModel),
                  icon: const Icon(
                    Icons.radio_button_checked_rounded,
                    size: 14,
                  ),
                  label: const Text("Activar", style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: isTesting ? null : () => _testKey(keyModel),
                icon: isTesting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check_rounded, size: 14),
                label: const Text(
                  "Probar Clave",
                  style: TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                onPressed: () => _copyKey(keyModel),
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: "Copiar Clave",
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _showEditAliasDialog(keyModel),
                icon: const Icon(Icons.edit_rounded, size: 16),
                tooltip: "Editar Nombre",
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _confirmDeleteKey(keyModel),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Colors.red,
                ),
                tooltip: "Eliminar",
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepByStepGuideCard(bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school_outlined, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "¿Cómo obtener una API Key gratis?",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStepTile(
              "1",
              "Ingresa a aistudio.google.com con tu cuenta de Google habitual.",
              isDark,
            ),
            _buildStepTile(
              "2",
              "Haz clic en 'Get API key' y luego en 'Create API key' en un nuevo proyecto.",
              isDark,
            ),
            _buildStepTile(
              "3",
              "Copia la clave generada (inicia con AIzaSy...) y regístrala en la bóveda superior.",
              isDark,
            ),
            const SizedBox(height: 10),

            // Botón directo para abrir Google AI Studio
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _launchAiStudio,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text(
                  "Abrir Google AI Studio",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Google ofrece un nivel gratuito con miles de peticiones mensuales sin costo de tarjeta.",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.green[200] : Colors.green[900],
                        fontWeight: FontWeight.w500,
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

  Widget _buildStepTile(String stepNumber, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
