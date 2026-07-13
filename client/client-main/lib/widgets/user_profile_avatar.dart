import 'package:flutter/material.dart';

import 'package:capstone_app/models/profile_image_info.dart';
import 'package:capstone_app/services/api_config.dart';
import 'package:capstone_app/widgets/profile_icon_catalog.dart';

class UserProfileAvatar extends StatelessWidget {
  final ProfileImageInfo? profileImage;
  final String fallbackIconKey;
  final String? fallbackCustomImageDataUrl;
  final double size;
  final bool selected;
  final bool showFrame;

  const UserProfileAvatar({
    super.key,
    this.profileImage,
    this.fallbackIconKey = 'vanguard',
    this.fallbackCustomImageDataUrl,
    this.size = 42,
    this.selected = false,
    this.showFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = profileImage;
    final customImage = fallbackCustomImageDataUrl?.trim();
    if (image == null || !image.hasDisplayImage) {
      return ProfileIconPreview(
        iconKey: _fallbackIconKey(image, fallbackIconKey, customImage),
        customImageDataUrl: customImage,
        size: size,
        selected: selected,
        showFrame: showFrame,
      );
    }

    if (image.isDataUrl) {
      return ProfileIconPreview(
        iconKey: customProfileIconKey,
        customImageDataUrl: image.displayUrl,
        size: size,
        selected: selected,
        showFrame: showFrame,
      );
    }

    final fallbackKey = image.assetKey.isNotEmpty
        ? image.assetKey
        : fallbackIconKey;
    final option = profileIconOptionFor(fallbackKey);
    final innerSize = size * 0.68;
    final innerRadius = size * 0.075;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showFrame)
            Image.asset(
              'assets/images/profile_frame.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              color: option.backgroundColor,
              borderRadius: BorderRadius.circular(innerRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: option.glowColor.withValues(
                    alpha: selected ? 0.42 : 0.22,
                  ),
                  blurRadius: selected ? 10 : 6,
                  spreadRadius: selected ? 1 : 0,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(innerRadius),
            child: _buildImage(image, innerSize, option),
          ),
          if (selected)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A7A35),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Icon(
                  Icons.check,
                  size: size * 0.18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(
    ProfileImageInfo image,
    double innerSize,
    ProfileIconOption fallback,
  ) {
    final fallbackIcon = Icon(
      fallback.icon,
      size: size * 0.38,
      color: fallback.iconColor,
    );
    if (image.isLocalAsset) {
      return Image.asset(
        image.displayUrl,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }
    if (image.isNetworkImage || image.displayUrl.startsWith('/')) {
      return Image.network(
        _resolveRemoteImageUrl(image.displayUrl),
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }
    return fallbackIcon;
  }

  String _fallbackIconKey(
    ProfileImageInfo? image,
    String fallbackIconKey,
    String? customImage,
  ) {
    if (customImage != null && customImage.isNotEmpty) {
      return customProfileIconKey;
    }
    final assetKey = image?.assetKey.trim();
    if (assetKey != null && assetKey.isNotEmpty) {
      return assetKey;
    }
    return fallbackIconKey;
  }

  String _resolveRemoteImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('/')) {
      return ApiConfig.uri(trimmed).toString();
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) return trimmed;

    final host = uri.host.toLowerCase();
    if (host != 'pocketbase' && host != '0.0.0.0') {
      return trimmed;
    }

    final apiUri = Uri.tryParse(ApiConfig.baseUrl);
    if (apiUri == null || apiUri.host.isEmpty) return trimmed;
    return uri
        .replace(scheme: apiUri.scheme, host: apiUri.host, port: 8090)
        .toString();
  }
}
