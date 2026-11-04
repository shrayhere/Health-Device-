import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../theme/app_theme.dart';

/// Reusable interactive RGB color picker for physical 4-pin RGB LEDs.
/// Features:
/// - Interactive HSV Color Wheel with draggable touch thumb
/// - Brightness / Value slider
/// - Live color preview chip with HEX display
/// - Fine-tuning sliders & numeric displays for R, G, B channels (0–255)
/// - Reset to initial & Save/Apply actions
class RgbColorPicker extends StatefulWidget {
  final RgbColor initialColor;
  final ValueChanged<RgbColor> onColorChanged;
  final VoidCallback? onCancel;
  final String title;

  const RgbColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.onCancel,
    this.title = 'Select RGB LED Color',
  });

  @override
  State<RgbColorPicker> createState() => _RgbColorPickerState();
}

class _RgbColorPickerState extends State<RgbColorPicker> {
  late double _hue; // 0..360
  late double _saturation; // 0..1
  late double _value; // 0..1

  late int _r; // 0..255
  late int _g; // 0..255
  late int _b; // 0..255

  @override
  void initState() {
    super.initState();
    _r = widget.initialColor.red.clamp(0, 255);
    _g = widget.initialColor.green.clamp(0, 255);
    _b = widget.initialColor.blue.clamp(0, 255);

    final hsv = HSVColor.fromColor(widget.initialColor.toColor());
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value.clamp(0.01, 1.0);
  }

  void _updateFromHsv(double h, double s, double v) {
    setState(() {
      _hue = h.clamp(0.0, 360.0);
      _saturation = s.clamp(0.0, 1.0);
      _value = v.clamp(0.0, 1.0);

      final color = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
      final argb = color.toARGB32();
      _r = (argb >> 16) & 0xFF;
      _g = (argb >> 8) & 0xFF;
      _b = argb & 0xFF;
    });
  }

  void _updateFromRgb(int r, int g, int b) {
    setState(() {
      _r = r.clamp(0, 255);
      _g = g.clamp(0, 255);
      _b = b.clamp(0, 255);

      final color = Color.fromARGB(255, _r, _g, _b);
      final hsv = HSVColor.fromColor(color);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    });
  }

  void _resetToDefault() {
    setState(() {
      _r = widget.initialColor.red;
      _g = widget.initialColor.green;
      _b = widget.initialColor.blue;
      final hsv = HSVColor.fromColor(widget.initialColor.toColor());
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value.clamp(0.01, 1.0);
    });
  }

  RgbColor get _currentColor => RgbColor(red: _r, green: _g, blue: _b);

