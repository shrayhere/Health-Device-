import 'package:flutter/material.dart';

import '../models/app_avatar.dart';
import '../theme/app_theme.dart';

/// Reusable widget rendering the user's custom application avatar.
class AppAvatarWidget extends StatelessWidget {
  final String? avatarId;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const AppAvatarWidget({
    super.key,
    required this.avatarId,
    this.size = 40,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final preset = AppAvatarCatalog.getPreset(avatarId);

    final avatarBody = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: preset.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: preset.primaryColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(preset.icon, size: size * 0.52, color: preset.primaryColor),
      ),
    );

    if (onTap == null && !showEditBadge) {
      return avatarBody;
    }

    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: avatarBody,
        ),
        if (showEditBadge)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border, width: 1.5),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 11,
                color: AppTheme.cyan,
              ),
            ),
          ),
      ],
    );
  }
}

/// Displays modal sheet for choosing an app avatar preset.
Future<void> showAvatarPickerModal({
  required BuildContext context,
  required String currentAvatarId,
  required ValueChanged<String> onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: AppTheme.border),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              const Text(
                'Choose Custom Avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select an application identity to represent your health profile.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppAvatarCatalog.presets.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final preset = AppAvatarCatalog.presets[index];
                  final isSelected = preset.id == currentAvatarId;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      onSelected(preset.id);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? preset.primaryColor.withValues(alpha: 0.15)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? preset.primaryColor
                              : AppTheme.borderSubtle,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: preset.backgroundColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: preset.primaryColor,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              preset.icon,
                              size: 22,
                              color: preset.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
