import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_toast.dart';

class PayslipPdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String? title;
  final Uint8List? pdfBytes;

  const PayslipPdfViewerScreen({
    super.key,
    required this.filePath,
    this.title,
    this.pdfBytes,
  });

  Future<Uint8List> _loadBytes() async {
    if (pdfBytes != null) return pdfBytes!;
    final file = File(filePath);
    return await file.readAsBytes();
  }

  void _openInExternalApp(BuildContext context) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && context.mounted) {
        AppToast.showError(
          context,
          title: 'Cannot Open File',
          message: result.message,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(
          context,
          title: 'Error',
          message: 'Could not launch external PDF reader: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title ?? 'Payslip Preview',
          style: AppTypography.headlineSmall.copyWith(
            fontSize: 18,
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: AppColors.primary),
            tooltip: 'Open with Device App',
            onPressed: () => _openInExternalApp(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _loadBytes(),
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: filePath.split('/').last,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}
