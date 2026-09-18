import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_buttons.dart';

class PolicyAcceptanceSheet extends StatefulWidget {
  final List<String> pendingPolicies;
  final VoidCallback onAccept;

  const PolicyAcceptanceSheet({
    super.key,
    required this.pendingPolicies,
    required this.onAccept,
  });

  static Future<bool?> show(BuildContext context, {required List<String> pendingPolicies, required VoidCallback onAccept}) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PolicyAcceptanceSheet(
        pendingPolicies: pendingPolicies,
        onAccept: onAccept,
      ),
    );
  }

  @override
  State<PolicyAcceptanceSheet> createState() => _PolicyAcceptanceSheetState();
}

class _PolicyAcceptanceSheetState extends State<PolicyAcceptanceSheet> {
  bool _hasReadAndAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Icon
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // Amber 100
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.policy_rounded,
                size: 30,
                color: Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Pending Corporate Policies',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Company policy requires all employees to review and acknowledge pending organizational guidelines prior to ending their shift.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Pending Policies Card List
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Acknowledgement:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tertiary,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.pendingPolicies.map((policy) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          policy,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        'Required',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Agreement Checkbox
          CheckboxListTile(
            value: _hasReadAndAgreed,
            onChanged: (val) {
              setState(() {
                _hasReadAndAgreed = val ?? false;
              });
            },
            title: Text(
              'I have read and agree to the above company policies and terms.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.brandBlue,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),

          // Buttons
          PrimaryButton(
            title: 'Acknowledge & Proceed',
            onPressed: _hasReadAndAgreed
                ? () {
                    widget.onAccept();
                    Navigator.of(context).pop(true);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
