import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';
import '../services/health_calculation_engine.dart';
import '../services/webcam_posture_service.dart';
import '../theme/app_theme.dart';
import '../utils/dob_input_formatter.dart';
import '../widgets/app_avatar_widget.dart';
import 'settings_screen.dart';

/// Screen: Profile screen (4th bottom tab).
///
/// Contains:
/// - Custom avatar selection & preview
/// - User identity header
/// - Personal Biometrics (Name, DOB formatted as DD/MM/YYYY with smart manual entry,
///   Age calculation, Height, Weight, Biological Sex, Measurement Units)
/// - Health & Goals Engine (Deterministic calculations: BMI, BMR, TDEE, Daily Calorie Target, Step Goal)
/// - Top-right Settings Gear: navigates to App & Account Settings (Profile Settings Menu)
class ProfileScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final HealthRepository repository;

  const ProfileScreen({
    super.key,
    required this.authRepository,
    required this.repository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  DateTime? _selectedDob;
  String _selectedSex = 'Prefer not to say';
  String _selectedUnits = 'Metric (cm, kg)';
  String _selectedGoal = 'General wellness';
  String _avatarId = 'avatar_pulse_cyan';
  bool _isSaving = false;
  String? _dobError;

  @override
  void initState() {
    super.initState();
    final profile = widget.authRepository.currentProfile.value;
    final user = widget.authRepository.currentUser.value;

    _nameController = TextEditingController(
      text: profile?.name ?? user?.name ?? '',
    );
    _selectedDob = profile?.dateOfBirth;
    _dobController = TextEditingController(
      text: _selectedDob != null ? DobInputFormatter.format(_selectedDob!) : '',
    );
    _heightController = TextEditingController(
      text: profile?.heightCm != null
          ? profile!.heightCm!.toInt().toString()
          : '',
    );
    _weightController = TextEditingController(
      text: profile?.weightKg != null
          ? profile!.weightKg!.toInt().toString()
          : '',
    );
    _selectedSex = profile?.biologicalSex ?? 'Prefer not to say';
    _selectedUnits = profile?.units ?? 'Metric (cm, kg)';
    _selectedGoal = profile?.primaryGoal ?? 'General wellness';
    _avatarId = profile?.avatarId ?? 'avatar_pulse_cyan';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDob ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryBlueLight,
              surface: AppTheme.card,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DobInputFormatter.format(picked);
        _dobError = null;
      });
    }
  }

  void _onDobTextChanged(String value) {
    if (value.length == 10) {
      final parsed = DobInputFormatter.parseAndValidate(value);
      if (parsed != null) {
        setState(() {
          _selectedDob = parsed;
          _dobError = null;
        });
      } else {
        setState(() {
          _dobError = 'Invalid date. Use DD/MM/YYYY up to current year.';
        });
      }
    } else {
      if (_dobError != null) {
        setState(() => _dobError = null);
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    DateTime? dob = _selectedDob;
    if (_dobController.text.isNotEmpty) {
      dob = DobInputFormatter.parseAndValidate(_dobController.text.trim());
      if (dob == null) {
        setState(() {
          _dobError = 'Please enter a valid past date (DD/MM/YYYY).';
        });
        return;
      }
    }

    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());

    setState(() => _isSaving = true);

    final updated = UserHealthProfile(
      name: name,
      dateOfBirth: dob,
      heightCm: height,
      weightKg: weight,
      biologicalSex: _selectedSex,
      units: _selectedUnits,
      primaryGoal: _selectedGoal,
      avatarId: _avatarId,
    );

    await widget.authRepository.updateHealthProfile(updated);
    if (!kIsWeb && Platform.isWindows) {
      WebcamPostureService.instance.syncProfileGender(updated.biologicalSex);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health Profile saved successfully.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final user = widget.authRepository.currentUser.value;

    final heightVal = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final weightVal = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final calculatedBmi = HealthCalculationEngine.calculateBmi(
      weightKg: weightVal,
      heightCm: heightVal,
    );
    final calculatedBmiCategory = HealthCalculationEngine.getBmiCategory(
      calculatedBmi,
    );
    final calculatedAge = _selectedDob != null
        ? HealthCalculationEngine.calculateAge(_selectedDob!)
        : null;
    final calculatedBmr = HealthCalculationEngine.calculateBmr(
      weightKg: weightVal,
      heightCm: heightVal,
      age: calculatedAge ?? 25,
      biologicalSex: _selectedSex,
    );
    final calculatedTdee = HealthCalculationEngine.calculateTdee(
      bmr: calculatedBmr,
      primaryGoal: _selectedGoal,
    );
    final dailyCalorieTarget =
        HealthCalculationEngine.calculateDailyCalorieTarget(
          tdee: calculatedTdee,
          primaryGoal: _selectedGoal,
        );
    final recommendedStepGoal =
        HealthCalculationEngine.calculateRecommendedStepGoal(
          primaryGoal: _selectedGoal,
        );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'App & Account Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => SettingsScreen(
                    repository: widget.repository,
                    authRepository: widget.authRepository,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Avatar & Identity Header Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        AppAvatarWidget(
                          avatarId: _avatarId,
                          size: 64,
                          showEditBadge: true,
                          onTap: () {
                            showAvatarPickerModal(
                              context: context,
                              currentAvatarId: _avatarId,
                              onSelected: (id) =>
                                  setState(() => _avatarId = id),
                            );
                          },
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'HealthDevice User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.email ?? 'Offline session',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  showAvatarPickerModal(
                                    context: context,
                                    currentAvatarId: _avatarId,
                                    onSelected: (id) =>
                                        setState(() => _avatarId = id),
                                  );
                                },
                                child: const Text(
                                  'Change Custom Avatar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.cyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Personal Biometrics
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name
                        _buildFieldLabel('Full Name'),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderSubtle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date of Birth (DD/MM/YYYY with intelligent formatter)
                        _buildFieldLabel('Date of Birth (DD/MM/YYYY)'),
                        TextField(
                          controller: _dobController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            DobInputFormatter(maxYear: DateTime.now().year),
                          ],
                          onChanged: _onDobTextChanged,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'DD/MM/YYYY  (e.g. 16/03/2005)',
                            hintStyle: const TextStyle(
                              color: AppTheme.textMuted,
                            ),
                            filled: true,
                            fillColor: AppTheme.surface,
                            errorText: _dobError,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: AppTheme.cyan,
                              ),
                              onPressed: _pickDateOfBirth,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderSubtle,
                              ),
                            ),
                          ),
                        ),
                        if (calculatedAge != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Calculated Age: $calculatedAge years old',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.cyan,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Height & Weight
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Height (cm)'),
                                  TextField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppTheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppTheme.borderSubtle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Weight (kg)'),
                                  TextField(
                                    controller: _weightController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppTheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppTheme.borderSubtle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Biological Sex
                        _buildFieldLabel('Sex Assigned at Birth'),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedSex,
                          dropdownColor: AppTheme.card,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderSubtle,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                            DropdownMenuItem(
                              value: 'Prefer not to say',
                              child: Text('Prefer not to say'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSex = val);
                              if (!kIsWeb && Platform.isWindows) {
                                WebcamPostureService.instance.syncProfileGender(val);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Measurement Units
                        _buildFieldLabel('Measurement Units'),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedUnits,
                          dropdownColor: AppTheme.card,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderSubtle,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Metric (cm, kg)',
                              child: Text('Metric (cm, kg, km)'),
                            ),
                            DropdownMenuItem(
                              value: 'Imperial (ft, lbs)',
                              child: Text('Imperial (ft/in, lbs, mi)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedUnits = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Health & Goals Engine Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primaryBlueLight.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.analytics_rounded,
                              size: 20,
                              color: AppTheme.cyan,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Health & Goals',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Deterministic',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Primary Goal Dropdown
                        _buildFieldLabel('Primary Health Goal'),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedGoal),
                          isExpanded: true,
                          initialValue: _selectedGoal,
                          dropdownColor: AppTheme.card,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.borderSubtle,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'General wellness',
                              child: Text('General wellness & Maintenance'),
                            ),
                            DropdownMenuItem(
                              value: 'Fitness',
                              child: Text('Cardio Fitness & Stamina'),
                            ),
                            DropdownMenuItem(
                              value: 'Weight management',
                              child: Text('Weight Loss Deficit'),
                            ),
                            DropdownMenuItem(
                              value: 'Posture',
                              child: Text('Ergonomics & Posture Alignment'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedGoal = val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // Calculated Metrics Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Body Mass Index',
                                value: calculatedBmi > 0
                                    ? '$calculatedBmi'
                                    : 'N/A',
                                badge: calculatedBmi > 0
                                    ? calculatedBmiCategory
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Basal Metabolic Rate',
                                value: weightVal > 0 && heightVal > 0
                                    ? '$calculatedBmr kcal'
                                    : 'N/A',
                                badge: 'Resting energy',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Estimated TDEE',
                                value: weightVal > 0 && heightVal > 0
                                    ? '$calculatedTdee kcal'
                                    : 'N/A',
                                badge: HealthCalculationEngine.getTdeeBadge(
                                  primaryGoal: _selectedGoal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Daily Calorie Target',
                                value: weightVal > 0 && heightVal > 0
                                    ? '$dailyCalorieTarget kcal'
                                    : 'N/A',
                                badge: HealthCalculationEngine.getCalorieTargetBadge(
                                  primaryGoal: _selectedGoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Daily Step Goal',
                                value: '$recommendedStepGoal steps',
                                badge: HealthCalculationEngine.getStepGoalBadge(
                                  primaryGoal: _selectedGoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Profile Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlueLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Profile Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.cyan,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
