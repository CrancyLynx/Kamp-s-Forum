import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../main.dart';
import '../../services/exam_dates_service.dart';
import '../../services/data_preload_service.dart';
import '../../utils/app_colors.dart';

// Loading item model
enum LoadingStatus { pending, loading, completed, failed }

class LoadingItem {
  final String name;
  final String icon;
  LoadingStatus status;

  LoadingItem({
    required this.name,
    required this.icon,
    this.status = LoadingStatus.pending,
  });
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _floatingController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;
  Timer? _navigationTimer;
  String _loadingStatus = "Veriler hazırlanıyor...";
  late List<LoadingItem> _loadingItems;

  @override
  void initState() {
    super.initState();

    // Loading items'ı başlat
    _loadingItems = [
      LoadingItem(name: "Forum Gönderileri", icon: "📝"),
      LoadingItem(name: "Market Ürünleri", icon: "🛍️"),
      LoadingItem(name: "Kullanıcı Profili", icon: "👤"),
      LoadingItem(name: "Bildirimler", icon: "🔔"),
      LoadingItem(name: "Bakiye ve Level", icon: "⭐"),
      LoadingItem(name: "Sıralama Tablosu", icon: "🏆"),
      LoadingItem(name: "Sınav Tarihleri", icon: "📅"),
    ];

    // 🔴 Native Splash'i HEMEN kaldır (addPostFrameCallback yerine)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        FlutterNativeSplash.remove();
        debugPrint('✅ Native splash kaldırıldı');
      } catch (e) {
        debugPrint('⚠️ Native splash kaldırılamadı: $e');
      }
    });

    // Logo scale animasyonu (0.3s)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Text slide animasyonu (aşağıdan yukarı)
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuad),
    );

    // Floating blob animasyonu (loop)
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _floatingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.linear),
    );

    // Animasyonları sırayla başlat
    _startSequentialAnimation();
  }

  void _startSequentialAnimation() {
    // Arka planda sınav tarihlerini güncelle
    _initializeExamDates();

    // Arka planda tüm verileri preload et (cache'le) ve status güncelle
    _startCachePreloading();

    _scaleController.forward().then((_) {
      _slideController.forward();
      // 2.5 saniye sonra sayfayı değiştir
      _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
        _navigateToHome();
      });
    });
  }

  /// Cache yükleme işlemini başlat ve durumu güncelle
  void _startCachePreloading() {
    // Loading items'ı dinamik olarak update et
    _updateLoadingItemStatus('Forum Gönderileri', LoadingStatus.loading);
    
    DataPreloadService.preloadAllData().then((results) {
      if (mounted) {
        // Sonuçlara göre items'ı güncelle
        _updateItemsBasedOnResults(results);
        
        int successCount = results.values.where((v) => v == true).length;
        int totalCount = results.length;
        
        setState(() {
          _loadingStatus = "✅ Veriler hazır ($successCount/$totalCount)";
        });
        
        debugPrint('📦 Cache preload tamamlandı: $successCount/$totalCount başarılı');
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _loadingStatus = "⚠️ Yükleniyor (çevrimdışı mod)...";
        });
      }
      debugPrint('⚠️ Cache preload hatası (çevrimdışı mod kullanılacak): $e');
    });
  }

  /// Loading item'ı durumuna göre güncelle
  void _updateLoadingItemStatus(String itemName, LoadingStatus status) {
    if (mounted) {
      setState(() {
        final index = _loadingItems.indexWhere((item) => item.name == itemName);
        if (index != -1) {
          _loadingItems[index].status = status;
        }
      });
    }
  }

  /// Preload sonuçlarına göre tüm items'ı güncelle
  void _updateItemsBasedOnResults(Map<String, dynamic> results) {
    if (!mounted) return;
    
    setState(() {
      // Map results to loading items
      final resultMapping = {
        'forum_posts': 'Forum Gönderileri',
        'market_products': 'Market Ürünleri',
        'user_profile': 'Kullanıcı Profili',
        'notifications': 'Bildirimler',
        'user_balance': 'Bakiye ve Level',
        'leaderboard': 'Sıralama Tablosu',
        'exam_dates': 'Sınav Tarihleri',
      };

      results.forEach((key, success) {
        final itemName = resultMapping[key];
        if (itemName != null) {
          final index = _loadingItems.indexWhere((item) => item.name == itemName);
          if (index != -1) {
            _loadingItems[index].status = success ? LoadingStatus.completed : LoadingStatus.failed;
          }
        }
      });
    });
  }

  /// Sınav tarihlerini arka planda güncelle
  Future<void> _initializeExamDates() async {
    try {
      final result = await ExamDatesService().triggerExamDatesUpdate();
      if (result['success'] == true) {
        debugPrint('✅ Sınav tarihleri güncellendi: ${result['count']} sınav');
      } else {
        debugPrint('⚠️ Sınav tarihleri güncellenemedi: ${result['error']}');
      }
    } catch (e) {
      debugPrint('❌ Sınav tarihleri başlatma hatası: $e');
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (_, __, ___) => const AnaKontrolcu(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _floatingController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E), const Color(0xFF0F3460)]
                : [AppColors.primary, AppColors.primaryDark, const Color(0xFF4A148C)],
          ),
        ),
        child: Stack(
          children: [
            // Animated blob background (Instagram style)
            Positioned(
              top: -100,
              right: -50,
              child: AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      50 * (0.5 - (_floatingAnimation.value - 0.5).abs()),
                      30 * sin(_floatingAnimation.value * 2 * pi),
                    ),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDark
                                ? Colors.white
                                : AppColors.primaryAccent)
                            .withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? Colors.white
                                    : AppColors.primaryAccent)
                                .withOpacity(0.2),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Second blob
            Positioned(
              bottom: -150,
              left: -80,
              child: AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      -50 * (0.5 - (_floatingAnimation.value - 0.5).abs()),
                      -30 * cos(_floatingAnimation.value * 2 * pi),
                    ),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDark ? Colors.blue : Colors.purple)
                            .withOpacity(0.08),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? Colors.blue : Colors.purple)
                                .withOpacity(0.15),
                            blurRadius: 60,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with scale animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: (isDark
                                  ? Colors.white
                                  : AppColors.primaryAccent)
                              .withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/app_logo3.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // App name with slide animation
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _slideController,
                      child: Column(
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? [Colors.white, Colors.white70]
                                  : [Colors.white, Colors.white54],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(
                              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                            ),
                            child: const Text(
                              "Kampüs Forum",
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? [Colors.white38, Colors.white24]
                                  : [Colors.white60, Colors.white38],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(
                              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                            ),
                            child: const Text(
                              "Öğrenci Topluluğu",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading items list
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _loadingItems.length,
                        itemBuilder: (context, index) {
                          final item = _loadingItems[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // Icon
                                Text(
                                  item.icon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 12),
                                // Item name
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status indicator
                                if (item.status == LoadingStatus.pending)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withOpacity(0.5),
                                      ),
                                      strokeWidth: 1.5,
                                    ),
                                  )
                                else if (item.status == LoadingStatus.loading)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.yellow[600]!,
                                      ),
                                      strokeWidth: 1.5,
                                    ),
                                  )
                                else if (item.status == LoadingStatus.completed)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.green,
                                  )
                                else
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Status text
                    Text(
                      _loadingStatus,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}