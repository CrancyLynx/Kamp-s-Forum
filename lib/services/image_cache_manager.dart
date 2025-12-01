import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Uygulama genelinde resim önbelleğini yönetmek için merkezi bir sınıf.
///
/// Bu, tüm `CachedNetworkImage` widget'larının aynı önbellek yapılandırmasını
/// ve depolama alanını paylaşmasını sağlar.
class ImageCacheManager {
  static const key = 'customImageCacheKey';

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 15), // Resimlerin önbellekte 15 gün taze kalmasını sağlar.
      maxNrOfCacheObjects: 200, // Önbellekte en fazla 200 resim tutar.
    ),
  );
}