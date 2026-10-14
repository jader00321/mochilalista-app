import 'package:flutter/material.dart';
import 'package:app_movil/core/models/user_model.dart';

/// =========================================================================
/// 🔧 TAREA 3.2: Indicador de "Perfil Completo"
/// Widget que muestra una barra de progreso animada con el % de completitud
/// del perfil y lista los campos pendientes de completar.
/// =========================================================================

class ProfileCompletionIndicator extends StatelessWidget {
  final UserModel user;
  final bool hasPin;
  final bool isDark;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditBusiness;
  final VoidCallback? onChangeLogo;
  final VoidCallback? onChangePin;

  const ProfileCompletionIndicator({
    super.key,
    required this.user,
    required this.hasPin,
    required this.isDark,
    this.onEditProfile,
    this.onEditBusiness,
    this.onChangeLogo,
    this.onChangePin,
  });

  List<_ProfileField> _getFields() {
    final biz = user.business;
    return [
      _ProfileField(
        label: 'Nombre',
        icon: Icons.person,
        isComplete: user.fullName.isNotEmpty && user.fullName != 'Usuario',
        onTap: onEditProfile,
      ),
      _ProfileField(
        label: 'Teléfono',
        icon: Icons.phone,
        isComplete: user.phone != null && user.phone!.isNotEmpty,
        onTap: onEditProfile,
      ),
      _ProfileField(
        label: 'Email',
        icon: Icons.email,
        isComplete: user.email != null && user.email!.isNotEmpty,
        onTap: onEditProfile,
      ),
      _ProfileField(
        label: 'Negocio',
        icon: Icons.store,
        isComplete: biz != null,
        onTap: onEditBusiness,
      ),
      _ProfileField(
        label: 'RUC',
        icon: Icons.badge,
        isComplete: biz?.ruc != null && biz!.ruc!.isNotEmpty,
        onTap: onEditBusiness,
      ),
      _ProfileField(
        label: 'Dirección',
        icon: Icons.location_on,
        isComplete: biz?.address != null && biz!.address!.isNotEmpty,
        onTap: onEditBusiness,
      ),
      _ProfileField(
        label: 'Logo',
        icon: Icons.image,
        isComplete: biz?.logoUrl != null && biz!.logoUrl!.isNotEmpty && biz.logoUrl != 'null',
        onTap: onChangeLogo ?? onEditBusiness,
      ),
      _ProfileField(
        label: 'Info Pago',
        icon: Icons.payment,
        isComplete: biz?.paymentInfo != null && biz!.paymentInfo!.isNotEmpty,
        onTap: onEditBusiness,
      ),
      _ProfileField(
        label: 'Ubicación GPS',
        icon: Icons.gps_fixed,
        isComplete: biz?.latitud != null && biz?.longitud != null,
        onTap: onEditBusiness,
      ),
      _ProfileField(
        label: 'PIN Seguridad',
        icon: Icons.lock,
        isComplete: hasPin,
        onTap: onChangePin,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fields = _getFields();
    final completed = fields.where((f) => f.isComplete).length;
    final total = fields.length;
    final progress = total > 0 ? completed / total : 0.0;
    final percentage = (progress * 100).round();
    final pending = fields.where((f) => !f.isComplete).toList();

    // No mostrar si está al 100%
    if (percentage == 100) return const SizedBox.shrink();

    final progressColor = percentage >= 80
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: progressColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Perfil $percentage% completo",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                "$completed/$total",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar animada
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              );
            },
          ),

          // Campos pendientes
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              "Pendientes:",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pending.map((field) {
                return InkWell(
                  onTap: field.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? progressColor.withValues(alpha: 0.1)
                          : progressColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: progressColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(field.icon, size: 14, color: progressColor),
                        const SizedBox(width: 4),
                        Text(
                          field.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileField {
  final String label;
  final IconData icon;
  final bool isComplete;
  final VoidCallback? onTap;

  const _ProfileField({
    required this.label,
    required this.icon,
    required this.isComplete,
    this.onTap,
  });
}
