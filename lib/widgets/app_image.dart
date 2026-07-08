import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';


/// A web-safe image widget that avoids dart:io File usage.
/// Supports: asset paths, network URLs, base64 data URIs, with branded placeholder.
class AppImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const AppImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = _buildImage();
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildImage() {
    final url = imageUrl ?? '';
    if (url.isEmpty) return _buildPlaceholder();

    // Asset image
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // Network image
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoadingShimmer();
        },
      );
    }

    // Base64 data URI (web image upload)
    if (url.startsWith('data:image')) {
      final bytes = _decodeBase64(url);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    }

    return _buildPlaceholder();
  }

  Uint8List? _decodeBase64(String dataUri) {
    try {
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex < 0) return null;
      final base64Str = dataUri.substring(commaIndex + 1);
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlaceholder() {
    return placeholder ?? _CategoryPlaceholder(imageUrl: imageUrl, width: width, height: height);
  }

  Widget _buildLoadingShimmer() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade200, Colors.grey.shade100],
        ),
      ),
    );
  }
}

/// Generates a category-specific colored placeholder card based on the image filename.
class _CategoryPlaceholder extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  const _CategoryPlaceholder({this.imageUrl, this.width, this.height});

  _PlaceholderTheme _detectTheme() {
    final name = (imageUrl ?? '').toLowerCase();

    if (name.contains('prod_hp')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.phone_android_rounded,
        label: 'HP Bekas',
      );
    }
    if (name.contains('prod_laptop')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00897B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.laptop_rounded,
        label: 'Laptop Bekas',
      );
    }
    if (name.contains('prod_tv')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.tv_rounded,
        label: 'TV Bekas',
      );
    }
    if (name.contains('prod_kipas')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF006064), Color(0xFF00ACC1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.air_rounded,
        label: 'Kipas Angin',
      );
    }
    if (name.contains('prod_baju')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF880E4F), Color(0xFFE91E63)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.checkroom_rounded,
        label: 'Baju Bekas',
      );
    }
    if (name.contains('prod_celana')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF311B92), Color(0xFF7B1FA2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.accessibility_new_rounded,
        label: 'Celana Bekas',
      );
    }
    if (name.contains('prod_sepatu')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF4E342E), Color(0xFF8D6E63)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.directions_walk_rounded,
        label: 'Sepatu Bekas',
      );
    }
    if (name.contains('prod_tas')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFFBF360C), Color(0xFFFF7043)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.backpack_rounded,
        label: 'Tas Bekas',
      );
    }
    if (name.contains('prod_kursi')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF78909C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.chair_rounded,
        label: 'Kursi Bekas',
      );
    }
    if (name.contains('prod_meja')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFFA1887F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.table_restaurant_rounded,
        label: 'Meja Bekas',
      );
    }
    if (name.contains('prod_lemari')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF263238), Color(0xFF546E7A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.door_sliding_rounded,
        label: 'Lemari Bekas',
      );
    }
    if (name.contains('prod_buku_pelajaran')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFFA726)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.menu_book_rounded,
        label: 'Buku Pelajaran',
      );
    }
    if (name.contains('prod_novel')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.auto_stories_rounded,
        label: 'Novel Bekas',
      );
    }
    if (name.contains('prod_sepeda')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.directions_bike_rounded,
        label: 'Sepeda Bekas',
      );
    }
    if (name.contains('prod_dapur')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFEF5350)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.kitchen_rounded,
        label: 'Peralatan Dapur',
      );
    }
    if (name.contains('banner')) {
      return _PlaceholderTheme(
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.local_offer_rounded,
        label: 'Promo',
      );
    }
    // Default
    return _PlaceholderTheme(
      gradient: LinearGradient(colors: [AppTheme.lightBlue, AppTheme.lightBlue.withOpacity(0.5)]),
      icon: Icons.shopping_bag_outlined,
      label: 'BeliBekas',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _detectTheme();
    final iconSize = (width ?? 80) < 100 ? 28.0 : 48.0;
    final showLabel = (height ?? 0) > 80;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: theme.gradient,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            theme.icon,
            color: Colors.white.withOpacity(0.85),
            size: iconSize,
          ),
          if (showLabel) ...[
            const SizedBox(height: 8),
            Text(
              theme.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceholderTheme {
  final LinearGradient gradient;
  final IconData icon;
  final String label;
  const _PlaceholderTheme({required this.gradient, required this.icon, required this.label});
}
