import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// ✅ YENİ: Seviye atlama animasyon widget'ı
/// Fullscreen overlay ile confetti ve animasyon gösterir
class LevelUpAnimation extends StatefulWidget {
  final int oldLevel;
  final int newLevel;
  final VoidCallback onComplete;

  const LevelUpAnimation({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.onComplete,
  });

  @override
  State<LevelUpAnimation> createState() => _LevelUpAnimationState();
}

class _LevelUpAnimationState extends State<LevelUpAnimation> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animasyonu (1.0 → 1.5 → 1.0)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Fade animasyonu
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Confetti animasyonu
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Sequence: Scale → Fade → Kapat
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
      if (mounted) _confettiController.forward();
    });

    // 2.5 saniye sonra dialog kapat
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Fullscreen dimmed background
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          // Confetti particles
          ..._buildConfetti(),

          // Center content
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Level ikonu - büyüleyici
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${widget.newLevel}',
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mesaj
                  Text(
                    'Seviye Atladın!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                  ),

                  const SizedBox(height: 12),

                  // Alt text
                  Text(
                    'Seviye ${widget.oldLevel} → ${widget.newLevel}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                  ),

                  const SizedBox(height: 20),

                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStar(delay: 200),
                      const SizedBox(width: 15),
                      _buildStar(delay: 400),
                      const SizedBox(width: 15),
                      _buildStar(delay: 600),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStar({required int delay}) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _scaleController,
          curve: Interval(
            delay / 1000,
            (delay + 500) / 1000,
            curve: Curves.elasticOut,
          ),
        ),
      ),
      child: const Text(
        '⭐',
        style: TextStyle(fontSize: 32),
      ),
    );
  }

  List<Widget> _buildConfetti() {
    List<Widget> confetti = [];
    final random = DateTime.now().millisecond;

    for (int i = 0; i < 30; i++) {
      confetti.add(
        Positioned(
          left: (MediaQuery.of(context).size.width / 2) + (random % 100 - 50),
          top: 0,
          child: AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              final progress = _confettiController.value;
              final angle = (random + i * 12) * 3.14159 / 180;
              final distance = 300 * progress;

              return Transform.translate(
                offset: Offset(
                  distance * cos(angle),
                  distance * sin(angle),
                ),
                child: Opacity(
                  opacity: 1 - progress,
                  child: Transform.rotate(
                    angle: progress * 8,
                    child: Text(
                      ['🎉', '🎊', '✨', '⭐', '🌟'][i % 5],
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return confetti;
  }
}
