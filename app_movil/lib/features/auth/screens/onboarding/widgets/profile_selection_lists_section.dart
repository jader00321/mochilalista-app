part of '../profile_selection_screen.dart';

mixin _ProfileSelectionListsMixin on _ProfileSelectionStateBase {
  // ============================================================
  // SUB-BUILDERS DE UI
  // ============================================================

  @override
  Widget _buildEmptyState(bool isDark) {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 76, color: isDark ? Colors.grey[700] : Colors.grey[300]),
              const SizedBox(height: 14),
              Text("No hay negocios registrados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 6),
              Text("Crea tu primer perfil para empezar.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 32),
              PrimaryButton(
                text: "CREAR NUEVO NEGOCIO",
                icon: Icons.add_business_rounded,
                onPressed: () async {
                  if (!await _ensureEulaAccepted()) return;
                  if (!mounted) return;
                  Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                  ));
                },
              ),
              const SizedBox(height: 14),
              _buildUnifiedBackupSection(context, isDark: isDark, isEmptyState: true, profiles: const []),
              const SizedBox(height: 12),
              _buildExplorerDemoButton(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildManagementButton(bool isDark) {
    return Align(
      key: const ValueKey('management_btn'),
      alignment: Alignment.centerRight,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openManagementModal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text("Gestionar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildSelectionHeader(bool isDark) {
    final isBackup = _screenMode == ProfileScreenMode.selectForBackup;
    final color = isBackup ? Colors.indigoAccent : Colors.redAccent;
    final icon = isBackup ? Icons.backup_rounded : Icons.delete_forever_rounded;
    final text = isBackup ? "Toca el perfil que deseas respaldar" : "Toca el perfil que deseas eliminar";

    return Container(
      key: const ValueKey('selection_header'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }

  @override
  Widget _buildReorderableList(List<UserModel> profiles, bool isDark, AuthProvider auth) {
    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: profiles.length,
      buildDefaultDragHandles: true,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final double elevateVal = lerpDouble(0, 12, Curves.easeInOut.transform(animation.value))!;
            return Material(
              elevation: elevateVal,
              color: Colors.transparent,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, profiles),
      itemBuilder: (context, index) {
        final p = profiles[index];
        final isLastActive = p.id == _lastActiveUserId;
        final hasPin = _pinProfileIds.contains(p.id);
        final bName = p.business?.commercialName.trim().toLowerCase() ?? '';
        final isDuplicate = _duplicateNames.contains(bName);

        return AnimatedProfileCard(
          key: ValueKey(p.id),
          controller: _animController,
          index: index,
          onTap: () => _handleProfileSelection(p.id, auth),
          child: ProfileCardContent(
            profile: p,
            isDark: isDark,
            isSelectionMode: false,
            screenMode: _screenMode,
            isLastActive: isLastActive,
            hasPin: hasPin,
            isDuplicateName: isDuplicate,
          ),
        );
      },
    );
  }

  @override
  Widget _buildSelectionList(List<UserModel> profiles, bool isDark, AuthProvider auth) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final p = profiles[index];
        final isSelected = _selectedProfileId == p.id;
        final isLastActive = p.id == _lastActiveUserId;
        final hasPin = _pinProfileIds.contains(p.id);
        final bName = p.business?.commercialName.trim().toLowerCase() ?? '';
        final isDuplicate = _duplicateNames.contains(bName);

        return AnimatedProfileCard(
          key: ValueKey(p.id),
          controller: _animController,
          index: index,
          onTap: () => _handleProfileTapInSelectionMode(p, auth),
          child: ProfileCardContent(
            profile: p,
            isDark: isDark,
            isSelectionMode: true,
            isSelected: isSelected,
            screenMode: _screenMode,
            isLastActive: isLastActive,
            hasPin: hasPin,
            isDuplicateName: isDuplicate,
          ),
        );
      },
    );
  }

  @override
  Widget _buildNormalBottomSection(bool isDark, List<UserModel> profiles) {
    return AnimatedBuilder(
      key: const ValueKey('normal_bottom'),
      animation: _animController,
      builder: (context, child) {
        final start = 0.2 + (profiles.length * 0.1).clamp(0.0, 0.5);
        final end = start + 0.3;

        final slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
          CurvedAnimation(parent: _animController, curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic)),
        );
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _animController, curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut)),
        );

        return Opacity(
          opacity: fadeAnimation.value,
          child: Transform.translate(offset: Offset(0, slideAnimation.value), child: child),
        );
      },
      child: Column(
        children: [
          const SizedBox(height: 14),
          PrimaryButton(
            text: "CREAR NUEVO NEGOCIO",
            icon: Icons.add_business_rounded,
            onPressed: () async {
              if (!await _ensureEulaAccepted()) return;
              if (!mounted) return;
              Navigator.push(context, PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
              ));
            },
          ),
          const SizedBox(height: 12),
          _buildUnifiedBackupSection(context, isDark: isDark, isEmptyState: false, profiles: profiles),
          const SizedBox(height: 10),
          _buildExplorerDemoButton(isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildExplorerDemoButton({required bool isDark}) {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 18,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Explorar la app sin registrarse",
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildCancelButton(bool isDark) {
    final isBackup = _screenMode == ProfileScreenMode.selectForBackup;
    final color = isBackup ? Colors.indigoAccent : Colors.redAccent;

    return Padding(
      key: const ValueKey('cancel_btn'),
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(Icons.arrow_back_rounded, size: 20, color: color),
          label: Text(
            isBackup ? "Cancelar y volver" : "Cancelar",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
          ),
          onPressed: _cancelSelection,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}
