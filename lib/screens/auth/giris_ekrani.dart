import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../utils/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../utils/maskot_helper.dart'; 
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../services/university_service.dart'; // YENİ: Servis importu
import '../../widgets/animated_list_item.dart';

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
  final TextEditingController _phoneController = TextEditingController(text: '+90'); 
  final TextEditingController _smsCodeController = TextEditingController();

  // Seçilen Üniversite ve Bölüm
  String? _selectedUniversity;
  String? _selectedDepartment;

  bool _agreedToTerms = false;
  // Durum Değişkenleri
  bool isLogin = true;
  bool _rememberMe = false;
  bool _isEduEmail = false;
  bool _isLoading = false;
  bool _isPhoneLoginMode = false; 
  bool _isMfaVerification = false; 
  bool _codeSent = false; 
  String? _verificationId; 

  // Global Key'ler
  final GlobalKey _loginButtonKey = GlobalKey();
  final GlobalKey _registerSwitchKey = GlobalKey();
  final GlobalKey _loginFormKey = GlobalKey(); 
  final GlobalKey _logoKey = GlobalKey(); 

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();

    // Üniversite verilerini yükle
    UniversityService().loadData().then((_) {
      if(mounted) setState(() {});
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    emailController.addListener(() {
      final email = emailController.text.trim().toLowerCase();
      final isEdu = email.endsWith('.edu.tr') || email.endsWith('.edu');
      if (isEdu != _isEduEmail) setState(() => _isEduEmail = isEdu);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MaskotHelper.checkAndShow(context,
          featureKey: 'giris_tutorial_gosterildi',
          targets: [
            TargetFocus(
                identify: "welcome-notification",
                shape: ShapeLightFocus.Circle, 
                keyTarget: _logoKey, 
                alignSkip: Alignment.bottomRight,
                contents: [
                  TargetContent( 
                      align: ContentAlign.top,
                      builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Haberdar Ol!', description: 'Duyurulardan, etkinliklerden ve kampüsteki önemli gelişmelerden anında haberdar olmak için bildirimlere izin vermeyi unutma!', mascotAssetPath: 'assets/images/mutlu_bay.png'))
                ]),
            TargetFocus(
                identify: "login-form", 
                keyTarget: _loginFormKey, 
                shape: ShapeLightFocus.RRect, 
                radius: 24, 
                contents: [
                  TargetContent(
                    align: ContentAlign.bottom, builder: (context, controller) => 
                      MaskotHelper.buildTutorialContent(
                          context,
                          title: 'Seni Bekliyoruz!',
                          description: 'Eğer bir hesabın varsa buradan giriş yapabilirsin.'),
                  )
                ]),
            TargetFocus(
                identify: "register-switch",
                shape: ShapeLightFocus.RRect, 
                radius: 16, 
                keyTarget: _registerSwitchKey,
                contents: [
                  TargetContent(align: ContentAlign.top, builder: (context, controller) => MaskotHelper.buildTutorialContent(
                    context,
                    title: 'Aramıza Katıl!',
                    description: 'Henüz bir hesabın yoksa buradan kolayca öğrenci kaydı oluşturabilirsin.'))
                ])
          ]);
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

  // YENİ: Şartlar ve Koşullar Diyalog Penceresi
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Şartlar ve Koşullar"),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Lütfen uygulamamızı kullanmadan önce bu şartları ve koşulları dikkatlice okuyun.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "1. Hesap Güvenliği: Hesap bilgilerinizin güvenliğinden siz sorumlusunuz. Şifrenizi kimseyle paylaşmayınız.\n\n"
                "2. Kullanım Koşulları: Uygulamayı yasa dışı veya yetkisiz amaçlarla kullanamazsınız. Diğer kullanıcıları taciz etmek, spam göndermek veya rahatsız etmek kesinlikle yasaktır.\n\n"
                "3. İçerik: Paylaştığınız içeriklerden (mesajlar, fotoğraflar vb.) siz sorumlusunuz. Topluluk kurallarına aykırı içerik paylaşılamaz.\n\n"
                "4. Gizlilik: Gizlilik politikamız, kişisel verilerinizi nasıl topladığımızı ve kullandığımızı açıklamaktadır. Kayıt olarak bu politikayı da kabul etmiş olursunuz.\n\n"
                "Bu koşulları kabul ederek uygulamamızı kullanmaya başlayabilirsiniz.",
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Kapat"))],
      ),
    );
  }

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
        if (mounted) setState(() => _isLoading = false);
        showSnackBar(msg, isError: true);
      },
    );
  }

  Future<void> _verifySmsCode() async {
    if (_smsCodeController.text.length < 6) {
      showSnackBar("Lütfen 6 haneli kodu tam girin.", isError: true);
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
        // User is already logged in, link the credential for MFA
        try {
          await user.linkWithCredential(credential);
          await user.reload();
          showSnackBar("Telefon numaranız başarıyla doğrulandı.");
           if (mounted) setState(() => _codeSent = false);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
            showSnackBar("Bu telefon numarası zaten doğrulanmış.");
            if (mounted) setState(() => _codeSent = false);
          } else {
            showSnackBar(_authService.publicHandleError(e), isError: true);
          }
        }
      } else {
        // User is not logged in (phone login flow)
        await FirebaseAuth.instance.signInWithCredential(credential);
        showSnackBar("Giriş başarılı!");
        // No need to set _codeSent to false, as the user will navigate away.
      }
    } catch (e) {
      showSnackBar(_authService.publicHandleError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
           _isLoading = false;
        });
      }
    }
  }

  void handleAuth() async {
    FocusScope.of(context).unfocus();

    if (_codeSent) {
      _verifySmsCode();
      return;
    }

    if (isLogin && _isPhoneLoginMode) {
      final phone = _phoneController.text.trim();
      final password = passwordController.text; 
      
      if (phone.isEmpty || phone.length < 10) return showSnackBar("Geçerli numara girin.", isError: true);

      setState(() => _isLoading = true);
      final error = await _authService.validatePhonePassword(phone, password);
      
      if (error == null) {
         await _sendSmsCode(phone);
      } else {
         if (mounted) setState(() => _isLoading = false);
         showSnackBar(error, isError: true);
      }
      return;
    }

    setState(() => _isLoading = true);
    
    if (!isLogin) {
      // --- KAYIT OLMA İŞLEMİ ---
      if (passwordController.text != _confirmPasswordController.text) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Şifreler eşleşmiyor.", isError: true);
        return;
      }

      // YENİ: Üniversite Seçimi Kontrolü
      if (_selectedUniversity == null || _selectedDepartment == null) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen üniversite ve bölüm seçin.", isError: true);
        return;
      }

      // YENİ: Şartlar ve Koşullar Kontrolü
      if (!_agreedToTerms) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen Şartlar ve Koşulları kabul edin.", isError: true);
        return;
      }
      
      final error = await _authService.register(
        email: emailController.text.trim(),
        password: passwordController.text,
        adSoyad: _adSoyadController.text.trim(),
        takmaAd: _takmaAdController.text.trim(),
        phone: _phoneController.text.trim(),
        university: _selectedUniversity!,
        department: _selectedDepartment!,
      );
      
      if (mounted) setState(() => _isLoading = false);
      if (error == null) showSnackBar("Kayıt başarılı! Yönlendiriliyorsunuz...");
      else showSnackBar(error, isError: true);

    } else {
      // --- GİRİŞ YAPMA İŞLEMİ ---
      final result = await _authService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text,
        _rememberMe
      );

      if (result == "success") {
        if (mounted) setState(() => _isLoading = false);
      } else if (result == "mfa_required") {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
            final phone = doc.data()?['phoneNumber'];
            
            if (phone != null && phone.toString().isNotEmpty) {
              setState(() {
                _isMfaVerification = true;
                _isPhoneLoginMode = true;
              });
              await _sendSmsCode(phone);
              showSnackBar("2 Aşamalı Doğrulama: Kod gönderildi.");
            } else {
              await AuthService().signOut();
              if (mounted) setState(() => _isLoading = false);
              showSnackBar("Hesabınızda 2FA açık ancak telefon numarası kayıtlı değil.", isError: true);
            }
          } catch (e) {
             if (mounted) setState(() => _isLoading = false);
             showSnackBar("MFA bilgisi alınamadı: $e", isError: true);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
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
                    Hero(tag: 'app_logo', child: KeyedSubtree(key: _logoKey, child: AppLogo(size: 145, isLightMode: !isDark))), 
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
                      child: KeyedSubtree( 
                        key: _loginFormKey,
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            // YENİ: Daha akıcı bir geçiş animasyonu
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              final inAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation);
                              final outAnimation = Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(animation);

                              return SlideTransition(
                                position: child.key == ValueKey(isLogin) ? inAnimation : outAnimation,
                                child: FadeTransition(opacity: animation, child: child),
                              );
                            },
                            child: _isMfaVerification || (_isPhoneLoginMode && _codeSent)
                                ? _buildSmsCodeForm(isDark, textColor) 
                                : (!isLogin 
                                    ? _buildRegisterForm(isDark)
                                    : (_isPhoneLoginMode 
                                        ? _buildPhoneLoginForm(isDark) 
                                        : _buildEmailLoginForm(isDark, textColor))), 
                          ),
                          
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              key: _loginButtonKey, 
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
                    ),
                    
                    const SizedBox(height: 24),
                    if (!_isMfaVerification) ...[
                      KeyedSubtree(
                        key: _registerSwitchKey, 
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(isLogin ? "Hesabın yok mu?" : "Zaten hesabın var mı?", style: TextStyle(color: textColor.withOpacity(0.7))),
                            TextButton(
                              onPressed: () => setState(() { isLogin = !isLogin; _isPhoneLoginMode = false; _codeSent = false; }),
                              child: Text(isLogin ? "Kayıt Ol" : "Giriş Yap", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
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
                        final isDarkTheme = themeProvider.themeMode == ThemeMode.dark ||
                            (themeProvider.themeMode == ThemeMode.system &&
                                MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return IconButton(
                            icon: Icon(isDarkTheme ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                color: textColor.withOpacity(0.6)),
                            onPressed: () => themeProvider.setThemeMode(isDarkTheme ? ThemeMode.light : ThemeMode.dark));
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

  Widget _buildSmsCodeForm(bool isDark, Color textColor) {
    return Column(
      children: [
        Text("Lütfen telefonunuza gönderilen 6 haneli kodu girin.", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.7))),
        const SizedBox(height: 16),
        _buildModernTextField(controller: _smsCodeController, label: "SMS Kodu", icon: Icons.lock_clock, isDark: isDark, inputType: TextInputType.number),
      ],
    );
  }

  // --- MODERN KAYIT FORMU (ANİMASYONLU) ---
  Widget _buildRegisterForm(bool isDark) {
    final universityNames = UniversityService().getUniversityNames();
    return Column(
      key: const ValueKey('register'), 
      children: [
        // YENİ: Kademeli animasyon için AnimatedListItem kullanıldı
        AnimatedListItem(index: 0, child: _buildModernTextField(controller: _adSoyadController, label: "Ad Soyad", icon: Icons.person_outline, isDark: isDark)),
        const SizedBox(height: 16),
        AnimatedListItem(index: 1, child: _buildModernTextField(controller: _takmaAdController, label: "Takma Ad", icon: Icons.alternate_email, isDark: isDark)),
        const SizedBox(height: 16),
        AnimatedListItem(index: 2, child: _buildModernTextField(controller: _phoneController, label: "Telefon Numarası", icon: Icons.phone_android, isDark: isDark, inputType: TextInputType.phone)),
        const SizedBox(height: 16),
        AnimatedListItem(index: 3, child: _buildModernTextField(controller: emailController, label: "Üniversite E-postası (.edu.tr)", icon: Icons.email_outlined, isDark: isDark, suffixIcon: _isEduEmail ? const Icon(Icons.check_circle, color: AppColors.success) : null)),
        const SizedBox(height: 16),

        // --- YENİ EKLENEN PANEL BUTONU (ÜNİVERSİTE) ---
        AnimatedListItem(
          index: 4,
          child: _buildModernSelectionField(
              label: "Üniversite",
              value: _selectedUniversity,
              hint: "Üniversiteni seçmek için tıkla...",
              enabled: true,
              icon: Icons.school,
              onTap: () async {
                final selected = await _showSelectionPanel(
                  context: context,
                  title: "Üniversite Seç",
                  options: universityNames,
                );
                if (selected != null && mounted) {
                  setState(() {
                    _selectedUniversity = selected;
                    _selectedDepartment = null; // Üniversite değişince bölüm sıfırlanır
                  });
                }
              },
              isDark: isDark),
        ),
        const SizedBox(height: 16),

        // --- YENİ EKLENEN PANEL BUTONU (BÖLÜM) ---
        AnimatedListItem(
          index: 5,
          child: _buildModernSelectionField(
              label: "Bölüm",
              value: _selectedDepartment,
              hint: _selectedUniversity == null ? "Önce üniversiteni seç" : "Bölümünü seçmek için tıkla...",
              enabled: _selectedUniversity != null,
              icon: Icons.book,
              onTap: () async {
                if (_selectedUniversity == null) return;
                final selected = await _showSelectionPanel(context: context, title: "Bölüm Seç", options: UniversityService().getDepartmentsForUniversity(_selectedUniversity!));
                if (selected != null && mounted) {
                  setState(() => _selectedDepartment = selected);
                }
              },
              isDark: isDark),
        ),
        const SizedBox(height: 16),

        AnimatedListItem(
          index: 6,
          child: _buildModernTextField(controller: passwordController, label: "Şifre", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
        ),
        const SizedBox(height: 16),
        AnimatedListItem(
          index: 7,
          child: _buildModernTextField(controller: _confirmPasswordController, label: "Şifre Tekrar", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
        ),
        const SizedBox(height: 16),

        AnimatedListItem(
          index: 8,
          child: _buildTermsAndConditions(isDark, isDark ? Colors.white70: Colors.black87),
        ),
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
        _buildModernTextField(controller: passwordController, label: "Şifre (Opsiyonel)", icon: Icons.lock_outline, isDark: isDark, isPassword: true),
      ],
    );
  }

  // YENİ: Şartlar ve Koşullar Onay Kutusu
  Widget _buildTermsAndConditions(bool isDark, Color textColor) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (value) {
              setState(() {
                _agreedToTerms = value!;
              });
            },
            activeColor: AppColors.primary,
            side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)),
              children: [
                const TextSpan(text: "Kayıt olarak "),
                TextSpan(text: "Şartlar ve Koşulları", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = _showTermsDialog),
                const TextSpan(text: " kabul etmiş olursunuz."),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- EKLENEN EKSİK FONKSİYON 1: Modern Seçim Alanı Widget'ı (Panel Tetikleyici) ---
  Widget _buildModernSelectionField({
    required String label,
    String? value,
    required String hint,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent), 
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: enabled ? AppColors.primary.withOpacity(0.7) : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value != null 
                          ? (isDark ? Colors.white : Colors.black87) 
                          : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- EKLENEN EKSİK FONKSİYON 2: ARAMA ÖZELLİKLİ ŞIK SEÇİM PANELİ ---
  Future<String?> _showSelectionPanel({
    required BuildContext context,
    required String title,
    required List<String> options,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        // Arama işlemi için yerel state
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Arama filtresi için yerel değişkenler (Closure içinde)
            // Not: Başlangıçta tüm listeyi gösterir.
            List<String> filteredOptions = options;
            
            // Eğer arama yapılmışsa (yani TextField doluysa) filtreli listeyi kullanırız.
            // *Basitleştirilmiş Yöntem*:
            // Burada controller yerine, arama metnini tutacak bir değişken kullanmıyoruz,
            // direkt TextField'ın onChanged'i ile listeyi filtreliyoruz.

            return DraggableScrollableSheet(
              initialChildSize: 0.8, // Ekranın %80'i kadar açıl
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                      
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      
                      // Arama Barı
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          autofocus: false,
                          onChanged: (val) {
                            setModalState(() {
                              // Listeyi filtrele ve UI'ı güncelle
                              if (val.isEmpty) {
                                filteredOptions = options; // Orijinal liste
                              } else {
                                filteredOptions = options.where((o) => o.toLowerCase().contains(val.toLowerCase())).toList();
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "$title Ara...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                        ),
                      ),

                      const Divider(height: 1),
                      
                      Expanded(
                        child: filteredOptions.isEmpty 
                          ? const Center(child: Text("Sonuç bulunamadı.", style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filteredOptions.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                final option = filteredOptions[index];
                                return ListTile(
                                  title: Text(option, style: const TextStyle(fontSize: 16)),
                                  onTap: () => Navigator.pop(context, option),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                );
              }
            );
          }
        );
      },
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