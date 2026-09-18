import '../../domain/entities/claim_entity.dart';

class ClaimModel {
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

  const ClaimModel({
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

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    String parseString(dynamic val, [String fallback = '']) {
      if (val == null) return fallback;
      return val.toString().trim();
    }

    double parseDouble(dynamic val, [double fallback = 0.0]) {
      if (val == null) return fallback;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(',', '').trim();
        return double.tryParse(clean) ?? fallback;
      }
      return fallback;
    }

    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      final str = val.toString().trim();
      if (str.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(str);
      } catch (_) {
        try {
          return DateTime.parse(str.replaceAll(' ', 'T'));
        } catch (_) {
          return DateTime.now();
        }
      }
    }

    ClaimStatus parseStatus(dynamic val) {
      if (val == null) return ClaimStatus.pending;
      if (val is int) {
        if (val == 1) return ClaimStatus.approved;
        if (val == 2) return ClaimStatus.rejected;
        return ClaimStatus.pending;
      }
      final s = val.toString().trim().toLowerCase();
      if (s == 'approved' || s == 'accepted' || s == 'accept' || s == '1') {
        return ClaimStatus.approved;
      }
      if (s == 'rejected' || s == 'reject' || s == 'declined' || s == '2') {
        return ClaimStatus.rejected;
      }
      return ClaimStatus.pending;
    }

    final id = parseString(json['id'] ?? json['claim_id'] ?? json['claimId']);
    final empId = parseString(json['employee_id'] ?? json['emp_id'] ?? json['employeeId']);
    final date = parseDateTime(json['date'] ?? json['claim_date'] ?? json['created_at']);
    final category = parseString(json['category'] ?? json['type'], 'miscellaneous');
    final amount = parseDouble(json['claim_amount'] ?? json['amount']);
    final paymentMethod = parseString(json['payment_method'] ?? json['paymentMethod'], 'cash');
    final details = parseString(json['details'] ?? json['description'] ?? json['purpose']);
    final status = parseStatus(
      json['status'] ??
          json['claim_status'] ??
          json['approval_status'] ??
          json['status_name'] ??
          json['status_text'],
    );
    final comments = json['comments'] != null ? parseString(json['comments']) : null;
    final receipt = json['receipt'] != null ? parseString(json['receipt']) : null;

    return ClaimModel(
      id: id,
      employeeId: empId,
      date: date,
      category: category,
      amount: amount,
      paymentMethod: paymentMethod,
      details: details,
      status: status,
      comments: comments != null && comments.isNotEmpty ? comments : null,
      receipt: receipt != null && receipt.isNotEmpty && receipt != 'null' ? receipt : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date.toIso8601String().split('T').first,
      'category': category,
      'claim_amount': amount,
      'payment_method': paymentMethod,
      'details': details,
      'status': status.name,
      'comments': comments,
      'receipt': receipt,
    };
  }

  ClaimEntity toEntity() {
    return ClaimEntity(
      id: id,
      employeeId: employeeId,
      date: date,
      category: category,
      amount: amount,
      paymentMethod: paymentMethod,
      details: details,
      status: status,
      comments: comments,
      receipt: receipt,
    );
  }
}
