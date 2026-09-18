import 'package:intl/intl.dart';
import '../../domain/entities/hr_letter_entity.dart';

class HrLetterModel {
  final String id;
  final String subject;
  final String content;
  final DateTime sentAt;
  final String sender;
  final String senderEmail;
  final String priority;

  const HrLetterModel({
    required this.id,
    required this.subject,
    required this.content,
    required this.sentAt,
    this.sender = 'HR Department',
    this.senderEmail = 'hr@ecashbook.com',
    this.priority = 'Medium',
  });

  factory HrLetterModel.fromJson(Map<String, dynamic> json) {
    // 1. ID
    final id = json['id']?.toString() ??
        json['letter_id']?.toString() ??
        json['letterId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // 2. Subject
    final subject = json['subject']?.toString() ??
        json['title']?.toString() ??
        'Official HR Communication';

    // 3. Content
    final content = json['content']?.toString() ??
        json['body']?.toString() ??
        json['html']?.toString() ??
        json['description']?.toString() ??
        '';

    // 4. Sent At
    final sentRaw = json['sent_at'] ??
        json['sentAt'] ??
        json['created_at'] ??
        json['createdAt'] ??
        json['date'];
    final sentAt = _parseDate(sentRaw) ?? DateTime.now();

    // 5. Sender & metadata (with API fallbacks)
    final sender = json['sender']?.toString() ??
        json['sender_name']?.toString() ??
        json['senderName']?.toString() ??
        'HR Department';

    final senderEmail = json['sender_email']?.toString() ??
        json['senderEmail']?.toString() ??
        json['email']?.toString() ??
        'hr@ecashbook.com';

    final priority = json['priority']?.toString() ?? 'Medium';

    return HrLetterModel(
      id: id,
      subject: subject,
      content: content,
      sentAt: sentAt,
      sender: sender,
      senderEmail: senderEmail,
      priority: priority,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return null;

    try {
      return DateTime.parse(str);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(str);
      } catch (_) {
        try {
          return DateFormat('yyyy-MM-dd').parse(str);
        } catch (_) {
          try {
            return DateFormat('dd-MM-yyyy HH:mm:ss').parse(str);
          } catch (_) {
            return null;
          }
        }
      }
    }
  }

  HrLetterEntity toEntity({bool isRead = true}) {
    return HrLetterEntity(
      id: id,
      subject: subject,
      content: content,
      sentAt: sentAt,
      sender: sender,
      senderEmail: senderEmail,
      priority: priority,
      isRead: isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'content': content,
        'sent_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(sentAt),
        'sender': sender,
        'sender_email': senderEmail,
        'priority': priority,
      };
}
