part of '../backup_screen.dart';

class AutoBackupTimerWidget extends StatefulWidget {
  final BackupProvider provider;
  final bool isDark;

  const AutoBackupTimerWidget({
    super.key,
    required this.provider,
    required this.isDark,
  });

  @override
  State<AutoBackupTimerWidget> createState() => _AutoBackupTimerWidgetState();
}

class _AutoBackupTimerWidgetState extends State<AutoBackupTimerWidget> {
  Timer? _timer;
  String _timeLeft = "Calculando...";

  @override
  void initState() {
    super.initState();
    _initAndCalculate();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _calculateTime();
    });
  }

  Future<void> _initAndCalculate() async {
    await widget.provider.reloadTimestamps();
    if (mounted) _calculateTime();
  }

  @override
  void didUpdateWidget(AutoBackupTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.lastRegisterTime !=
            widget.provider.lastRegisterTime ||
        oldWidget.provider.lastRunTime != widget.provider.lastRunTime ||
        oldWidget.provider.autoBackupIntervalDays !=
            widget.provider.autoBackupIntervalDays) {
      _calculateTime();
    }
  }

  void _calculateTime() {
    if (!mounted) return;

    final int baseTimeMs =
        widget.provider.lastRunTime > widget.provider.lastRegisterTime
        ? widget.provider.lastRunTime
        : widget.provider.lastRegisterTime;

    if (baseTimeMs == 0) {
      setState(() => _timeLeft = "Programado para iniciar...");
      return;
    }

    final baseDate = DateTime.fromMillisecondsSinceEpoch(baseTimeMs);
    final targetDate = baseDate.add(
      Duration(days: widget.provider.autoBackupIntervalDays),
    );
    final now = DateTime.now();

    if (now.isAfter(targetDate)) {
      setState(() => _timeLeft = "A punto de ejecutarse...");
      return;
    }

    final diff = targetDate.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      setState(() => _timeLeft = "Faltan $days d y $hours h");
    } else if (hours > 0) {
      setState(() => _timeLeft = "Faltan $hours h y $minutes m");
    } else {
      setState(() => _timeLeft = "Faltan $minutes min");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.indigoAccent.withValues(alpha: 0.1)
            : Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigoAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              size: 20,
              color: Colors.indigoAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Próximo respaldo automático en:",
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLeft,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.indigo[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PinDelayConfigWidget extends StatefulWidget {
  final bool isDark;
  const PinDelayConfigWidget({super.key, required this.isDark});

  @override
  State<PinDelayConfigWidget> createState() => _PinDelayConfigWidgetState();
}

class _PinDelayConfigWidgetState extends State<PinDelayConfigWidget> {
  int _delayMinutes = 1;

  @override
  void initState() {
    super.initState();
    _loadDelay();
  }

  Future<void> _loadDelay() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _delayMinutes = prefs.getInt('pin_delay_minutes') ?? 1;
    });
  }

  Future<void> _setDelay(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pin_delay_minutes', value);
    if (!mounted) return;
    setState(() {
      _delayMinutes = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white10
              : Colors.teal.withValues(alpha: 0.3),
        ),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bloqueo automático",
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tiempo inactivo antes de pedir PIN.",
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<int>(
                value: _delayMinutes,
                underline: const SizedBox(),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.teal,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Inmediato")),
                  DropdownMenuItem(value: 1, child: Text("1 minuto")),
                  DropdownMenuItem(value: 2, child: Text("2 minutos")),
                  DropdownMenuItem(value: 5, child: Text("5 minutos")),
                  DropdownMenuItem(value: 10, child: Text("10 minutos")),
                  DropdownMenuItem(value: 15, child: Text("15 minutos")),
                  DropdownMenuItem(value: 30, child: Text("30 minutos")),
                  DropdownMenuItem(value: 60, child: Text("1 hora")),
                ],
                onChanged: (val) {
                  if (val != null) _setDelay(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoBackupSettingsView extends StatefulWidget {
  final BackupProvider provider;
  final bool isDark;
  const _AutoBackupSettingsView({required this.provider, required this.isDark});

  @override
  State<_AutoBackupSettingsView> createState() =>
      _AutoBackupSettingsViewState();
}

class _AutoBackupSettingsViewState extends State<_AutoBackupSettingsView> {
  int? _initialFrequency;

  @override
  void initState() {
    super.initState();
    _initialFrequency = widget.provider.autoBackupIntervalDays;
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDropdownW = math.min(215.0, constraints.maxWidth * 0.62);
          return Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxDropdownW),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.indigoAccent,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final isDark = widget.isDark;
    final showWarning =
        _initialFrequency != null &&
        provider.autoBackupIntervalDays != _initialFrequency;

    return Column(
      children: [
        _Divider(isDark: isDark),
        _buildDropdownRow<String>(
          label: "Tipo",
          value: provider.autoBackupType,
          isDark: isDark,
          items: const [
            DropdownMenuItem(
              value: 'global',
              child: Text("Global (.mlbg)", overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'perfil',
              child: Text(
                "Solo este negocio (.mlb)",
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'ambos',
              child: Text(
                "Ambos (.mlbg y .mlb)",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              provider.setAutoBackupType(
                val,
                negocioId: auth.activeBusinessId,
                negocioNombre: auth.businessName,
              );
            }
          },
        ),
        _buildDropdownRow<int>(
          label: "Frecuencia",
          value: provider.autoBackupIntervalDays,
          isDark: isDark,
          items: const [
            DropdownMenuItem(value: 1, child: Text("Cada 1 Día")),
            DropdownMenuItem(value: 7, child: Text("Cada 7 Días")),
            DropdownMenuItem(value: 15, child: Text("Cada 15 Días")),
            DropdownMenuItem(value: 30, child: Text("Cada 30 Días")),
          ],
          onChanged: (val) {
            if (val != null) provider.setAutoBackupInterval(val);
          },
        ),
        _buildDropdownRow<String>(
          label: "Destino",
          value: provider.autoBackupLocation,
          isDark: isDark,
          items: const [
            DropdownMenuItem(
              value: 'Local',
              child: Text("Descargas", overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'Drive',
              child: Text("Guardar en Nube", overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text(
                "Carpeta personalizada...",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (val) async {
            if (val == 'custom') {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                provider.setAutoBackupLocation(
                  val!,
                  customPath: selectedDirectory,
                );
              }
            } else if (val != null) {
              provider.setAutoBackupLocation(val);
            }
          },
        ),
        if (provider.autoBackupLocation == 'custom' &&
            provider.autoBackupCustomPath != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.folder_special, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.autoBackupCustomPath!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (showWarning)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Frecuencia actualizada. Para que el nuevo tiempo surta efecto, desactiva y vuelve a activar la Protección Automática.",
                    style: TextStyle(
                      color: isDark ? Colors.orange[200] : Colors.orange[800],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        AutoBackupTimerWidget(provider: provider, isDark: isDark),
      ],
    );
  }
}
