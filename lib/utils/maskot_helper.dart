import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'app_colors.dart';

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

    // HATA DÜZELTMESİ: Eğer daha önce gösterilmediyse, context hala geçerliyse VE hedef listesi boş değilse turu başlat.
    if (!isShown && targets.isNotEmpty && context.mounted) {
      // ignore: use_build_context_synchronously
      _showTutorial(
        context,
        targets: targets,
        onFinish: () { prefs.setBool(featureKey, true); return true; },
        onSkip: () { prefs.setBool(featureKey, true); return true; },
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
    TutorialCoachMark(
      targets: targets, // Vurgulanacak hedefler
      colorShadow: Colors.black.withOpacity(0.85), // Arka plan rengini siyah ve daha opak yap
      textSkip: skipText,
      textStyleSkip: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: onFinish,
      onSkip: onSkip,
      // Her adımda bir sonraki adıma geçmek için tıklanabilir yapar.
      onClickTarget: (target) {
        // İsteğe bağlı: Her hedefe tıklandığında özel bir eylem gerçekleştirilebilir.
      },
    ).show(context: context);
  }

  /// Tüm tanıtımlar için standart bir içerik balonu oluşturan yardımcı metot.
  /// Bu metot, `TargetContent`'in `builder`'ı içinde kullanılmak üzere tasarlanmıştır.
  ///
  /// [title], [description] ve [mascotAssetPath] parametrelerini alarak standart bir
  /// eğitim içeriği widget'ı döndürür.
  static Widget buildTutorialContent(BuildContext context, {
      required String title,
      required String description,
      String mascotAssetPath = 'assets/images/teltutan_bay.png',
  }) {
    // YENİ: Modern ve okunaklı bir baloncuk tasarımı
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75), // Yarı şeffaf siyah arka plan
        borderRadius: BorderRadius.circular(16), // Yumuşak köşeler
        border: Border.all(color: Colors.white.withOpacity(0.2)), // İnce bir çerçeve
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Maskot görselini daha küçük ve sola dayalı kullanabiliriz.
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