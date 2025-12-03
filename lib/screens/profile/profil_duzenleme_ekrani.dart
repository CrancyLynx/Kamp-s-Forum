import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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

  // --- YENİ EKLENEN DOĞRULAMA STATE'LERİ ---
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  // -----------------------------------------

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Auth verilerini tazeleyin
    await user.reload();
    final updatedUser = FirebaseAuth.instance.currentUser!;

    final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_userId).get();
    if (userDoc.exists && mounted) {
      final data = userDoc.data()!;
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
    } catch (e) {
      return null;
    }
  }

  // --- PROFİLİ KAYDETME ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newTakmaAd = _takmaAdController.text.trim();
    if (newTakmaAd != _originalTakmaAd) {
      final query = await FirebaseFirestore.instance.collection('kullanicilar').where('takmaAd', isEqualTo: newTakmaAd).limit(1).get();
      if (query.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu takma ad kullanımda."), backgroundColor: AppColors.error));
          setState(() => _isLoading = false);
        }
        return;
      }
    }

    String? newAvatarUrl;
    if (_isAvatarRemoved) {
      newAvatarUrl = '';
    } else if (_selectedPresetAvatarUrl != null) {
      newAvatarUrl = _selectedPresetAvatarUrl;
    } else if (_avatarImageFile != null) {
      newAvatarUrl = await _uploadImage(_avatarImageFile!, 'profil_resimleri/$_userId.jpg');
    }

    final Map<String, dynamic> updateData = {
      'ad': _adSoyadController.text.trim(),
      'takmaAd': _takmaAdController.text.trim(),
      'biyografi': _biyografiController.text.trim(),
      'github': _githubController.text.trim(),
      'linkedin': _linkedinController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'x_platform': _xPlatformController.text.trim(),
    };

    if (newAvatarUrl != null) updateData['avatarUrl'] = newAvatarUrl;

    try {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(_userId).update(updateData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil güncellendi!"), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPhoneUpdateDialog() {
    final newPhoneController = TextEditingController();
    final smsCodeController = TextEditingController();
    String? verificationId;
    int step = 1;

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
                  TextField(controller: newPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
                ] else ...[
                  const Text("SMS kodunu girin."),
                  const SizedBox(height: 10),
                  TextField(controller: smsCodeController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: "Kod", border: OutlineInputBorder())),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
              ElevatedButton(
                onPressed: () async {
                  if (step == 1) {
                    final phone = newPhoneController.text.trim();
                    if (phone.length < 10) return;
                    setDialogState(() => _isLoading = true);
                    await _authService.verifyPhone(
                      phoneNumber: phone,
                      onCodeSent: (verId) {
                        setDialogState(() { verificationId = verId; step = 2; _isLoading = false; });
                      },
                      onError: (msg) {
                        setDialogState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      },
                    );
                  } else {
                    final code = smsCodeController.text.trim();
                    if (code.length < 6 || verificationId == null) return;
                    setDialogState(() => _isLoading = true);
                    try {
                      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: code);
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await user.updatePhoneNumber(credential);
                        
                        await FirebaseFirestore.instance.collection('kullanicilar').doc(_userId).update({
                          'phoneNumber': newPhoneController.text.trim(),
                        });

                        setState(() { 
                          _phoneController.text = newPhoneController.text.trim();
                          _isPhoneVerified = true;
                        });
                        if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Güncellendi!"))); }
                      }
                    } catch (e) {
                      setDialogState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                    }
                  }
                },
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : Text(step == 1 ? "Kod Gönder" : "Doğrula"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleMFA(bool value) async {
    if (value && !_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce telefon numaranızı doğrulamanız gerekir."), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    final error = await _authService.toggleMFA(value);
    setState(() {
      _isLoading = false;
      if (error == null) {
        _isTwoFactorEnabled = value;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? "2 Adımlı Doğrulama Aktif!" : "2 Adımlı Doğrulama Kapalı."), backgroundColor: value ? AppColors.success : Colors.grey));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
      }
    });
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Güvenlik Kontrolü"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Hesabınızı silme işlemini onaylamak için lütfen şifrenizi girin."),
            const SizedBox(height: 10),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Şifre", border: OutlineInputBorder())),
          ],
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
             onPressed: () async {
               Navigator.pop(ctx, false);
               final success = await _authService.reauthenticateUser(passwordController.text);
               if (success && mounted) _performDelete();
               else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre yanlış."), backgroundColor: Colors.red));
             },
             child: const Text("Hesabımı Sil", style: TextStyle(color: Colors.white)),
           )
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('deleteUserAccount').call();
      if (result.data['success'] == true && mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const GirisEkrani()), (route) => false);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showChangeRequestDialog() {
      final uniController = TextEditingController(text: _university);
      final deptController = TextEditingController(text: _department);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Bilgi Değişikliği Talebi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Üniversite veya bölüm bilgilerinizde bir hata varsa, düzeltilmesi için talep gönderebilirsiniz."),
              const SizedBox(height: 15),
              TextField(controller: uniController, decoration: const InputDecoration(labelText: "Üniversite", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: deptController, decoration: const InputDecoration(labelText: "Bölüm", border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            ElevatedButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Talebiniz yöneticiye iletildi."))); }, child: const Text("Talep Gönder")),
          ],
        ),
      );
  }

  // --- UI WIDGETLARI ---
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
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

  Widget _buildModernInput(TextEditingController controller, String label, dynamic iconData, {String? prefixText, int maxLines = 1, bool readOnly = false, VoidCallback? onTap}) {
    final Widget prefixIconWidget = iconData is IconData
        ? Icon(iconData, size: 20, color: Colors.grey[600])
        : FaIcon(iconData, size: 20, color: Colors.grey[600]);
        
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIconWidget,
          prefixText: prefixText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true, 
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profili Düzenle", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            key: _saveButtonKey,
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Center(
              child: GestureDetector(
                key: _avatarAreaKey,
                onTap: _showImageSourceActionSheet,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor, 
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)
                        ]
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _isAvatarRemoved ? null : (_avatarImageFile != null
                            ? FileImage(_avatarImageFile!) as ImageProvider
                            : _selectedPresetAvatarUrl != null
                              ? CachedNetworkImageProvider(_selectedPresetAvatarUrl!, cacheManager: CustomCacheManager.instance)
                              : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(_currentAvatarUrl!, cacheManager: CustomCacheManager.instance)
                                  : null),
                        child: (_isAvatarRemoved || (_avatarImageFile == null && _selectedPresetAvatarUrl == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)))
                            ? const Icon(Icons.person, size: 70, color: Colors.grey)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary, 
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionTitle("Kişisel Bilgiler", Icons.person_outline),
                    _buildModernInput(_adSoyadController, "Ad Soyad", Icons.person),
                    _buildModernInput(_takmaAdController, "Takma Ad", Icons.alternate_email),
                    _buildModernInput(_biyografiController, "Hakkımda", Icons.info_outline, maxLines: 3),

                    const SizedBox(height: 10),
                    _buildSectionTitle("Hesap & Güvenlik", Icons.security),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
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
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _buildVerificationTile(
                            icon: Icons.phone_android,
                            title: "Telefon Numarası",
                            value: _phoneController.text.isEmpty ? 'Eklenmemiş' : _phoneController.text,
                            isVerified: _isPhoneVerified,
                            onVerify: _showPhoneUpdateDialog,
                            verifyText: _isPhoneVerified ? "Değiştir" : "Doğrula",
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
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

                    const SizedBox(height: 10),
                    _buildSectionTitle("Akademik Bilgiler", Icons.school_outlined),
                    Opacity(
                      opacity: 0.8, 
                      child: Column(
                        children: [
                          _buildModernInput(TextEditingController(text: _university ?? 'Belirtilmemiş'), "Üniversite", Icons.account_balance, readOnly: true),
                          _buildModernInput(TextEditingController(text: _department ?? 'Belirtilmemiş'), "Bölüm", Icons.book_outlined, readOnly: true),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _showChangeRequestDialog,
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text("Değişiklik Talep Et"),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ),

                    const SizedBox(height: 10),
                    _buildSectionTitle("Sosyal Medya", Icons.link),
                    _buildModernInput(_githubController, "GitHub", FontAwesomeIcons.github, prefixText: "github.com/"),
                    _buildModernInput(_linkedinController, "LinkedIn", FontAwesomeIcons.linkedinIn, prefixText: "linkedin.com/in/"),
                    _buildModernInput(_instagramController, "Instagram", FontAwesomeIcons.instagram, prefixText: "instagram.com/"),
                    _buildModernInput(_xPlatformController, "X (Twitter)", FontAwesomeIcons.xTwitter, prefixText: "x.com/"),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text("Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _deleteAccount,
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text("Hesabımı Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
