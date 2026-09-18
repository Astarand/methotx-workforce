import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:methotx_workforce/features/payslip/data/models/company_details_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/environment_config.dart';

class HrLetterPdfService {
  /// Generates a professional A4 MultiPage PDF for an HR letter
  /// Downloads an image from [url] using dart:io HttpClient with optional
  /// auth headers. Works reliably on both Android and iOS.
  static Future<pw.ImageProvider?> _downloadImageWithAuth(
    String url, {
    String? authToken,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      if (authToken != null && authToken.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $authToken');
      }
      request.headers.set('Accept', 'image/*');
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        if (bytes.isNotEmpty) {
          return pw.MemoryImage(Uint8List.fromList(bytes));
        }
      }
      client.close(force: true);
    } catch (_) {
      // Silently fail — caller handles null
    }
    return null;
  }

  static Future<Uint8List> generatePdf({
    required String contentHtml,
    required String subject,
    CompanyDetailsModel? companyDetails,
    DateTime? sentAt,
    String? letterId,
    String? authToken,
  }) async {
    final doc = pw.Document();

    // 1. Load Unicode Fonts
    pw.Font fontRegular;
    pw.Font fontBold;
    pw.Font fontItalic;
    try {
      fontRegular = await PdfGoogleFonts.notoSansRegular();
      fontBold = await PdfGoogleFonts.notoSansBold();
      fontItalic = await PdfGoogleFonts.notoSansItalic();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontItalic = pw.Font.helveticaOblique();
    }

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
    );

    // 2. Fetch Company Logo
    pw.ImageProvider? logoProvider;
    final rawLogo = companyDetails?.compLogo;
    if (rawLogo != null &&
        rawLogo.trim().isNotEmpty &&
        rawLogo.trim() != 'null') {
      final trimmed = rawLogo.trim();
      final fullUrl =
          (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
          ? trimmed
          : ApiEndpoints.resolveImageUrl(trimmed) ??
                '${EnvironmentConfig.domainUrl}/${trimmed.replaceFirst(RegExp(r'^/'), '')}';

      // Build auth headers map for networkImage
      final Map<String, String> imageHeaders = {
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
        'Accept': 'image/*',
      };

      try {
        // Try printing package's networkImage with auth headers
        logoProvider = await networkImage(fullUrl, headers: imageHeaders);
      } catch (_) {
        try {
          // Fallback: use dart:io HttpClient (more reliable on iOS)
          logoProvider = await _downloadImageWithAuth(
            fullUrl,
            authToken: authToken,
          );
        } catch (_) {
          try {
            // Last resort: try raw URL without path resolution
            if (fullUrl != trimmed) {
              logoProvider = await _downloadImageWithAuth(
                trimmed,
                authToken: authToken,
              );
            }
          } catch (_) {
            logoProvider = null;
          }
        }
      }
    }

    // 3. Company Metadata
    final compName = companyDetails?.compName ?? 'MethotX Workforce';
    final address = companyDetails?.fullAddress ?? 'Corporate Headquarters';
    final email = companyDetails?.compEmail;
    final phone = companyDetails?.compPhone;
    final gstNo = companyDetails?.gstNo;

    // 4. Parse HTML Content into PDF Widgets
    final contentWidgets = _parseHtmlToWidgets(
      contentHtml,
      fontRegular,
      fontBold,
      fontItalic,
    );

    final dateStr = DateFormat('dd MMMM yyyy').format(sentAt ?? DateTime.now());

    // 5. Build Document Page
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Company text details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          compName,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 15,
                            color: PdfColor.fromHex('#004C6D'),
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          address,
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 8.5,
                            color: PdfColors.grey700,
                          ),
                        ),
                        if (email != null && email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Email: $email ${phone != null && phone.isNotEmpty ? "• Phone: $phone" : ""}',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                        if (gstNo != null && gstNo.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'GSTIN / Reg No: $gstNo',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8.5,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Company Logo
                  if (logoProvider != null)
                    pw.Container(
                      width: 60,
                      height: 50,
                      margin: const pw.EdgeInsets.only(left: 12),
                      alignment: pw.Alignment.topRight,
                      child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                    ),
                ],
              ),
              pw.SizedBox(height: 10),
              // Blue divider line
              pw.Container(height: 2, color: PdfColor.fromHex('#004C6D')),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.Container(height: 0.8, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated via MethotX HR Portal',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated document. No physical signature is required.',
                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 7,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
        build: (context) {
          return [
            // Metadata header (Date, Ref)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (letterId != null && letterId.isNotEmpty)
                  pw.Text(
                    'Ref: HR/LTR/$letterId',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  )
                else
                  pw.SizedBox(),
                pw.Text(
                  'Date: $dateStr',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Subject
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 10,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0F7FB'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(
                  color: PdfColor.fromHex('#CCE5F4'),
                  width: 0.8,
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Subject: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: PdfColor.fromHex('#004C6D'),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      subject,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Letter Body Elements
            ...contentWidgets,
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Converts HTML string into list of native PDF widgets
  static List<pw.Widget> _parseHtmlToWidgets(
    String html,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontItalic,
  ) {
    final widgets = <pw.Widget>[];

    // Normalize breaks and line endings
    String cleanHtml = html
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .trim();

    // Match blocks (headings, paragraphs, lists, tables)
    final blockRegex = RegExp(
      r'<(h[1-6]|p|div|ul|ol|table|hr)[^>]*>(.*?)</\1>|<hr\s*/?>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = blockRegex.allMatches(cleanHtml);

    if (matches.isEmpty) {
      // Fallback: split by double newlines
      final paragraphs = cleanHtml.split(RegExp(r'\n{2,}'));
      for (final p in paragraphs) {
        final text = p.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (text.isNotEmpty) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9.5,
                  lineSpacing: 2,
                ),
              ),
            ),
          );
        }
      }
      return widgets;
    }

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final inner = match.group(2) ?? '';

      if (tag == 'hr' || match.group(0)?.startsWith('<hr') == true) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Container(height: 0.8, color: PdfColors.grey300),
          ),
        );
        continue;
      }

      if (tag != null && tag.startsWith('h')) {
        final level = int.tryParse(tag.substring(1)) ?? 2;
        final fontSize = level == 1
            ? 13.0
            : level == 2
            ? 11.5
            : 10.0;
        final text = _stripTags(inner);
        if (text.isNotEmpty) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: fontSize,
                  color: PdfColor.fromHex('#004C6D'),
                ),
              ),
            ),
          );
        }
        continue;
      }

      if (tag == 'ul' || tag == 'ol') {
        final isOrdered = tag == 'ol';
        final itemRegex = RegExp(
          r'<li[^>]*>(.*?)</li>',
          caseSensitive: false,
          dotAll: true,
        );
        final itemMatches = itemRegex.allMatches(inner);

        int index = 1;
        for (final item in itemMatches) {
          final itemText = _stripTags(item.group(1) ?? '');
          if (itemText.isNotEmpty) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (isOrdered)
                      pw.SizedBox(
                        width: 16,
                        child: pw.Text(
                          '$index.',
                          style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                        ),
                      )
                    else
                      pw.Container(
                        width: 16,
                        alignment: pw.Alignment.topLeft,
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Container(
                          width: 3.5,
                          height: 3.5,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.black,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      ),
                    pw.Expanded(
                      child: pw.Text(
                        itemText,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 9.5,
                          lineSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            index++;
          }
        }
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      // Paragraph / Div
      final text = _stripTags(inner);
      if (text.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 9.5,
                lineSpacing: 2,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
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
        .replaceAll('₹', 'Rs. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Saves PDF to local device storage and opens with viewer
  static Future<String> saveAndOpenPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
    return file.path;
  }

  /// Native Share / Print PDF
  static Future<void> sharePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
