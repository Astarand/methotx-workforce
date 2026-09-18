import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PinDotsIndicator extends StatelessWidget {
  final int pinLength;
  final int maxPinLength;
  final bool hasError;

  const PinDotsIndicator({
    super.key,
    required this.pinLength,
    this.maxPinLength = 4,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxPinLength, (index) {
        final isFilled = index < pinLength;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? AppColors.error
                : (isFilled ? AppColors.primaryContainer : AppColors.surfaceContainerLowest),
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : (isFilled ? AppColors.primaryContainer : AppColors.outlineVariant),
              width: 2,
            ),
            boxShadow: isFilled && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
