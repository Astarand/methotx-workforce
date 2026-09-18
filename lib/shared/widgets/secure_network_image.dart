import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_constants.dart';
import '../../core/theme/app_colors.dart';

/// Semantic classification for image fallbacks & default styling
enum ImageType { employee, company, general }

/// A highly optimized, production-ready secure network image widget.
///
/// Handles Bearer authentication headers (`Authorization: Bearer <token>`),
/// `Accept: image/*`, local caching via [CachedNetworkImage] and [CacheManager],
/// smooth Shimmer loading effects, and customizable fallback states.
class SecureNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final String? authToken;
  final ImageType imageType;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;
  final Color? backgroundColor;
  final Widget? customPlaceholder;
  final Widget? customErrorWidget;
  final IconData? fallbackIcon;
  final CacheManager? cacheManager;
  final String? cacheKey;

  const SecureNetworkImage({
    super.key,
    required this.imageUrl,
    this.authToken,
    this.imageType = ImageType.general,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.border,
    this.backgroundColor,
    this.customPlaceholder,
    this.customErrorWidget,
    this.fallbackIcon,
    this.cacheManager,
    this.cacheKey,
  });

  /// Factory constructor tailored for Company Logos
  factory SecureNetworkImage.companyLogo({
    Key? key,
    required String? url,
    String? token,
    double width = 48.0,
    double height = 48.0,
    BoxFit fit = BoxFit.contain,
    BorderRadiusGeometry? borderRadius,
    Border? border,
    Color? backgroundColor,
    String? cacheKey,
  }) {
    return SecureNetworkImage(
      key: key,
      imageUrl: url,
      authToken: token,
      imageType: ImageType.company,
      width: width,
      height: height,
      fit: fit,
      shape: BoxShape.rectangle,
      borderRadius: borderRadius ?? BorderRadius.circular(8.0),
      border: border,
      backgroundColor: backgroundColor ?? AppColors.surfaceContainerLow,
      cacheKey: cacheKey,
    );
  }

  /// Factory constructor tailored for Employee Profile Images
  factory SecureNetworkImage.employeeProfile({
    Key? key,
    required String? url,
    String? token,
    double size = 50.0,
    BoxFit fit = BoxFit.cover,
    Border? border,
    Color? backgroundColor,
    String? cacheKey,
  }) {
    return SecureNetworkImage(
      key: key,
      imageUrl: url,
      authToken: token,
      imageType: ImageType.employee,
      width: size,
      height: size,
      fit: fit,
      shape: BoxShape.circle,
      border: border,
      backgroundColor: backgroundColor ?? AppColors.surfaceContainerLow,
      cacheKey: cacheKey,
    );
  }

  /// Evicts a specific image URL from local memory and disk cache so that
  /// the app fetches the latest updated image from the server.
  static Future<void> evictImage(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    try {
      final clean = url.trim();
      // Skip path_provider dependent cache in test environments
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
      await CachedNetworkImage.evictFromCache(clean);
      await DefaultCacheManager().removeFile(clean);
      if (clean.contains('?')) {
        final noQuery = clean.split('?').first;
        await CachedNetworkImage.evictFromCache(noQuery);
        await DefaultCacheManager().removeFile(noQuery);
      }
    } catch (_) {
      // Gracefully ignore missing cache manager / missing plugin in test environments
    }
  }

  /// Clears all cached network images from device storage
  static Future<void> clearAllCache() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Gracefully ignore missing cache manager in test environments
    }
  }

  @override
  State<SecureNetworkImage> createState() => _SecureNetworkImageState();
}

