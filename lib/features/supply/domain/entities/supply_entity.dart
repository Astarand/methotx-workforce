import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';

enum SupplyStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  final String label;
  const SupplyStatus(this.label);

  Color get textColor {
    switch (this) {
      case SupplyStatus.approved:
        return AppColors.success;
      case SupplyStatus.rejected:
        return AppColors.error;
      case SupplyStatus.pending:
        return AppColors.warning;
    }
  }

  Color get bgColor {
    switch (this) {
      case SupplyStatus.approved:
        return AppColors.success.withValues(alpha: 0.12);
      case SupplyStatus.rejected:
        return AppColors.error.withValues(alpha: 0.12);
      case SupplyStatus.pending:
        return AppColors.warning.withValues(alpha: 0.12);
    }
  }

  IconData get icon {
    switch (this) {
      case SupplyStatus.approved:
        return Icons.check_circle_rounded;
      case SupplyStatus.rejected:
        return Icons.cancel_rounded;
      case SupplyStatus.pending:
        return Icons.schedule_rounded;
    }
  }
}

enum SupplyPriority {
  top('Top Priority'),
  normal('Normal Priority');

  final String label;
  const SupplyPriority(this.label);

  Color get textColor {
    switch (this) {
      case SupplyPriority.top:
        return const Color(0xFFD32F2F);
      case SupplyPriority.normal:
        return const Color(0xFF1976D2);
    }
  }

  Color get bgColor {
    switch (this) {
      case SupplyPriority.top:
        return const Color(0xFFFFEBEE);
      case SupplyPriority.normal:
        return const Color(0xFFE3F2FD);
    }
  }

  IconData get icon {
    switch (this) {
      case SupplyPriority.top:
        return Icons.error_outline_rounded;
      case SupplyPriority.normal:
        return Icons.flag_outlined;
    }
  }

  static SupplyPriority fromString(String? val) {
    if (val == null) return SupplyPriority.normal;
    final clean = val.trim().toLowerCase();
    if (clean.contains('top') || clean.contains('high') || clean.contains('urgent')) {
      return SupplyPriority.top;
    }
    return SupplyPriority.normal;
  }
}

class SupplyCategoryInfo {
  final String key;
  final String title;
  final IconData icon;

  const SupplyCategoryInfo({
    required this.key,
    required this.title,
    required this.icon,
  });

  static const List<SupplyCategoryInfo> all = [
    SupplyCategoryInfo(
      key: 'office_supplies',
      title: 'Office Supplies',
      icon: Icons.inventory_2_outlined,
    ),
    SupplyCategoryInfo(
      key: 'technology',
      title: 'Technology & IT',
      icon: Icons.computer_rounded,
    ),
    SupplyCategoryInfo(
      key: 'furniture',
      title: 'Office Furniture',
      icon: Icons.chair_rounded,
    ),
    SupplyCategoryInfo(
      key: 'stationery',
      title: 'Stationery',
      icon: Icons.edit_note_rounded,
    ),
    SupplyCategoryInfo(
      key: 'uniforms',
      title: 'Uniforms & Apparel',
      icon: Icons.checkroom_rounded,
    ),
    SupplyCategoryInfo(
      key: 'breakroom',
      title: 'Breakroom & Pantry',
      icon: Icons.coffee_rounded,
    ),
    SupplyCategoryInfo(
      key: 'software',
      title: 'Software & Licenses',
      icon: Icons.terminal_rounded,
    ),
    SupplyCategoryInfo(
      key: 'ppe',
      title: 'PPE & Safety Equipment',
      icon: Icons.health_and_safety_rounded,
    ),
    SupplyCategoryInfo(
      key: 'marketing',
      title: 'Marketing Materials',
      icon: Icons.campaign_rounded,
    ),
    SupplyCategoryInfo(
      key: 'decor',
      title: 'Office Decor',
      icon: Icons.park_rounded,
    ),
    SupplyCategoryInfo(
      key: 'travel',
      title: 'Travel Supplies',
      icon: Icons.luggage_rounded,
    ),
    SupplyCategoryInfo(
      key: 'gifts',
      title: 'Corporate Gifts',
      icon: Icons.card_giftcard_rounded,
    ),
    SupplyCategoryInfo(
      key: 'cleaning',
      title: 'Cleaning & Hygiene',
      icon: Icons.cleaning_services_rounded,
    ),
    SupplyCategoryInfo(
      key: 'wellness',
      title: 'Wellness & Health',
      icon: Icons.spa_rounded,
    ),
    SupplyCategoryInfo(
      key: 'miscellaneous',
      title: 'Miscellaneous',
      icon: Icons.category_rounded,
    ),
  ];

  static SupplyCategoryInfo get(String categoryKey) {
    final clean = categoryKey.trim().toLowerCase();
    return all.firstWhere(
      (c) => c.key == clean,
      orElse: () => SupplyCategoryInfo(
        key: clean,
        title: clean.isEmpty
            ? 'General Requisition'
            : clean
                .split('_')
                .map((w) => w.isNotEmpty
                    ? '${w[0].toUpperCase()}${w.substring(1)}'
                    : '')
                .join(' '),
        icon: Icons.inventory_2_outlined,
      ),
    );
  }
}

class SupplyEntity {
  final String id;
  final String employeeId;
  final DateTime date;
  final String category;
  final String details;
  final String quantity;
  final double amount;
  final SupplyPriority priority;
  final String? returnExchange;
  final SupplyStatus status;
  final String? comments;
  final String? attachment;
  final String? attachmentUrl;

  const SupplyEntity({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.category,
    required this.details,
    required this.quantity,
    required this.amount,
    required this.priority,
    this.returnExchange,
    required this.status,
    this.comments,
    this.attachment,
    this.attachmentUrl,
  });

  String get categoryTitle => SupplyCategoryInfo.get(category).title;
  IconData get categoryIcon => SupplyCategoryInfo.get(category).icon;

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy').format(date);
  }

  bool get hasAttachment {
    final hasDirectUrl = attachmentUrl != null &&
        attachmentUrl!.trim().isNotEmpty &&
        attachmentUrl != 'null';
    final hasFileName = attachment != null &&
        attachment!.trim().isNotEmpty &&
        attachment != 'null';
    return hasDirectUrl || hasFileName;
  }

  String? get resolvedAttachmentUrl {
    // 1. Prefer explicit attachment_url from server if present
    if (attachmentUrl != null &&
        attachmentUrl!.trim().isNotEmpty &&
        attachmentUrl != 'null') {
      return ApiEndpoints.resolveImageUrl(attachmentUrl);
    }
    // 2. Fall back to resolving attachment filename
    return ApiEndpoints.resolveImageUrl(attachment);
  }

  bool get isPdfAttachment {
    if (!hasAttachment) return false;
    final path = (attachmentUrl ?? attachment ?? '').toLowerCase();
    return path.endsWith('.pdf') || path.contains('.pdf?') || path.contains('/pdf');
  }
}
