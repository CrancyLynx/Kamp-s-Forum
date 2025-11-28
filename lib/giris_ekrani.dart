import 'dart:ui'; // Blur efekti için gerekli
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math; // Arka plan animasyonu için

import 'app_colors.dart';
import 'main.dart';
import 'widgets/app_logo.dart'; // ÖZEL LOGO WIDGET'I

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> with SingleTickerProviderStateMixin {
  // Animasyon Kontrolcüsü (Arka plan şekilleri için)
  late AnimationController _animationController;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _takmaAdController = TextEditingController();
  final TextEditingController _adSoyadController = TextEditingController();

  bool isLogin = true;
  bool _rememberMe = false;
  bool _isEduEmail = false;
  bool _isLoading = false; // Yükleniyor durumu
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadCredentials();

    // Arka plan animasyonunu başlat
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // E-posta alanını dinle (.edu kontrolü için)
    emailController.addListener(() {
      final email = emailController.text;
      final isEdu = email.endsWith('.edu.tr') || email.endsWith('.edu');
      if (isEdu != _isEduEmail) setState(() => _isEduEmail = isEdu);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _confirmPasswordController.dispose();
    _takmaAdController.dispose();
    _adSoyadController.dispose();
    super.dispose();
  }

  void _loadCredentials() async {
    final savedEmail = await _storage.read(key: 'saved_email');
    if (savedEmail != null && mounted) {
      setState(() {
        emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveOrClearCredentials(bool shouldSave) async {
    if (shouldSave) {
      await _storage.write(key: 'saved_email', value: emailController.text);
    } else {
      await _storage.delete(key: 'saved_email');
    }
  }

  void showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 15),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 15, color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }

  String _translateFirebaseAuthException(String code) {
    switch (code) {
      case 'invalid-email': return 'Geçersiz e-posta formatı.';
      case 'user-not-found': return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password': return 'Hatalı şifre.';
      case 'invalid-credential': return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use': return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password': return 'Şifre çok zayıf (en az 6 karakter olmalı).';
      case 'network-request-failed': return 'İnternet bağlantısı yok.';
      default: return 'Giriş hatası: $code';
    }
  }

  void _showPasswordResetDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Şifre Sıfırlama"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kayıtlı e-posta adresinizi girin. Size bir şifre sıfırlama bağlantısı göndereceğiz."),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                labelText: "E-posta Adresi",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  showSnackBar("Şifre sıfırlama e-postası gönderildi.");
                } catch (e) {
                  showSnackBar("Hata: $e", isError: true);
                }
                if (mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }

  void handleAuth() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      if (!isLogin && passwordController.text != _confirmPasswordController.text) {
        showSnackBar("Şifreler eşleşmiyor.", isError: true);
        return;
      }

      if (!isLogin) {
        String email = emailController.text.trim();
        if (email.isEmpty) {
          showSnackBar("Lütfen bir e-posta adresi girin.", isError: true);
          return;
        }
        if (!email.endsWith('.edu.tr') && !email.endsWith('.edu')) {
          showSnackBar("Sadece üniversite e-postası (.edu veya .edu.tr) ile kayıt olabilirsiniz.", isError: true);
          return;
        }

        final querySnapshot = await FirebaseFirestore.instance
            .collection('kullanicilar')
            .where('takmaAd', isEqualTo: _takmaAdController.text.trim())
            .limit(1).get();

        if (querySnapshot.docs.isNotEmpty) {
          showSnackBar("Bu takma ad zaten alınmış.", isError: true);
          return;
        }
      }

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text);
      } else {
        final adSoyad = _adSoyadController.text.trim();
        final takmaAd = _takmaAdController.text.trim();

        if (adSoyad.isEmpty || takmaAd.isEmpty) {
          showSnackBar("Lütfen tüm alanları doldurun.", isError: true);
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text);
        
        final adSoyadParts = adSoyad.split(' ');
        final sadeceAd = adSoyadParts.isNotEmpty ? adSoyadParts.first : '';

        await FirebaseFirestore.instance.collection('kullanicilar').doc(userCredential.user!.uid).set({
          'email': emailController.text.trim(),
          'takmaAd': takmaAd,
          'ad': sadeceAd,
          'kayit_tarihi': FieldValue.serverTimestamp(),
          'verified': false,
          'status': 'Unverified',
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'earnedBadges': [],
          'followers': [],
          'following': [],
          'savedPosts': []
        });
      }
      _saveOrClearCredentials(_rememberMe);
    } on FirebaseAuthException catch (e) {
      showSnackBar(_translateFirebaseAuthException(e.code), isError: true);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        showSnackBar("Erişim reddedildi. Kuralları kontrol edin.", isError: true);
      } else {
        showSnackBar("Firebase Hatası: ${e.message}", isError: true);
      }
    } catch (e) {
      showSnackBar("Beklenmedik Hata: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      showSnackBar("Misafir girişi hatası: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          // 1. ARKA PLAN ANİMASYONU
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      _buildAnimatedBlob(
                        color: AppColors.primary.withOpacity(0.4),
                        top: 50 + 20 * math.sin(_animationController.value * 2 * math.pi),
                        left: 20 + 20 * math.cos(_animationController.value * 2 * math.pi),
                        size: 200,
                      ),
                      _buildAnimatedBlob(
                        color: Colors.blueAccent.withOpacity(0.4),
                        bottom: 100 + 30 * math.cos(_animationController.value * 2 * math.pi),
                        right: -20 + 20 * math.sin(_animationController.value * 2 * math.pi),
                        size: 250,
                      ),
                      _buildAnimatedBlob(
                        color: Colors.purpleAccent.withOpacity(0.3),
                        top: MediaQuery.of(context).size.height / 2,
                        left: -50 + 50 * math.sin(_animationController.value * 2 * math.pi),
                        size: 150,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. BLUR EFEKTİ
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 3. İÇERİK
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Padding(
                padding: MediaQuery.of(context).viewInsets,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- GÜNCELLENEN KISIM: LOGO AYARLARI ---
                    const SizedBox(height: 60), // Yukarıdan boşluk (kamera şeklinden kaçmak için)
                    Hero(
                      tag: 'app_logo',
                      child: AppLogo(
                        size: 120, // Boyut küçültüldü (daha zarif)
                        isLightMode: !isDark, 
                      ),
                    ),
                    const SizedBox(height: 30), // Logo ile form arası boşluk

                    // CAM KART (Giriş Formu)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOutBack,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              isLogin ? "Hoş Geldiniz" : "Aramıza Katılın",
                              key: ValueKey<bool>(isLogin),
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ),
                          const SizedBox(height: 20),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: Column(
                              children: [
                                if (!isLogin) ...[
                                  _buildModernTextField(
                                    controller: _adSoyadController,
                                    label: "Ad Soyad",
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    controller: _takmaAdController,
                                    label: "Takma Ad",
                                    icon: Icons.alternate_email,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _buildModernTextField(
                                  controller: emailController,
                                  label: "Öğrenci Maili",
                                  icon: Icons.email_outlined,
                                  isDark: isDark,
                                  suffixIcon: !isLogin && _isEduEmail ? const Icon(Icons.check_circle, color: AppColors.success) : null,
                                ),
                                const SizedBox(height: 16),
                                _buildModernTextField(
                                  controller: passwordController,
                                  label: "Şifre",
                                  icon: Icons.lock_outline,
                                  isDark: isDark,
                                  isPassword: true,
                                ),
                                if (!isLogin) ...[
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    controller: _confirmPasswordController,
                                    label: "Şifre Tekrar",
                                    icon: Icons.lock_outline,
                                    isDark: isDark,
                                    isPassword: true,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          if (isLogin)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 24, width: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(() => _rememberMe = v!),
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text("Beni Hatırla", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showPasswordResetDialog,
                                  child: Text("Şifremi Unuttum?", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: AppColors.primary.withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      isLogin ? "Giriş Yap" : "Kayıt Ol",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLogin ? "Hesabın yok mu?" : "Zaten hesabın var mı?",
                          style: TextStyle(color: textColor.withOpacity(0.7)),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(
                            isLogin ? "Hemen Kayıt Ol" : "Giriş Yap",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    if (isLogin)
                      TextButton.icon(
                        onPressed: _signInAsGuest,
                        icon: Icon(Icons.person_outline, size: 18, color: textColor.withOpacity(0.6)),
                        label: Text("Misafir Olarak Göz At", style: TextStyle(color: textColor.withOpacity(0.6))),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        final isDarkTheme = themeProvider.themeMode == ThemeMode.dark ||
                            (themeProvider.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return IconButton(
                          icon: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode, color: textColor.withOpacity(0.5)),
                          onPressed: () {
                            themeProvider.setThemeMode(isDarkTheme ? ThemeMode.light : ThemeMode.dark);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAnimatedBlob({required Color color, double? top, double? left, double? right, double? bottom, required double size}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}