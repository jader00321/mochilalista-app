import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/models/notification_model.dart';

class NotificationItemCard extends StatefulWidget {
  final NotificationModel notif;
  final bool isDark;
  final bool isSelected;
  final bool isSelectionMode;
  final int tabIndex;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final bool enableSwipeActions;
  final VoidCallback? onArchive;
  final VoidCallback? onSilence;
  final VoidCallback? onToggleResolve;
  
  // Callbacks de In-Card Actions directas
  final VoidCallback? onActionRecordar;
  final VoidCallback? onActionCobrar;
  final VoidCallback? onActionMora;
  final VoidCallback? onActionAbastecer;
  final VoidCallback? onActionKardex;
  final VoidCallback? onActionVerCotizacion;
  final VoidCallback? onActionVerPremio;
  final VoidCallback? onShowActions;

  const NotificationItemCard({
    super.key,
    required this.notif,
    required this.isDark,
    required this.isSelected,
    required this.isSelectionMode,
    required this.tabIndex,
    required this.onLongPress,
    required this.onTap,
    this.enableSwipeActions = false,
    this.onArchive,
    this.onSilence,
    this.onToggleResolve,
    this.onActionRecordar,
    this.onActionCobrar,
    this.onActionMora,
    this.onActionAbastecer,
    this.onActionKardex,
    this.onActionVerCotizacion,
    this.onActionVerPremio,
    this.onShowActions,
  });

  @override
  State<NotificationItemCard> createState() => _NotificationItemCardState();
}

class _NotificationItemCardState extends State<NotificationItemCard> with SingleTickerProviderStateMixin {
  static const double _maxRevealWidth = 150.0;
  double _dragOffset = 0.0;
  late AnimationController _animController;
  Animation<double>? _snapAnimation;

  @override
  void initState({Key? key}) {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      if (_snapAnimation != null) {
        setState(() {
          _dragOffset = _snapAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _snapAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0.0);
  }

  String _cleanTitle(String rawTitle) {
    return rawTitle
        .replaceAll(RegExp(r'^(💰|⚠️|🚨|📋|✅|📦)\s*'), '')
        .trim();
  }

  Widget _buildDrawerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _animateTo(0.0);
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: widget.isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealDrawer() {
    final isDark = widget.isDark;
    final isResolved = widget.notif.isResolved;

    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        child: Container(
          width: _maxRevealWidth,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              // 1. Archivar
              _buildDrawerButton(
                icon: Icons.inventory_2_outlined,
                label: "Archivar",
                color: isDark ? Colors.amber[300]! : Colors.orange[800]!,
                onTap: () => widget.onArchive?.call(),
              ),

              // 2. Silenciar
              _buildDrawerButton(
                icon: Icons.notifications_off_outlined,
                label: "Silenciar",
                color: isDark ? Colors.red[300]! : Colors.red[700]!,
                onTap: () => widget.onSilence?.call(),
              ),

              // 3. Resolver / Pendiente
              _buildDrawerButton(
                icon: isResolved ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
                label: isResolved ? "Reabrir" : "Resolver",
                color: isResolved
                    ? (isDark ? Colors.blue[300]! : Colors.blue[700]!)
                    : (isDark ? Colors.green[300]! : Colors.green[700]!),
                onTap: () => widget.onToggleResolve?.call(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Color iconColor, IconData iconData, Color cardBgColor, String displayTitle) {
    final notif = widget.notif;
    final isDark = widget.isDark;
    final isSelected = widget.isSelected;
    final isSelectionMode = widget.isSelectionMode;
    final tabIndex = widget.tabIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected 
           ? (isDark ? Colors.red[900]!.withValues(alpha: 0.35) : Colors.red[50])
           : (notif.isRead 
               ? cardBgColor 
               : (isDark ? iconColor.withValues(alpha: 0.12) : iconColor.withValues(alpha: 0.05))),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
             ? Colors.red[400]!
             : (notif.isRead 
                 ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200) 
                 : iconColor.withValues(alpha: 0.45)), 
          width: notif.isRead ? 1.0 : 1.5,
        ),
        boxShadow: [
          if (!isDark && notif.isRead && !isSelected) 
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          if (!isDark && !notif.isRead && !isSelected) 
            BoxShadow(color: iconColor.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode && tabIndex == 2)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                    color: isSelected ? Colors.red[600] : Colors.grey[400],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15), 
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle, 
                            style: TextStyle(
                              fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900, 
                              fontSize: 15.5, 
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(notif.createdAt), 
                              style: TextStyle(
                                fontSize: 12, 
                                color: isDark ? Colors.grey[400] : Colors.grey[600], 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!isSelectionMode && widget.onShowActions != null) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: widget.onShowActions,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    size: 19,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.message, 
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[800], 
                        fontSize: 13.5, 
                        height: 1.45,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notif.isRead && !isSelectionMode) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 9, 
                  height: 9,
                  decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                )
              ]
            ],
          ),

