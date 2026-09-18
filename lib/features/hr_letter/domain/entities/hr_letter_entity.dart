import 'package:intl/intl.dart';

/// Pure Domain Entity representing an official HR Letter
class HrLetterEntity {
  final String id;
  final String subject;
  final String content;
  final DateTime sentAt;
  final String sender;
  final String senderEmail;
  final String priority;
  final bool isRead;

  const HrLetterEntity({
    required this.id,
    required this.subject,
    required this.content,
    required this.sentAt,
    this.sender = 'HR Department',
    this.senderEmail = 'hr@ecashbook.com',
    this.priority = 'Medium',
    this.isRead = true,
  });

  /// Formatted date string (e.g. "30 Aug 2026")
  String get formattedDate => DateFormat('dd MMM yyyy').format(sentAt);

  /// Formatted time string (e.g. "10:15 AM")
  String get formattedTime => DateFormat('hh:mm a').format(sentAt);

  /// Combined formatted date and time
  String get formattedDateTime => '$formattedDate, $formattedTime';

  /// Plain text preview stripped of common HTML tags
  String get previewText {
    final text = content
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isNotEmpty ? text : 'No preview available';
  }

  HrLetterEntity copyWith({
    String? id,
    String? subject,
    String? content,
    DateTime? sentAt,
    String? sender,
    String? senderEmail,
    String? priority,
    bool? isRead,
  }) {
    return HrLetterEntity(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      sender: sender ?? this.sender,
      senderEmail: senderEmail ?? this.senderEmail,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HrLetterEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ isRead.hashCode;
}
