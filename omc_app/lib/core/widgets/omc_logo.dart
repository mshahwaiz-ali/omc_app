import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

class OmcLogo extends StatelessWidget {
  const OmcLogo.symbol({
    super.key,
    this.size = 58,
    this.borderRadius = 20,
  }) : assetPath = AppAssets.logoSymbol,
       width = size,
       height = size,
       fit = BoxFit.contain;

  const OmcLogo.full({
    super.key,
    this.width = 170,
    this.height = 64,
    this.fit = BoxFit.contain,
  }) : assetPath = AppAssets.logoFull,
       size = null,
       borderRadius = null;

  const OmcLogo.appIcon({
    super.key,
    this.size = 132,
    this.borderRadius = 32,
  }) : assetPath = AppAssets.faviconLogo,
       width = size,
       height = size,
       fit = BoxFit.contain;

  final String assetPath;
  final double? size;
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );

    if (borderRadius == null) return image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius!),
      child: image,
    );
  }
}
