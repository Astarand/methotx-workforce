import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/hr_letter/data/models/hr_letter_model.dart';
import 'package:methotx_workforce/features/hr_letter/domain/entities/hr_letter_entity.dart';
import 'package:methotx_workforce/features/hr_letter/domain/repositories/hr_letter_repository.dart';
import 'package:methotx_workforce/features/hr_letter/presentation/controllers/hr_letter_controller.dart';
import 'package:methotx_workforce/features/hr_letter/presentation/screens/hr_letter_list_screen.dart';
import 'package:methotx_workforce/features/hr_letter/services/hr_letter_pdf_service.dart';
import 'package:methotx_workforce/features/payslip/data/models/company_details_model.dart';

class FakeHrLetterRepository implements HrLetterRepository {
  List<HrLetterEntity> letters = [];
  CompanyDetailsModel? company = const CompanyDetailsModel(
    compName: 'MethotX Corp Ltd',
    compEmail: 'hr@methotx.com',
    compPhone: '+91 9876543210',
    addressLine1: 'Park Street, Kolkata',
    city: 'Kolkata',
    state: 'West Bengal',
    pin: '700016',
    gstNo: '19ABCDE1234F1Z5',
  );

  @override
  Future<List<HrLetterEntity>> getLetterList() async => letters;

  @override
  Future<CompanyDetailsModel?> getCompanyDetails() async => company;

  @override
  void markLetterAsRead(String letterId) {
    letters = letters.map((l) {
      if (l.id == letterId) return l.copyWith(isRead: true);
      return l;
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HR Letter Model & Entity Tests', () {
    test('HrLetterModel.fromJson parses complete API payload accurately', () {
      final json = {
        'id': 17,
        'subject': 'Salary Revision Letter',
        'content': '<p>Dear Employee, We are pleased to revise your salary.</p>',
        'sent_at': '2026-08-30 10:15:00',
        'sender': 'HR Department',
        'sender_email': 'hr@ecashbook.com',
        'priority': 'High',
      };

      final model = HrLetterModel.fromJson(json);
      expect(model.id, '17');
      expect(model.subject, 'Salary Revision Letter');
      expect(model.content, contains('Dear Employee'));
      expect(model.sentAt.year, 2026);
      expect(model.sentAt.month, 8);
      expect(model.sentAt.day, 30);
      expect(model.sender, 'HR Department');
      expect(model.senderEmail, 'hr@ecashbook.com');
      expect(model.priority, 'High');

      final entity = model.toEntity(isRead: false);
      expect(entity.isRead, false);
      expect(entity.formattedDate, '30 Aug 2026');
      expect(entity.previewText, 'Dear Employee, We are pleased to revise your salary.');
    });

    test('HrLetterModel handles ISO 8601 date strings and fallback defaults', () {
      final json = {
        'letter_id': 'LTR-99',
        'title': 'Confirmation Letter',
        'body': '<h3>Congratulations</h3><p>Your probation is confirmed.</p>',
        'createdAt': '2026-09-01T14:30:00.000Z',
      };

      final model = HrLetterModel.fromJson(json);
      expect(model.id, 'LTR-99');
      expect(model.subject, 'Confirmation Letter');
      expect(model.sentAt.year, 2026);
      expect(model.sender, 'HR Department');

      final entity = model.toEntity(isRead: true);
      expect(entity.isRead, true);
      expect(entity.previewText, 'Congratulations Your probation is confirmed.');
    });
  });

  group('HR Letter PDF Generation Tests', () {
    test('HrLetterPdfService generates valid non-empty PDF bytes', () async {
      const company = CompanyDetailsModel(
        compName: 'MethotX Technologies',
        compEmail: 'contact@methotx.com',
        addressLine1: 'Tech Hub, Sector V',
        city: 'Kolkata',
        state: 'WB',
        pin: '700091',
        gstNo: '19AAACM1234A1Z1',
      );

      final pdfBytes = await HrLetterPdfService.generatePdf(
        contentHtml: '''
          <h1>Employment Certificate</h1>
          <p>This is to certify that the employee has been working with us.</p>
          <ul>
            <li>Designation: Software Engineer</li>
            <li>Department: Engineering</li>
          </ul>
          <hr />
          <p>Wishing them all the best for future endeavours.</p>
        ''',
        subject: 'Employment Certificate',
        companyDetails: company,
        sentAt: DateTime(2026, 9, 1),
        letterId: '101',
      );

      expect(pdfBytes, isNotEmpty);
      // PDF documents always begin with '%PDF-' magic header bytes (0x25, 0x50, 0x44, 0x46)
      expect(pdfBytes[0], 0x25);
      expect(pdfBytes[1], 0x50);
      expect(pdfBytes[2], 0x44);
      expect(pdfBytes[3], 0x46);
    });
  });

  group('HR Letter UI Widget Tests', () {
    testWidgets('HrLetterListScreen displays empty state when no letters available', (tester) async {
      final fakeRepo = FakeHrLetterRepository()..letters = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hrLetterControllerProvider.overrideWith(
              (ref) => HrLetterController(fakeRepo, ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HrLetterListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HR Letters'), findsOneWidget);
      expect(find.text('No HR Letters'), findsOneWidget);
    });

    testWidgets('HrLetterListScreen renders letters with unread count and latest letter unread badge', (tester) async {
      final fakeRepo = FakeHrLetterRepository()
        ..letters = [
          HrLetterEntity(
            id: '1',
            subject: 'Salary Increment Letter',
            content: '<p>Your revised CTC is active.</p>',
            sentAt: DateTime(2026, 9, 2, 10, 0),
            isRead: false,
          ),
          HrLetterEntity(
            id: '2',
            subject: 'Holiday Announcement',
            content: '<p>Office will remain closed on Friday.</p>',
            sentAt: DateTime(2026, 8, 25, 9, 0),
            isRead: true,
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hrLetterControllerProvider.overrideWith(
              (ref) => HrLetterController(fakeRepo, ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HrLetterListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HR Letters'), findsOneWidget);
      expect(find.text('1 Unread'), findsOneWidget);
      expect(find.text('Salary Increment Letter'), findsOneWidget);
      expect(find.text('Holiday Announcement'), findsOneWidget);
    });

    testWidgets('Tapping letter card navigates to HrLetterViewScreen and renders details', (tester) async {
      final letter = HrLetterEntity(
        id: '10',
        subject: 'Promotion Notification',
        content: '<h1>Congratulations</h1><p>You are promoted to Senior Lead.</p>',
        sentAt: DateTime(2026, 9, 3, 11, 30),
        sender: 'HR Department',
        senderEmail: 'hr@ecashbook.com',
        priority: 'High',
        isRead: false,
      );

      final fakeRepo = FakeHrLetterRepository()..letters = [letter];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hrLetterControllerProvider.overrideWith(
              (ref) => HrLetterController(fakeRepo, ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HrLetterListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Promotion Notification'));
      await tester.pumpAndSettle();

      // Verify View Screen
      expect(find.text('Letter Details'), findsOneWidget);
      expect(find.text('Promotion Notification'), findsOneWidget);
      expect(find.text('hr@ecashbook.com'), findsOneWidget);
      expect(find.text('Congratulations'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
    });
  });
}
