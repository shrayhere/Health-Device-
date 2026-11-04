import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../repositories/auth_repository.dart';
import '../screens/device_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../services/ble_device_manager.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';

/// Unified root scaffold managing bottom navigation on mobile (Android)
/// and a responsive sidebar / NavigationRail on desktop (Windows).
///
/// Exactly 4 sections: Home | History | Device | Profile
class AppScaffold extends StatefulWidget {
  final HealthRepository repository;
  final AuthRepository? authRepository;

  const AppScaffold({super.key, required this.repository, this.authRepository});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Automatically trigger initial scan for HealthDevice if not connected
    // and sync latest readings from the cloud
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CloudSyncService.instance.syncFromCloud(repository: widget.repository);

      final ble = BleDeviceManager();
      if (!ble.isConnected &&
          !ble.isScanning.value &&
          ble.connectionState.value != BleDeviceState.connecting &&
          ble.connectionState.value != BleDeviceState.discoveringServices) {
        ble.startScan();
      }
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    final authRepo = widget.authRepository ?? LocalAuthRepository();

    final screens = [
      HomeScreen(
        repository: widget.repository,
        authRepository: widget.authRepository,
        onNavigateToDevice: () => _onDestinationSelected(2),
        onNavigateToHistory: () => _onDestinationSelected(1),
        onNavigateToProfile: () => _onDestinationSelected(3),
      ),
      HistoryScreen(repository: widget.repository),
      DeviceScreen(repository: widget.repository),
      ProfileScreen(authRepository: authRepo, repository: widget.repository),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Row(
          children: [
            _buildDesktopSidebar(context),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppTheme.borderSubtle,
            ),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: screens),
            ),
          ],
        ),
      );
    }

    // Android / Compact window layout
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          backgroundColor: AppTheme.surface,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.watch_outlined),
              selectedIcon: Icon(Icons.watch_rounded),
              label: 'Device',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    return ValueListenableBuilder<ConnectionStatus>(
      valueListenable: widget.repository.connectionStatus,
      builder: (context, connection, _) {
        return ValueListenableBuilder<BatteryData>(
          valueListenable: widget.repository.battery,
          builder: (context, battery, _) {
            final isConnected = connection.isConnected;

            return NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              backgroundColor: AppTheme.surface,
              extended: true,
              minExtendedWidth: 220,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cyan, width: 1.5),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.cyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HealthDevice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: SizedBox(
                  width: 188,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? AppTheme.goodPostureGreen
                                : AppTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isConnected)
                          Text(
                            '${battery.percentage}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: Text('History'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.watch_outlined),
                  selectedIcon: Icon(Icons.watch_rounded),
                  label: Text('Device'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
