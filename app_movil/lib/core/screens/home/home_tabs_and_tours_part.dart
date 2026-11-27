part of '../home_screen.dart';

extension _HomeTabsAndToursPart on _HomeScreenState {
  ScreenTourConfig _buildCatalogTourConfig() {
    return CatalogTour.buildConfig(
      keys: _catalogTourKeys,
      onExpandOffers: () async {
        await _catalogScreenKey.currentState?.expandOffersSection();
      },
      onCollapseOffers: () async {
        await _catalogScreenKey.currentState?.collapseOffersSection();
      },
      onExpandBottomMenu: () async {
        await _catalogScreenKey.currentState?.expandBottomMenu();
      },
      onCollapseBottomMenu: () async {
        await _catalogScreenKey.currentState?.collapseBottomMenu();
      },
    );
  }

  void _dispatchTourForActiveTab() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_currentIndex == 0) {
        await InteractiveTourService.maybeStartAutomaticTour(
          context,
          HomeScreenTour.buildConfig(keys: _tourKeys),
        );
      } else if (_currentIndex == 1) {
        if (_inventoryScreenKey.currentState != null) {
          await _inventoryScreenKey.currentState!.startActiveTabTour(
            automatic: true,
          );
        } else {
          await InteractiveTourService.maybeStartAutomaticTour(
            context,
            InventoryTour.buildConfigForTab(
              tabIndex: 0,
              keys: _inventoryTourKeys,
            ),
          );
        }
      } else if (_currentIndex == 2) {
        await InteractiveTourService.maybeStartAutomaticTour(
          context,
          _buildCatalogTourConfig(),
        );
      } else if (_currentIndex == 3) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.canManageClients) {
          await InteractiveTourService.maybeStartAutomaticTour(
            context,
            ClientTrackingTour.buildConfig(keys: _clientTrackingTourKeys),
          );
        }
      }
    });
  }

  ({List<Widget> screens, List<NavigationDestination> destinations})
  _resolveNavigationTabs(AuthProvider auth) {
    final bool isGuest = !auth.hasActiveContext;
    final bool isCommunityClient = auth.isCommunityClient;

    if (isGuest) {
      return (
        screens: [
          _HomeDashboardView(
            tourKeys: _tourKeys,
            onProfileReturned: _onProfileReturned,
          ),
          InventoryScreen(
            key: _inventoryScreenKey,
            autoTriggerTour: false,
            tourKeys: _inventoryTourKeys,
          ),
          CatalogScreen(
            key: _catalogScreenKey,
            autoTriggerTour: false,
            tourKeys: _catalogTourKeys,
          ),
        ],
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Catálogo',
          ),
        ],
      );
    }

    if (isCommunityClient) {
      return (
        screens: [
          _HomeDashboardView(
            tourKeys: _tourKeys,
            onProfileReturned: _onProfileReturned,
          ),
          CatalogScreen(
            key: _catalogScreenKey,
            autoTriggerTour: false,
            tourKeys: _catalogTourKeys,
          ),
          const ClientOrdersScreen(),
        ],
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Mi Tienda',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_mall_outlined),
            selectedIcon: Icon(Icons.local_mall),
            label: 'Mis Pedidos',
          ),
        ],
      );
    }

    return (
      screens: [
        _HomeDashboardView(
          tourKeys: _tourKeys,
          onProfileReturned: _onProfileReturned,
        ),
        InventoryScreen(
          key: _inventoryScreenKey,
          autoTriggerTour: false,
          tourKeys: _inventoryTourKeys,
        ),
        CatalogScreen(
          key: _catalogScreenKey,
          autoTriggerTour: false,
          tourKeys: _catalogTourKeys,
        ),
        if (auth.canManageClients)
          ClientTrackingScreen(
            autoTriggerTour: false,
            tourKeys: _clientTrackingTourKeys,
          ),
      ],
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Inicio',
        ),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Inventario',
        ),
        const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Catálogo',
        ),
        if (auth.canManageClients)
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
      ],
    );
  }

  Widget _buildBottomNavigationBar({
    required BuildContext context,
    required AuthProvider auth,
    required bool isDark,
    required List<NavigationDestination> destinations,
  }) {
    return NavigationBar(
      key: _tourKeys.bottomNavKey,
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        if (_currentIndex == index) return;
        _updateState(() => _currentIndex = index);
        if (index == 0 && auth.hasActiveContext) {
          auth.refreshActiveUser();
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).fetchNotifications();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (index == 0) {
            InteractiveTourService.maybeStartAutomaticTour(
              context,
              HomeScreenTour.buildConfig(keys: _tourKeys),
            );
          } else if (index == 1) {
            if (_inventoryScreenKey.currentState != null) {
              _inventoryScreenKey.currentState!.startActiveTabTour(
                automatic: true,
              );
            } else {
              InteractiveTourService.maybeStartAutomaticTour(
                context,
                InventoryTour.buildConfigForTab(
                  tabIndex: 0,
                  keys: _inventoryTourKeys,
                ),
              );
            }
          } else if (index == 2) {
            InteractiveTourService.maybeStartAutomaticTour(
              context,
              _buildCatalogTourConfig(),
            );
          } else if (index == 3 && auth.canManageClients) {
            InteractiveTourService.maybeStartAutomaticTour(
              context,
              ClientTrackingTour.buildConfig(keys: _clientTrackingTourKeys),
            );
          }
        });
      },
      backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
      elevation: 15,
      shadowColor: Colors.black,
      indicatorColor: isDark
          ? Colors.blue.withValues(alpha: 0.2)
          : Colors.blue.withValues(alpha: 0.15),
      destinations: destinations,
    );
  }
}