class _SecureNetworkImageState extends State<SecureNetworkImage> {
  late Future<String?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _resolveAuthToken();
  }

  @override
  void didUpdateWidget(covariant SecureNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authToken != widget.authToken ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey) {
      _tokenFuture = _resolveAuthToken();
    }
  }

  /// Dynamically retrieves the Bearer token if not explicitly provided
  Future<String?> _resolveAuthToken() async {
    if (widget.authToken != null && widget.authToken!.trim().isNotEmpty) {
      return widget.authToken!.trim();
    }

    try {
      // 1. Check Hardware Secure Storage with aligned platform options
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      final secureToken = await secureStorage.read(
        key: ApiConstants.storageTokenKey,
      );
      if (secureToken != null && secureToken.trim().isNotEmpty) {
        return secureToken.trim();
      }

      // 2. Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsToken = prefs.getString(ApiConstants.storageTokenKey);
      if (prefsToken != null && prefsToken.trim().isNotEmpty) {
        return prefsToken.trim();
      }
    } catch (_) {
      // Silent catch - fallback UI will handle missing auth gracefully
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.imageUrl?.trim();

    if (cleanUrl == null || cleanUrl.isEmpty || cleanUrl == 'null') {
      return _buildFallbackWidget(context);
    }

    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.customPlaceholder ??
              CustomShimmerWidget(
                width: widget.width,
                height: widget.height,
                shape: widget.shape,
                borderRadius: widget.borderRadius,
              );
        }

        final token = snapshot.data;
        return _buildCachedImageWidget(context, cleanUrl, token);
      },
    );
  }

  /// Constructs the CachedNetworkImage widget with injected headers
  Widget _buildCachedImageWidget(
    BuildContext context,
    String url,
    String? token,
  ) {
    // 1. Force HTTPS on all network requests so cleartext policy never blocks
    final secureUrl = url.startsWith('http://')
        ? url.replaceFirst('http://', 'https://')
        : url;

    // 2. Prepare headers with Bearer token, Accept, and standard Mobile User-Agent
    final cleanToken = token?.trim();
    final effectiveToken =
        (cleanToken != null && cleanToken.startsWith('Bearer '))
            ? cleanToken.substring(7).trim()
            : cleanToken;

    final headers = <String, String>{
      if (effectiveToken != null && effectiveToken.isNotEmpty)
        ApiConstants.headerAuthorization:
            '${ApiConstants.bearerPrefix}$effectiveToken',
      ApiConstants.headerAccept: 'image/*',
      'User-Agent': 'MethotX-Workforce/1.1.0 (Mobile)',
    };

    Widget imageWidget = CachedNetworkImage(
      imageUrl: secureUrl,
      cacheKey: widget.cacheKey,
      cacheManager: widget.cacheManager,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      httpHeaders: headers,
      placeholder: (context, url) =>
          widget.customPlaceholder ??
          CustomShimmerWidget(
            width: widget.width,
            height: widget.height,
            shape: widget.shape,
            borderRadius: widget.borderRadius,
          ),
      errorWidget: (context, errorUrl, error) {
        debugPrint('[SecureNetworkImage] Error loading image from $errorUrl: $error');
        return _buildFallbackWidget(context);
      },
    );

    // Apply clipping for border radius or circular shape
    if (widget.shape == BoxShape.circle) {
      imageWidget = ClipOval(child: imageWidget);
    } else if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    // Apply border and background container if specified
    if (widget.border != null || widget.backgroundColor != null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: widget.shape,
          borderRadius: widget.shape == BoxShape.rectangle
              ? widget.borderRadius
              : null,
          border: widget.border,
          color: widget.backgroundColor,
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Builds placeholder and fallback UI for error / missing states
  Widget _buildFallbackWidget(BuildContext context) {
    if (widget.customErrorWidget != null) {
      return widget.customErrorWidget!;
    }

    final IconData defaultIcon =
        widget.fallbackIcon ??
        (widget.imageType == ImageType.company
            ? Icons.business_rounded
            : widget.imageType == ImageType.employee
            ? Icons.person_rounded
            : Icons.image_not_supported_rounded);

    final double minDim = (widget.width != null && widget.height != null)
        ? (widget.width! < widget.height! ? widget.width! : widget.height!)
        : 48.0;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.surfaceContainerLow,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle
            ? widget.borderRadius ?? BorderRadius.circular(8)
            : null,
        border: widget.border,
      ),
      child: Center(
        child: Icon(defaultIcon, size: minDim * 0.5, color: AppColors.outline),
      ),
    );
  }
}

/// A zero-dependency linear shimmer loading animation widget
class CustomShimmerWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;

  const CustomShimmerWidget({
    super.key,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  @override
  State<CustomShimmerWidget> createState() => _CustomShimmerWidgetState();
}

class _CustomShimmerWidgetState extends State<CustomShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? widget.borderRadius ?? BorderRadius.circular(8)
                : null,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 3.0), -0.3),
              end: Alignment(-0.3 + (_controller.value * 3.0), 0.3),
              colors: const [
                Color(0xFFE8E8ED),
                Color(0xFFF5F5FA),
                Color(0xFFE8E8ED),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
