import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// =========================================================================
/// 🏆 INTERACTIVE SHEET WRAPPER (Mobile Awards Quality)
/// Wrapper universal para modales y bottom sheets con:
/// 1. Física fluida de resorte y arrastre vertical (swipe-down to dismiss).
/// 2. Coordinación de scroll interno (cierre al arrastrar en cualquier parte).
/// 3. Handle reactivo (se expande de 40px a 56px al arrastrar).
/// 4. Micro-háptica táctil al alcanzar el umbral de descarte.
/// 5. Blindaje universal contra barra de 3 botones de Android / Edge-to-Edge (BUG-07).
/// 🛡️ Colchón defensivo mínimo cuando Android reporta inset 0.0 (Barra Fantasma).
/// La barra física de 3 botones en Android mide entre 48dp y 56dp; 28dp garantiza que
/// el botón de acción quede siempre visible y operable incluso si el SO reporta 0.0 de padding.
const double kMinDefensiveBottomClearance = 28.0;

/// 🛡️ Espacio de respiro extra al pie de listas y scrolls dentro de modales (36dp a 48dp).
const double kModalScrollBottomClearance = 40.0;

class InteractiveSheetWrapper extends StatefulWidget {
  final Widget child;
  final String? title;
  final Widget? titleWidget;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final Widget? bottomAction;
  final double maxHeightFactor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showHandle;
  final bool enableDragToDismiss;
  final bool enableHeaderDragToDismiss;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry? contentPadding;
  final bool applyEffectiveBottomPadding;
  final double minBottomPadding;
  final ScrollController? scrollController;
  final bool maintainFixedHeightOnKeyboard;

  final int titleMaxLines;
  final bool showCloseButton;

  /// 🛡️ Colchón defensivo mínimo cuando Android reporta inset 0.0 (Barra Fantasma).
  /// La barra física de 3 botones en Android mide entre 48dp y 56dp; 28dp garantiza que
  /// el botón de acción quede siempre visible y operable incluso si el SO reporta 0.0 de padding.
  static const double kMinDefensiveBottomClearance = 28.0;

  /// 🛡️ Espacio de respiro extra al pie de listas y scrolls dentro de modales (36dp a 48dp).
  static const double kModalScrollBottomClearance = 40.0;

  const InteractiveSheetWrapper({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.icon,
    this.iconColor,
    this.actions,
    this.bottomAction,
    this.maxHeightFactor = 0.90,
    this.backgroundColor,
    this.borderRadius,
    this.showHandle = true,
    this.enableDragToDismiss = true,
    this.enableHeaderDragToDismiss = false,
    this.onDismiss,
    this.contentPadding,
    this.applyEffectiveBottomPadding = true,
    this.minBottomPadding = kMinDefensiveBottomClearance,
    this.scrollController,
    this.maintainFixedHeightOnKeyboard = false,
    this.titleMaxLines = 2,
    this.showCloseButton = false,
  });

