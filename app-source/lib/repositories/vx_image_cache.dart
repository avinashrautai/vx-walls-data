import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// One bounded cache for thumbnails, previews and actions.
/// Keeps the app lightweight while still making repeat viewing fast.
class VXImageCacheManager {
  VXImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'vxWallsImageCacheV1',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 80,
    ),
  );
}
