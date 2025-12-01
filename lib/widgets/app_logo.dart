import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size; // Logonun genel boyutu
  final bool isLightMode; // Açık/Koyu tema ayarı

  const AppLogo({
    super.key,
    this.size = 120,
    this.isLightMode = true, // Varsayılan true
  });

  @override
  Widget build(BuildContext context) {
    // Yazı Rengi: Arka plan koyuysa beyaz, açıksa mor olsun
    final Color textColor = isLightMode ? AppColors.primary : Colors.white;
    final Color secondaryColor = isLightMode ? AppColors.greyText : Colors.white70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. LOGO RESMİ (app_logo3.png)
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.transparent, 
            shape: BoxShape.circle,
            // İsteğe bağlı hafif çerçeve
            border: Border.all(
              color: textColor.withAlpha(26), 
              width: 1
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/app_logo3.png', // Kesinlikle bu dosya kullanılacak
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Eğer resim yüklenemezse yedek ikon göster
                return Center(
                  child: Icon(
                    FontAwesomeIcons.graduationCap,
                    size: size * 0.5,
                    color: textColor,
                  ),
                );
              },
            ),
          ),
        ),
        
        SizedBox(height: size * 0.1), // Resim ile yazı arası boşluk

        // 2. LOGO YAZISI
        Text(
          "KAMPÜS",
          style: TextStyle(
            fontSize: size * 0.24,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: textColor.withAlpha(51),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
        Text(
          "FORUM",
          style: TextStyle(
            fontSize: size * 0.14,
            fontWeight: FontWeight.w300,
            color: secondaryColor,
            letterSpacing: 6,
          ),
        ),
      ],
    );
  }
}