/// Deterministic clinical and wellness calculation engine.
///
/// Implements standardized medical & sports science formulas:
/// - BMI: Quetelet's index (kg/m²) + WHO categorization
/// - BMR: Mifflin-St Jeor Equation
/// - TDEE: Activity-factored energy expenditure
/// - Caloric balance & step goal recommendations
/// - Aggregate trends, averages, and percentage differentials
class HealthCalculationEngine {
  HealthCalculationEngine._();

  /// Calculates Body Mass Index (BMI).
  ///
  /// Formula: weight (kg) / [height (m)]²
  static double calculateBmi({
    required double weightKg,
    required double heightCm,
  }) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);
    return double.parse(bmi.toStringAsFixed(1));
  }

  /// Returns WHO BMI classification string.
  static String getBmiCategory(double bmi) {
    if (bmi <= 0) return 'Unknown';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal weight';
    if (bmi < 30.0) return 'Overweight';
    if (bmi < 35.0) return 'Obesity Class I';
    if (bmi < 40.0) return 'Obesity Class II';
    return 'Obesity Class III';
  }

  /// Calculates Basal Metabolic Rate (BMR) via Mifflin-St Jeor equation.
  ///
  /// Men: 10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5
  /// Women: 10 * weight(kg) + 6.25 * height(cm) - 5 * age - 161
  /// Other/Unspecified: Average offset (-78)
  static int calculateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required String biologicalSex,
  }) {
    if (weightKg <= 0 || heightCm <= 0 || age <= 0) return 1600;

    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age);
    final sexLower = biologicalSex.toLowerCase();

    double total;
    if (sexLower.contains('male') && !sexLower.contains('female')) {
      total = base + 5.0;
    } else if (sexLower.contains('female')) {
      total = base - 161.0;
    } else {
      total = base - 78.0;
    }

    return total.round().clamp(800, 4000);
  }

  /// Calculates Total Daily Energy Expenditure (TDEE).
  /// Calculates Total Daily Energy Expenditure (TDEE).
  ///
  /// Takes BMR and an activity multiplier (1.2 to 1.9), tailored to the primary goal.
  static int calculateTdee({
    required int bmr,
    String activityLevel = 'Moderate',
    String? primaryGoal,
  }) {
    double multiplier;
    if (primaryGoal != null) {
      final goalLower = primaryGoal.toLowerCase();
      if (goalLower.contains('fitness') ||
          goalLower.contains('cardio') ||
          goalLower.contains('stamina')) {
        multiplier = 1.65; // Athletic cardio training
      } else if (goalLower.contains('weight') ||
          goalLower.contains('management') ||
          goalLower.contains('loss') ||
          goalLower.contains('deficit')) {
        multiplier = 1.50; // Active deficit baseline
      } else if (goalLower.contains('activity') || goalLower.contains('step')) {
        multiplier = 1.55;
      } else if (goalLower.contains('posture') ||
          goalLower.contains('ergonomic')) {
        multiplier = 1.35; // Sedentary/desk alignment focus
      } else {
        multiplier = 1.45; // General wellness maintenance
      }
    } else {
      switch (activityLevel.toLowerCase()) {
        case 'sedentary':
          multiplier = 1.2;
          break;
        case 'light':
          multiplier = 1.375;
          break;
        case 'moderate':
          multiplier = 1.55;
          break;
        case 'active':
          multiplier = 1.725;
          break;
        case 'very active':
          multiplier = 1.9;
          break;
        default:
          multiplier = 1.4;
      }
    }
    return (bmr * multiplier).round();
  }

  /// Calculates targeted daily caloric intake recommendation based on primary goal.
  static int calculateDailyCalorieTarget({
    required int tdee,
    required String primaryGoal,
  }) {
    final goalLower = primaryGoal.toLowerCase();
    if (goalLower.contains('weight') ||
        goalLower.contains('management') ||
        goalLower.contains('loss') ||
        goalLower.contains('deficit') ||
        goalLower.contains('lose')) {
      return (tdee - 500).clamp(1200, 3500); // 500 kcal deficit for safe sustained fat loss
    } else if (goalLower.contains('fitness') ||
        goalLower.contains('cardio') ||
        goalLower.contains('stamina') ||
        goalLower.contains('heart')) {
      return (tdee + 250).clamp(1400, 4200); // 250 kcal surplus for endurance recovery
    } else if (goalLower.contains('activity')) {
      return (tdee + 150).clamp(1300, 4000);
    } else if (goalLower.contains('muscle') || goalLower.contains('gain')) {
      return (tdee + 300).clamp(1500, 4500); // 300 kcal surplus
    } else if (goalLower.contains('posture') ||
        goalLower.contains('ergonomic')) {
      return tdee; // Ergonomic maintenance
    }
    return tdee; // General wellness maintenance
  }

  /// Determines personalized step goal based on user baseline and health target.
  static int calculateRecommendedStepGoal({required String primaryGoal}) {
    final goalLower = primaryGoal.toLowerCase();
    if (goalLower.contains('weight') ||
        goalLower.contains('management') ||
        goalLower.contains('loss') ||
        goalLower.contains('deficit') ||
        goalLower.contains('lose')) {
      return 12000; // Accelerated caloric expenditure
    } else if (goalLower.contains('fitness') ||
        goalLower.contains('cardio') ||
        goalLower.contains('stamina')) {
      return 10000; // Optimal cardiovascular aerobic stimulus
    } else if (goalLower.contains('activity') || goalLower.contains('step')) {
      return 11000;
    } else if (goalLower.contains('posture') ||
        goalLower.contains('ergonomic')) {
      return 8500; // Hourly posture and movement breaks
    }
    return 10000; // Standard wellness baseline
  }

  /// Returns contextual badge string for Estimated TDEE.
  static String getTdeeBadge({required String primaryGoal}) {
    final goalLower = primaryGoal.toLowerCase();
    if (goalLower.contains('fitness') ||
        goalLower.contains('cardio') ||
        goalLower.contains('stamina')) {
      return 'Cardio burn';
    } else if (goalLower.contains('weight') ||
        goalLower.contains('management') ||
        goalLower.contains('loss') ||
        goalLower.contains('deficit')) {
      return 'Deficit base';
    } else if (goalLower.contains('posture') ||
        goalLower.contains('ergonomic')) {
      return 'Desk / Light';
    }
    return 'Active burn';
  }

  /// Returns contextual badge string for Daily Calorie Target.
  static String getCalorieTargetBadge({required String primaryGoal}) {
    final goalLower = primaryGoal.toLowerCase();
    if (goalLower.contains('weight') ||
        goalLower.contains('management') ||
        goalLower.contains('loss') ||
        goalLower.contains('deficit') ||
        goalLower.contains('lose')) {
      return '-500 kcal Deficit';
    } else if (goalLower.contains('fitness') ||
        goalLower.contains('cardio') ||
        goalLower.contains('stamina')) {
      return '+250 kcal Fuel';
    } else if (goalLower.contains('activity')) {
      return '+150 kcal Active';
    } else if (goalLower.contains('muscle') || goalLower.contains('gain')) {
      return '+300 kcal Surplus';
    } else if (goalLower.contains('posture') ||
        goalLower.contains('ergonomic')) {
      return 'Posture plan';
    }
    return 'Maintenance';
  }

  /// Returns contextual badge string for Daily Step Goal.
  static String getStepGoalBadge({required String primaryGoal}) {
    final goalLower = primaryGoal.toLowerCase();
    if (goalLower.contains('weight') ||
        goalLower.contains('management') ||
        goalLower.contains('loss') ||
        goalLower.contains('deficit') ||
        goalLower.contains('lose')) {
      return 'Fat Burn';
    } else if (goalLower.contains('fitness') ||
        goalLower.contains('cardio') ||
        goalLower.contains('stamina')) {
      return 'Cardio Target';
    } else if (goalLower.contains('activity')) {
      return 'Daily Active';
    } else if (goalLower.contains('posture') ||
        goalLower.contains('ergonomic')) {
      return 'Mobility Breaks';
    }
    return 'Target';
  }

  /// Calculates age dynamically from Date of Birth.
  static int calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age.clamp(0, 130);
  }

  /// Calculates percentage change between previous and current values.
  static double calculatePercentageChange(num previous, num current) {
    if (previous == 0) return 0.0;
    final diff = ((current - previous) / previous) * 100.0;
    return double.parse(diff.toStringAsFixed(1));
  }

  /// Calculates statistical average of a list of numbers.
  static double calculateAverage(List<num> values) {
    if (values.isEmpty) return 0.0;
    final sum = values.fold<double>(0.0, (acc, val) => acc + val);
    return double.parse((sum / values.length).toStringAsFixed(1));
  }

  /// Formats goal progress percentage (0% to 100%+).
  static double calculateGoalProgress({
    required num current,
    required num goal,
  }) {
    if (goal <= 0) return 0.0;
    final progress = (current / goal) * 100.0;
    return double.parse(progress.toStringAsFixed(1));
  }
}
