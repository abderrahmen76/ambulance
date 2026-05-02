import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// Cache for theme styles to avoid repeated Theme.of(context) calls
class ThemeStyleCache {
  static final Map<BuildContext, Map<String, TextStyle>> _styleCache = {};

  static TextStyle getHeadlineSmall(BuildContext context) {
    _ensureCache(context);
    return _styleCache[context]!['headlineSmall'] ??
        Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ) ??
        const TextStyle();
  }

  static TextStyle getBodyMedium(BuildContext context) {
    _ensureCache(context);
    return _styleCache[context]!['bodyMedium'] ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ) ??
        const TextStyle();
  }

  static TextStyle getBodySmall(BuildContext context) {
    _ensureCache(context);
    return _styleCache[context]!['bodySmall'] ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ) ??
        const TextStyle();
  }

  static void _ensureCache(BuildContext context) {
    if (!_styleCache.containsKey(context)) {
      _styleCache[context] = {};
    }
  }

  // Clear cache when theme changes
  static void clearCache() {
    _styleCache.clear();
  }
}

/// Optimized, memoizable widget builders
abstract class OptimizedWidgets {
  /// Build section header - marked const for optimization
  static Widget sectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPERATIONAL PARAMETERS'.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: ThemeStyleCache.getHeadlineSmall(context),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: ThemeStyleCache.getBodySmall(context),
        ),
      ],
    );
  }

  /// Build toggle with subtitle - optimized version
  static Widget toggleWithSubtitle(
    BuildContext context, {
    required String label,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ThemeStyleCache.getBodyMedium(context),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  /// Build slider row - optimized version
  static Widget sliderRow(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}${suffix != null ? ' $suffix' : ''}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.toInt()}${suffix != null ? ' $suffix' : ''}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            Text(
              '${max.toInt()}${suffix != null ? ' $suffix' : ''}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ],
    );
  }

  /// Build dropdown row - optimized version
  static Widget dropdownRow(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            onChanged: onChanged,
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Build info row for dark cards
  static Widget infoRow({
    required String label,
    required String value,
    bool isDark = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Build permission checkbox
  static Widget permissionCheckbox({
    required bool value,
  }) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value ? AppColors.success : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: value ? AppColors.success : Colors.grey[300]!,
        ),
      ),
      child:
          value ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
    );
  }
}
