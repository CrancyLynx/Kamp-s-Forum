import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Sadece Credential tipleri için
import 'package:cloud_firestore/cloud_firestore.dart'; // Sadece telefon sorgusu için
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../utils/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart'; // Servisimizi ekledik

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final AuthService _authService = AuthService();

  // Controllerlar
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _takmaAdController = TextEditingController();
  final TextEditingController _adSoyadController = TextEditingController();
  
  // Telefon/SMS Girişi
  final TextEditingController _phoneController = TextEditingController(); 
  final TextEditingController _smsCodeController = TextEditingController();

  // Durum Değişkenleri
  bool isLogin = true;
  bool _rememberMe = false;
  bool _isEduEmail = false;
  bool _isLoading = false;
  
  // 2FA ve Telefon Modu
  bool _isPhoneLoginMode = false; // Telefon sekmesi açık mı?
  bool _isMfaVerification = false; // E-posta sonrası 2FA doğrulaması mı yapılıyor?
  bool _codeSent = false; // SMS kodu gönderildi mi?
  String? _verificationId; 

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    emailController.addListener(() {
      final email = emailController.text.trim().toLowerCase();
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
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _loadSavedEmail() async {
    final savedEmail = await _authService.getSavedEmail();
    if (savedEmail != null && mounted) {
      setState(() {
        emailController.text = savedEmail;
        _rememberMe = true;
      });
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
      ),
    );
  }

  void _showPasswordResetDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Şifre Sıfırlama"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kayıtlı e-posta adresinizi girin."),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(labelText: "E-posta Adresi", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.isEmpty) return;
              Navigator.pop(ctx);
              final error = await _authService.sendPasswordReset(resetEmailController.text.trim());
              showSnackBar(error ?? "Şifre sıfırlama linki gönderildi.", isError: error != null);
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }

  // --- SMS GÖNDERME İŞLEMİ ---
  Future<void> _sendSmsCode(String phone) async {
    setState(() => _isLoading = true);
    await _authService.verifyPhone(
      phoneNumber: phone,
      onCodeSent: (verId) {
        setState(() {
          _verificationId = verId;
          _codeSent = true;
          _isLoading = false;
        });
        showSnackBar("Doğrulama kodu gönderildi.");
      },
      onError: (msg) {
        setState(() => _isLoading = false);
        showSnackBar(msg, isError: true);
      },
    );
  }

  // --- SMS KODU DOĞRULAMA (SON ADIM) ---
  Future<void> _verifySmsCode() async {
    if (_smsCodeController.text.length < 6) {
      showSnackBar("Lütfen kodu tam girin.", isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Mevcut oturuma telefonu bağla (MFA için)
        await user.linkWithCredential(credential);
        await user.reload();
        showSnackBar("Giriş Başarılı!");
      } else {
        // Sıfırdan telefonla giriş
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      // Zaten bağlıysa hata verebilir, yutuyoruz
      if (!e.toString().contains('credential-already-in-use')) {
        showSnackBar("Hatalı kod veya işlem başarısız.", isError: true);
      } else {
        showSnackBar("Giriş Başarılı!");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ANA AUTH BUTONU ---
  void handleAuth() async {
    FocusScope.of(context).unfocus();

    // 1. KOD GİRME AŞAMASI (Hem Telefon Girişi hem MFA için)
    if (_codeSent) {
      _verifySmsCode();
      return;
    }

    // 2. TELEFON GİRİŞİ BAŞLATMA
    if (isLogin && _isPhoneLoginMode) {
      final phone = _phoneController.text.trim();
      final password = passwordController.text; // Telefon girişinde de şifre soruyoruz (Güvenlik)
      
      if (phone.isEmpty || phone.length < 10) return showSnackBar("Geçerli numara girin.", isError: true);
      if (password.isEmpty) return showSnackBar("Şifrenizi girin.", isError: true);

      // Önce şifreyi doğrula (Manuel Query - Sadece telefon girişine özel)
      // Not: Bu kısım normalde Backend'de olmalı ama basitlik için burada bırakıyorum.
      try {
        setState(() => _isLoading = true);
        final query = await FirebaseFirestore.instance.collection('kullanicilar').where('phoneNumber', isEqualTo: phone).limit(1).get();
        if (query.docs.isEmpty) throw Exception("Numara kayıtlı değil.");
        final email = query.docs.first['email'];
        
        // Şifre doğru mu?
        final result = await _authService.signInWithEmail(email, password, false);
        if (result != "success" && result != "mfa_required") throw Exception(result);
        
        // Şifre doğru, şimdi SMS gönder
        await _sendSmsCode(phone);
      } catch (e) {
        setState(() => _isLoading = false);
        showSnackBar(e.toString().replaceAll("Exception: ", ""), isError: true);
      }
      return;
    }

    // 3. E-POSTA İLE GİRİŞ / KAYIT
    setState(() => _isLoading = true);
    
    if (!isLogin) {
      // --- KAYIT OL ---
      if (passwordController.text != _confirmPasswordController.text) {
        setState(() => _isLoading = false);
        showSnackBar("Şifreler eşleşmiyor.", isError: true);
        return;
      }
      
      final error = await _authService.register(
        email: emailController.text.trim(),
        password: passwordController.text,
        adSoyad: _adSoyadController.text.trim(),
        takmaAd: _takmaAdController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      
      setState(() => _isLoading = false);
      if (error == null) showSnackBar("Kayıt başarılı! Yönlendiriliyorsunuz...");
      else showSnackBar(error, isError: true);

    } else {
      // --- GİRİŞ YAP ---
      final result = await _authService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text,
        _rememberMe
      );

      if (result == "success") {
        setState(() => _isLoading = false);
        // Main.dart otomatik yönlendirecek
      } else if (result == "mfa_required") {
        // MFA Gerekli: Kullanıcının telefon numarasını bul ve SMS gönder
        final user = FirebaseAuth.instance.currentUser;
        final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user!.uid).get();
        final phone = doc.data()?['phoneNumber'];
        
        if (phone != null) {
          setState(() {
            _isMfaVerification = true; // Arayüzü güncelle
            _isPhoneLoginMode = true; // Telefon formunu göster
          });
          await _sendSmsCode(phone);
          showSnackBar("2 Aşamalı Doğrulama: Kod gönderildi.");
        } else {
          setState(() => _isLoading = false);
          showSnackBar("Hesabınızda kayıtlı telefon numarası yok.", isError: true);
        }
      } else {
        setState(() => _isLoading = false);
        showSnackBar(result, isError: true);
      }
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
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      _buildAnimatedBlob(color: AppColors.primary.withOpacity(0.4), top: 50 + 20 * math.sin(_animationController.value * 2 * math.pi), left: 20 + 20 * math.cos(_animationController.value * 2 * math.pi), size: 200),
                      _buildAnimatedBlob(color: Colors.blueAccent.withOpacity(0.4), bottom: 100 + 30 * math.cos(_animationController.value * 2 * math.pi), right: -20 + 20 * math.sin(_animationController.value * 2 * math.pi), size: 250),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Padding(
                padding: MediaQuery.of(context).viewInsets,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Hero(tag: 'app_logo', child: AppLogo(size: 120, isLightMode: !isDark)),
                    const SizedBox(height: 30), 
                    
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
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
                          // BAŞLIK ALANI
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _isMfaVerification 
                                      ? "Güvenlik Kodu" 
                                      : (isLogin ? "Giriş Yap" : "Öğrenci Kaydı"),
                                  key: ValueKey<String>(_isMfaVerification ? 'mfa' : (isLogin ? 'login' : 'register')),
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ),
                              if (isLogin && !_isMfaVerification)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildToggleOption(icon: Icons.email, isSelected: !_isPhoneLoginMode, onTap: () => setState(() { _isPhoneLoginMode = false; _codeSent = false; })),
                                      _buildToggleOption(icon: Icons.phone, isSelected: _isPhoneLoginMode, onTap: () => setState(() { _isPhoneLoginMode = true; })),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // FORM ALANI
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: _isMfaVerification || (_isPhoneLoginMode && _codeSent)
                                ? _buildSmsCodeForm(isDark, textColor) // Kod Girme Ekranı
                                : (!isLogin 
                                    ? _buildRegisterForm(isDark) // Kayıt Ekranı
                                    : (_isPhoneLoginMode 
                                        ? _buildPhoneLoginForm(isDark) // Telefonla Giriş
                                        : _buildEmailLoginForm(isDark, textColor))), // E-posta Giriş
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // BUTON
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : handleAuth,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: _isLoading 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      _isMfaVerification || _codeSent 
                                          ? "Doğrula" 
                                          : (!isLogin ? "Kayıt Ol" : (_isPhoneLoginMode ? "Kod Gönder" : "Giriş Yap")), 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                    ),
                            ),
                          ),
                          if ((_isPhoneLoginMode && _codeSent) || _isMfaVerification)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _codeSent = false;
                                  _isMfaVerification = false;
                                  _isPhoneLoginMode = false;
                                  _isLoading = false;
                                });
                              },
                              child: const Text("Vazgeç / Düzenle", style: TextStyle(color: Colors.grey)),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    if (!_isMfaVerification) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLogin ? "Hesabın yok mu?" : "Zaten hesabın var mı?", style: TextStyle(color: textColor.withOpacity(0.7))),
                          TextButton(
                            onPressed: () => setState(() { isLogin = !isLogin; _isPhoneLoginMode = false; _codeSent = false; }),
                            child: Text(isLogin ? "Kayıt Ol" : "Giriş Yap", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (isLogin)
                        TextButton.icon(
                          onPressed: () async {
                            setState(() => _isLoading = true);
                            final error = await _authService.signInGuest();
                            if (mounted) setState(() => _isLoading = false);
                            if (error != null) showSnackBar(error, isError: true);
                          },
                          icon: Icon(Icons.person_outline, size: 18, color: textColor.withOpacity(0.6)), 
                          label: Text("Misafir Olarak Göz At", style: TextStyle(color: textColor.withOpacity(0.6)))
                        ),
                    ],
                    const SizedBox(height: 20),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        final isDarkTheme = themeProvider.themeMode == ThemeMode.dark || (themeProvider.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return IconButton(icon: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode, color: textColor.withOpacity(0.5)), onPressed: () => themeProvider.setThemeMode(isDarkTheme ? ThemeMode.light : ThemeMode.dark));
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

  // --- FORM WIDGETLARI ---
  Widget _buildSmsCodeForm(bool isDark, Color textColor) {
    return Column(
      children: [
        Text("Lütfen telefonunuza gönderilen 6 haneli kodu girin.", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.7))),
        const SizedBox(height: 16),
        _buildModernTextField(controller: _smsCodeController, label: "SMS Kodu", icon: Icons.lock_clock, isDark: isDark, inputType: TextInputType.number),
      ],
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Column(
      key: const ValueKey('register'), 
      children: [
        _buildModernTextField(controller: _adSoyadController, label: "Ad Soyad", icon: Icons.person_outline, isDark: isDark),
        const SizedBox(height: 16),
        _buildModernTextField(controller: _takmaAdController, label: "Takma Ad", icon: Icons.alternate_email, isDark: isDark),
        const SizedBox(height: 16),
        _buildModernTextField(controller: _phoneController, label: "Telefon Numarası", icon: Icons.phone_android, isDark: isDark, inputType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildModernTextField(controller: emailController, label: "Üniversite E-postası (.edu.tr)", icon: Icons.email_outlined, isDark: isDark, suffixIcon: _isEduEmail ? const Icon(Icons.check_circle, color: AppColors.success) : null),
        const SizedBox(height: 16),
        _buildModernTextField(controller: passwordController, label: "Şifre", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
        const SizedBox(height: 16),
        _buildModernTextField(controller: _confirmPasswordController, label: "Şifre Tekrar", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
      ],
    );
  }

  Widget _buildEmailLoginForm(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey('email_login'), 
      children: [
        _buildModernTextField(controller: emailController, label: "E-posta", icon: Icons.email_outlined, isDark: isDark),
        const SizedBox(height: 16),
        _buildModernTextField(controller: passwordController, label: "Şifre", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  SizedBox(height: 24, width: 24, child: Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!), activeColor: AppColors.primary)),
                  const SizedBox(width: 8),
                  Text("Beni Hatırla", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            ),
            TextButton(onPressed: _showPasswordResetDialog, child: Text("Şifremi Unuttum?", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneLoginForm(bool isDark) {
    return Column(
      key: const ValueKey('phone_login'), 
      children: [
        _buildModernTextField(controller: _phoneController, label: "Telefon Numarası", icon: Icons.phone_android, isDark: isDark, inputType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildModernTextField(controller: passwordController, label: "Şifre", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
      ],
    );
  }

  Widget _buildToggleOption({required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.transparent, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildModernTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, bool isPassword = false, TextInputType inputType = TextInputType.text, Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
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
      child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }
}