import '../../domain/entities/supply_entity.dart';

class SupplyModel {
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

  const SupplyModel({
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

  factory SupplyModel.fromJson(Map<String, dynamic> json) {
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

    SupplyStatus parseStatus(dynamic val) {
      if (val == null) return SupplyStatus.pending;
      if (val is int) {
        if (val == 1) return SupplyStatus.approved;
        if (val == 2) return SupplyStatus.rejected;
        return SupplyStatus.pending;
      }
      final s = val.toString().trim().toLowerCase();
      if (s == 'approved' || s == 'accepted' || s == 'accept' || s == '1') {
        return SupplyStatus.approved;
      }
      if (s == 'rejected' || s == 'reject' || s == 'declined' || s == '2') {
        return SupplyStatus.rejected;
      }
      return SupplyStatus.pending;
    }

    final id = parseString(json['id'] ?? json['requisition_id'] ?? json['requisitionId']);
    final empId = parseString(json['employee_id'] ?? json['emp_id'] ?? json['employeeId']);
    final date = parseDateTime(
      json['date'] ?? json['requisition_date'] ?? json['claim_date'] ?? json['created_at'],
    );
    final category = parseString(json['category'] ?? json['type'], 'miscellaneous');
    final details = parseString(json['details'] ?? json['description'] ?? json['purpose']);
    final quantity = parseString(json['quantity'], '1');
    final amount = parseDouble(json['amount'] ?? json['claim_amount']);
    final priority = SupplyPriority.fromString(parseString(json['priority'], 'Normal Priority'));
    final returnExchange = json['return_exchange'] != null || json['returnExchange'] != null
        ? parseString(json['return_exchange'] ?? json['returnExchange'])
        : null;
    final status = parseStatus(
      json['status'] ??
          json['claim_status'] ??
          json['approval_status'] ??
          json['status_name'] ??
          json['status_text'],
    );
    final comments = json['comments'] != null ? parseString(json['comments']) : null;
    final attachment = json['attachment'] != null || json['receipt'] != null || json['file'] != null
        ? parseString(json['attachment'] ?? json['receipt'] ?? json['file'])
        : null;
    final attachmentUrl = json['attachment_url'] != null || json['attachmentUrl'] != null
        ? parseString(json['attachment_url'] ?? json['attachmentUrl'])
        : null;

    return SupplyModel(
      id: id,
      employeeId: empId,
      date: date,
      category: category,
      details: details,
      quantity: quantity.isEmpty ? '1' : quantity,
      amount: amount,
      priority: priority,
      returnExchange: returnExchange != null && returnExchange.isNotEmpty ? returnExchange : null,
      status: status,
      comments: comments != null && comments.isNotEmpty ? comments : null,
      attachment: attachment != null && attachment.isNotEmpty && attachment != 'null' ? attachment : null,
      attachmentUrl: attachmentUrl != null && attachmentUrl.isNotEmpty && attachmentUrl != 'null' ? attachmentUrl : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date.toIso8601String().split('T').first,
      'category': category,
      'details': details,
      'quantity': quantity,
      'amount': amount,
      'priority': priority.label,
      if (returnExchange != null) 'return_exchange': returnExchange,
      'status': status.name,
      if (comments != null) 'comments': comments,
      if (attachment != null) 'attachment': attachment,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
    };
  }

  SupplyEntity toEntity() {
    return SupplyEntity(
      id: id,
      employeeId: employeeId,
      date: date,
      category: category,
      details: details,
      quantity: quantity,
      amount: amount,
      priority: priority,
      returnExchange: returnExchange,
      status: status,
      comments: comments,
      attachment: attachment,
      attachmentUrl: attachmentUrl,
    );
  }
}
