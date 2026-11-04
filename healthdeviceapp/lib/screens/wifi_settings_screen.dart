import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';

/// Wi-Fi settings screen matching the reference designs.
/// Features:
/// - Fixed responsive SSID layout (no character splitting, ellipsis for long names)
/// - Saved Networks with connection status, priority, move up/down, edit, and delete
/// - Edit Existing Network (updates existing entry, preserves ID, never duplicates)
/// - Nearby Networks Scanner (strictly 2.4 GHz and WPA2-Personal for ESP32 compatibility)
/// - Real Signal Strength stepped bars indicator and dBm values
/// - Add from Scan with prefilled details and duplicate detection
class WiFiSettingsScreen extends StatefulWidget {
  final HealthRepository repository;

  const WiFiSettingsScreen({super.key, required this.repository});

  @override
  State<WiFiSettingsScreen> createState() => _WiFiSettingsScreenState();
}

class _WiFiSettingsScreenState extends State<WiFiSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-scan nearby networks upon opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.scanWiFi();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<WiFiState>(
      valueListenable: widget.repository.wifiState,
      builder: (context, wifiState, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Wi-Fi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: AppTheme.cyan,
                ),
                tooltip: 'Add Network',
                onPressed: () => _openAddNetwork(context, wifiState),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 20,
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Connection Section
                      const Text(
                        'Current Connection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCurrentConnectionCard(context, wifiState),
                      const SizedBox(height: 24),

                      // Saved Networks Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Saved Networks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${wifiState.savedNetworks.length} configured',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Saved Networks List
                      if (wifiState.savedNetworks.isEmpty) ...[
                        _buildEmptySavedNetworks(context),
                      ] else ...[
                        Material(
                          color: AppTheme.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: wifiState.savedNetworks.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = wifiState.savedNetworks[index];
                              final isCurrent =
                                  wifiState.isConnected &&
                                  wifiState.connectedSsid == item.ssid;
                              return _buildSavedNetworkTile(
                                context,
                                item,
                                isCurrent: isCurrent,
                                isFirst: index == 0,
                                isLast:
                                    index == wifiState.savedNetworks.length - 1,
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // "+ Add Wi-Fi" Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openAddNetwork(context, wifiState),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            '+ Add Wi-Fi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cyan,
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Nearby Networks Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Nearby Networks',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '(2.4 GHz • WPA2 only)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              onPressed: wifiState.isScanning
                                  ? null
                                  : () => widget.repository.scanWiFi(),
                              icon: wifiState.isScanning
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppTheme.cyan,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 16),
                              label: Text(
                                wifiState.isScanning ? 'Scanning...' : 'Scan',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.cyan,
                                side: const BorderSide(color: AppTheme.cyan),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Scanning Banner or Scanned Networks List
                      if (wifiState.isScanning) ...[
                        _buildScanningBanner(),
                        const SizedBox(height: 12),
                      ],

                      _buildScannedNetworksSection(context, wifiState),
                      const SizedBox(height: 16),

                      // Info Note: ESP32 2.4 GHz compatibility
                      _buildEsp32InfoNote(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentConnectionCard(
    BuildContext context,
    WiFiState wifiState,
  ) {
    final isConnected =
        wifiState.isConnected && wifiState.connectedSsid != null;

    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isConnected
                    ? AppTheme.cyan.withValues(alpha: 0.15)
                    : AppTheme.borderSubtle,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: isConnected ? AppTheme.cyan : AppTheme.textMuted,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected
                        ? (wifiState.connectedSsid ?? '')
                        : 'No Wi-Fi Connection',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? AppTheme.goodPostureGreen
                              : AppTheme.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected ? 'Connected' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? AppTheme.goodPostureGreen
                              : AppTheme.textMuted,
                        ),
                      ),
                      if (isConnected && wifiState.ipAddress != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          wifiState.ipAddress!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isConnected)
              TextButton(
                onPressed: () => widget.repository.disconnectWiFi(),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.alarmRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: const Text('Disconnect'),
              )
            else if (wifiState.savedNetworks.isNotEmpty)
              TextButton(
                onPressed: () => widget.repository.connectWiFi(
                  wifiState.savedNetworks.first.ssid,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.cyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: const Text('Connect'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySavedNetworks(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Center(
        child: Text(
          'No saved networks yet. Add one to enable ESP32 auto-connection.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  /// Saved network tile with proper responsive layout.
  /// SSID receives maximum horizontal space and never splits into individual characters.
  Widget _buildSavedNetworkTile(
    BuildContext context,
    WiFiNetworkItem item, {
    required bool isCurrent,
    required bool isFirst,
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Wi-Fi icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppTheme.cyan.withValues(alpha: 0.15)
                  : AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_rounded,
              size: 19,
              color: isCurrent ? AppTheme.cyan : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),

          // SSID, Status, Priority (Given flexible expanded space)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Actual SSID - fully responsive, ellipsized for long names, never split!
                Text(
                  item.ssid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    color: isCurrent ? AppTheme.cyan : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),

                // Connection status dot and text
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppTheme.goodPostureGreen
                            : AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCurrent ? 'Connected' : 'Saved',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isCurrent
                            ? AppTheme.goodPostureGreen
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Priority Badge
                Text(
                  'Priority ${item.priority}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action buttons: ↑ ↓ Edit Delete (Compact row)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 17),
                  tooltip: 'Move Up',
                  padding: EdgeInsets.zero,
                  color: isFirst
                      ? AppTheme.textMuted.withValues(alpha: 0.3)
                      : AppTheme.textSecondary,
                  onPressed: isFirst
                      ? null
                      : () => widget.repository.moveWiFiPriorityUp(item.id),
                ),
              ),
              SizedBox(
                width: 30,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 17),
                  tooltip: 'Move Down',
                  padding: EdgeInsets.zero,
                  color: isLast
                      ? AppTheme.textMuted.withValues(alpha: 0.3)
                      : AppTheme.textSecondary,
                  onPressed: isLast
                      ? null
                      : () => widget.repository.moveWiFiPriorityDown(item.id),
                ),
              ),
              SizedBox(
                width: 30,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  tooltip: 'Edit Network',
                  padding: EdgeInsets.zero,
                  color: AppTheme.textSecondary,
                  onPressed: () => _openEditNetwork(context, item),
                ),
              ),
              SizedBox(
                width: 30,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  tooltip: 'Delete Network',
                  padding: EdgeInsets.zero,
                  color: AppTheme.alarmRed,
                  onPressed: () => widget.repository.deleteWiFiNetwork(item.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Scanning for nearby networks...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Showing only 2.4 GHz • WPA2-Personal',
                  style: TextStyle(fontSize: 12, color: AppTheme.cyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedNetworksSection(
    BuildContext context,
    WiFiState wifiState,
  ) {
    final scanned = wifiState.scannedNetworks;

    if (scanned.isEmpty && !wifiState.isScanning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.wifi_find_rounded,
              size: 36,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 10),
            const Text(
              'No compatible 2.4 GHz networks detected.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap Scan above to discover nearby 2.4 GHz access points.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: scanned.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = scanned[index];
          return _buildScannedNetworkTile(context, item, wifiState);
        },
      ),
    );
  }

  Widget _buildScannedNetworkTile(
    BuildContext context,
    WiFiNetworkItem item,
    WiFiState wifiState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Real Signal Strength Stepped Bars Indicator
          SizedBox(width: 32, child: _buildSignalBars(item.rssi)),
          const SizedBox(width: 12),

          // SSID, Security, Frequency & dBm
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.ssid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.securityType} • ${item.frequency}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.rssi != null ? "${item.rssi} dBm" : "- dBm"} (${item.signalLabel})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // "[Add]" Button
          FilledButton(
            onPressed: () => _openAddFromScan(context, item, wifiState),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlueLight,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(60, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4-bar stepped signal indicator matching reference specifications:
  /// -30 to -50 dBm = Very Strong (4 bars)
  /// -50 to -65 dBm = Strong (3 bars)
  /// -65 to -75 dBm = Medium (2 bars)
  /// -75 to -85 dBm = Weak (1 bar)
  /// -85 to -100 dBm = Very Weak (0 bars)
  Widget _buildSignalBars(int? rssi) {
    int activeBars = 3;
    if (rssi != null) {
      if (rssi >= -50) {
        activeBars = 4;
      } else if (rssi >= -65) {
        activeBars = 3;
      } else if (rssi >= -75) {
        activeBars = 2;
      } else if (rssi >= -85) {
        activeBars = 1;
      } else {
        activeBars = 0;
      }
    }

    const heights = [6.0, 10.0, 14.0, 18.0];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isFilled = i < activeBars;
        return Container(
          width: 3.5,
          height: heights[i],
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            color: isFilled ? AppTheme.cyan : AppTheme.borderSubtle,
            borderRadius: BorderRadius.circular(1.2),
          ),
        );
      }),
    );
  }

  Widget _buildEsp32InfoNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.cyan),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing only 2.4 GHz networks with WPA2-Personal security (ESP32 compatible).',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddNetwork(BuildContext context, WiFiState wifiState) {
    showDialog(
      context: context,
      builder: (ctx) => _AddWiFiDialog(
        repository: widget.repository,
        defaultPriority: wifiState.savedNetworks.length + 1,
      ),
    );
  }

  void _openAddFromScan(
    BuildContext context,
    WiFiNetworkItem scanned,
    WiFiState wifiState,
  ) {
    // Check if network already exists
    final existing = wifiState.savedNetworks
        .cast<WiFiNetworkItem?>()
        .firstWhere(
          (n) => n?.ssid.toLowerCase() == scanned.ssid.toLowerCase(),
          orElse: () => null,
        );

    showDialog(
      context: context,
      builder: (ctx) => _AddWiFiDialog(
        repository: widget.repository,
        prefilledScanned: scanned,
        existingMatch: existing,
        defaultPriority:
            existing?.priority ?? (wifiState.savedNetworks.length + 1),
      ),
    );
  }

  void _openEditNetwork(BuildContext context, WiFiNetworkItem existing) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _EditWiFiDialog(repository: widget.repository, network: existing),
    );
  }
}

/// Screen 3: Add Wi-Fi Network Dialog
class _AddWiFiDialog extends StatefulWidget {
  final HealthRepository repository;
  final WiFiNetworkItem? prefilledScanned;
  final WiFiNetworkItem? existingMatch;
  final int defaultPriority;

  const _AddWiFiDialog({
    required this.repository,
    this.prefilledScanned,
    this.existingMatch,
    required this.defaultPriority,
  });

  @override
  State<_AddWiFiDialog> createState() => _AddWiFiDialogState();
}

class _AddWiFiDialogState extends State<_AddWiFiDialog> {
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;
  late int _priority;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final initialSsid =
        widget.existingMatch?.ssid ?? widget.prefilledScanned?.ssid ?? '';
    final initialPass = widget.existingMatch?.password ?? '';

    _ssidController = TextEditingController(text: initialSsid);
    _passwordController = TextEditingController(text: initialPass);
    _priority = widget.defaultPriority.clamp(1, 10);
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanned = widget.prefilledScanned;

    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Add Wi-Fi Network',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Network Name (SSID)
              const Text(
                'Network Name (SSID)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _ssidController,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surface,
                  hintText: 'Enter SSID',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlueLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Security Read-Only Badge
              const Text(
                'Security',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  '${scanned?.securityType ?? "WPA2-Personal"} (${scanned?.frequency ?? "2.4 GHz"})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Signal Strength Row (if available)
              if (scanned?.rssi != null) ...[
                const Text(
                  'Signal Strength',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildDialogSignalBars(scanned!.rssi ?? -60),
                    const SizedBox(width: 10),
                    Text(
                      '${scanned.rssi} dBm (${scanned.signalLabel})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Password
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surface,
                  hintText: 'Enter Wi-Fi password',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlueLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Priority Selector
              const Text(
                'Priority',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _priority,
                    dropdownColor: AppTheme.card,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((p) {
                      return DropdownMenuItem<int>(
                        value: p,
                        child: Text(p == 1 ? '1 (Highest)' : '$p'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons: Add & Save / Cancel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    final ssid = _ssidController.text.trim();
                    if (ssid.isEmpty) return;
                    final pass = _passwordController.text;

                    final item = WiFiNetworkItem(
                      id:
                          widget.existingMatch?.id ??
                          'wifi_${DateTime.now().millisecondsSinceEpoch}',
                      ssid: ssid,
                      password: pass,
                      priority: _priority,
                      enabled: true,
                      securityType: scanned?.securityType ?? 'WPA2-Personal',
                      frequency: scanned?.frequency ?? '2.4 GHz',
                      rssi: scanned?.rssi,
                    );

                    widget.repository.addWiFiNetwork(item);
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlueLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Add & Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogSignalBars(int rssi) {
    int activeBars = 3;
    if (rssi >= -50) {
      activeBars = 4;
    } else if (rssi >= -65) {
      activeBars = 3;
    } else if (rssi >= -75) {
      activeBars = 2;
    } else if (rssi >= -85) {
      activeBars = 1;
    } else {
      activeBars = 0;
    }

    const heights = [6.0, 10.0, 14.0, 18.0];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isFilled = i < activeBars;
        return Container(
          width: 3.5,
          height: heights[i],
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            color: isFilled ? AppTheme.cyan : AppTheme.borderSubtle,
            borderRadius: BorderRadius.circular(1.2),
          ),
        );
      }),
    );
  }
}

/// Screen 4: Edit Existing Network Dialog
/// Critical Requirement:
/// - Changing password or SSID updates the existing network entry
/// - Preserves the same network ID
/// - Never duplicates
class _EditWiFiDialog extends StatefulWidget {
  final HealthRepository repository;
  final WiFiNetworkItem network;

  const _EditWiFiDialog({required this.repository, required this.network});

  @override
  State<_EditWiFiDialog> createState() => _EditWiFiDialogState();
}

class _EditWiFiDialogState extends State<_EditWiFiDialog> {
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;
  late int _priority;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController(text: widget.network.ssid);
    _passwordController = TextEditingController(text: widget.network.password);
    _priority = widget.network.priority.clamp(1, 10);
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Edit Wi-Fi Network',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Network Name (SSID)
              const Text(
                'Network Name (SSID)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _ssidController,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlueLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Password with reveal/hide eye toggle
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surface,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlueLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Priority
              const Text(
                'Priority',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _priority,
                    dropdownColor: AppTheme.card,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((p) {
                      return DropdownMenuItem<int>(
                        value: p,
                        child: Text(p == 1 ? '1 (Highest)' : '$p'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Save Changes & Cancel Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    final newSsid = _ssidController.text.trim();
                    if (newSsid.isEmpty) return;
                    final newPass = _passwordController.text;

                    // Update existing entry, preserving original ID
                    final updated = widget.network.copyWith(
                      ssid: newSsid,
                      password: newPass,
                      priority: _priority,
                    );
                    widget.repository.updateWiFiNetwork(updated);
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlueLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