  @override
  Widget build(BuildContext context) {
    final currentColorObj = _currentColor.toColor();
    final hexCode = _currentColor.toHexString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: Title & Close/Reset
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _resetToDefault,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
              label: const Text(
                'Reset',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Color Wheel & Brightness Slider Container
        LayoutBuilder(
          builder: (context, constraints) {
            final double wheelSize = math.min(
              constraints.maxWidth * 0.68,
              190.0,
            );
            return Center(
              child: SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: _ColorWheelGesture(
                  hue: _hue,
                  saturation: _saturation,
                  size: wheelSize,
                  onHsvChanged: (h, s) => _updateFromHsv(h, s, _value),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),

        // Brightness / Value Slider
        Row(
          children: [
            const Icon(
              Icons.brightness_medium_rounded,
              size: 18,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            const Text(
              'Brightness',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${(_value * 100).round()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppTheme.primaryBlueLight,
            inactiveTrackColor: AppTheme.borderSubtle,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: _value,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => _updateFromHsv(_hue, _saturation, val),
          ),
        ),
        const SizedBox(height: 12),

        // Preview & Values Card
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Live Color Chip with subtle glow
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: currentColorObj,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentColorObj.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Values Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          hexCode,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.borderSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PWM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R: $_r  •  G: $_g  •  B: $_b',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Fine-tuning R, G, B channel sliders (0–255)
        _buildChannelSlider(
          label: 'R',
          value: _r,
          color: const Color(0xFFEF4444),
          onChanged: (v) => _updateFromRgb(v, _g, _b),
        ),
        _buildChannelSlider(
          label: 'G',
          value: _g,
          color: const Color(0xFF10B981),
          onChanged: (v) => _updateFromRgb(_r, v, _b),
        ),
        _buildChannelSlider(
          label: 'B',
          value: _b,
          color: const Color(0xFF3B82F6),
          onChanged: (v) => _updateFromRgb(_r, _g, v),
        ),
        const SizedBox(height: 16),

        // Action Buttons: Cancel and Apply/Save
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.onCancel?.call();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  widget.onColorChanged(_currentColor);
                  Navigator.of(context).pop(_currentColor);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlueLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Apply Color',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelSlider({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: color.withValues(alpha: 0.8),
                inactiveTrackColor: AppTheme.borderSubtle,
                thumbColor: color,
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 255,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gesture detector and custom canvas painter for the circular Hue-Saturation wheel.
class _ColorWheelGesture extends StatelessWidget {
  final double hue;
  final double saturation;
  final double size;
  final void Function(double hue, double saturation) onHsvChanged;

  const _ColorWheelGesture({
    required this.hue,
    required this.saturation,
    required this.size,
    required this.onHsvChanged,
  });

  void _handleTouch(Offset localPosition) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final radius = size / 2;

    final distance = math.sqrt(dx * dx + dy * dy);
    final newSaturation = (distance / radius).clamp(0.0, 1.0);

    // Calculate angle in degrees: 0 = East, 90 = South, etc.
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    onHsvChanged(angle, newSaturation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (details) => _handleTouch(details.localPosition),
      onPanUpdate: (details) => _handleTouch(details.localPosition),
      child: CustomPaint(
        size: Size(size, size),
        painter: _ColorWheelPainter(hue: hue, saturation: saturation),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;

  _ColorWheelPainter({required this.hue, required this.saturation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw SweepGradient for Hue
    final sweepGradient = const SweepGradient(
      colors: [
        Color(0xFFFF0000), // Red 0°
        Color(0xFFFFFF00), // Yellow 60°
        Color(0xFF00FF00), // Green 120°
        Color(0xFF00FFFF), // Cyan 180°
        Color(0xFF0000FF), // Blue 240°
        Color(0xFFFF00FF), // Magenta 300°
        Color(0xFFFF0000), // Red 360°
      ],
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Radial gradient from White (center, saturation=0) to Transparent (outer, saturation=1)
    final radialGradient = RadialGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
    );

    final radialPaint = Paint()
      ..shader = radialGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, radialPaint);

    // 3. Subtle boundary ring
    final borderPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Indicator Thumb for current (Hue, Saturation)
    final angleRad = hue * math.pi / 180;
    final thumbDist = saturation * radius;
    final thumbX = center.dx + thumbDist * math.cos(angleRad);
    final thumbY = center.dy + thumbDist * math.sin(angleRad);
    final thumbCenter = Offset(thumbX, thumbY);

    // Outer thumb ring (white + dark shadow)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(thumbCenter, 9, shadowPaint);

    final thumbRing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(thumbCenter, 8, thumbRing);

    // Inner preview circle
    final currentColor = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();
    final thumbFill = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 6, thumbFill);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue || oldDelegate.saturation != saturation;
  }
}

/// Helper function to display the RGB color picker modal/dialog anywhere in the app.
Future<RgbColor?> showRgbColorPickerDialog({
  required BuildContext context,
  required RgbColor initialColor,
  String title = 'Select RGB LED Color',
}) async {
  final isDesktop = MediaQuery.of(context).size.width >= 700;

  if (isDesktop) {
    return showDialog<RgbColor>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RgbColorPicker(
                initialColor: initialColor,
                title: title,
                onColorChanged: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        );
      },
    );
  } else {
    return showModalBottomSheet<RgbColor>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                RgbColorPicker(
                  initialColor: initialColor,
                  title: title,
                  onColorChanged: (_) {},
                  onCancel: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
