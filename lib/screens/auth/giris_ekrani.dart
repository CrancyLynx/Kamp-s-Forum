import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../utils/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_logo.dart';
import 'verification_wrapper.dart'; 

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Controllerlar
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _takmaAdController = TextEditingController();
  final TextEditingController _adSoyadController = TextEditingController();
  
  // Telefon Girişi İçin Controllerlar
  final TextEditingController _phoneController = TextEditingController(); 
  final TextEditingController _smsCodeController = TextEditingController();

  // Durum Değişkenleri
  bool isLogin = true;
  bool _rememberMe = false;
  bool _isEduEmail = false;
  bool _isLoading = false;
  
  // Telefonla Giriş Modu Değişkenleri
  bool _isPhoneLoginMode = false; 
  bool _codeSent = false; 
  String? _verificationId; 
  int? _resendToken; 

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadCredentials();

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
              decoration: const InputDecoration(
                labelText: "E-posta Adresi",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
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
                  showSnackBar("Şifre sıfırlama linki mailinize gönderildi.");
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

  // --- ŞİFRE KONTROLLÜ TELEFON GİRİŞİ: SMS Gönderme ---
  Future<void> _validatePasswordAndSendSMS() async {
    final phone = _phoneController.text.trim();
    final password = passwordController.text;

    if (phone.isEmpty || phone.length < 10) {
      showSnackBar("Lütfen geçerli bir telefon numarası girin.", isError: true);
      return;
    }
    if (password.isEmpty) {
      showSnackBar("Lütfen şifrenizi girin.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Adım: Telefondan E-postayı bul (Gerekli Email/Password Girişi için)
      final query = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw FirebaseAuthException(code: 'user-not-found', message: 'Bu telefon numarasına ait kullanıcı bulunamadı.');
      }

      final email = query.docs.first['email'];

      // 2. Adım: E-posta ve Şifre ile Geçici Giriş Yap (Şifre Doğrulama)
      // Bu adım, kullanıcının kimliğini doğrulayıp Auth state'i aktive eder.
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      
      // 3. Adım: SMS gönder
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Otomatik doğrulama
          await _finalizePhoneLogin(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          showSnackBar("SMS Gönderme Hatası: ${e.message}", isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
          });
          showSnackBar("Şifre doğru. Doğrulama kodu gönderildi.");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _verificationId = verificationId);
        },
        forceResendingToken: _resendToken,
      );

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String msg = "Giriş başarısız.";
      if (e.code == 'wrong-password') msg = "Hatalı şifre.";
      else if (e.code == 'user-not-found') msg = "Kullanıcı bulunamadı.";
      else if (e.code == 'too-many-requests') msg = "Çok fazla deneme yaptınız. Biraz bekleyin.";
      showSnackBar(msg, isError: true);
    } catch (e) {
      setState(() => _isLoading = false);
      showSnackBar("Hata: $e", isError: true);
    }
  }

  // --- ŞİFRE KONTROLLÜ TELEFON GİRİŞİ: Kod Doğrulama ---
  Future<void> _verifySmsCode() async {
    final smsCode = _smsCodeController.text.trim();
    if (smsCode.length < 6 || _verificationId == null) {
      showSnackBar("Lütfen kodu tam girin.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      
      await _finalizePhoneLogin(credential);

    } on FirebaseAuthException catch (e) {
      showSnackBar("Hatalı kod: ${e.message}", isError: true);
      setState(() => _isLoading = false);
    } catch (e) {
      showSnackBar("Beklenmedik hata: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  // --- KRİTİK DÜZELTME: Girişin Tamamlanması ve Yetkilendirme Sağlamlaştırma ---
  Future<void> _finalizePhoneLogin(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Telefon numarasını mevcut e-posta hesabına bağlamayı dener.
        // Eğer numara zaten bağlıysa, bir hata fırlatabilir, bu hatayı yakalamalıyız.
        if (user.phoneNumber == null || user.phoneNumber != _phoneController.text.trim()) {
           try {
              await user.linkWithCredential(credential);
           } on FirebaseAuthException catch(e) {
              // Hata kodu 'credential-already-in-use' veya 'provider-already-linked' olabilir.
              // Bunlar girişin başarılı olduğu anlamına gelir.
              if (e.code != 'provider-already-linked' && e.code != 'credential-already-in-use') {
                 rethrow; // Başka bir hata varsa tekrar fırlat
              }
           }
        }
        
        // Final sign-in step: Mevcut kullanıcıyı yenile, böylece Auth state'i en güncel halini alır.
        await user.reload(); 
        
        // Başarılı, Main.dart yönlendirecek
        showSnackBar("Giriş Başarılı!");
        
      } else {
         // Bu senaryo olmamalı, çünkü _validatePasswordAndSendSMS'te zaten giriş yaptık.
         // Yine de oluşursa, kimlik bilgilerini kullanarak oturum açmayı deneriz.
         await FirebaseAuth.instance.signInWithCredential(credential);
      }
      
    } on FirebaseAuthException catch (e) {
       showSnackBar("Giriş tamamlama hatası: ${e.message}", isError: true);
    } catch (e) {
      debugPrint("Phone link error: $e");
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ANA AUTH FONKSİYONU ---
  void handleAuth() async {
    FocusScope.of(context).unfocus();

    if (isLogin && _isPhoneLoginMode) {
      if (_codeSent) {
        _verifySmsCode();
      } else {
        _validatePasswordAndSendSMS();
      }
      return;
    }

    // ... Klasik E-posta/Kayıt İşlemleri ...
    setState(() => _isLoading = true);

    try {
      if (!isLogin) {
        // --- KAYIT OLMA ---
        if (passwordController.text != _confirmPasswordController.text) {
          showSnackBar("Şifreler eşleşmiyor.", isError: true);
          return;
        }

        String email = emailController.text.trim();
        String phone = _phoneController.text.trim();

        if (email.isEmpty) {
          showSnackBar("Lütfen e-posta adresinizi girin.", isError: true);
          return;
        }
        
        if (phone.isEmpty || phone.length < 10) {
           showSnackBar("Lütfen geçerli bir telefon numarası girin.", isError: true);
           return;
        }

        final lowerEmail = email.toLowerCase();
        if (!(lowerEmail.endsWith('.edu.tr') || lowerEmail.endsWith('.edu'))) {
          showSnackBar("Sadece üniversite e-postası (.edu veya .edu.tr) ile kayıt olabilirsiniz.", isError: true);
          return;
        }

        final takmaAd = _takmaAdController.text.trim();
        final adSoyad = _adSoyadController.text.trim();
        
        if (adSoyad.isEmpty || takmaAd.isEmpty) {
          showSnackBar("Lütfen tüm alanları doldurun.", isError: true);
          return;
        }

        final querySnapshot = await FirebaseFirestore.instance
            .collection('kullanicilar')
            .where('takmaAd', isEqualTo: takmaAd)
            .limit(1).get();

        if (querySnapshot.docs.isNotEmpty) {
          showSnackBar("Bu takma ad zaten alınmış.", isError: true);
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, 
          password: passwordController.text
        );

        final user = userCredential.user;
        if (user != null) {
          final adSoyadParts = adSoyad.split(' ');
          final sadeceAd = adSoyadParts.isNotEmpty ? adSoyadParts.first : '';

          await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).set({
            'email': email,
            'phoneNumber': phone,
            'takmaAd': takmaAd,
            'ad': sadeceAd,
            'fullName': adSoyad,
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
          
          showSnackBar("Kayıt başarılı! Doğrulama adımına yönlendiriliyorsunuz...");
        }
      } else {
        // --- E-POSTA İLE GİRİŞ YAPMA ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(), 
          password: passwordController.text
        );
      }
      
      _saveOrClearCredentials(_rememberMe);

    } on FirebaseAuthException catch (e) {
      String message = "Bir hata oluştu.";
      if (e.code == 'user-not-found') message = "Kullanıcı bulunamadı.";
      else if (e.code == 'wrong-password') message = "Hatalı şifre.";
      else if (e.code == 'email-already-in-use') message = "Bu e-posta zaten kullanımda.";
      else if (e.code == 'invalid-email') message = "Geçersiz e-posta formatı.";
      showSnackBar(message, isError: true);
    } catch (e) {
      showSnackBar("Beklenmedik hata: $e", isError: true);
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

  // --- FORM WIDGETLARI (Değişmedi) ---
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

  Widget _buildPhoneLoginForm(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey('phone_login'), 
      children: [
        if (!_codeSent) ...[
          // Şifreli Telefon Girişi Ekranı
          _buildModernTextField(
            controller: _phoneController,
            label: "Telefon Numarası",
            icon: Icons.phone_android,
            isDark: isDark,
            inputType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: passwordController, // Şifre Alanı Eklendi
            label: "Şifre",
            icon: Icons.lock_outline,
            isDark: isDark,
            isPassword: true,
          ),
        ] else ...[
          // Kod Giriş Ekranı
          Column(
            children: [
              Text("Şifre doğrulandı. $_verificationId adresine gönderilen kodu girin.", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
              const SizedBox(height: 10),
              _buildModernTextField(
                controller: _smsCodeController,
                label: "SMS Kodu",
                icon: Icons.lock_clock,
                isDark: isDark,
                inputType: TextInputType.number,
              ),
            ],
          ),
        ]
      ],
    );
  }

  // --- BUILD METODU (Değişmedi) ---
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  isLogin ? "Giriş Yap" : "Öğrenci Kaydı",
                                  key: ValueKey<bool>(isLogin),
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ),
                              if (isLogin)
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

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
                            },
                            child: !isLogin 
                                ? _buildRegisterForm(isDark)
                                : (_isPhoneLoginMode 
                                    ? _buildPhoneLoginForm(isDark, textColor) 
                                    : _buildEmailLoginForm(isDark, textColor)),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : handleAuth,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: _isLoading 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      !isLogin ? "Kayıt Ol" : (_isPhoneLoginMode ? (_codeSent ? "Giriş Yap" : "Kod Gönder") : "Giriş Yap"), 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                    ),
                            ),
                          ),
                          if (_isPhoneLoginMode && _codeSent)
                            TextButton(
                              onPressed: () => setState(() => _codeSent = false),
                              child: const Text("Numarayı Düzenle", style: TextStyle(color: Colors.grey)),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
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
                      TextButton.icon(onPressed: _signInAsGuest, icon: Icon(Icons.person_outline, size: 18, color: textColor.withOpacity(0.6)), label: Text("Misafir Olarak Göz At", style: TextStyle(color: textColor.withOpacity(0.6)))),
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

  Widget _buildToggleOption({required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
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
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}