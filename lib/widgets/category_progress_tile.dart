import 'package:flutter/material.dart';

import '../scoring/scoring.dart';
import 'category_presentation.dart';

/// One category's week-to-date standing: how much has been logged, and what
/// that is worth out of ten.
///
/// The bar tracks the sub-score rather than raw minutes, because several
/// categories are non-monotonic - 200 minutes of resistance training is worth
/// far less than 50, and a bar that only ever grew would hide that.
class CategoryProgressTile extends StatelessWidget {
  const CategoryProgressTile({
    super.key,
    required this.category,
    required this.subScore,
    required this.rawAmount,
    this.onTap,
  });

  final ActivityCategory category;
  final double subScore;
  final double rawAmount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = subScore < 0;
    final colour =
        negative ? theme.colorScheme.error : theme.colorScheme.primary;
    final fraction = (subScore.abs() / 10).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryPresentation[category]!.icon,
                    size: 20, color: colour),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      Text(category.label, style: theme.textTheme.titleSmall),
                ),
                Text(
                  formatAmount(category, rawAmount),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Text(
                  formatSubScore(subScore),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colour, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colour),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
