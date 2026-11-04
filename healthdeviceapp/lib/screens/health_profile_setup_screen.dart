import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../utils/dob_input_formatter.dart';
import '../widgets/app_avatar_widget.dart';
import '../widgets/app_scaffold.dart';

/// Screen: Required onboarding "Let's set up your Health Profile".
class HealthProfileSetupScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final HealthRepository healthRepository;
  final AuthUser user;

  const HealthProfileSetupScreen({
    super.key,
    required this.authRepository,
    required this.healthRepository,
    required this.user,
  });

  @override
  State<HealthProfileSetupScreen> createState() =>
      _HealthProfileSetupScreenState();
}

class _HealthProfileSetupScreenState extends State<HealthProfileSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  DateTime? _selectedDob;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  String _selectedSex = 'Prefer not to say';
  String _selectedUnits = 'Metric (cm, kg)';
  String _selectedGoal = 'General wellness';
  String _avatarId = 'avatar_pulse_cyan';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _dobController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
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
      });
    }
  }

  Future<void> _handleSaveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name.');
      return;
    }

    DateTime? dob = _selectedDob;
    if (_dobController.text.isNotEmpty) {
      dob = DobInputFormatter.parseAndValidate(_dobController.text.trim());
    }
    if (dob == null) {
      setState(
        () => _errorMessage = 'Please enter a valid Date of Birth (DD/MM/YYYY) up to current year.',
      );
      return;
    }

    final height = double.tryParse(_heightController.text.trim());
    if (height == null || height <= 30 || height >= 260) {
      setState(() => _errorMessage = 'Please enter a realistic height.');
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 15 || weight >= 300) {
      setState(() => _errorMessage = 'Please enter a realistic weight.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profile = UserHealthProfile(
      name: name,
      dateOfBirth: dob,
      heightCm: height,
      weightKg: weight,
      biologicalSex: _selectedSex,
      units: _selectedUnits,
      primaryGoal: _selectedGoal,
      avatarId: _avatarId,
    );

    await widget.authRepository.updateHealthProfile(profile);

    if (!mounted) return;

    // Navigate to Main App Scaffold
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => AppScaffold(
          repository: widget.healthRepository,
          authRepository: widget.authRepository,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 48 : 24,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Subtitle
                  const Text(
                    "Let's set up your Health Profile",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We request only the minimum health profile fields required to calibrate your optical vitals, posture monitoring, and AI health summaries.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.heartRateRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.heartRateRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppTheme.heartRateRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.heartRateRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Container
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
                        // Custom App Avatar Selection
                        Center(
                          child: Column(
                            children: [
                              AppAvatarWidget(
                                avatarId: _avatarId,
                                size: 72,
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
                                  'Choose Custom Avatar',
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
                        const SizedBox(height: 20),

                        // 1. Name
                        _buildFieldHeader(
                          title: '1. Name',
                          hint: 'Your preferred display name across the app.',
                        ),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Shaurya Gupta',
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
                        const SizedBox(height: 18),

                        // 2. Date of Birth (DD/MM/YYYY)
                        _buildFieldHeader(
                          title: '2. Date of Birth (DD/MM/YYYY)',
                          hint: 'Enter manual DD/MM/YYYY or tap calendar icon.',
                        ),
                        TextField(
                          controller: _dobController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            DobInputFormatter(maxYear: DateTime.now().year),
                          ],
                          onChanged: (val) {
                            if (val.length == 10) {
                              final parsed = DobInputFormatter.parseAndValidate(
                                val,
                              );
                              if (parsed != null) {
                                setState(() => _selectedDob = parsed);
                              }
                            }
                          },
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
                        const SizedBox(height: 18),

                        // 3 & 4. Height & Weight
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldHeader(
                                    title: '3. Height (cm)',
                                    hint: 'Used to improve activity/calorie calculations.',
                                  ),
                                  TextField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 175',
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
                                  _buildFieldHeader(
                                    title: '4. Weight (kg)',
                                    hint: 'Used for personalized health & activity math.',
                                  ),
                                  TextField(
                                    controller: _weightController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 70',
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
                        const SizedBox(height: 18),

                        // 5. Sex assigned at birth
                        _buildFieldHeader(
                          title:
                              '5. Biological Profile / Sex Assigned at Birth',
                          hint: 'Used for standard basal metabolic and lung volume baselines.',
                        ),
                        DropdownButtonFormField<String>(
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
                            if (val != null) setState(() => _selectedSex = val);
                          },
                        ),
                        const SizedBox(height: 18),

                        // 6. Units
                        _buildFieldHeader(
                          title: '6. Measurement Units',
                          hint: 'Configure sensor reading metrics across screens.',
                        ),
                        DropdownButtonFormField<String>(
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
                        const SizedBox(height: 18),

                        // 7. Primary Goal
                        _buildFieldHeader(
                          title: '7. Primary Goal',
                          hint: 'Guides AI assistant recommendations & daily targets.',
                        ),
                        DropdownButtonFormField<String>(
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
                              child: Text('General wellness'),
                            ),
                            DropdownMenuItem(
                              value: 'Fitness',
                              child: Text('Fitness & Stamina'),
                            ),
                            DropdownMenuItem(
                              value: 'Activity',
                              child: Text('Daily Activity & Steps'),
                            ),
                            DropdownMenuItem(
                              value: 'Weight management',
                              child: Text('Weight management'),
                            ),
                            DropdownMenuItem(
                              value: 'Posture',
                              child: Text('Posture & Spine Ergonomics'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other Health Goals'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedGoal = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save & Complete Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleSaveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlueLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Health Profile & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldHeader({required String title, required String hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
