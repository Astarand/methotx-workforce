import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_toast.dart';

class AttachmentViewerHelper {
  AttachmentViewerHelper._();

  /// Downloads a remote attachment (if not already cached) to temporary storage and
  /// opens it natively via OpenFilex (launches iOS QuickLook or Android system viewer).
  static Future<void> openAttachment(
    BuildContext context, {
    required String url,
    String? fileName,
  }) async {
    try {
      AppToast.showInfo(context, message: 'Opening document...');

      var name = fileName ?? url.split('/').last.split('?').first;
      if (name.isEmpty || name == 'attachment') {
        name = 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      }
      // Ensure file has an extension if missing so system file handlers resolve MIME type correctly
      if (!name.contains('.')) {
        if (url.toLowerCase().contains('.pdf') || url.toLowerCase().contains('pdf')) {
          name = '$name.pdf';
        } else if (url.toLowerCase().contains('.png')) {
          name = '$name.png';
        } else {
          name = '$name.jpg'; // default image fallback
        }
      }

      final dir = await getTemporaryDirectory();
      final targetDir = Directory('${dir.path}/attachments');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final localFile = File('${targetDir.path}/$name');

      // Download if not already cached locally or if empty
      if (!await localFile.exists() || await localFile.length() == 0) {
        final dio = Dio();
        await dio.download(url, localFile.path);
      }

      final result = await OpenFilex.open(localFile.path);
      if (result.type != ResultType.done && context.mounted) {
        final isImage = name.toLowerCase().endsWith('.png') ||
            name.toLowerCase().endsWith('.jpg') ||
            name.toLowerCase().endsWith('.jpeg') ||
            url.toLowerCase().endsWith('.png') ||
            url.toLowerCase().endsWith('.jpg') ||
            url.toLowerCase().endsWith('.jpeg');

        if (isImage) {
          showImageViewer(context, url: url, title: 'Attachment Preview', fileName: name);
        } else {
          AppToast.showError(
            context,
            message: 'Unable to open file: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(
          context,
          message: 'Could not open document: $e',
        );
      }
    }
  }

  /// Displays an interactive full-screen image viewer with pinch-to-zoom, pan,
  /// and an action button to open/download in the native system viewer.
  static void showImageViewer(
    BuildContext context, {
    required String url,
    String title = 'Attachment Preview',
    String? fileName,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.6),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                tooltip: 'Open in system viewer',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAttachment(context, url: url, fileName: fileName);
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Unable to display image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
