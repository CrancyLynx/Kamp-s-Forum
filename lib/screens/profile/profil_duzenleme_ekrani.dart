import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import '../auth/giris_ekrani.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../services/auth_service.dart';
import '../../utils/maskot_helper.dart';
import '../../services/image_compression_service.dart';
import '../../services/image_cache_manager.dart';

class ProfilDuzenlemeEkrani extends StatefulWidget {
  const ProfilDuzenlemeEkrani({super.key});

  @override
  State<ProfilDuzenlemeEkrani> createState() => _ProfilDuzenlemeEkraniState();
}

class _ProfilDuzenlemeEkraniState extends State<ProfilDuzenlemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // Controllerlar
  final _takmaAdController = TextEditingController();
  final _adSoyadController = TextEditingController();
  final _biyografiController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _xPlatformController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final GlobalKey _avatarAreaKey = GlobalKey();
  final GlobalKey _saveButtonKey = GlobalKey();

  // State Değişkenleri
  String? _university;
  String? _department;
  String? _originalTakmaAd;
  
  // Avatar Yönetimi
  String? _currentAvatarUrl;
  File? _avatarImageFile;
  bool _isAvatarRemoved = false;
  String? _selectedPresetAvatarUrl;

  bool _isTwoFactorEnabled = false;
  bool _isLoading = false;

  // --- DOĞRULAMA STATE'LERİ ---
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  final List<String> _presetAvatars = [
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Leo',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Gizmo',
    'https://api.dicebear.com/7.x/bottts/png?seed=Rascal',
    'https://api.dicebear.com/7.x/micah/png?seed=Missy',
    'https://api.dicebear.com/7.x/pixel-art/png?seed=Max',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Luna',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MaskotHelper.checkAndShow(context,
          featureKey: 'profil_duzenle_tutorial_gosterildi',
          targets: [
            TargetFocus(
                identify: "avatar-area",
                keyTarget: _avatarAreaKey,
                alignSkip: Alignment.bottomCenter,
                contents: [
                  TargetContent(
                    align: ContentAlign.bottom, builder: (context, controller) =>
                      MaskotHelper.buildTutorialContent(
                          context,
                          title: 'Yeni Tarzın',
                          description: 'Profil fotoğrafını buradan değiştirebilir veya hazır avatarlardan birini seçebilirsin.'),
                  )
                ]),
            TargetFocus(
                identify: "save-button",
                keyTarget: _saveButtonKey,
                alignSkip: Alignment.topRight,
                contents: [TargetContent(align: ContentAlign.top, builder: (context, controller) => MaskotHelper.buildTutorialContent(
                  context,
                  title: 'Değişiklikleri Kaydet',
                  description: 'Yaptığın tüm değişiklikleri profilinde göstermek için bu butona basmayı unutma.'))])
          ]);
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Auth verilerini tazeleyin
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_userId).get();
      
      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Kullanıcı profili bulunamadı."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        final data = userDoc.data();
        if (data != null) {
          setState(() {
            _takmaAdController.text = data['takmaAd'] ?? '';
            _originalTakmaAd = data['takmaAd'];
            _adSoyadController.text = data['ad'] ?? '';
            _biyografiController.text = data['biyografi'] ?? '';
            _githubController.text = data['github'] ?? '';
            _linkedinController.text = data['linkedin'] ?? '';
            _instagramController.text = data['instagram'] ?? '';
            _xPlatformController.text = data['x_platform'] ?? '';
            _isTwoFactorEnabled = data['isTwoFactorEnabled'] ?? false;
            
            final submissionData = data['submissionData'] as Map<String, dynamic>?;
            _university = submissionData?['university'];
            _department = submissionData?['department'];
            _currentAvatarUrl = data['avatarUrl'];

            // Auth ve Firestore verilerini birleştir
            _emailController.text = updatedUser.email ?? '';
            _phoneController.text = data['phoneNumber'] ?? ''; 

            // Doğrulama durumlarını ayarla
            _isEmailVerified = updatedUser.emailVerified;
            _isPhoneVerified = updatedUser.phoneNumber != null && updatedUser.phoneNumber!.isNotEmpty;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Profil yüklemesi hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profil yüklenemedi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- E-POSTA DOĞRULAMA ---
  void _sendVerificationEmail() async {
    if (_cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lütfen tekrar denemeden önce $_cooldownSeconds saniye bekleyin."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Doğrulama e-postası gönderildi! Lütfen gelen kutunuzu kontrol edin."), backgroundColor: AppColors.success));
        
        // Cooldown başlat
        setState(() => _cooldownSeconds = 60);
        _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_cooldownSeconds > 0) {
            setState(() => _cooldownSeconds--);
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- RESİM SEÇME FONKSİYONLARI ---
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary), 
                title: const Text('Kameradan Çek'), 
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary), 
                title: const Text('Galeriden Seç'), 
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }
              ),
              ListTile(
                leading: const Icon(Icons.face, color: AppColors.primary), 
                title: const Text('Hazır Avatar Seç'), 
                onTap: () { Navigator.pop(context); _selectPresetAvatar(); }
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error), 
                title: const Text('Fotoğrafı Kaldır'), 
                onTap: () { 
                  Navigator.pop(context); 
                  setState(() { 
                    _avatarImageFile = null;
                    _selectedPresetAvatarUrl = null;
                    _isAvatarRemoved = true;
                  }); 
                }
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectPresetAvatar() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Avatar Seç"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _presetAvatars.length,
              itemBuilder: (context, index) {
                final url = _presetAvatars[index];
                return GestureDetector(
                  onTap: () {
                    setState(() { _selectedPresetAvatarUrl = url; _avatarImageFile = null; _isAvatarRemoved = false; });
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(backgroundImage: CachedNetworkImageProvider(url, cacheManager: CustomCacheManager.instance)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      File? compressedFile = await ImageCompressionService.compressImage(file);
      file = compressedFile ?? file; 

      if (mounted) {
        setState(() {
          _avatarImageFile = file;
          _selectedPresetAvatarUrl = null;
          _isAvatarRemoved = false;
        });
      }
    }
  }

  Future<String?> _uploadImage(File file, String path) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);
      final uploadTask = storageRef.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (kDebugMode) print('Firebase Storage Hatası: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resim yüklenemedi: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Resim yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resim yüklenemedi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // --- PROFİLİ KAYDETME ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final newTakmaAd = _takmaAdController.text.trim();
      
      // ✅ Takma ad validasyonu
      if (newTakmaAd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Takma ad boş olamaz."), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (newTakmaAd.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Takma ad en az 3 karakter olmalıdır."), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (newTakmaAd.length > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Takma ad en fazla 30 karakter olabilir."), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Biyografi validasyonu
      if (_biyografiController.text.length > 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biyografi en fazla 200 karakter olabilir."), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Takma ad benzersizliği kontrolü
      if (newTakmaAd != _originalTakmaAd) {
        final query = await FirebaseFirestore.instance
            .collection('kullanicilar')
            .where('takmaAd', isEqualTo: newTakmaAd)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bu takma ad zaten kullanılıyor."), backgroundColor: AppColors.error),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      String? newAvatarUrl;
      
      // ✅ Avatar yükleme
      if (_isAvatarRemoved) {
        newAvatarUrl = '';
      } else if (_selectedPresetAvatarUrl != null) {
        newAvatarUrl = _selectedPresetAvatarUrl;
      } else if (_avatarImageFile != null) {
        newAvatarUrl = await _uploadImage(_avatarImageFile!, 'profil_resimleri/$_userId.jpg');
        if (newAvatarUrl == null) {
          setState(() => _isLoading = false);
          return; // Yükleme başarısız, SnackBar zaten gösterildi
        }
      }

      final Map<String, dynamic> updateData = {
        'ad': _adSoyadController.text.trim(),
        'takmaAd': newTakmaAd,
        'biyografi': _biyografiController.text.trim(),
        'github': _githubController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'x_platform': _xPlatformController.text.trim(),
      };

      if (newAvatarUrl != null) {
        updateData['avatarUrl'] = newAvatarUrl;
      }

      // ✅ Firestore güncelleme
      await FirebaseFirestore.instance.collection('kullanicilar').doc(_userId).update(updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil başarıyla güncellendi!"),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) print('Firebase Firestore Hatası: ${e.message}');
      
      if (mounted) {
        String errorMessage = "Profil güncellenemedi.";
        if (e.code == 'permission-denied') {
          errorMessage = "Bu işlemi yapmaya yetkiniz yok.";
        } else if (e.code == 'not-found') {
          errorMessage = "Profil bulunamadı.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Profil kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPhoneUpdateDialog() {
    final newPhoneController = TextEditingController();
    final smsCodeController = TextEditingController();
    String? verificationId;
    int step = 1;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Telefon Numarası Güncelle"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 1) ...[
                  const Text("Yeni telefon numaranızı girin (Başında +90 ile)."),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Telefon",
                      border: OutlineInputBorder(),
                      hintText: "+90 5XX XXX XXXX",
                    ),
                  ),
                ] else ...[
                  const Text("SMS kodunu girin (6 haneli)."),
                  const SizedBox(height: 10),
                  TextField(
                    controller: smsCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: "SMS Kodu",
                      border: OutlineInputBorder(),
                      hintText: "000000",
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () => Navigator.pop(ctx),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: isDialogLoading ? null : () async {
                  try {
                    if (step == 1) {
                      final phone = newPhoneController.text.trim();
                      
                      // Telefon numarası validasyonu
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Telefon numarası boş olamaz."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      if (!phone.startsWith('+90') || phone.length < 13) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Telefon numarasını +90 ile başlayarak girin."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isDialogLoading = true);
                      
                      await _authService.verifyPhone(
                        phoneNumber: phone,
                        onCodeSent: (verId) {
                          setDialogState(() {
                            verificationId = verId;
                            step = 2;
                            isDialogLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("SMS kodu gönderildi."),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        onError: (msg) {
                          setDialogState(() => isDialogLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Hata: $msg"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                      );
                    } else {
                      final code = smsCodeController.text.trim();
                      
                      // SMS kodu validasyonu
                      if (code.isEmpty || code.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("SMS kodunu tam olarak girin (6 hane)."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      if (verificationId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Doğrulama ID'si bulunamadı. Lütfen baştan başlayın."),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isDialogLoading = true);
                      
                      try {
                        PhoneAuthCredential credential = PhoneAuthProvider.credential(
                          verificationId: verificationId!,
                          smsCode: code,
                        );
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await user.updatePhoneNumber(credential);
                          
                          await FirebaseFirestore.instance
                              .collection('kullanicilar')
                              .doc(_userId)
                              .update({'phoneNumber': newPhoneController.text.trim()});

                          setState(() {
                            _phoneController.text = newPhoneController.text.trim();
                            _isPhoneVerified = true;
                          });
                          
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Telefon numarası başarıyla güncellendi!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => isDialogLoading = false);
                        String errorMsg = "Doğrulama başarısız.";
                        if (e.code == 'invalid-verification-code') {
                          errorMsg = "SMS kodu yanlış. Lütfen kontrol edin.";
                        } else if (e.code == 'session-expired') {
                          errorMsg = "Doğrulama süresi doldu. Lütfen yeniden başlayın.";
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    setDialogState(() => isDialogLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Hata: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: isDialogLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(step == 1 ? "SMS Kodu Gönder" : "Doğrula"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleMFA(bool value) async {
    try {
      if (value && !_isPhoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Önce telefon numaranızı doğrulamanız gerekir."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      final error = await _authService.toggleMFA(value);
      
      if (mounted) {
        if (error == null) {
          setState(() {
            _isTwoFactorEnabled = value;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? "2 Adımlı Doğrulama başarıyla aktif edildi!"
                    : "2 Adımlı Doğrulama kapatıldı.",
              ),
              backgroundColor: value ? AppColors.success : Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Hata: $error"),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('2FA toggle hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bağlantı hatası. Lütfen tekrar deneyin."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hesabı Sil"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Bu işlem geri alınamaz. Hesabınıza ve tüm verilerinize erişim kaybedeceksiniz.",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text("Lütfen onaylamak için şifrenizi girin:"),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Şifre",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hesabı Sil", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ) ?? false;

    if (confirmed) {
      final success = await _authService.reauthenticateUser(passwordController.text);
      
      if (success && mounted) {
        _performDelete();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Şifre yanlış. Hesap silinemedi."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    
    passwordController.dispose();
  }

  Future<void> _performDelete() async {
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('deleteUserAccount').call();

      if (result.data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hesap başarıyla silindi."),
            backgroundColor: Colors.green,
          ),
        );
        
        // Giriş ekranına yönlendir ve tüm önceki ekranları kaldır
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const GirisEkrani()),
          (route) => false,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Hesap silme başarısız oldu. Lütfen tekrar deneyin."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) print('Firebase Hatası: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMsg = "Hesap silinemedi.";
        if (e.code == 'permission-denied') {
          errorMsg = "Bu işlemi yapmaya yetkiniz yok.";
        } else if (e.code == 'unauthenticated') {
          errorMsg = "Oturum süresi doldu. Lütfen yeniden giriş yapın.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Hesap silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showChangeRequestDialog() {
    final uniController = TextEditingController(text: _university);
    final deptController = TextEditingController(text: _department);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bilgi Değişikliği Talebi"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Üniversite veya bölüm bilgilerinizde bir hata varsa, düzeltilmesi için talep gönderebilirsiniz.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: uniController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Mevcut Üniversite",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Mevcut Bölüm",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
              ),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Doğru Bilgiler (lütfen detaylı yazın)",
                  border: OutlineInputBorder(),
                  hintText: "Örn: Üniversite adı... Bölüm adı...",
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              uniController.dispose();
              deptController.dispose();
              reasonController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              
              // Validasyon
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Lütfen doğru bilgiyi yazın."),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Lütfen yeterli detay sağlayın (en az 10 karakter)."),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Firestore'a talep kaydet
              _submitChangeRequest(reason);
              
              uniController.dispose();
              deptController.dispose();
              reasonController.dispose();
              Navigator.pop(ctx);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Talebiniz yöneticiye iletildi. Teşekkürler!"),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text("Talep Gönder"),
          ),
        ],
      ),
    );
  }

  /// Değişiklik talebini Firestore'a kaydeder
  Future<void> _submitChangeRequest(String reason) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('university_change_requests').add({
        'userId': userId,
        'currentUniversity': _university,
        'currentDepartment': _department,
        'requestedInfo': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('Talep gönderme hatası: $e');
    }
  }

  // --- UI WIDGETLARI (GÜNCELLENMİŞ - TEMA UYUMLU) ---
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildStandardInput(TextEditingController controller, String label, IconData icon, {String? prefixText, int maxLines = 1, bool readOnly = false, VoidCallback? onTap}) {
    // Theme.of(context).inputDecorationTheme sayesinde stil otomatik gelir.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          prefixText: prefixText,
        ),
      ),
    );
  }

  Widget _buildSocialInput(TextEditingController controller, String label, IconData icon, String prefixUrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: FaIcon(icon, size: 20), // FontAwesome ikonları için
          ),
          prefixText: prefixUrl,
        ),
      ),
    );
  }

  Widget _buildVerificationTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isVerified,
    required VoidCallback? onVerify,
    String verifyText = "Doğrula",
    int cooldown = 0,
  }) {
    bool onCooldown = cooldown > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: isVerified
        ? const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified, color: AppColors.success, size: 18),
            SizedBox(width: 4),
            Text("Doğrulandı", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
          ])
        : TextButton(
            onPressed: onCooldown ? null : onVerify,
            child: Text(onCooldown ? "$cooldown sn" : verifyText, style: TextStyle(color: onCooldown ? Colors.grey : AppColors.primary, fontWeight: FontWeight.bold)),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profili Düzenle"),
        actions: [
          IconButton(
            key: _saveButtonKey,
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Alanı
              Center(
                child: GestureDetector(
                  key: _avatarAreaKey,
                  onTap: _showImageSourceActionSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _isAvatarRemoved ? null : (_avatarImageFile != null
                            ? FileImage(_avatarImageFile!) as ImageProvider
                            : _selectedPresetAvatarUrl != null
                              ? CachedNetworkImageProvider(_selectedPresetAvatarUrl!)
                              : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(_currentAvatarUrl!)
                                  : null),
                        child: (_isAvatarRemoved || (_avatarImageFile == null && _selectedPresetAvatarUrl == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)))
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _buildSectionTitle("Kişisel Bilgiler", Icons.person_outline),
              _buildStandardInput(_adSoyadController, "Ad Soyad", Icons.person),
              _buildStandardInput(_takmaAdController, "Takma Ad", Icons.alternate_email),
              _buildStandardInput(_biyografiController, "Hakkımda", Icons.info_outline, maxLines: 3),

              _buildSectionTitle("Hesap & Güvenlik", Icons.security),
              // Doğrulama Kartı
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                elevation: 0,
                child: Column(
                  children: [
                    _buildVerificationTile(
                      icon: Icons.email_outlined,
                      title: "E-posta Adresi",
                      value: _emailController.text,
                      isVerified: _isEmailVerified,
                      onVerify: _isEmailVerified ? null : _sendVerificationEmail,
                      cooldown: _cooldownSeconds,
                    ),
                    const Divider(height: 1),
                    _buildVerificationTile(
                      icon: Icons.phone_android,
                      title: "Telefon Numarası",
                      value: _phoneController.text.isEmpty ? 'Eklenmemiş' : _phoneController.text,
                      isVerified: _isPhoneVerified,
                      onVerify: _showPhoneUpdateDialog,
                      verifyText: _isPhoneVerified ? "Değiştir" : "Doğrula",
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text("İki Adımlı Doğrulama (2FA)", style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(_isTwoFactorEnabled ? "Aktif" : "Pasif", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      value: _isTwoFactorEnabled,
                      activeColor: AppColors.success,
                      onChanged: (val) => _toggleMFA(val),
                      secondary: Icon(_isTwoFactorEnabled ? Icons.lock : Icons.lock_open, color: _isTwoFactorEnabled ? AppColors.success : Colors.grey),
                    ),
                  ],
                ),
              ),

              _buildSectionTitle("Akademik Bilgiler", Icons.school_outlined),
              _buildStandardInput(TextEditingController(text: _university), "Üniversite", Icons.account_balance, readOnly: true),
              _buildStandardInput(TextEditingController(text: _department), "Bölüm", Icons.book_outlined, readOnly: true),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _showChangeRequestDialog, child: const Text("Değişiklik Talep Et"))),

              _buildSectionTitle("Sosyal Medya", Icons.link),
              _buildSocialInput(_githubController, "GitHub", FontAwesomeIcons.github, "github.com/"),
              _buildSocialInput(_linkedinController, "LinkedIn", FontAwesomeIcons.linkedinIn, "linkedin.com/in/"),
              _buildSocialInput(_instagramController, "Instagram", FontAwesomeIcons.instagram, "instagram.com/"),
              _buildSocialInput(_xPlatformController, "X (Twitter)", FontAwesomeIcons.xTwitter, "x.com/"),

              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: const Text("Kaydet"),
                ),
              ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: _deleteAccount,
                child: const Text("Hesabımı Sil", style: TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}