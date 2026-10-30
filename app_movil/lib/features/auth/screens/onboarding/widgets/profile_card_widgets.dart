import 'package:flutter/material.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

// ============================================================
// ENUM: Modos de la pantalla de selección de perfiles
// ============================================================
enum ProfileScreenMode {
  normal,          // Vista estándar: listar perfiles, entrar, crear, restaurar
  selectForBackup, // Modo selección para crear backup de un perfil específico
  selectForDelete, // Modo selección para eliminar un perfil
}

// ============================================================
// CONSTANTES: Gradientes para avatares de perfiles
// ============================================================
const List<List<Color>> profileAvatarGradients = [
  [Color(0xFF00C6FF), Color(0xFF0072FF)], // Blue
  [Color(0xFFF77062), Color(0xFFFE5196)], // Pink/Orange
  [Color(0xFF11998E), Color(0xFF38EF7D)], // Green
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple
  [Color(0xFFF2994A), Color(0xFFF2C94C)], // Yellow/Orange
];

// ============================================================
// WIDGET: Tarjeta animada de perfil (animación de entrada + tap)
// ============================================================
class AnimatedProfileCard extends StatefulWidget {
  final Widget child;
  final AnimationController controller;
  final int index;
  final VoidCallback onTap;

  const AnimatedProfileCard({
    super.key,
    required this.child,
    required this.controller,
    required this.index,
    required this.onTap,
  });

  @override
  State<AnimatedProfileCard> createState() => _AnimatedProfileCardState();
}

class _AnimatedProfileCardState extends State<AnimatedProfileCard> with SingleTickerProviderStateMixin {
  late Animation<double> _scaleAnimation;
  late AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = 0.2 + (widget.index * 0.1).clamp(0.0, 0.5);
    final end = start + 0.3;

    final slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _tapController.forward(),
        onTapUp: (_) {
          _tapController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _tapController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET: Contenido de la tarjeta de perfil
// ============================================================
class ProfileCardContent extends StatelessWidget {
  final UserModel profile;
  final bool isDark;
  final bool isSelectionMode;
  final bool isSelected;
  final ProfileScreenMode screenMode;
  final bool isLastActive;
  final bool hasPin;
  final bool isDuplicateName;

  const ProfileCardContent({
    super.key,
    required this.profile,
    required this.isDark,
    required this.isSelectionMode,
    this.isSelected = false,
    this.screenMode = ProfileScreenMode.normal,
    this.isLastActive = false,
    this.hasPin = false,
    this.isDuplicateName = false,
  });

  @override
  Widget build(BuildContext context) {
    final business = profile.business;
    final String bName = business?.commercialName ?? "Negocio sin nombre";
    final bool hasLogo = business?.logoUrl != null &&
        business!.logoUrl!.isNotEmpty &&
        business.logoUrl != 'null';
    final List<Color> gradient = profileAvatarGradients[profile.id % profileAvatarGradients.length];

    String initials = "N";
    if (bName.isNotEmpty) {
      final parts = bName.trim().split(RegExp(r'\s+'));
      initials = parts.length > 1
          ? (parts[0][0] + parts[1][0]).toUpperCase()
          : parts[0][0].toUpperCase();
    }

    final isBackupMode = screenMode == ProfileScreenMode.selectForBackup;
    final accentColor = isBackupMode ? Colors.indigoAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? accentColor.withValues(alpha: 0.08) : accentColor.withValues(alpha: 0.04))
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? accentColor.withValues(alpha: 0.4)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasLogo
                  ? null
                  : LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [
                if (!hasLogo)
                  BoxShadow(color: gradient[0].withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: hasLogo
                ? ClipOval(
                    child: UniversalImage(
                      path: business.logoUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          const SizedBox(width: 14),

          // Información del perfil
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLastActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            size: 8,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Último activo",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  bName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.25,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          profile.fullName,
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    if (hasPin)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 13, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                          const SizedBox(width: 3),
                          Text(
                            "PIN",
                            style: TextStyle(
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    if (isDuplicateName)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "#${profile.id}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Trailing: Check (selección) o Flecha (normal)
          if (isSelectionMode)
            SelectionIndicator(isSelected: isSelected, accentColor: accentColor, isDark: isDark)
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.blue[300] : Colors.blue[700],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGET: Indicador de selección (check circle animado)
// ============================================================
class SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  final Color accentColor;
  final bool isDark;

  const SelectionIndicator({
    super.key,
    required this.isSelected,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? accentColor : Colors.transparent,
        border: Border.all(
          color: isSelected ? accentColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          width: 2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isSelected
            ? const Icon(Icons.check_rounded, size: 20, color: Colors.white, key: ValueKey('check'))
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}

// ============================================================
// WIDGET: Overlay de procesamiento (backup en progreso)
// ============================================================
class ProfileProcessingOverlay extends StatelessWidget {
  final String message;
  final bool isDark;
  final Color surfaceColor;

  const ProfileProcessingOverlay({
    super.key,
    required this.message,
    required this.isDark,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: 0.7, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        color: isDark ? Colors.indigoAccent : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
