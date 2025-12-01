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

  /// `TutorialCoachMark`'ı oluşturan ve gösteren özel fonksiyon.
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
        // Context/RenderObject anlık olarak mevcut olmayabilir, bu durumda null kalır ve orijinal hizalama kullanılır.
      }

      List<TargetContent>? updatedContents;

      if (renderBox != null && target.contents != null) {
        final targetPosition = renderBox.localToGlobal(Offset.zero);
        final targetHeight = renderBox.size.height;

        updatedContents = target.contents!.map((content) {
          var newAlign = content.align;

          // Eğer içerik YUKARIDA gösterilecekse ama hedef ekranın üst %40'ındaysa, AŞAĞIYA al.
          if (content.align == ContentAlign.top && targetPosition.dy < screenSize.height * 0.4) {
            newAlign = ContentAlign.bottom;
          }
          // Eğer içerik AŞAĞIDA gösterilecekse ama hedef ekranın alt %40'ındaysa, YUKARIYA al.
          else if (content.align == ContentAlign.bottom && (targetPosition.dy + targetHeight) > screenSize.height * 0.6) {
            newAlign = ContentAlign.top;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Image.asset(mascotAssetPath, height: 120),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
        ],
      ),
    );
  }
}