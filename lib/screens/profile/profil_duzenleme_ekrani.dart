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
import '../../services/image_compression_service.dart'; // DÜZELTME: Servis import edildi
import '../../services/image_cache_manager.dart'; // YENİ: Merkezi önbellek yöneticisi

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

  // Global Key'ler
  final GlobalKey _coverAvatarKey = GlobalKey();
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

  // Kapak Fotoğrafı Yönetimi
  String? _currentCoverUrl;
  File? _coverImageFile;
  bool _isCoverRemoved = false;

  bool _isTwoFactorEnabled = false;
  bool _isLoading = false;

  // Hazır avatarlar
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
                identify: "cover-avatar-area",
                keyTarget: _coverAvatarKey,
                alignSkip: Alignment.topRight,
                contents: [
                  TargetContent(
                    align: ContentAlign.bottom, builder: (context, controller) =>
                      MaskotHelper.buildTutorialContent(
                          context,
                          title: 'Görünümünü Özelleştir',
                          description: 'Buraya tıklayarak kapak fotoğrafını ve avatarını değiştirebilirsin. İstersen hazır avatarlardan birini de seçebilirsin!'),
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

  Future<void> _loadUserData() async {
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
        _phoneController.text = data['phoneNumber'] ?? '';
        _isTwoFactorEnabled = data['isTwoFactorEnabled'] ?? false;
        
        final submissionData = data['submissionData'] as Map<String, dynamic>?;
        _university = submissionData?['university'];
        _department = submissionData?['department'];
        _currentAvatarUrl = data['avatarUrl'];
        _currentCoverUrl = data['coverUrl'];
      });
    }
  }

  // --- 1. RESİM SEÇME FONKSİYONLARI ---

  void _showImageSourceActionSheet({required bool isCover}) {
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
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera, isCover: isCover); }
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary), 
                title: const Text('Galeriden Seç'), 
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery, isCover: isCover); }
              ),
              if (!isCover)
                ListTile(
                  leading: const Icon(Icons.face, color: AppColors.primary), 
                  title: const Text('Hazır Avatar Seç'), 
                  onTap: () { Navigator.pop(context); _selectPresetAvatar(); }
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error), 
                title: Text(isCover ? 'Kapağı Kaldır' : 'Fotoğrafı Kaldır'), 
                onTap: () { 
                  Navigator.pop(context); 
                  setState(() { 
                    if (isCover) {
                      _coverImageFile = null;
                      _isCoverRemoved = true;
                    } else {
                      _avatarImageFile = null;
                      _selectedPresetAvatarUrl = null;
                      _isAvatarRemoved = true;
                    }
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
                  child: CircleAvatar(backgroundImage: CachedNetworkImageProvider(url, cacheManager: ImageCacheManager.instance)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, {required bool isCover}) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      // DÜZELTME: Gerçek sıkıştırma servisi kullanılıyor
      File? compressedFile = await ImageCompressionService.compressImage(file);
      file = compressedFile ?? file; 

      if (mounted) {
        setState(() {
          if (isCover) {
            _coverImageFile = file;
            _isCoverRemoved = false;
          } else {
            _avatarImageFile = file;
            _selectedPresetAvatarUrl = null;
            _isAvatarRemoved = false;
          }
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

  // --- 2. PROFİLİ KAYDETME ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Takma Ad Kontrolü
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

    // Avatar Yükleme/Belirleme
    String? newAvatarUrl;
    if (_isAvatarRemoved) {
      newAvatarUrl = '';
    } else if (_selectedPresetAvatarUrl != null) {
      newAvatarUrl = _selectedPresetAvatarUrl;
    } else if (_avatarImageFile != null) {
      newAvatarUrl = await _uploadImage(_avatarImageFile!, 'profil_resimleri/$_userId.jpg');
    }

    // Kapak Fotoğrafı Yükleme/Belirleme
    String? newCoverUrl;
    if (_isCoverRemoved) {
      newCoverUrl = ''; 
    } else if (_coverImageFile != null) {
      newCoverUrl = await _uploadImage(_coverImageFile!, 'kapak_resimleri/$_userId.jpg');
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
    if (newCoverUrl != null) updateData['coverUrl'] = newCoverUrl;

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

  // --- DİĞER (Telefon, 2FA, Silme) ---
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

                        setState(() => _phoneController.text = newPhoneController.text.trim());
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
    if (value && (_phoneController.text.isEmpty || _phoneController.text.length < 10)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce telefon numarası eklemelisiniz."), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    final error = await _authService.toggleMFA(value);
    setState(() {
      _isLoading = false;
      if (error == null) {
        _isTwoFactorEnabled = value;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? "2FA Aktif!" : "2FA Kapalı."), backgroundColor: value ? AppColors.success : Colors.grey));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
      }
    });
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Güvenlik Kontrolü"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Şifrenizi girin."),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Şifre", border: OutlineInputBorder())),
          ],
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
           ElevatedButton(
             onPressed: () async {
               Navigator.pop(ctx, false);
               final success = await _authService.reauthenticateUser(passwordController.text);
               if (success && mounted) _performDelete();
               else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre yanlış."), backgroundColor: Colors.red));
             },
             child: const Text("Onayla"),
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
          title: const Text("Bilgi Değişikliği"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: uniController, decoration: const InputDecoration(labelText: "Yeni Üniversite")),
              TextField(controller: deptController, decoration: const InputDecoration(labelText: "Yeni Bölüm")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            ElevatedButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Talebiniz iletildi."))); }, child: const Text("Gönder")),
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
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. GÖRSEL DÜZENLEME ALANI (Kapak + Avatar) ---
            SizedBox(
              height: 240, 
              child: Stack(
                key: _coverAvatarKey, 
                children: [
                  // A. Kapak Fotoğrafı
                  GestureDetector(
                    onTap: () => _showImageSourceActionSheet(isCover: true),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        image: (_isCoverRemoved) 
                            ? null
                            : (_coverImageFile != null)
                                ? DecorationImage(image: FileImage(_coverImageFile!), fit: BoxFit.cover)
                                : (_currentCoverUrl != null && _currentCoverUrl!.isNotEmpty) 
                                    ? DecorationImage(image: CachedNetworkImageProvider(_currentCoverUrl!, cacheManager: ImageCacheManager.instance), fit: BoxFit.cover)
                                    : const DecorationImage(image: CachedNetworkImageProvider('https://images.unsplash.com/photo-1557683316-973673baf926?w=900&q=80'), fit: BoxFit.cover),
                      ),
                      child: Container(
                        color: Colors.black26, 
                        child: const Center(
                          child: Icon(Icons.camera_alt, color: Colors.white70, size: 40),
                        ),
                      ),
                    ),
                  ),

                  // B. Avatar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _showImageSourceActionSheet(isCover: false),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _isAvatarRemoved ? null : (_avatarImageFile != null
                                    ? FileImage(_avatarImageFile!) as ImageProvider 
                                    : _selectedPresetAvatarUrl != null 
                                      ? CachedNetworkImageProvider(_selectedPresetAvatarUrl!, cacheManager: ImageCacheManager.instance)
                                      : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) 
                                          ? CachedNetworkImageProvider(_currentAvatarUrl!, cacheManager: ImageCacheManager.instance)
                                          : null),
                                child: (_isAvatarRemoved || (_avatarImageFile == null && _selectedPresetAvatarUrl == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)))
                                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- 2. FORM ALANLARI ---
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
                          _buildModernInput(_phoneController, "Telefon Numarası", Icons.phone_android, readOnly: true, onTap: _showPhoneUpdateDialog),
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
                        key: _saveButtonKey, 
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