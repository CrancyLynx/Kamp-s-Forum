import 'dart:async';
import 'package:flutter/material.dart';
// YENİ: Native Splash Paketi Importu
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../utils/app_colors.dart';
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

    // YENİ: Bu ekran açıldığı anda Native (Beyaz) Splash ekranını kaldırıyoruz.
    // Böylece kullanıcı doğrudan animasyonumuzu görüyor.
    FlutterNativeSplash.remove();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Logo ve yazının opaklık animasyonları için farklı zamanlamalar
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
    // Arka plan rengini, logonun kendi rengiyle aynı yapıyoruz.
    const logoBackgroundColor = Color.fromARGB(34, 67, 0, 55);

    return Scaffold(
      backgroundColor: logoBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Image.asset('assets/images/app_logo3.png', width: 150),
                  ),
                  const SizedBox(height: 24),
                  // Animasyonlu ve Gradient'li Yazı
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.primaryLight, AppColors.primaryAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          "Kampüs Forum",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // ShaderMask için temel renk
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
    );
  }
}