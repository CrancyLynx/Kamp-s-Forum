import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class MaskotHelper {
  /// Belirtilen özellik için bir eğitim turunun gösterilip gösterilmeyeceğini kontrol eder.
  /// `tutorial_coach_mark` paketini kullanarak ekrandaki belirli widget'ları vurgular.
  static Future<void> checkAndShow(
    BuildContext context, {
    required String featureKey, // Eğitimin gösterilip gösterilmediğini takip eden anahtar.
    required List<TargetFocus> targets, // Vurgulanacak widget'ların listesi.
    String skipText = "ATLA",
    String finishText = "ANLADIM",
  }) async {
    final prefs = await SharedPreferences.getInstance();
    bool isShown = prefs.getBool(featureKey) ?? false;

    // Eğer daha önce gösterilmediyse, context hala geçerliyse VE hedef listesi boş değilse turu başlat.
    if (!isShown && targets.isNotEmpty && context.mounted) {
      // ignore: use_build_context_synchronously
      _showTutorial(
        context,
        targets: targets,
        onFinish: () {
          prefs.setBool(featureKey, true);
          return true;
        },
        onSkip: () {
          prefs.setBool(featureKey, true);
          return true;
        },
        skipText: skipText,
        finishText: finishText,
      );
    }
  }

  /// ✅ YENİ: Safe async initialize with retry logic ve validation
  static Future<void> checkAndShowSafe(
    BuildContext context, {
    required String featureKey,
    required List<TargetFocus> rawTargets,
    Duration delay = const Duration(milliseconds: 500),
    int maxRetries = 3,
    String skipText = "ATLA",
    String finishText = "ANLADIM",
  }) async {
    // Retry logic ile key validation
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      // Geçerli targets'ları filter et
      final validTargets = <TargetFocus>[];
      
      for (final target in rawTargets) {
        try {
          final renderBox = target.keyTarget?.currentContext
              ?.findRenderObject() as RenderBox?;
          
          if (renderBox != null) {
            validTargets.add(target);
          }
        } catch (e) {
          debugPrint('❌ Target validation failed: ${target.identify} - ${e.toString()}');
        }
      }
      
      // Eğer yeterli target varsa göster
      if (validTargets.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final isShown = prefs.getBool(featureKey) ?? false;
        
        if (!isShown && context.mounted) {
          _showTutorial(
            context,
            targets: validTargets,
            onFinish: () {
              prefs.setBool(featureKey, true);
              return true;
            },
            onSkip: () {
              prefs.setBool(featureKey, true);
              return true;
            },
            skipText: skipText,
            finishText: finishText,
          );
          return; // Success, exit retry loop
        }
      }
      
      // Retry'dan önce ekstra delay (log message de ekleyebiliriz)
      if (attempt < maxRetries - 1) {
        debugPrint('🔄 Maskot retry attempt ${attempt + 1}/$maxRetries for $featureKey');
        await Future.delayed(delay);
      }
    }
    
    // Tüm retries başarısız
    if (rawTargets.isNotEmpty) {
      debugPrint('⚠️ Maskot tutorial başarısız oldu: $featureKey - Tüm targets geçersiz');
    }
  }

  /// `TutorialCoachMark`'ı oluşturan ve gösteren özel fonksiyon.
  /// ✅ GELIŞTIRILMIŞ: Smart positioning + bounds checking
  static void _showTutorial(
    BuildContext context, {
    required List<TargetFocus> targets,
    required bool Function() onFinish,
    required bool Function() onSkip,
    String skipText = "ATLA",
    String finishText = "ANLADIM",
  }) {
    final screenSize = MediaQuery.of(context).size;

    final updatedTargets = targets.map((target) {
      // --- AKILLI KONUMLANDIRMA MANTIĞI ---
      RenderBox? renderBox;
      try {
        renderBox = target.keyTarget?.currentContext?.findRenderObject() as RenderBox?;
      } catch (e) {
        debugPrint('❌ RenderBox fetch error for ${target.identify}: $e');
        // Context/RenderObject anlık olarak mevcut olmayabilir, bu durumda null kalır ve orijinal hizalama kullanılır.
      }

      List<TargetContent>? updatedContents;

      if (renderBox != null && target.contents != null) {
        final targetPosition = renderBox.localToGlobal(Offset.zero);
        final targetHeight = renderBox.size.height;
        final targetWidth = renderBox.size.width;

        updatedContents = target.contents!.map((content) {
          var newAlign = content.align;
          
          // ✅ GELIŞTIRILMIŞ: Daha akıllı bounds checking
          final topThreshold = screenSize.height * 0.35;
          final bottomThreshold = screenSize.height * 0.65;

          // Eğer içerik YUKARIDA gösterilecekse ama hedef ekranın üst %35'inde ise, AŞAĞIYA al
          if (content.align == ContentAlign.top && targetPosition.dy < topThreshold) {
            newAlign = ContentAlign.bottom;
            debugPrint('✅ ${target.identify}: Top → Bottom (target too high)');
          }
          // Eğer içerik AŞAĞIDA gösterilecekse ama hedef ekranın alt %35'inde ise, YUKARIYA al
          else if (content.align == ContentAlign.bottom && (targetPosition.dy + targetHeight) > bottomThreshold) {
            newAlign = ContentAlign.top;
            debugPrint('✅ ${target.identify}: Bottom → Top (target too low)');
          }
          // ✅ YENİ: Horizontal bounds check
          else if (content.align == ContentAlign.right && targetPosition.dx + targetWidth > screenSize.width * 0.8) {
            newAlign = ContentAlign.left;
            debugPrint('✅ ${target.identify}: Right → Left (target too right)');
          }
          else if (content.align == ContentAlign.left && targetPosition.dx < screenSize.width * 0.2) {
            newAlign = ContentAlign.right;
            debugPrint('✅ ${target.identify}: Left → Right (target too left)');
          }

          // Sadece hizalama değiştiyse yeni bir TargetContent oluştur, aksi halde orijinali kullan.
          if (newAlign != content.align) {
            return TargetContent(
              align: newAlign,
              builder: content.builder,
              customPosition: content.customPosition,
            );
          }
          return content;
        }).toList();
      }

      // Orijinal TargetFocus'u yeni içeriklerle (eğer varsa) veya varsayılan değerlerle yeniden oluştur.
      return TargetFocus(
        identify: target.identify,
        keyTarget: target.keyTarget,
        targetPosition: target.targetPosition,
        contents: updatedContents ?? target.contents,
        shape: target.shape ?? ShapeLightFocus.RRect,
        radius: target.radius ?? 12,
        color: target.color,
        enableOverlayTab: target.enableOverlayTab,
        enableTargetTab: target.enableTargetTab,
        alignSkip: target.alignSkip,
        paddingFocus: target.paddingFocus,
        focusAnimationDuration: target.focusAnimationDuration,
        unFocusAnimationDuration: target.unFocusAnimationDuration,
        pulseVariation: target.pulseVariation,
      );
    }).toList();

    TutorialCoachMark(
      targets: updatedTargets, // Güncellenmiş listeyi kullanıyoruz
      colorShadow: Colors.black.withAlpha(217),
      textSkip: skipText,
      textStyleSkip: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: onFinish,
      onSkip: onSkip,
      onClickTarget: (target) {
        // İsteğe bağlı tıklama işlemi
        debugPrint('📍 Maskot target clicked: ${target.identify}');
      },
    ).show(context: context);
  }

  /// Tüm tanıtımlar için standart bir içerik balonu oluşturan yardımcı metot.
  static Widget buildTutorialContent(BuildContext context, {
      required String title,
      required String description,
      String mascotAssetPath = 'assets/images/teltutan_bay.png',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(191),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(51)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 15, spreadRadius: 5),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ✅ YENİ: Asset validation with fallback
            _buildMascotImage(mascotAssetPath),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
          ],
        ),
      ),
    );
  }

  /// ✅ YENİ: Mascot image builder with fallback
  static Widget _buildMascotImage(String assetPath) {
    return Image.asset(
      assetPath,
      height: 120,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ Maskot asset yükleme hatası: $assetPath - $error');
        // Fallback: placeholder icon
        return Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image_not_supported, color: Colors.white, size: 50),
        );
      },
    );
  }
}