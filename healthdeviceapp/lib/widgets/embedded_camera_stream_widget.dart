import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Embedded Camera Stream Widget that renders the live AI Posture camera
/// feed directly inside the Flutter UI without popping up any external window.
class EmbeddedCameraStreamWidget extends StatefulWidget {
  final String streamUrl;
  final bool isConnected;
  final bool personDetected;
  final int postureScore;
  final String status;
  final Color statusColor;

  const EmbeddedCameraStreamWidget({
    super.key,
    required this.streamUrl,
    required this.isConnected,
    required this.personDetected,
    required this.postureScore,
    required this.status,
    required this.statusColor,
  });

  @override
  State<EmbeddedCameraStreamWidget> createState() =>
      _EmbeddedCameraStreamWidgetState();
}

class _EmbeddedCameraStreamWidgetState extends State<EmbeddedCameraStreamWidget> {
  HttpClient? _client;
  StreamSubscription<List<int>>? _subscription;
  Timer? _reconnectTimer;
  Timer? _snapshotPollingTimer;
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCollapsed = false;
  final List<int> _buffer = [];

  @override
  void initState() {
    super.initState();
    if (widget.isConnected) {
      _startStream();
    }
  }

  @override
  void didUpdateWidget(covariant EmbeddedCameraStreamWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected != oldWidget.isConnected) {
      if (widget.isConnected) {
        _startStream();
      } else {
        _stopStream();
      }
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _snapshotPollingTimer?.cancel();
    _snapshotPollingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    _buffer.clear();
    if (mounted) {
      setState(() {
        _currentFrame = null;
        _isLoading = true;
        _hasError = false;
      });
    }
  }

  void _startStream() {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _stopStream();
    _connectMjpeg();
  }

  Future<void> _connectMjpeg() async {
    if (!mounted || !widget.isConnected) return;

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      _client = client;
      final request = await client.getUrl(Uri.parse(widget.streamUrl));
      request.headers.set('Accept', 'multipart/x-mixed-replace');
      final response = await request.close();

      if (response.statusCode != 200) {
        _fallbackToPolling();
        return;
      }

      _subscription = response.listen(
        (chunk) {
          _buffer.addAll(chunk);

          // Find full JPEG frames delimited by SOI (0xFF, 0xD8) and EOI (0xFF, 0xD9)
          while (true) {
            final start = _indexOfJpegStart(_buffer);
            if (start == -1) {
              if (_buffer.length > 512 * 1024) _buffer.clear();
              break;
            }

            final end = _indexOfJpegEnd(_buffer, start + 2);
            if (end == -1) {
              // Frame incomplete, await more bytes
              break;
            }

            final frameBytes = Uint8List.fromList(_buffer.sublist(start, end));
            _buffer.removeRange(0, end);

            if (mounted) {
              setState(() {
                _currentFrame = frameBytes;
                _isLoading = false;
                _hasError = false;
              });
            }
          }
        },
        onError: (e) {
          _fallbackToPolling();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _fallbackToPolling();
    }
  }

  int _indexOfJpegStart(List<int> bytes) {
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) return i;
    }
    return -1;
  }

  int _indexOfJpegEnd(List<int> bytes, int startOffset) {
    for (int i = startOffset; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) return i + 2;
    }
    return -1;
  }

  void _fallbackToPolling() {
    _subscription?.cancel();
    _subscription = null;
    _snapshotPollingTimer?.cancel();

    // Poll snapshot endpoint every 65ms (~15 FPS fallback)
    _snapshotPollingTimer =
        Timer.periodic(const Duration(milliseconds: 65), (_) async {
      if (!mounted || !widget.isConnected) return;
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 250);
        final baseUrl = widget.streamUrl.replaceAll('/video_feed', '');
        final request = await client.getUrl(Uri.parse('$baseUrl/frame.jpg'));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          if (mounted && bytes.isNotEmpty) {
            setState(() {
              _currentFrame = bytes;
              _isLoading = false;
              _hasError = false;
            });
          }
        }
        client.close();
      } catch (_) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && widget.isConnected) {
        _startStream();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.isConnected;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isConnected
              ? widget.statusColor.withValues(alpha: 0.45)
              : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: widget.statusColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? (widget.personDetected ? AppTheme.neonGreen : AppTheme.statusOrange)
                        : AppTheme.textMuted,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: (widget.personDetected ? AppTheme.neonGreen : AppTheme.statusOrange)
                                  .withValues(alpha: 0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live In-App Vision',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      widget.personDetected
                          ? '${widget.postureScore}% • ${widget.status}'
                          : 'AWAY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: widget.statusColor,
                      ),
                    ),
                  ),
                const Spacer(),
                if (isConnected)
                  IconButton(
                    tooltip: _isCollapsed ? 'Expand Vision' : 'Collapse Vision',
                    icon: Icon(
                      _isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _isCollapsed = !_isCollapsed;
                      });
                    },
                  ),
              ],
            ),
          ),

          // Collapsible Video Player Area
          if (!_isCollapsed)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: isConnected ? 320 : 180,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Live Frame Feed
                  if (isConnected && _currentFrame != null)
                    Image.memory(
                      _currentFrame!,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    )
                  else if (isConnected && _isLoading)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.cyan,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Connecting to webcam stream...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Offline / Turned OFF Placeholder
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.surface.withValues(alpha: 0.6),
                            ),
                            child: const Icon(
                              Icons.videocam_off_rounded,
                              size: 32,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'AI Camera is Currently Turned OFF',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "Turn ON" above to start live in-app posture vision.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 2. Overlay Banner when person is Away / Not visible
                  if (isConnected && !widget.personDetected)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.card.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.statusOrange.withValues(alpha: 0.6),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_off_rounded,
                                  color: AppTheme.statusOrange,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Person Not Visible In Frame',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.statusOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Live Corner Watermark
                  if (isConnected && _currentFrame != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fiber_manual_record,
                              size: 8,
                              color: AppTheme.heartRateRed,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'LIVE AI',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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
}
