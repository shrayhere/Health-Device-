import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/rgb_color_picker.dart';

/// Reminders management screen (Settings -> Reminders).
/// Displays reminders list, supports adding, editing, deleting, toggle enable/disable,
/// schedules (Daily, Hourly, Weekdays, Weekends), sound on/off, and custom RGB LED color.
class RemindersScreen extends StatelessWidget {
  final HealthRepository repository;

  const RemindersScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<List<ReminderItem>>(
      valueListenable: repository.reminders,
      builder: (context, reminders, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Reminders',
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
                tooltip: 'Add Reminder',
                onPressed: () => _openReminderEditor(context),
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
                            'Active Reminders',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${reminders.where((r) => r.enabled).length} active',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.cyan,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (reminders.isEmpty) ...[
                        _buildEmptyState(context),
                      ] else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reminders.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final reminder = reminders[index];
                            return _buildReminderCard(context, reminder);
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
            Icons.notifications_off_rounded,
            size: 40,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Reminders Configured',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add reminders to drink water, stretch, or check posture during the day.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _openReminderEditor(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Reminder'),
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

  Widget _buildReminderCard(BuildContext context, ReminderItem reminder) {
    final ledColorObj = reminder.ledColor.toColor();

    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openReminderEditor(context, existing: reminder),
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
                          reminder.time,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: reminder.enabled
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: reminder.enabled
                                ? AppTheme.cyan
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: reminder.enabled,
                    onChanged: (val) =>
                        repository.toggleReminder(reminder.id, val),
                    activeThumbColor: AppTheme.primaryBlueLight,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Schedule Badge
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
                      reminder.repeatSchedule,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sound icon
                  Icon(
                    reminder.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 16,
                    color: reminder.soundEnabled
                        ? AppTheme.textSecondary
                        : AppTheme.textMuted,
                  ),
                  const Spacer(),
                  // LED Color preview
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
                    reminder.ledColor.toHexString(),
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

  void _openReminderEditor(BuildContext context, {ReminderItem? existing}) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _ReminderEditorDialog(repository: repository, reminder: existing),
    );
  }
}

class _ReminderEditorDialog extends StatefulWidget {
  final HealthRepository repository;
  final ReminderItem? reminder;

  const _ReminderEditorDialog({required this.repository, this.reminder});

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  late TextEditingController _nameController;
  late TimeOfDay _selectedTime;
  late String _repeatSchedule;
  late bool _soundEnabled;
  late RgbColor _ledColor;

  static const _schedules = ['Daily', 'Hourly', 'Weekdays', 'Weekends', 'Once'];

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _nameController = TextEditingController(text: r?.name ?? 'Drink Water');

    if (r != null) {
      _selectedTime = _parseTimeOfDay(r.time);
      _repeatSchedule = r.repeatSchedule;
      _soundEnabled = r.soundEnabled;
      _ledColor = r.ledColor;
    } else {
      _selectedTime = const TimeOfDay(hour: 14, minute: 0);
      _repeatSchedule = 'Daily';
      _soundEnabled = true;
      _ledColor = const RgbColor.cyan();
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
      return const TimeOfDay(hour: 14, minute: 0);
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
    final isNew = widget.reminder == null;

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
                isNew ? 'New Reminder' : 'Edit Reminder',
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

              // Reminder Name TextField
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'Reminder Name / Purpose',
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

              // Repeat Schedule Selector
              const Text(
                'Schedule',
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
                children: _schedules.map((schedule) {
                  final isSelected = _repeatSchedule == schedule;
                  return ChoiceChip(
                    label: Text(
                      schedule,
                      style: TextStyle(
                        fontSize: 12,
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
                      if (val) setState(() => _repeatSchedule = schedule);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Sound Toggle
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

              // LED Color (Opens RGB Color Wheel Picker)
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
                        title: 'Reminder LED Color',
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

              // Actions
              Row(
                children: [
                  if (!isNew) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.alarmRed,
                      ),
                      tooltip: 'Delete Reminder',
                      onPressed: () {
                        widget.repository.deleteReminder(widget.reminder!.id);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reminder deleted'),
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
                            ? 'Reminder'
                            : _nameController.text.trim();
                        final timeStr = _formatTimeOfDay(_selectedTime);

                        if (isNew) {
                          final newReminder = ReminderItem(
                            id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            time: timeStr,
                            enabled: true,
                            repeatSchedule: _repeatSchedule,
                            soundEnabled: _soundEnabled,
                            ledColor: _ledColor,
                          );
                          widget.repository.addReminder(newReminder);
                        } else {
                          final updated = widget.reminder!.copyWith(
                            name: name,
                            time: timeStr,
                            repeatSchedule: _repeatSchedule,
                            soundEnabled: _soundEnabled,
                            ledColor: _ledColor,
                          );
                          widget.repository.updateReminder(updated);
                        }
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNew
                                  ? 'Reminder "$name" created & synced'
                                  : 'Reminder "$name" updated & synced',
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
                      child: const Text('Save Reminder'),
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
