part of '../dashboard_header.dart';

extension _DashboardHeaderKpiCarouselPart on _DashboardHeaderState {
  Widget _buildAnimatedBackgroundContainer({
    required bool isDark,
    required Widget? child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A2E5C), const Color(0xFF001229)]
              : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
          begin: Alignment.lerp(
            Alignment.topLeft,
            Alignment.topRight,
            _bgAnimController.value,
          )!,
          end: Alignment.lerp(
            Alignment.bottomRight,
            Alignment.bottomLeft,
            _bgAnimController.value,
          )!,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.blue.shade900.withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        child: Stack(
          children: [
            _buildAmbientOrb(
              top: -50 + math.sin(_bgAnimController.value * math.pi * 2) * 20,
              left: -50 + math.cos(_bgAnimController.value * math.pi * 2) * 20,
              size: 250,
              color: Colors.cyanAccent,
              alpha: isDark ? 0.14 : 0.20,
            ),
            _buildAmbientOrb(
              bottom:
                  -80 + math.cos(_bgAnimController.value * math.pi * 2) * 30,
              right: -50 + math.sin(_bgAnimController.value * math.pi * 2) * 30,
              size: 300,
              color: Colors.blueAccent,
              alpha: isDark ? 0.18 : 0.24,
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientOrb({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required Color color,
    required double alpha,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationsCarousel(WorkbenchProvider workbench, bool isDark) {
    final String label;
    final double target;
    final Color color;
    final IconData icon;

    if (_kpiIndex == 0) {
      label = "Por Revisar";
      target = workbench.inProcessList.length.toDouble();
      color = Colors.orangeAccent;
      icon = Icons.assignment_late_rounded;
    } else if (_kpiIndex == 1) {
      label = "Listas Preparadas";
      target = workbench.readyAndPacksList.length.toDouble();
      color = Colors.lightBlueAccent;
      icon = Icons.check_circle_outline_rounded;
    } else {
      label = "Vendidas";
      target = workbench.soldList.length.toDouble();
      color = Colors.tealAccent;
      icon = Icons.monetization_on_outlined;
    }

    return _buildAnimatedKpi(
      keyId: "op_$_kpiIndex",
      icon: icon,
      label: label,
      value: "${target.toInt()}",
      numericTarget: target,
      formatter: (v) => "${v.toInt()}",
      color: color,
      isDark: isDark,
      isLoading: workbench.isLoading,
    );
  }

  Widget _buildFinanceCarousel(SaleProvider salesProv, bool isDark) {
    final String label;
    String value = "";
    double? target;
    String Function(double)? formatter;
    final Color color;
    final IconData icon;

    if (_kpiIndex == 0) {
      label = "Ventas Hoy";
      target = salesProv.todaySalesTotal;
      formatter = (v) => AppCurrency.format(v);
      value = AppCurrency.format(target);
      color = Colors.greenAccent;
      icon = Icons.trending_up_rounded;
    } else if (_kpiIndex == 1) {
      label = "Operaciones Hoy";
      target = salesProv.todaySalesCount.toDouble();
      formatter = (v) => "${v.toInt()}";
      value = "${target.toInt()}";
      color = Colors.pinkAccent;
      icon = Icons.shopping_bag_outlined;
    } else {
      label = "Ventas Mes";
      if (salesProv.currentMonthSalesTotal == null) {
        value = "...";
      } else {
        target = salesProv.currentMonthSalesTotal!;
        formatter = (v) => AppCurrency.format(v);
        value = AppCurrency.format(target);
      }
      color = Colors.cyanAccent;
      icon = Icons.calendar_month_rounded;
    }

    return _buildAnimatedKpi(
      keyId: "fin_$_kpiIndex",
      icon: icon,
      label: label,
      value: value,
      numericTarget: target,
      formatter: formatter,
      color: color,
      isDark: isDark,
      isLoading: salesProv.isLoading,
    );
  }

  Widget _buildAnimatedKpi({
    required String keyId,
    required IconData icon,
    required String label,
    required String value,
    double? numericTarget,
    String Function(double)? formatter,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 74,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildKpiCard(
          key: ValueKey(keyId),
          kpiMemoryKey: keyId,
          icon: icon,
          label: label,
          value: value,
          numericTarget: numericTarget,
          formatter: formatter,
          color: color,
          isDark: isDark,
          isLoading: isLoading,
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    Key? key,
    required String kpiMemoryKey,
    required IconData icon,
    required String label,
    required String value,
    double? numericTarget,
    String Function(double)? formatter,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    double? beginTarget;
    if (!isLoading && numericTarget != null && formatter != null) {
      beginTarget = _lastKpiTargets[kpiMemoryKey] ?? 0.0;
      _lastKpiTargets[kpiMemoryKey] = numericTarget;
    }

    return Container(
      key: key,
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const ShimmerBox(width: 80, height: 18, borderRadius: 4)
                else
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: numericTarget != null && formatter != null
                          ? TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: beginTarget ?? numericTarget,
                                end: numericTarget,
                              ),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, _) {
                                return Text(
                                  formatter(val),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                  maxLines: 1,
                                );
                              },
                            )
                          : Text(
                              value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 6) {
      return "¿Trabajando hasta tarde?";
    }
    if (hour < 12) {
      return "Buenos días,";
    }
    if (hour < 19) {
      return "Buenas tardes,";
    }
    return "Buenas noches,";
  }
}
