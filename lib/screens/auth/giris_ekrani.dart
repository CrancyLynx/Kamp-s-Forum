import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

// Utils & Services
import '../../../utils/app_colors.dart';
import '../../../main.dart';
import '../../../widgets/app_logo.dart';
import '../../../services/auth_service.dart';
import '../../../utils/maskot_helper.dart';
import '../../../services/university_service.dart';

// YENİ: UI Bileşenleri
import '../../../widgets/auth/auth_components.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  // Durum Değişkenleri
  bool isLogin = true;
  bool _rememberMe = false;
  bool _isEduEmail = false;
  bool _isLoading = false;
  bool _isPhoneLoginMode = false; 
  bool _isMfaVerification = false; 
  bool _codeSent = false; 
  String? _verificationId; 
  
  // Onay Kutusu
  bool _agreedToTerms = false;
  late final TapGestureRecognizer _termsRecognizer;

  // Global Key'ler
  final GlobalKey _loginButtonKey = GlobalKey();
  final GlobalKey _registerSwitchKey = GlobalKey();
  final GlobalKey _loginFormKey = GlobalKey(); 
  final GlobalKey _logoKey = GlobalKey(); 

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _showTermsAndConditions;
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

    // Maskot (Tutorial) Başlatma
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
    _termsRecognizer.dispose();
    super.dispose();
  }

  // --- YARDIMCI FONKSİYONLAR ---

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

  // --- DİYALOGLAR VE PANELLER ---

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Kullanım Koşulları ve Gizlilik Politikası"),
          content: const SingleChildScrollView(
            child: Text(
              "Kampüs Forum uygulaması kullanım koşulları...", // İçerik kısaltıldı, orijinal metin kullanılabilir.
              style: TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Kapat"),
            ),
          ],
        );
      },
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
            ModernTextField(
              controller: resetEmailController,
              label: "E-posta Adresi",
              iconData: Icons.email,
              isDark: false,
              inputType: TextInputType.emailAddress,
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

  Future<String?> _showSelectionPanel({
    required BuildContext context,
    required String title,
    required List<String> options,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        String searchQuery = '';
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredOptions = options
                .where((option) => option.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                      
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          onChanged: (value) => setModalState(() => searchQuery = value),
                          decoration: const InputDecoration(
                            hintText: "Ara...",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filteredOptions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final option = filteredOptions[index];
                            return ListTile(
                              title: Text(option),
                              onTap: () => Navigator.pop(context, option),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- AUTH İŞLEMLERİ ---

  Future<void> _sendSmsCode(String phone) async {
    await _authService.verifyPhone(
      phoneNumber: phone,
      onCodeSent: (verId) {
        if (mounted) {
          setState(() {
            _verificationId = verId;
            _codeSent = true;
            _isLoading = false;
          });
        }
        showSnackBar("Doğrulama kodu gönderildi.");
      },
      onError: (msg) {
        if (mounted) {
          setState(() => _isLoading = false);
          showSnackBar(msg, isError: true);
        }
      },
    );
  }

  Future<void> _verifySmsCode() async {
    final code = _smsCodeController.text.trim();
    
    // ✅ Validasyon
    if (code.isEmpty || code.length != 6) {
      showSnackBar("Lütfen 6 haneli kodu tam ve doğru girin.", isError: true);
      return;
    }
    
    if (_verificationId == null || _verificationId!.isEmpty) {
      showSnackBar("Doğrulama ID'si kayboldu. Lütfen tekrar başlayın.", isError: true);
      return;
    }
    
    if (mounted) setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) { // Mevcut kullanıcıya linkleme (2FA veya Telefon Doğrulama)
        try {
          await user.linkWithCredential(credential);
          await user.reload();
          if (mounted) {
            showSnackBar("Telefon numaranız başarıyla doğrulandı.");
            setState(() => _codeSent = false);
          }
        } on FirebaseAuthException catch (e) {
          if (mounted) {
            if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
              showSnackBar("Bu telefon numarası zaten doğrulanmış.");
              setState(() => _codeSent = false);
            } else {
              showSnackBar(_authService.publicHandleError(e), isError: true);
            }
          }
        }
      } else { // Telefonla giriş
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) showSnackBar("Giriş başarılı!");
        } on FirebaseAuthException catch (e) {
          if (mounted) showSnackBar(_authService.publicHandleError(e), isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnackBar(_authService.publicHandleError(e), isError: true);
    } catch (e) {
      if (mounted) showSnackBar("Beklenmeyen hata: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      
      // ✅ Phone validation
      if (phone.isEmpty) return showSnackBar("Telefon numarası boş olamaz.", isError: true);
      if (phone.length < 10) return showSnackBar("Lütfen geçerli bir telefon numarası girin (en az 10 hane).", isError: true);
      if (password.isEmpty) return showSnackBar("Şifre boş olamaz.", isError: true);

      if (mounted) setState(() => _isLoading = true);
      
      final error = await _authService.validatePhonePassword(phone, password);
      
      if (mounted) {
        if (error == null) {
          await _sendSmsCode(phone);
        } else {
          setState(() => _isLoading = false);
          showSnackBar(error, isError: true);
        }
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    
    if (!isLogin) {
      // --- KAYIT OLMA İŞLEMİ - KAPSAMLI VALIDASYON ---
      final adSoyad = _adSoyadController.text.trim();
      final takmaAd = _takmaAdController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text;
      final confirmPassword = _confirmPasswordController.text;
      final phone = _phoneController.text.trim();
      
      // Ad-Soyad
      if (adSoyad.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen ad soyadınızı giriniz.", isError: true);
        return;
      }
      if (adSoyad.length < 3) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Ad soyad en az 3 karakter olmalıdır.", isError: true);
        return;
      }
      
      // Takma Ad
      if (takmaAd.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen takma ad giriniz.", isError: true);
        return;
      }
      if (takmaAd.length < 3 || takmaAd.length > 30) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Takma ad 3-30 karakter arası olmalıdır.", isError: true);
        return;
      }
      
      // Email
      if (email.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen e-posta giriniz.", isError: true);
        return;
      }
      if (!email.contains('@') || !email.contains('.')) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen geçerli bir e-posta adresi giriniz.", isError: true);
        return;
      }
      
      // Şifre
      if (password.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen şifre giriniz.", isError: true);
        return;
      }
      if (password.length < 6) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Şifre en az 6 karakter olmalıdır.", isError: true);
        return;
      }
      if (password != confirmPassword) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Şifreler eşleşmiyor.", isError: true);
        return;
      }
      
      // Telefon
      if (phone.isEmpty || phone.length < 10) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen geçerli bir telefon numarası giriniz.", isError: true);
        return;
      }
      
      // Üniversite ve Bölüm
      if (_selectedUniversity == null || _selectedDepartment == null) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen üniversite ve bölüm seçiniz.", isError: true);
        return;
      }
      
      // Şartlar
      if (!_agreedToTerms) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Kayıt olmak için şartları kabul etmelisiniz.", isError: true);
        return;
      }

      try {
        final error = await _authService.register(
          email: email,
          password: password,
          adSoyad: adSoyad,
          takmaAd: takmaAd,
          phone: phone,
          university: _selectedUniversity!,
          department: _selectedDepartment!,
        );
        
        if (mounted) {
          setState(() => _isLoading = false);
          if (error == null) {
            showSnackBar("Kayıt başarılı! Lütfen e-postanızı doğrulayın.");
          } else {
            showSnackBar(error, isError: true);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          showSnackBar("Kayıt işlemi başarısız: $e", isError: true);
        }
      }

    } else {
      // --- GİRİŞ YAPMA İŞLEMİ ---
      final email = emailController.text.trim();
      final password = passwordController.text;
      
      // ✅ Giriş validasyonu
      if (email.isEmpty || password.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        showSnackBar("Lütfen e-posta ve şifre giriniz.", isError: true);
        return;
      }
      
      try {
        final result = await _authService.signInWithEmail(email, password, _rememberMe);

        if (mounted) {
          if (result == "success") {
            setState(() => _isLoading = false);
          } else if (result == "mfa_required") {
            // MFA Mantığı
            setState(() => _isMfaVerification = true);
            setState(() => _isLoading = false);
          } else {
            setState(() => _isLoading = false);
            showSnackBar(result, isError: true);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          showSnackBar("Giriş hatası: $e", isError: true);
        }
      }
    }
  }

  // --- UI PARTLAR (REFACTORED) ---

  Widget _buildSmsCodeForm(bool isDark, Color textColor) {
    return Column(
      children: [
        Text("Lütfen telefonunuza gönderilen 6 haneli kodu girin.", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.7))),
        const SizedBox(height: 16),
        ModernTextField(controller: _smsCodeController, label: "SMS Kodu", iconData: Icons.lock_clock, isDark: isDark, inputType: TextInputType.number),
      ],
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Column(
      key: const ValueKey('register'), 
      children: [
        ModernTextField(controller: _adSoyadController, label: "Ad Soyad", iconData: Icons.person_outline, isDark: isDark),
        ModernTextField(controller: _takmaAdController, label: "Takma Ad", iconData: Icons.alternate_email, isDark: isDark),
        ModernTextField(controller: _phoneController, label: "Telefon Numarası", iconData: Icons.phone_android, isDark: isDark, inputType: TextInputType.phone),
        ModernTextField(controller: emailController, label: "Üniversite E-postası (.edu.tr)", iconData: Icons.email_outlined, isDark: isDark, suffixIcon: _isEduEmail ? const Icon(Icons.check_circle, color: AppColors.success) : null),
        
        ModernSelectionField(
          label: "Üniversite",
          value: _selectedUniversity,
          hint: "Üniversiteni seçmek için tıkla...",
          enabled: true,
          icon: Icons.school,
          isDark: isDark,
          onTap: () async {
             final selected = await _showSelectionPanel(context: context, title: "Üniversite Seç", options: UniversityService().getUniversityNames());
             if (selected != null) setState(() { _selectedUniversity = selected; _selectedDepartment = null; });
          },
        ),
        const SizedBox(height: 12),
        ModernSelectionField(
          label: "Bölüm",
          value: _selectedDepartment,
          hint: _selectedUniversity == null ? "Önce üniversiteni seç" : "Bölümünü seçmek için tıkla...",
          enabled: _selectedUniversity != null,
          icon: Icons.book,
          isDark: isDark,
          onTap: () async {
             if (_selectedUniversity == null) return;
             final selected = await _showSelectionPanel(context: context, title: "Bölüm Seç", options: UniversityService().getDepartmentsForUniversity(_selectedUniversity!));
             if (selected != null) setState(() => _selectedDepartment = selected);
          },
        ),
        const SizedBox(height: 12),

        ModernTextField(controller: passwordController, label: "Şifre", iconData: Icons.lock_outline, isDark: isDark, isPassword: true),
        ModernTextField(controller: _confirmPasswordController, label: "Şifre Tekrar", iconData: Icons.lock_outline, isDark: isDark, isPassword: true),
        
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith<Color>((s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey))),
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: RichText(
              text: TextSpan(
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                children: [
                  const TextSpan(text: "Okudum, anladım ve "),
                  TextSpan(text: "Şartlar ve Koşulları", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: _termsRecognizer),
                  const TextSpan(text: " kabul ediyorum."),
                ],
              ),
            ),
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            controlAffinity: ListTileControlAffinity.leading, 
          ),
        ),
      ],
    );
  }

  Widget _buildEmailLoginForm(bool isDark, Color textColor) {
    return Column(
      key: const ValueKey('email_login'), 
      children: [
        ModernTextField(controller: emailController, label: "E-posta", iconData: Icons.email_outlined, isDark: isDark),
        ModernTextField(controller: passwordController, label: "Şifre", iconData: Icons.lock_outline, isDark: isDark, isPassword: true),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(children: [SizedBox(height: 24, width: 24, child: Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!), activeColor: AppColors.primary)), const SizedBox(width: 8), Text("Beni Hatırla", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13))]),
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
        ModernTextField(controller: _phoneController, label: "Telefon Numarası", iconData: Icons.phone_android, isDark: isDark, inputType: TextInputType.phone),
        ModernTextField(controller: passwordController, label: "Şifre", iconData: Icons.lock_outline, isDark: isDark, isPassword: true),
      ],
    );
  }

  Widget _buildAnimatedBlob({required Color color, double? top, double? left, double? right, double? bottom, required double size}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
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
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(color: Colors.transparent))),
          
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
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
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
                                  _isMfaVerification ? "Güvenlik Kodu" : (isLogin ? "Giriş Yap" : "Öğrenci Kaydı"),
                                  key: ValueKey<String>(_isMfaVerification ? 'mfa' : (isLogin ? 'login' : 'register')),
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ),
                              if (isLogin && !_isMfaVerification)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                                  child: Row(children: [
                                      AuthToggleOption(icon: Icons.email, isSelected: !_isPhoneLoginMode, onTap: () => setState(() { _isPhoneLoginMode = false; _codeSent = false; })),
                                      AuthToggleOption(icon: Icons.phone, isSelected: _isPhoneLoginMode, onTap: () => setState(() { _isPhoneLoginMode = true; })),
                                  ]),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              final inAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation);
                              final outAnimation = Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(animation);
                              return SlideTransition(position: child.key == ValueKey(isLogin) ? inAnimation : outAnimation, child: FadeTransition(opacity: animation, child: child));
                            },
                            child: _isMfaVerification || (_isPhoneLoginMode && _codeSent)
                                ? _buildSmsCodeForm(isDark, textColor) 
                                : (!isLogin ? _buildRegisterForm(isDark) : (_isPhoneLoginMode ? _buildPhoneLoginForm(isDark) : _buildEmailLoginForm(isDark, textColor))), 
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
                                  : Text(_isMfaVerification || _codeSent ? "Doğrula" : (!isLogin ? "Kayıt Ol" : (_isPhoneLoginMode ? "Kod Gönder" : "Giriş Yap")), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if ((_isPhoneLoginMode && _codeSent) || _isMfaVerification)
                            TextButton(onPressed: () { setState(() { _codeSent = false; _isMfaVerification = false; _isPhoneLoginMode = false; _isLoading = false; }); }, child: const Text("Vazgeç / Düzenle", style: TextStyle(color: Colors.grey))),
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
                            TextButton(onPressed: () => setState(() { isLogin = !isLogin; _isPhoneLoginMode = false; _codeSent = false; }), child: Text(isLogin ? "Kayıt Ol" : "Giriş Yap", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
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
                        final isDarkTheme = themeProvider.themeMode == ThemeMode.dark || (themeProvider.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return IconButton(icon: Icon(isDarkTheme ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: textColor.withOpacity(0.6)), onPressed: () => themeProvider.setThemeMode(isDarkTheme ? ThemeMode.light : ThemeMode.dark));
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
}