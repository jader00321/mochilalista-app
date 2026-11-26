part of '../profile_screen.dart';

mixin _ProfileMenuSectionsMixin on _ProfileStateBase {
  @override
  List<Widget> _buildProfileMenuSections({
    required BuildContext context,
    required AuthProvider auth,
    required ThemeProvider themeProv,
    required bool isDark,
    required bool isGuest,
    required Color cardColor,
    required Color textColor,
  }) {
    return [
                        _buildSectionHeader("Configuración General", textColor),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _tourKeys.operationalCenterKey,
                          child: _buildSettingsContainer(cardColor, [
                          ProfileMenuItem(
                            title: "Editar Datos Personales",
                            icon: Icons.person_outline,
                            isDark: isDark,
                            onTap: () => _showEditProfile(context),
                          ),
                          _buildDivider(isDark),

                          KeyedSubtree(
                            key: _tourKeys.licenseSupportKey,
                            child: ProfileMenuItem(
                              title: "Estado y Activación de Licencia",
                              icon: Icons.verified_outlined,
                              isDark: isDark,
                              onTap: () async {
                                _markProfileMutated();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LicenseStatusAndActivationScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildDivider(isDark),

                          ProfileMenuItem(
                            title: "Cotizador Universal IA y API Key",
                            icon: Icons.auto_awesome_outlined,
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AiSettingsScreen(),
                              ),
                            ),
                          ),
                          _buildDivider(isDark),

                          KeyedSubtree(
                            key: _tourKeys.backupsKey,
                            child: ProfileMenuItem(
                              title: "Respaldos y Seguridad",
                              icon: Icons.security_rounded,
                              isDark: isDark,
                              onTap: () async {
                                _markProfileMutated();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BackupScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildDivider(isDark),

                          ProfileMenuItem(
                            title: isDark ? "Modo Noche" : "Modo Claro",
                            icon: isDark
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_outlined,
                            isDark: isDark,
                            onTap: () => themeProv.toggleTheme(!isDark),
                            trailing: Switch(
                              value: isDark,
                              activeThumbColor: Colors.blue[400],
                              onChanged: (v) => themeProv.toggleTheme(v),
                            ),
                          ),
                          _buildDivider(isDark),
                          ProfileMenuItem(
                            title: "Notificaciones",
                            icon: Icons.notifications_none,
                            isDark: isDark,
                            onTap: () async {
                              _markProfileMutated();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(isDark),
                          KeyedSubtree(
                            key: _tourKeys.printerKey,
                            child: ProfileMenuItem(
                              title: "Impresora Térmica",
                              icon: Icons.print_outlined,
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PrinterConfigScreen(),
                                ),
                              ),
                              trailing: const Icon(
                                Icons.bluetooth,
                                size: 22,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ]),
                        ),

                        const SizedBox(height: 35),
                        _buildSectionHeader(
                          "Seguridad de la Cuenta",
                          textColor,
                        ),
                        const SizedBox(height: 12),

                        // 🔧 Recordatorio amigable de PIN de seguridad con snooze de 7 días
                        if (!auth.hasPinCache &&
                            !isGuest &&
                            !auth.isPinReminderSnoozed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.amber.withValues(alpha: 0.12)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.amber.withValues(alpha: 0.35)
                                    : Colors.amber.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Protege tu Negocio con un PIN",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.amber[200]
                                              : Colors.amber[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Configura un PIN de 4 dígitos para bloquear la app y proteger tus finanzas.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () => _showChangePassword(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Activar",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                  tooltip: "Recordar en 7 días",
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  onPressed: () async {
                                    await auth.snoozePinReminder(days: 7);
                                    if (context.mounted) {
                                      CustomSnackBar.show(
                                        context,
                                        message:
                                            "Recordatorio pospuesto por 7 días. Puedes crear tu PIN en la sección inferior.",
                                        isError: false,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                        KeyedSubtree(
                          key: _tourKeys.securityPinKey,
                          child: _buildSettingsContainer(cardColor, [
                            ProfileMenuItem(
                              title: auth.hasPinCache
                                  ? "Cambiar PIN de Seguridad"
                                  : "Crear PIN de Seguridad",
                              icon: Icons.lock_outline,
                              isDark: isDark,
                              onTap: () => _showChangePassword(context),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 35),
                        _buildSectionHeader("Aprendizaje y Ayuda", textColor),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _tourKeys.toursSettingsKey,
                          child: _buildSettingsContainer(cardColor, [
                            ProfileMenuItem(
                              title: "Guías interactivas automáticas",
                              icon: Icons.explore_outlined,
                              isDark: isDark,
                              onTap: () async {
                                final next = !_automaticToursEnabled;
                                await InteractiveTourService.setAutomaticToursEnabled(
                                  next,
                                  userInitiated: true,
                                );
                                if (mounted) {
                                  setState(() => _automaticToursEnabled = next);
                                }
                              },
                              trailing: Switch(
                                value: _automaticToursEnabled,
                                activeThumbColor: Colors.blue[400],
                                onChanged: (val) async {
                                  await InteractiveTourService.setAutomaticToursEnabled(
                                    val,
                                    userInitiated: true,
                                  );
                                  if (mounted) {
                                    setState(
                                      () => _automaticToursEnabled = val,
                                    );
                                  }
                                },
                              ),
                            ),
                            _buildDivider(isDark),
                            ProfileMenuItem(
                              title: "Reiniciar guías de aprendizaje",
                              icon: Icons.restart_alt_rounded,
                              isDark: isDark,
                              onTap: () => _confirmResetTours(context, isDark),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 35),
                        _buildSectionHeader("Sesión Activa", textColor),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _tourKeys.sessionSwitchKey,
                          child: _buildSettingsContainer(cardColor, [
                            ProfileMenuItem(
                              title: "Cambiar de Negocio / Cerrar Sesión",
                              icon: Icons.swap_horiz_rounded,
                              isDark: isDark,
                              isDestructive: false,
                              onTap: () =>
                                  _confirmLogout(context, auth, isDark),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 35),
                        // 🛡️ ZONA DE PELIGRO (DANGER ZONE)
                        Container(
                          key: _tourKeys.dangerZoneKey,
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1418)
                                : const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.red.withValues(alpha: 0.25)
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: Colors.red[400],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Zona de Peligro",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.red[300]
                                            : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Esta acción eliminará de forma permanente este perfil de negocio y todos sus registros locales en este dispositivo.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDeleteBusinessModal(
                                    context,
                                    auth,
                                    isDark,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                    size: 18,
                                  ),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Eliminar este perfil de negocio",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.red[300]
                                        : Colors.red[700],
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.red.withValues(alpha: 0.4)
                                          : Colors.red.shade300,
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.red.withValues(alpha: 0.06)
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
    ];
  }
}