  /// 🛡️ CÁLCULO UNIVERSAL DE BLINDAJE INFERIOR (BUG-07 & GHOST BAR RESILIENCE)
  /// Distingue con precisión los 3 estados del sistema:
  /// - Estado A (Teclado): viewInsets.bottom > 0 -> ajuste limpio para teclado.
  /// - Estado B (Barra Fantasma): viewPadding.bottom == 0 && padding.bottom == 0
  ///   -> inyecta kMinDefensiveBottomClearance (28.0dp).
  /// - Estado C (Consumido por SafeArea): viewPadding.bottom > 0 && padding.bottom == 0
  ///   -> SafeArea o useSafeArea: true ya aplicó los 48dp del sistema; se devuelve únicamente
  ///      un respiro ergonómico compacto (16.0dp) para evitar duplicación (48dp + 48dp = 96dp).
  /// - Inset no consumido (padding.bottom > 0) -> math.max(minPadding, padding.bottom).
  static double getEffectiveBottomPadding(
    BuildContext context, {
    double minPadding = kMinDefensiveBottomClearance,
    bool includeKeyboard = false,
    double consumedSafeAreaPadding = 16.0,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = includeKeyboard ? mediaQuery.viewInsets.bottom : 0.0;
    if (keyboardInset > 0) {
      return keyboardInset + 8.0;
    }

    final systemPadding = mediaQuery.padding.bottom;
    final systemViewPadding = mediaQuery.viewPadding.bottom;

    // Estado C: SafeArea (o useSafeArea: true) ya consumió el inset del sistema
    if (systemPadding == 0.0 && systemViewPadding > 0) {
      return consumedSafeAreaPadding;
    }

    // Estado B: Barra Fantasma (el SO reporta 0.0 en ambos)
    if (systemPadding == 0.0 && systemViewPadding == 0.0) {
      return minPadding > 0 ? minPadding : kMinDefensiveBottomClearance;
    }

    // Inset aún no consumido por ningún SafeArea ancestro
    final effectiveMin = minPadding > 0 ? minPadding : kMinDefensiveBottomClearance;
    return math.max(effectiveMin, systemPadding);
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
    Color? barrierColor,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor ?? Colors.black54,
      builder: builder,
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  State<InteractiveSheetWrapper> createState() => _InteractiveSheetWrapperState();
}

class _InteractiveSheetWrapperState extends State<InteractiveSheetWrapper>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _isDraggingFromHandle = false;
  double _currentScrollPixels = 0.0;
  late AnimationController _animController;
  Animation<double>? _dragAnimation;
  bool _dismissTriggered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    final canDrag = widget.enableDragToDismiss || (_isDraggingFromHandle && widget.enableHeaderDragToDismiss);
    if (!canDrag) return;
    if (!_isDraggingFromHandle && _currentScrollPixels > 0.5) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _animController.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final canDrag = widget.enableDragToDismiss || (_isDraggingFromHandle && widget.enableHeaderDragToDismiss);
    if (!canDrag) return;
    if (!_isDraggingFromHandle && _currentScrollPixels > 0.5) return;
    final newOffset = _dragOffset + details.delta.dy;
    if (newOffset >= 0) {
      setState(() {
        _dragOffset = newOffset;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details, double totalHeight) {
    final wasDraggingFromHandle = _isDraggingFromHandle;
    _isDraggingFromHandle = false;
    if (!_isDragging && _dragOffset == 0.0) return;
    final canDrag = widget.enableDragToDismiss || (wasDraggingFromHandle && widget.enableHeaderDragToDismiss);
    if (!canDrag) return;
    setState(() {
      _isDragging = false;
    });

    final velocity = details.primaryVelocity ?? 0.0;
    // Si es arrastre exclusivo desde cabecera (enableDragToDismiss: false, enableHeaderDragToDismiss: true),
    // requerir arrastre pronunciado: > 100.0 px o velocidad > 450 px/s
    final isHeaderOnlyDrag = !widget.enableDragToDismiss && widget.enableHeaderDragToDismiss;
    final threshold = isHeaderOnlyDrag
        ? math.max(100.0, totalHeight * 0.20)
        : math.min(85.0, totalHeight * 0.15);
    final velocityThreshold = isHeaderOnlyDrag ? 450.0 : 380.0;

    // Si la velocidad supera velocityThreshold o el desplazamiento supera el umbral, cerrar modal
    if (velocity > velocityThreshold || _dragOffset > threshold) {
      _triggerDismiss(totalHeight);
    } else {
      // Retorno con rebote elástico suave
      _animateBack();
    }
  }

  void _triggerDismiss(double totalHeight) {
    if (_dismissTriggered) return;
    _dismissTriggered = true;
    HapticFeedback.lightImpact();

    _dragAnimation = Tween<double>(
      begin: _dragOffset,
      end: totalHeight > 0 ? totalHeight : 600.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.duration = const Duration(milliseconds: 200);
    _animController.forward(from: 0.0).then((_) {
      if (mounted) {
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        } else {
          Navigator.of(context).pop();
        }
      }
    });

    _animController.addListener(() {
      if (_dragAnimation != null) {
        setState(() {
          _dragOffset = _dragAnimation!.value;
        });
      }
    });
  }

  void _animateBack() {
    _dragAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.duration = const Duration(milliseconds: 240);
    _animController.forward(from: 0.0);

    _animController.addListener(() {
      if (_dragAnimation != null) {
        setState(() {
          _dragOffset = _dragAnimation!.value;
        });
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification, double totalHeight) {
    if (!widget.enableDragToDismiss) return false;

    // 🛡️ PUNTO 1: Rastrear offset del scroll interno en tiempo real
    _currentScrollPixels = notification.metrics.pixels;

    // Si la lista interna NO está en el tope superior (> 0.5), no capturar el desplazamiento hacia abajo
    // para permitir que el usuario vuelva a subir en la lista con total normalidad
    if (notification is ScrollUpdateNotification) {
      if (_currentScrollPixels <= 0.5 && (notification.scrollDelta ?? 0) < 0) {
        final delta = -(notification.scrollDelta ?? 0);
        setState(() {
          _dragOffset = math.max(0.0, _dragOffset + delta);
        });
        return false;
      } else if (_dragOffset > 0 && (notification.scrollDelta ?? 0) > 0) {
        // Reducir arrastre si el usuario vuelve a empujar hacia arriba
        final delta = notification.scrollDelta ?? 0;
        setState(() {
          _dragOffset = math.max(0.0, _dragOffset - delta);
        });
        return true;
      }
    } else if (notification is OverscrollNotification) {
      // Solo capturar sobre-desplazamiento hacia abajo si estamos en el tope del scroll
      if (notification.overscroll < 0 && _currentScrollPixels <= 0.5) {
        setState(() {
          _dragOffset = math.max(0.0, _dragOffset + (-notification.overscroll));
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset > 0) {
        final velocity = notification.dragDetails?.primaryVelocity ?? 0.0;
        final threshold = math.min(85.0, totalHeight * 0.15);
        if (velocity > 380 || _dragOffset > threshold) {
          _triggerDismiss(totalHeight);
        } else {
          _animateBack();
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final topPadding = mediaQuery.padding.top;
    final isKeyboardOpen = keyboardInset > 0;

    // 🛡️ REDUCCIÓN DINÁMICA DE VIEWPORT: Garantiza que el modal no colisione con el tope
    // de la pantalla ni provoque RenderFlex overflow cuando el teclado está abierto.
    // Con maintainFixedHeightOnKeyboard: true, preserva la altura exterior constante sin restar keyboardInset.
    final safeAvailableHeight = widget.maintainFixedHeightOnKeyboard
        ? math.max(160.0, screenHeight - topPadding - 16.0)
        : math.max(160.0, screenHeight - keyboardInset - topPadding - 16.0);
    final maxAllowedHeight = math.min(screenHeight * widget.maxHeightFactor, safeAvailableHeight);

    final sheetBgColor = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E28) : Colors.white);

    final sheetBorderRadius = widget.borderRadius ??
        const BorderRadius.vertical(top: Radius.circular(28));

    // Handle reactivo: se expande de 40 a 56 px de ancho al arrastrar
    final dragProgress = (_dragOffset / 60.0).clamp(0.0, 1.0);
    final handleWidth = 40.0 + (16.0 * (_isDragging ? math.max(0.4, dragProgress) : dragProgress));
    final handleColor = isDark
        ? Color.lerp(Colors.white24, Colors.white60, _isDragging ? math.max(0.5, dragProgress) : dragProgress)
        : Color.lerp(Colors.grey[300], Colors.grey[600], _isDragging ? math.max(0.5, dragProgress) : dragProgress);

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: widget.maintainFixedHeightOnKeyboard ? 0.0 : keyboardInset,
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = math.min(constraints.maxHeight, maxAllowedHeight);

        return Transform.translate(
          offset: Offset(0, _dragOffset),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notif) => _handleScrollNotification(notif, totalHeight),
            child: ScrollConfiguration(
              // Inyectar BouncingScrollPhysics para que todo scroll interno despache OverscrollNotification en Android e iOS
              behavior: const ScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                overscroll: true,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: widget.enableDragToDismiss ? _handleDragStart : null,
                onVerticalDragUpdate: widget.enableDragToDismiss ? _handleDragUpdate : null,
                onVerticalDragEnd: widget.enableDragToDismiss ? (d) => _handleDragEnd(d, totalHeight) : null,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: maxAllowedHeight,
                    minHeight: 0,
                  ),
                  decoration: BoxDecoration(
                    color: sheetBgColor,
                    borderRadius: sheetBorderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    maintainBottomViewPadding: true,
                    child: Builder(
                      builder: (innerContext) {
                        return MediaQuery(
                          data: mediaQuery.copyWith(
                            padding: mediaQuery.padding.copyWith(bottom: 0.0),
                            viewPadding: mediaQuery.viewPadding,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                      // ZONA SUPERIOR CON HANDLE REACTIVO (ARRASTRE PRIORITARIO 1:1)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (widget.enableDragToDismiss || widget.enableHeaderDragToDismiss)
                            ? (d) {
                                _isDraggingFromHandle = true;
                                _handleDragStart(d);
                              }
                            : null,
                        onVerticalDragUpdate: (widget.enableDragToDismiss || widget.enableHeaderDragToDismiss)
                            ? _handleDragUpdate
                            : null,
                        onVerticalDragEnd: (widget.enableDragToDismiss || widget.enableHeaderDragToDismiss)
                            ? (d) => _handleDragEnd(d, totalHeight)
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showHandle) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: handleWidth,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: handleColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Cabecera opcional
                            if (widget.title != null || widget.titleWidget != null) ...[
                              Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                              child: Row(
                                children: [
                                  if (widget.icon != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (widget.iconColor ??
                                                (isDark
                                                    ? Colors.blue[400]!
                                                    : Colors.blue[700]!))
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        widget.icon,
                                        color: widget.iconColor ??
                                            (isDark
                                                ? Colors.blue[300]
                                                : Colors.blue[700]),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: widget.titleWidget ??
                                        Text(
                                          widget.title!,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          maxLines: widget.titleMaxLines,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  ),
                                  if (widget.actions != null) ...widget.actions!,
                                  if (widget.showCloseButton)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: Icon(
                                        Icons.close,
                                        size: 20,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                      onPressed: () {
                                        if (widget.onDismiss != null) {
                                          widget.onDismiss!();
                                        }
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                          ],
                        ],
                      ),
                    ),

                      // CUERPO DEL MODAL (Flexible con scroll interno o contenido estático)
                      Flexible(
                        fit: FlexFit.loose,
                        child: Padding(
                          padding: widget.contentPadding ?? EdgeInsets.zero,
                          child: widget.child,
                        ),
                      ),

                      // ACCIÓN INFERIOR FIJA BLINDADA CONTRA BARRA DEL SISTEMA (BUG-07 & GHOST BAR)
                      if (widget.bottomAction != null)
                        Builder(
                          builder: (actionCtx) {
                            final effectiveBottom = widget.maintainFixedHeightOnKeyboard
                                ? 0.0
                                : (isKeyboardOpen
                                    ? 12.0
                                    : InteractiveSheetWrapper.getEffectiveBottomPadding(
                                        actionCtx,
                                        minPadding: widget.minBottomPadding > 0
                                            ? widget.minBottomPadding
                                            : InteractiveSheetWrapper.kMinDefensiveBottomClearance,
                                        includeKeyboard: false,
                                      ));
                            return Container(
                              padding: EdgeInsets.fromLTRB(20, isKeyboardOpen ? 8 : 12, 20, effectiveBottom),
                              decoration: BoxDecoration(
                                color: sheetBgColor,
                                border: Border(
                                  top: BorderSide(
                                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: widget.bottomAction!,
                            );
                          },
                        )
                      else if (widget.applyEffectiveBottomPadding)
                        Builder(
                          builder: (childCtx) {
                            final effectiveBottom = widget.maintainFixedHeightOnKeyboard
                                ? 0.0
                                : (isKeyboardOpen
                                    ? 12.0
                                    : InteractiveSheetWrapper.getEffectiveBottomPadding(
                                        childCtx,
                                        minPadding: widget.minBottomPadding > 0
                                            ? widget.minBottomPadding
                                            : InteractiveSheetWrapper.kMinDefensiveBottomClearance,
                                        includeKeyboard: false,
                                      ));
                            return SizedBox(height: effectiveBottom);
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  ),
);
      },
    ),
  );
}
}
