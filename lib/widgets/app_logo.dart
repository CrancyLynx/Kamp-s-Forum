import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size; // Logonun genel boyutu
  final bool isLightMode; // Açık/Koyu tema ayarı

  const AppLogo({
    super.key,
    this.size = 120,
    this.isLightMode = true,
  });

  @override
  Widget build(BuildContext context) {
    // Yazı Rengi: Arka plan koyuysa beyaz, açıksa mor olsun
    final Color textColor = isLightMode ? AppColors.primary : Colors.white;
    final Color secondaryColor = isLightMode ? AppColors.greyText : Colors.white70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. LOGO KISMI (Çerçevesiz ve Şık)
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Beyaz arka plan yerine transparan veya hafif bir parlama efekti
            color: Colors.transparent, 
            shape: BoxShape.circle,
            // Sadece hafif bir çerçeve (isteğe bağlı)
            border: Border.all(
              color: textColor.withOpacity(0.2), 
              width: 2
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/app_icon.jpg',
              fit: BoxFit.cover, // Resmi daireye tam doldur
              errorBuilder: (context, error, stackTrace) {
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
        
        SizedBox(height: size * 0.15), // Boşluk

        // 2. METİN KISMI (MODERN FONT)
        Text(
          "KAMPÜS",
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900, // Kalın
            color: textColor,
            letterSpacing: 4, // Harf aralığı
            shadows: [
              Shadow(
                color: textColor.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
        Text(
          "FORUM",
          style: TextStyle(
            fontSize: size * 0.16,
            fontWeight: FontWeight.w300, // İnce
            color: secondaryColor,
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }
}