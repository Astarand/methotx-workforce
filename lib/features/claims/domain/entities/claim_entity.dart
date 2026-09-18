import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';

enum ClaimStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.rejected:
        return 'Rejected';
      case ClaimStatus.pending:
        return 'Pending';
    }
  }

  Color get textColor {
    switch (this) {
      case ClaimStatus.approved:
        return const Color(0xFF166534); // Green
      case ClaimStatus.rejected:
        return const Color(0xFFDC2626); // Red
      case ClaimStatus.pending:
        return const Color(0xFFD97706); // Amber / Orange
    }
  }

  Color get bgColor {
    switch (this) {
      case ClaimStatus.approved:
        return const Color(0xFFDCFCE7);
      case ClaimStatus.rejected:
        return const Color(0xFFFEE2E2);
      case ClaimStatus.pending:
        return const Color(0xFFFEF3C7);
    }
  }

  IconData get icon {
    switch (this) {
      case ClaimStatus.approved:
        return Icons.check_circle_rounded;
      case ClaimStatus.rejected:
        return Icons.cancel_rounded;
      case ClaimStatus.pending:
        return Icons.schedule_rounded;
    }
  }
}

class ClaimCategoryMetadata {
  final String key;
  final String title;
  final IconData icon;

  const ClaimCategoryMetadata({
    required this.key,
    required this.title,
    required this.icon,
  });

  static const List<ClaimCategoryMetadata> allCategories = [
    ClaimCategoryMetadata(
      key: 'travel',
      title: 'Travel & Conveyance',
      icon: Icons.directions_car_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'accommodation',
      title: 'Accommodation & Hotel',
      icon: Icons.hotel_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'meals',
      title: 'Meals & Dining',
      icon: Icons.restaurant_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'office_supplies',
      title: 'Office Supplies',
      icon: Icons.print_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'communication',
      title: 'Internet & Phone',
      icon: Icons.phone_iphone_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'training',
      title: 'Training & Courses',
      icon: Icons.school_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'equipment',
      title: 'Hardware & Equipment',
      icon: Icons.devices_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'client_entertainment',
      title: 'Client Entertainment',
      icon: Icons.local_cafe_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'shipping',
      title: 'Shipping & Courier',
      icon: Icons.local_shipping_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'marketing',
      title: 'Marketing & Advertising',
      icon: Icons.campaign_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'office_rent',
      title: 'Office Rent',
      icon: Icons.apartment_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'employee_welfare',
      title: 'Employee Welfare',
      icon: Icons.favorite_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'legal',
      title: 'Legal & Professional',
      icon: Icons.gavel_rounded,
    ),
    ClaimCategoryMetadata(
      key: 'miscellaneous',
      title: 'Miscellaneous',
      icon: Icons.category_rounded,
    ),
  ];

  static ClaimCategoryMetadata get(String key) {
    final lower = key.trim().toLowerCase();
    return allCategories.firstWhere(
      (c) => c.key == lower,
      orElse: () => ClaimCategoryMetadata(
        key: lower,
        title: lower.replaceAll('_', ' ').toUpperCase(),
        icon: Icons.receipt_long_rounded,
      ),
    );
  }
}

class PaymentMethodMetadata {
  final String key;
  final String title;
  final IconData icon;

  const PaymentMethodMetadata({
    required this.key,
    required this.title,
    required this.icon,
  });

  static const List<PaymentMethodMetadata> allMethods = [
    PaymentMethodMetadata(
      key: 'cash',
      title: 'Cash',
      icon: Icons.money_rounded,
    ),
    PaymentMethodMetadata(
      key: 'upi',
      title: 'UPI',
      icon: Icons.qr_code_2_rounded,
    ),
    PaymentMethodMetadata(
      key: 'card',
      title: 'Debit / Credit Card',
      icon: Icons.credit_card_rounded,
    ),
    PaymentMethodMetadata(
      key: 'banking',
      title: 'Net Banking',
      icon: Icons.account_balance_rounded,
    ),
  ];

  static PaymentMethodMetadata get(String key) {
    final lower = key.trim().toLowerCase();
    return allMethods.firstWhere(
      (m) => m.key == lower,
      orElse: () => PaymentMethodMetadata(
        key: lower,
        title: lower.toUpperCase(),
        icon: Icons.payment_rounded,
      ),
    );
  }
}

class ClaimEntity {
  final String id;
  final String employeeId;
  final DateTime date;
  final String category;
  final double amount;
  final String paymentMethod;
  final String details;
  final ClaimStatus status;
  final String? comments;
  final String? receipt;

  const ClaimEntity({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.details,
    required this.status,
    this.comments,
    this.receipt,
  });

  String get formattedDate => DateFormat('dd MMM yyyy').format(date);

  String get formattedAmount {
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
    return format.format(amount);
  }

  String get categoryTitle => ClaimCategoryMetadata.get(category).title;

  IconData get categoryIcon => ClaimCategoryMetadata.get(category).icon;

  String get paymentMethodTitle => PaymentMethodMetadata.get(paymentMethod).title;

  bool get hasReceipt => receipt != null && receipt!.trim().isNotEmpty && receipt != 'null';

  String? get resolvedReceiptUrl {
    if (!hasReceipt) return null;
    return ApiEndpoints.resolveImageUrl(receipt);
  }

  bool get isPdfReceipt {
    if (!hasReceipt) return false;
    final r = receipt!.toLowerCase();
    return r.endsWith('.pdf');
  }

  bool get isImageReceipt {
    if (!hasReceipt) return false;
    final r = receipt!.toLowerCase();
    return r.endsWith('.jpg') ||
        r.endsWith('.jpeg') ||
        r.endsWith('.png') ||
        r.endsWith('.webp');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          employeeId == other.employeeId &&
          amount == other.amount &&
          status == other.status &&
          date == other.date;

  @override
  int get hashCode =>
      id.hashCode ^
      employeeId.hashCode ^
      amount.hashCode ^
      status.hashCode ^
      date.hashCode;
}
