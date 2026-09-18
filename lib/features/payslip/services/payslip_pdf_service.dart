import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_endpoints.dart';
import '../data/models/company_details_model.dart';
import '../domain/entities/payslip_entity.dart';

class PayslipPdfService {
  static const _rupeeSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 512">
  <path fill="#000000" d="M308 96c6.6 0 12-5.4 12-12V44c0-6.6-5.4-12-12-12H12C5.4 32 0 37.4 0 44v40c0 6.6 5.4 12 12 12h56.7c39.9 0 74.4 24.3 88.9 59.2H12c-6.6 0-12 5.4-12 12v40c0 6.6 5.4 12 12 12h147.2c-15.3 35.8-51 60.8-92.5 60.8H12c-6.6 0-12 5.4-12 12v44.2c0 3.2 1.3 6.3 3.6 8.5l172.5 168c4.7 4.6 12.3 4.6 17 0l31.1-30.3c4.8-4.7 4.8-12.4 0-17.1L95.5 320H156c70.8 0 130.6-47.5 148.9-112H308c6.6 0 12-5.4 12-12v-40c0-6.6-5.4-12-12-12h-47.9c-2.4-13.6-7-26.4-13.4-38H308z"/>
</svg>
''';

  static String formatAmountNumber(dynamic value) {
    if (value == null ||
        value == 0 ||
        value == '0' ||
        value == '0.00' ||
        value == 0.0) {
      return '0.00';
    }
    final clean = value
        .toString()
        .replaceAll(',', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll('₹', '')
        .trim();
    final d = double.tryParse(clean);
    if (d != null) {
      return NumberFormat('#,##,##0.00', 'en_IN').format(d);
    }
    return value.toString();
  }

  static pw.Widget rupeeAmount(
    dynamic value, {
    bool isBold = false,
    double fontSize = 7.5,
    PdfColor color = PdfColors.black,
  }) {
    final numStr = formatAmountNumber(value);
    final iconWidth = fontSize * 0.65;
    final iconHeight = fontSize * 0.92;

    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SvgImage(svg: _rupeeSvg, width: iconWidth, height: iconHeight),
        pw.SizedBox(width: 2.5),
        pw.Text(
          numStr,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Downloads an image from [url] using dart:io HttpClient with optional
  /// auth headers. Auto-retrieves stored auth token if [authToken] is omitted or empty.
  static Future<pw.ImageProvider?> _downloadImageWithAuth(
    String url, {
    String? authToken,
  }) async {
    try {
      var token = authToken?.trim();
      if (token == null || token.isEmpty) {
        try {
          const secureStorage = FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );
          token = await secureStorage.read(key: ApiConstants.storageTokenKey);
          if (token == null || token.trim().isEmpty) {
            final prefs = await SharedPreferences.getInstance();
            token = prefs.getString(ApiConstants.storageTokenKey);
          }
        } catch (_) {}
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      if (token != null && token.trim().isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${token.trim()}');
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

  /// Loads a local fallback asset image as Uint8List for PDF rendering
  static Future<pw.ImageProvider?> _loadFallbackAssetImage(
    String assetPath,
  ) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final assetBytes = byteData.buffer.asUint8List();
      if (assetBytes.isNotEmpty) {
        return pw.MemoryImage(assetBytes);
      }
    } catch (_) {
      // Silently fail if asset fails
    }
    return null;
  }

  /// Main Generator Method matching exact Laravel A4 PDF design
  static Future<Uint8List> generate({
    required Map<String, dynamic> visible,
    Map<String, dynamic>? companyInfo,
    String? authToken,
  }) async {
    final doc = pw.Document();

    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
      fontRegular = await PdfGoogleFonts.notoSansRegular();
      fontBold = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // Extract nested sub-maps safely
    final emp = visible['employee_details'] is Map
        ? Map<String, dynamic>.from(visible['employee_details'] as Map)
        : <String, dynamic>{};

    final finalCal = visible['final_salary_calculation'] is Map
        ? Map<String, dynamic>.from(visible['final_salary_calculation'] as Map)
        : <String, dynamic>{};

    // Download company logo specifically using comp_logo URL or company logo API endpoint
    pw.ImageProvider? logoProvider;

    String? resolveCompanyLogoUrl() {
      // 1. Check comp_logo URL returned from POST /users/company/details
      final rawLogo = companyInfo?['comp_logo']?.toString() ??
          companyInfo?['logo']?.toString() ??
          companyInfo?['company_logo']?.toString() ??
          (visible['company_info'] is Map
              ? (visible['company_info']['comp_logo'] ??
                      visible['company_info']['logo'] ??
                      visible['company_info']['company_logo'])
                  ?.toString()
              : null);

      if (rawLogo != null &&
          rawLogo.trim().isNotEmpty &&
          rawLogo.trim() != 'null') {
        final trimmed = rawLogo.trim();

        // If rawLogo is a pure numeric ID like "1" or "42", resolve to company logo endpoint URL
        if (RegExp(r'^\d+$').hasMatch(trimmed)) {
          return ApiEndpoints.companyLogo(trimmed);
        }

        // If already a full http/https URL
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }

        // If relative path contains "company/logo" or "logo/"
        if (trimmed.contains('company/logo/')) {
          final idPart = trimmed.split('company/logo/').last;
          final cleanId = RegExp(r'^\d+').stringMatch(idPart);
          if (cleanId != null && cleanId.isNotEmpty) {
            return ApiEndpoints.companyLogo(cleanId);
          }
        }

        final resolved = ApiEndpoints.resolveImageUrl(trimmed);
        if (resolved != null) return resolved;
      }

      // 2. Check explicit company ID if comp_logo string was missing
      final compId = companyInfo?['id']?.toString() ??
          companyInfo?['comp_id']?.toString() ??
          companyInfo?['company_id']?.toString() ??
          (visible['company_info'] is Map
              ? (visible['company_info']['id'] ??
                      visible['company_info']['comp_id'] ??
                      visible['company_info']['company_id'])
                  ?.toString()
              : null);

      if (compId != null &&
          compId.trim().isNotEmpty &&
          compId.trim() != 'null') {
        return ApiEndpoints.companyLogo(compId.trim());
      }

      // 3. Fallback to default company logo endpoint via ApiEndpoints.companyLogo('1')
      return ApiEndpoints.companyLogo('1');
    }

    final fullUrl = resolveCompanyLogoUrl();

    if (fullUrl != null && fullUrl.isNotEmpty) {
      final Map<String, String> imageHeaders = {
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
        'Accept': 'image/*',
      };

      try {
        logoProvider = await networkImage(fullUrl, headers: imageHeaders);
      } catch (_) {
        try {
          logoProvider = await _downloadImageWithAuth(
            fullUrl,
            authToken: authToken,
          );
        } catch (_) {
          logoProvider = null;
        }
      }
    }

    // Fallback to local bundled asset if network logo fails or is unavailable
    logoProvider ??= await _loadFallbackAssetImage('assets/images/logo.png');

    // Company Header Info
    final compName =
        companyInfo?['comp_name']?.toString() ??
        companyInfo?['company_name']?.toString() ??
        companyInfo?['name']?.toString() ??
        '360 BUSINESS & SERVICES';

    final addOne =
        companyInfo?['comp_bill_addone']?.toString() ??
        companyInfo?['address']?.toString() ??
        companyInfo?['addressLine1']?.toString() ??
        '';

    final addTwo = companyInfo?['comp_bill_addtwo']?.toString() ?? '';
    final city =
        companyInfo?['comp_bill_city']?.toString() ??
        companyInfo?['city']?.toString() ??
        '';
    final pin =
        companyInfo?['comp_bill_pin']?.toString() ??
        companyInfo?['pin']?.toString() ??
        '';

    final line2Parts = [
      if (addTwo.isNotEmpty) addTwo,
      if (city.isNotEmpty) city,
      if (pin.isNotEmpty) pin,
    ];
    final addTwoLine = line2Parts.isNotEmpty ? line2Parts.join(', ') : '';

    final phone =
        companyInfo?['comp_phone']?.toString() ??
        companyInfo?['phone']?.toString() ??
        '';
    final email =
        companyInfo?['comp_email']?.toString() ??
        companyInfo?['email']?.toString() ??
        '';
    final contactParts = [
      if (phone.isNotEmpty) 'Phone: $phone',
      if (email.isNotEmpty) 'Email: $email',
    ];
    final contactLine = contactParts.join(' | ');

    final gst =
        companyInfo?['comp_bill_gst_no']?.toString() ??
        companyInfo?['gst_no']?.toString() ??
        companyInfo?['gstNo']?.toString() ??
        companyInfo?['gstin']?.toString() ??
        '';
    final pan =
        companyInfo?['comp_pan_no']?.toString() ??
        companyInfo?['pan_no']?.toString() ??
        companyInfo?['pan']?.toString() ??
        '';
    final taxParts = [
      if (gst.isNotEmpty) 'GST: $gst',
      if (pan.isNotEmpty) 'PAN: $pan',
    ];
    final taxLine = taxParts.join(' | ');

    // Payslip Metadata
    final payslipNo =
        visible['payslip_no']?.toString() ??
        visible['payslip_number']?.toString() ??
        '-';
    final monthName =
        visible['month_name']?.toString() ?? visible['month']?.toString() ?? '';
    final year =
        visible['year']?.toString() ??
        visible['financial_year']?.toString() ??
        '';
    final monthYear = [monthName, year].where((s) => s.isNotEmpty).join(' ');

    // Standard Grid Border
    const tableBorderColor = PdfColor.fromInt(0xFFD0D5DD);
    final gridBorder = pw.TableBorder.all(color: tableBorderColor, width: 0.5);

    // Earnings & Deductions Mappings
    final earningsMap = <String, dynamic>{
      'Basic Salary': finalCal['basic_salary'],
      'House Rent Allowance (HRA)': finalCal['hra'],
      'Conveyance Allowance': finalCal['conveyance'],
      'Medical Allowance': finalCal['medical_allowance'],
      'Special Allowance': finalCal['special_allowance'],
      'Performance Bonus': finalCal['performance_bonus'],
      'Overtime Payment': finalCal['overtime_payment'],
    };

    final deductionsMap = <String, dynamic>{
      'Employee Provident Fund (EPF)': finalCal['provident_fund'],
      'Employee State Insurance (ESI)': finalCal['esi'],
      'Professional Tax (PT)': finalCal['ptax'],
      'TDS - Tax Deducted at Source': finalCal['tds'],
      'Loan Deduction': finalCal['loan'],
      'Loss of Pay (LOP)': finalCal['lop'],
      'Advance': finalCal['advance'],
    };

    if (finalCal['lwf'] != null &&
        finalCal['lwf'] != 0 &&
        finalCal['lwf'] != '0' &&
        finalCal['lwf'] != '0.00') {
      deductionsMap['Labour Welfare Fund (LWF)'] = finalCal['lwf'];
    }

    final eKeys = earningsMap.keys.toList();
    final dKeys = deductionsMap.keys.toList();
    final rowCount = eKeys.length > dKeys.length ? eKeys.length : dKeys.length;

    // In Words text
    final inWordsText =
        finalCal['in_words']?.toString() ??
        visible['in_words']?.toString() ??
        _numberToWords(
          double.tryParse(finalCal['net_salary']?.toString() ?? '0') ?? 0.0,
        );

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Company Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo
                  if (logoProvider != null)
                    pw.SizedBox(
                      width: 80,
                      height: 80,
                      child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.SizedBox(width: 80),

                  // Company Address / Info (Right Aligned)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          compName,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        if (addOne.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            addOne,
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                        if (addTwoLine.isNotEmpty) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            addTwoLine,
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                        if (contactLine.isNotEmpty) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            contactLine,
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                        if (taxLine.isNotEmpty) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            taxLine,
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 2. Payslip Metadata Table
              pw.Table(
                border: gridBorder,
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.6),
                  2: pw.FlexColumnWidth(1.6),
                  3: pw.FlexColumnWidth(2.2),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5.5,
                        ),
                        child: pw.Text(
                          'Payslip Number',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5.5,
                        ),
                        child: pw.Text(
                          payslipNo,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5.5,
                        ),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            'Payslip Month & Year',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5.5,
                        ),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            monthYear,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // 3. Employee and Bank Details (Side-by-Side Tables)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Employee Details
                  pw.Expanded(
                    child: pw.Table(
                      border: gridBorder,
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.1),
                        1: pw.FlexColumnWidth(1.8),
                      },
                      children: [
                        _buildInfoRow(
                          'Employee Name:',
                          emp['name']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'Employee ID:',
                          emp['employee_id']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'Department:',
                          emp['dept_name']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'Designation:',
                          emp['designation_name']?.toString() ?? '-',
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Right: Bank Details
                  pw.Expanded(
                    child: pw.Table(
                      border: gridBorder,
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.1),
                        1: pw.FlexColumnWidth(1.8),
                      },
                      children: [
                        _buildInfoRow(
                          'Bank Name:',
                          emp['bank_name']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'Account No.:',
                          emp['account_number']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'IFSC Code:',
                          emp['ifsc']?.toString() ?? '-',
                        ),
                        _buildInfoRow(
                          'PAN No:',
                          emp['pan_number']?.toString() ?? '-',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 4. "Details" Section Header
              pw.Text(
                'Details',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 6),

              // 5. Earnings and Deductions Composite Table matching exact Laravel A4 Portal
              // 5a. Category Header (Grey Banner across 50% / 50%)
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                border: pw.TableBorder(
                  top: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  left: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  right: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  bottom: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  verticalInside: pw.BorderSide(
                    color: tableBorderColor,
                    width: 0.5,
                  ),
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFECEFF1),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: pw.Text(
                          'EARNINGS',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: pw.Text(
                          'DEDUCTIONS',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 5b. Subheaders, Data Rows, and Totals Row (4 Columns: 35% | 15% | 35% | 15%)
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.5),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(3.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                border: pw.TableBorder(
                  left: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  right: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  bottom: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  verticalInside: pw.BorderSide(
                    color: tableBorderColor,
                    width: 0.5,
                  ),
                  horizontalInside: pw.BorderSide(
                    color: tableBorderColor,
                    width: 0.5,
                  ),
                ),
                children: [
                  // Subheaders
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: pw.Text(
                          'DESCRIPTION',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: pw.Text(
                          'AMOUNT',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: pw.Text(
                          'DESCRIPTION',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: pw.Text(
                          'AMOUNT',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Side-by-Side Data Rows
                  for (int i = 0; i < rowCount; i++)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          child: pw.Text(
                            i < eKeys.length ? eKeys[i] : '',
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          child:
                              (i < eKeys.length &&
                                  earningsMap[eKeys[i]] != null)
                              ? rupeeAmount(earningsMap[eKeys[i]])
                              : pw.Container(),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          child: pw.Text(
                            i < dKeys.length ? dKeys[i] : '',
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          child:
                              (i < dKeys.length &&
                                  deductionsMap[dKeys[i]] != null)
                              ? rupeeAmount(deductionsMap[dKeys[i]])
                              : pw.Container(),
                        ),
                      ],
                    ),

                  // Totals Row (Mint Green Banner)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFD1E7DD),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: pw.Text(
                          'Total Earnings',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: rupeeAmount(
                          finalCal['total_earnings'],
                          isBold: true,
                          fontSize: 8,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: pw.Text(
                          'Total Deductions',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: rupeeAmount(
                          finalCal['total_deductions'],
                          isBold: true,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 5c. Net Salary & In Words Rows (2 Columns: 50% | 50% split)
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                border: pw.TableBorder(
                  left: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  right: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  bottom: pw.BorderSide(color: tableBorderColor, width: 0.5),
                  verticalInside: pw.BorderSide(
                    color: tableBorderColor,
                    width: 0.5,
                  ),
                  horizontalInside: pw.BorderSide(
                    color: tableBorderColor,
                    width: 0.5,
                  ),
                ),
                children: [
                  // Net Salary Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'Net Salary: ',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            rupeeAmount(
                              finalCal['net_salary'],
                              isBold: true,
                              fontSize: 8,
                            ),
                          ],
                        ),
                      ),
                      pw.Container(),
                    ],
                  ),

                  // Net Salary In Words Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'Net Salary (In Words): ',
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.TextSpan(
                                text: inWordsText,
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.Container(),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // 6. Footer
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'This is a computer-generated document. No signature is required.',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Generates a PDF byte array using PayslipEntity (delegates to `generate`)
  static Future<Uint8List> generatePayslipPdf({
    required PayslipEntity payslip,
    CompanyDetailsModel? company,
    String? authToken,
  }) async {
    final effectiveLogo =
        (company?.compLogo != null &&
            company!.compLogo!.isNotEmpty &&
            company.compLogo != 'null')
        ? company.compLogo
        : (payslip.companyLogo != null &&
              payslip.companyLogo!.isNotEmpty &&
              payslip.companyLogo != 'null')
        ? payslip.companyLogo
        : null;

    final compMap = <String, dynamic>{
      if (company != null) ...company.toJson(),
      if (payslip.companyInfo != null) ...payslip.companyInfo!,
      if (effectiveLogo != null) ...{
        'comp_logo': effectiveLogo,
        'logo': effectiveLogo,
      },
    };

    // If raw visibleData is directly present, use it
    if (payslip.visibleData != null && payslip.visibleData!.isNotEmpty) {
      return generate(visible: payslip.visibleData!, companyInfo: compMap, authToken: authToken);
    }

    // Construct visibleData map from PayslipEntity
    final visibleMap = _entityToVisibleMap(payslip);

    return generate(visible: visibleMap, companyInfo: compMap, authToken: authToken);
  }

  /// Helper to convert PayslipEntity to visibleData map structure
  static Map<String, dynamic> _entityToVisibleMap(PayslipEntity p) {
    double findAmount(
      List<PayslipItemEntity> items,
      List<String> matchKeywords,
    ) {
      for (final kw in matchKeywords) {
        final found = items.firstWhere(
          (e) => e.title.toLowerCase().contains(kw.toLowerCase()),
          orElse: () => const PayslipItemEntity(title: '', amount: 0.0),
        );
        if (found.amount > 0) return found.amount;
      }
      return 0.0;
    }

    final basic = findAmount(p.earnings, ['basic']);
    final hra = findAmount(p.earnings, ['hra', 'house rent']);
    final conveyance = findAmount(p.earnings, ['conveyance']);
    final medical = findAmount(p.earnings, ['medical']);
    final special = findAmount(p.earnings, ['special']);
    final bonus = findAmount(p.earnings, ['bonus', 'performance']);
    final overtime = findAmount(p.earnings, ['overtime']);

    final epf = findAmount(p.deductions, ['provident', 'epf', 'pf']);
    final esi = findAmount(p.deductions, ['esi', 'insurance']);
    final pt = findAmount(p.deductions, ['professional', 'ptax', 'pt']);
    final tds = findAmount(p.deductions, ['tds', 'tax']);
    final loan = findAmount(p.deductions, ['loan']);
    final lop = findAmount(p.deductions, ['lop', 'loss']);
    final advance = findAmount(p.deductions, ['advance']);

    return {
      'payslip_no': p.payslipNumber,
      'month_name': p.month,
      'year': p.financialYear,
      'month': p.month,
      'employee_details': {
        'name': p.employeeName,
        'employee_id': p.employeeCode,
        'dept_name': p.department,
        'designation_name': p.designation,
        'bank_name': p.bankName ?? '-',
        'account_number': p.accountNo ?? '-',
        'ifsc': p.ifscCode ?? '-',
        'pan_number': p.panNo ?? '-',
      },
      'final_salary_calculation': {
        'basic_salary': basic > 0 ? basic : p.grossSalary,
        'hra': hra,
        'conveyance': conveyance,
        'medical_allowance': medical,
        'special_allowance': special,
        'performance_bonus': bonus,
        'overtime_payment': overtime,
        'provident_fund': epf,
        'esi': esi,
        'ptax': pt,
        'tds': tds,
        'loan': loan,
        'lop': lop,
        'advance': advance,
        'total_earnings': p.totalAdditions > 0
            ? p.totalAdditions
            : p.grossSalary,
        'total_deductions': p.totalDeductions,
        'net_salary': p.netSalary,
        'in_words': p.inWords ?? _numberToWords(p.netSalary),
      },
    };
  }

  /// Writes PDF bytes to local app storage and returns the absolute file path
  static Future<String> savePdfToFile({
    required Uint8List bytes,
    required String employeeId,
    required String month,
    required String financialYear,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final cleanYear = financialYear.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cleanMonth = month.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanEmp = employeeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    final fileName = 'Payslip_${cleanEmp}_${cleanMonth}_$cleanYear.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static pw.TableRow _buildInfoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
            ),
          ),
        ),
      ],
    );
  }

  static String _numberToWords(double amount) {
    if (amount <= 0) return 'Rupees Zero Only';
    final intVal = amount.round();
    final words = _convertChunk(intVal);
    return '$words Only';
  }

  static String _convertChunk(int n) {
    const units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (n == 0) return '';
    if (n < 20) return units[n];
    if (n < 100) {
      final rem = n % 10;
      return '${tens[n ~/ 10]}${rem != 0 ? ' ${units[rem]}' : ''}';
    }
    if (n < 1000) {
      final rem = n % 100;
      return '${units[n ~/ 100]} Hundred${rem != 0 ? ' and ${_convertChunk(rem)}' : ''}';
    }
    if (n < 100000) {
      final rem = n % 1000;
      return '${_convertChunk(n ~/ 1000)} Thousand${rem != 0 ? ' ${_convertChunk(rem)}' : ''}';
    }
    if (n < 10000000) {
      final rem = n % 100000;
      return '${_convertChunk(n ~/ 100000)} Lakh${rem != 0 ? ' ${_convertChunk(rem)}' : ''}';
    }
    final rem = n % 10000000;
    return '${_convertChunk(n ~/ 10000000)} Crore${rem != 0 ? ' ${_convertChunk(rem)}' : ''}';
  }
}
