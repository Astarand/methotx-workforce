import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';

class LoginHeroHeader extends StatelessWidget {
  final double height;

  const LoginHeroHeader({
    super.key,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.whiteLogo,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'MethotX Logo',
    );
  }
}