          // In-Card Action Buttons Bar
          if (!isSelectionMode) ...[
            const SizedBox(height: 12),
            _buildInCardActions(context, iconColor),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;

    final nivel = widget.notif.nivelPrioridad.toLowerCase();
    final tipo = widget.notif.objetoRelacionadoTipo?.toLowerCase();

    if (nivel == 'critica') {
      iconColor = widget.isDark ? const Color(0xFFFF5252) : const Color(0xFFE53935);
      if (tipo == 'producto') {
        iconData = Icons.remove_shopping_cart_rounded;
      } else {
        iconData = Icons.error_outline_rounded;
      }
    } else if (nivel == 'preventiva') {
      iconColor = widget.isDark ? const Color(0xFFFFA726) : const Color(0xFFFB8C00);
      if (tipo == 'producto') {
        iconData = Icons.inventory_2_outlined;
      } else {
        iconData = Icons.schedule_rounded;
      }
    } else if (nivel == 'informativa' || widget.notif.type == 'exito') {
      iconColor = widget.isDark ? const Color(0xFF66BB6A) : const Color(0xFF43A047);
      if (tipo == 'recompensa') {
        iconData = Icons.military_tech_rounded;
      } else {
        iconData = Icons.check_circle_outline_rounded;
      }
    } else {
      // Sistema / Cotización
      iconColor = widget.isDark ? const Color(0xFF7986CB) : const Color(0xFF3949AB);
      if (tipo == 'cotizacion' || tipo == 'venta') {
        iconData = Icons.receipt_long_rounded;
      } else {
        iconData = Icons.shield_outlined;
      }
    }

    final cardBgColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;
    final displayTitle = _cleanTitle(widget.notif.title);

    // Si NO están habilitadas las acciones swipe (modo navegación entre pestañas)
    if (!widget.enableSwipeActions || widget.isSelectionMode) {
      return GestureDetector(
        onLongPress: widget.onLongPress,
        onTap: widget.onTap,
        child: _buildCardContent(context, iconColor, iconData, cardBgColor, displayTitle),
      );
    }

    // Modo Swipe Actions (Slide-to-Reveal con tope estricto a 150dp y sin disparo automático)
    return Stack(
      children: [
        // Botones del cajón revelable detrás de la tarjeta
        _buildRevealDrawer(),

        // Tarjeta frontal deslizable
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset = (_dragOffset + details.primaryDelta!).clamp(-_maxRevealWidth, 0.0);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragOffset < -(_maxRevealWidth / 2)) {
                _animateTo(-_maxRevealWidth);
              } else {
                _animateTo(0.0);
              }
            },
            onLongPress: widget.onLongPress,
            onTap: () {
              if (_dragOffset < -10.0) {
                _animateTo(0.0);
              } else {
                widget.onTap();
              }
            },
            child: _buildCardContent(context, iconColor, iconData, cardBgColor, displayTitle),
          ),
        ),
      ],
    );
  }

  Widget _buildInCardActions(BuildContext context, Color themeColor) {
    final tipo = widget.notif.objetoRelacionadoTipo?.toLowerCase();

    if (widget.notif.isResolved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              "Resuelta automáticamente", 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: widget.isDark ? Colors.green[300] : Colors.green[800],
              ),
            ),
          ],
        ),
      );
    }

    List<Widget> actions = [];

    if (tipo == 'cuota') {
      if (widget.onActionRecordar != null) {
        actions.add(_buildActionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: "Recordar",
          color: Colors.green[700]!,
          onTap: widget.onActionRecordar!,
        ));
      }
      if (widget.onActionCobrar != null) {
        actions.add(_buildActionBtn(
          icon: Icons.payments_outlined,
          label: "Cobrar",
          color: widget.isDark ? Colors.blue[300]! : Colors.blue[700]!,
          onTap: widget.onActionCobrar!,
          isPrimary: true,
        ));
      }
      if (widget.onActionMora != null) {
        actions.add(_buildActionBtn(
          icon: Icons.trending_up_rounded,
          label: "Mora",
          color: widget.isDark ? Colors.amber[300]! : Colors.orange[800]!,
          onTap: widget.onActionMora!,
        ));
      }
    } else if (tipo == 'producto') {
      if (widget.onActionAbastecer != null) {
        actions.add(_buildActionBtn(
          icon: Icons.add_business_rounded,
          label: "Abastecer",
          color: widget.isDark ? Colors.blue[300]! : Colors.blue[700]!,
          onTap: widget.onActionAbastecer!,
          isPrimary: true,
        ));
      }
      if (widget.onActionKardex != null) {
        actions.add(_buildActionBtn(
          icon: Icons.analytics_outlined,
          label: "Kardex",
          color: widget.isDark ? Colors.teal[300]! : Colors.teal[800]!,
          onTap: widget.onActionKardex!,
        ));
      }
    } else if (tipo == 'cotizacion') {
      if (widget.onActionVerCotizacion != null) {
        actions.add(_buildActionBtn(
          icon: Icons.receipt_long_rounded,
          label: "Ver Cotización",
          color: widget.isDark ? Colors.indigo[300]! : Colors.indigo[700]!,
          onTap: widget.onActionVerCotizacion!,
          isPrimary: true,
        ));
      }
    } else if (tipo == 'recompensa') {
      if (widget.onActionVerPremio != null) {
        actions.add(_buildActionBtn(
          icon: Icons.military_tech_rounded,
          label: "Ver Premio",
          color: widget.isDark ? Colors.amber[300]! : Colors.amber[800]!,
          onTap: widget.onActionVerPremio!,
          isPrimary: true,
        ));
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: actions.map((btn) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: btn,
        )).toList(),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isPrimary 
                ? color.withValues(alpha: widget.isDark ? 0.25 : 0.12)
                : (widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary 
                  ? color.withValues(alpha: 0.5) 
                  : (widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
