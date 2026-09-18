import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../domain/entities/hr_letter_entity.dart';
import '../controllers/hr_letter_controller.dart';

class HrLetterViewScreen extends ConsumerWidget {
  final HrLetterEntity letter;

  const HrLetterViewScreen({
    super.key,
    required this.letter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrLetterControllerProvider);
    final controller = ref.read(hrLetterControllerProvider.notifier);
    final isDownloadingThis = state.isDownloading && state.downloadingLetterId == letter.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Letter Details',
          style: AppTypography.headlineSmall.copyWith(
            fontSize: 18,
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: isDownloadingThis
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: AppColors.primary),
            tooltip: 'Download PDF',
            onPressed: isDownloadingThis ? null : () => controller.downloadPdf(context, letter),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.onSurfaceVariant),
            tooltip: 'Share Letter',
            onPressed: isDownloadingThis ? null : () => controller.sharePdf(context, letter),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Metadata Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject
                  Text(
                    letter.subject,
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Sender & Metadata Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.corporate_fare_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              letter.sender,
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              letter.senderEmail,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Priority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityBgColor(letter.priority),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          letter.priority,
                          style: AppTypography.labelTiny.copyWith(
                            color: _getPriorityTextColor(letter.priority),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sent Timestamp
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sent: ${letter.formattedDateTime}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Letter Body Container
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildRenderedHtml(letter.content),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          12,
          AppSpacing.marginMobile,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: PrimaryButton(
                title: 'Download PDF',
                icon: isDownloadingThis
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                onPressed: isDownloadingThis
                    ? null
                    : () => controller.downloadPdf(context, letter),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isDownloadingThis
                    ? null
                    : () => controller.sharePdf(context, letter),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parses and displays HTML content cleanly
  Widget _buildRenderedHtml(String html) {
    if (html.trim().isEmpty) {
      return const Text(
        'No content available for this letter.',
        style: TextStyle(color: AppColors.onSurfaceVariant),
      );
    }

    // Normalize breaks
    final normalized = html
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    final blockRegex = RegExp(
      r'<(h[1-6]|p|div|ul|ol|table|hr)[^>]*>(.*?)</\1>|<hr\s*/?>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = blockRegex.allMatches(normalized);

    if (matches.isEmpty) {
      final paragraphs = normalized.split(RegExp(r'\n{2,}'));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((p) {
          final clean = _stripTags(p);
          if (clean.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              clean,
              style: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFF1E293B),
                height: 1.65,
                fontSize: 14.5,
              ),
            ),
          );
        }).toList(),
      );
    }

    final children = <Widget>[];

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final inner = match.group(2) ?? '';

      if (tag == 'hr' || match.group(0)?.startsWith('<hr') == true) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: AppColors.outlineVariant),
        ));
        continue;
      }

      if (tag != null && tag.startsWith('h')) {
        final level = int.tryParse(tag.substring(1)) ?? 2;
        final fontSize = level == 1
            ? 18.0
            : level == 2
                ? 16.0
                : 15.0;
        final text = _stripTags(inner);
        if (text.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              text,
              style: AppTypography.headlineSmall.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ));
        }
        continue;
      }

      if (tag == 'ul' || tag == 'ol') {
        final isOrdered = tag == 'ol';
        final itemRegex = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true);
        final itemMatches = itemRegex.allMatches(inner);

        int index = 1;
        for (final item in itemMatches) {
          final itemText = _stripTags(item.group(1) ?? '');
          if (itemText.isNotEmpty) {
            children.add(Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOrdered ? '$index. ' : '•  ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      itemText,
                      style: AppTypography.bodyMedium.copyWith(
                        color: const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ));
            index++;
          }
        }
        children.add(const SizedBox(height: 8));
        continue;
      }

      // Paragraph / Div
      final cleanText = _stripTags(inner);
      if (cleanText.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            cleanText,
            style: AppTypography.bodyMedium.copyWith(
              color: const Color(0xFF1E293B),
              height: 1.65,
              fontSize: 14.5,
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Color _getPriorityBgColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFEE2E2);
      case 'low':
        return const Color(0xFFF1F5F9);
      case 'medium':
      default:
        return const Color(0xFFE0F2FE);
    }
  }

  Color _getPriorityTextColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'low':
        return const Color(0xFF64748B);
      case 'medium':
      default:
        return const Color(0xFF0284C7);
    }
  }
}
