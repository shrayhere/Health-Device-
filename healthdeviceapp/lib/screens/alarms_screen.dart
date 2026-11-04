import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/rgb_color_picker.dart';

/// Alarms management screen (Settings -> Alarms).
/// Displays alarms, supports adding, editing, deleting, toggle enable/disable,
/// sound on/off, repeat days, and RGB LED color wheel selection.
class AlarmsScreen extends StatelessWidget {
  final HealthRepository repository;

  const AlarmsScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<List<AlarmItem>>(
      valueListenable: repository.alarms,
      builder: (context, alarms, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Alarms',
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
                tooltip: 'Add Alarm',
                onPressed: () => _openAlarmEditor(context),
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
                      // Subheader
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Configured Alarms',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${alarms.where((a) => a.enabled).length} active',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.cyan,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (alarms.isEmpty) ...[
                        _buildEmptyState(context),
                      ] else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: alarms.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final alarm = alarms[index];
                            return _buildAlarmCard(context, alarm);
                          },
                        ),
                      ],
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.alarm_off_rounded,
            size: 40,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Alarms Configured',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create an alarm to wake up or trigger high-priority alerts on HealthDevice.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _openAlarmEditor(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Alarm'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlueLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, AlarmItem alarm) {
    final ledColorObj = alarm.ledColor.toColor();

    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAlarmEditor(context, existing: alarm),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alarm.time,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: alarm.enabled
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alarm.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: alarm.enabled
                                ? AppTheme.cyan
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: alarm.enabled,
                    onChanged: (val) => repository.toggleAlarm(alarm.id, val),
                    activeThumbColor: AppTheme.primaryBlueLight,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Repeat days badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      alarm.repeatDays.isEmpty
                          ? 'Once'
                          : alarm.repeatDays.join(' '),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sound indicator
                  Icon(
                    alarm.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 16,
                    color: alarm.soundEnabled
                        ? AppTheme.textSecondary
                        : AppTheme.textMuted,
                  ),
                  const Spacer(),
                  // LED color preview
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: ledColorObj,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ledColorObj.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    alarm.ledColor.toHexString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAlarmEditor(BuildContext context, {AlarmItem? existing}) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _AlarmEditorDialog(repository: repository, alarm: existing),
    );
  }
}

class _AlarmEditorDialog extends StatefulWidget {
  final HealthRepository repository;
  final AlarmItem? alarm;

  const _AlarmEditorDialog({required this.repository, this.alarm});

  @override
  State<_AlarmEditorDialog> createState() => _AlarmEditorDialogState();
}

class _AlarmEditorDialogState extends State<_AlarmEditorDialog> {
  late TextEditingController _nameController;
  late TimeOfDay _selectedTime;
  late List<String> _selectedDays;
  late bool _soundEnabled;
  late RgbColor _ledColor;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _nameController = TextEditingController(text: a?.name ?? 'Wake Up');

    if (a != null) {
      _selectedTime = _parseTimeOfDay(a.time);
      _selectedDays = List.from(a.repeatDays);
      _soundEnabled = a.soundEnabled;
      _ledColor = a.ledColor;
    } else {
      _selectedTime = const TimeOfDay(hour: 7, minute: 30);
      _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
      _soundEnabled = true;
      _ledColor = const RgbColor.redColor();
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && h < 12) {
        h += 12;
      } else if (parts.length > 1 &&
          parts[1].toUpperCase() == 'AM' &&
          h == 12) {
        h = 0;
      }
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 7, minute: 30);
    }
  }

  String _formatTimeNumber(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _openTimePicker(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.primaryBlueLight,
                onPrimary: Colors.white,
                surface: AppTheme.card,
                onSurface: AppTheme.textPrimary,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: AppTheme.card,
                hourMinuteTextColor: AppTheme.cyan,
                dayPeriodTextColor: AppTheme.textPrimary,
                dayPeriodColor: AppTheme.primaryBlueLight,
                dialHandColor: AppTheme.primaryBlueLight,
                dialBackgroundColor: AppTheme.surface,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Widget _buildPeriodToggle({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryBlueLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlueLight.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.alarm == null;

    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNew ? 'New Alarm' : 'Edit Alarm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 18),

              // Time & AM/PM Switch Row
              Row(
                children: [
                  // Clickable Time Display (opens 12h TimePicker)
                  Expanded(
                    child: InkWell(
                      onTap: () => _openTimePicker(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: AppTheme.cyan,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimeNumber(_selectedTime),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.cyan,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Dedicated AM / PM Switch Buttons
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPeriodToggle(
                          label: 'AM',
                          isActive: _selectedTime.period == DayPeriod.am,
                          onTap: () {
                            if (_selectedTime.period != DayPeriod.am) {
                              setState(() {
                                final newHour = _selectedTime.hour % 12;
                                _selectedTime = TimeOfDay(
                                  hour: newHour,
                                  minute: _selectedTime.minute,
                                );
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        _buildPeriodToggle(
                          label: 'PM',
                          isActive: _selectedTime.period == DayPeriod.pm,
                          onTap: () {
                            if (_selectedTime.period != DayPeriod.pm) {
                              setState(() {
                                final newHour = (_selectedTime.hour % 12) + 12;
                                _selectedTime = TimeOfDay(
                                  hour: newHour,
                                  minute: _selectedTime.minute,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Alarm Name TextField
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'Alarm Name / Label',
                  labelStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
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
              const SizedBox(height: 16),

              // Repeat Days Chips
              const Text(
                'Repeat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _days.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppTheme.primaryBlue,
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryBlueLight
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Sound Toggle Tile
              SwitchListTile(
                value: _soundEnabled,
                onChanged: (val) => setState(() => _soundEnabled = val),
                title: const Text(
                  'Sound / Beep',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                activeThumbColor: AppTheme.primaryBlueLight,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // LED Color Selector (Opens RGB Color Wheel Picker)
              Row(
                children: [
                  const Text(
                    'LED Diode Color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showRgbColorPickerDialog(
                        context: context,
                        initialColor: _ledColor,
                        title: 'Alarm LED Color',
                      );
                      if (picked != null) {
                        setState(() => _ledColor = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _ledColor.toColor(),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _ledColor.toColor().withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _ledColor.toHexString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  if (!isNew) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.alarmRed,
                      ),
                      tooltip: 'Delete Alarm',
                      onPressed: () {
                        widget.repository.deleteAlarm(widget.alarm!.id);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alarm deleted'),
                            backgroundColor: AppTheme.surface,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final name = _nameController.text.trim().isEmpty
                            ? 'Alarm'
                            : _nameController.text.trim();
                        final timeStr = _formatTimeOfDay(_selectedTime);

                        if (isNew) {
                          final newAlarm = AlarmItem(
                            id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            time: timeStr,
                            enabled: true,
                            repeatDays: _selectedDays,
                            soundEnabled: _soundEnabled,
                            ledColor: _ledColor,
                          );
                          widget.repository.addAlarm(newAlarm);
                        } else {
                          final updated = widget.alarm!.copyWith(
                            name: name,
                            time: timeStr,
                            repeatDays: _selectedDays,
                            soundEnabled: _soundEnabled,
                            ledColor: _ledColor,
                          );
                          widget.repository.updateAlarm(updated);
                        }
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNew
                                  ? 'Alarm "$name" created & synced'
                                  : 'Alarm "$name" updated & synced',
                            ),
                            backgroundColor: AppTheme.goodPostureGreen,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlueLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Save Alarm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
