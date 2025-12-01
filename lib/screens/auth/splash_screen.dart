import 'dart:async';
import 'package:flutter/material.dart';
// Native Splash Paketi Importu
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../main.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation; 

  @override
  void initState() {
    super.initState();

    // YENİ: Native Splash'i hemen kaldırmak yerine, build işlemi bittikten sonra kaldırıyoruz.
    // Bu sayede arada siyah/beyaz boşluk oluşmaz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Logo ve yazının opaklık animasyonları
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),
    );

    // Yazının aşağıdan yukarı kayması için animasyon tanımı
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const AnaKontrolcu(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // DEĞİŞTİRİLDİ: Arka plan mora çevrildi.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF512DA8), Color(0xFF311B92)], // Koyu mordan -> daha koyu mora
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    FadeTransition(
                      opacity: _opacityAnimation,
                      child: Image.asset('assets/images/app_logo3.png', width: 150),
                    ),
                    const SizedBox(height: 24),
                    // Animasyonlu Yazı
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
                        // YENİ: Metalik görünüm için ShaderMask
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)], // Açık griden -> Koyu griye
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter, 
                          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                          child: const Text(
                            "Kampüs Forum",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.black54,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}