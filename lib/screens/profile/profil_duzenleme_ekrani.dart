import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Cloud Function için gerekli
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import '../auth/giris_ekrani.dart'; // Silince giriş ekranına atmak için

Future<File> _compressImage(File file) async {
  return file; 
}

class ProfilDuzenlemeEkrani extends StatefulWidget {
  const ProfilDuzenlemeEkrani({super.key});

  @override
  State<ProfilDuzenlemeEkrani> createState() => _ProfilDuzenlemeEkraniState();
}

class _ProfilDuzenlemeEkraniState extends State<ProfilDuzenlemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _takmaAdController = TextEditingController();
  final _adSoyadController = TextEditingController();
  final _biyografiController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _xPlatformController = TextEditingController();

  String? _university;
  String? _department;
  String? _originalTakmaAd;
  String? _currentAvatarUrl;
  File? _imageFile;
  bool _isLoading = false;
  bool _isAvatarRemoved = false;
  String? _selectedPresetAvatarUrl;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

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
        final submissionData = data['submissionData'] as Map<String, dynamic>?;
        _university = submissionData?['university'];
        _department = submissionData?['department'];
        _currentAvatarUrl = data['avatarUrl'];
      });
    }
  }

  // --- HESAP SİLME FONKSİYONU (GÜNCELLENDİ) ---
  Future<void> _deleteAccount() async {
    // 1. Onay Dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hesabı Sil", style: TextStyle(color: Colors.red)),
        content: const Text(
          "Hesabınızı silmek istediğinize emin misiniz?\n\n"
          "DİKKAT: Kişisel verileriniz (profil fotoğrafı, isim vb.) tamamen silinecek, ancak yazdığınız gönderiler ve yorumlar 'Silinmiş Üye' adıyla forumda kalmaya devam edecektir.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Evet, Hesabımı Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // 2. Cloud Function Çağrısı (Anonymization)
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('deleteUserAccount')
          .call();

      if (result.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hesabınız başarıyla silindi.")),
          );
          // 3. Giriş Ekranına Yönlendir
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const GirisEkrani()),
            (route) => false,
          );
        }
      } else {
        throw Exception(result.data['message'] ?? "Bilinmeyen hata.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Silme hatası: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChangeRequestDialog() {
    final uniController = TextEditingController(text: _university);
    final deptController = TextEditingController(text: _department);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bilgi Değişikliği Talep Et"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Üniversite veya bölüm değişikliği yönetici onayı gerektirir. Lütfen yeni bilgileri giriniz.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uniController,
                decoration: const InputDecoration(labelText: "Yeni Üniversite", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptController,
                decoration: const InputDecoration(labelText: "Yeni Bölüm", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: "Notunuz (Opsiyonel)", border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              if (uniController.text.isEmpty || deptController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen üniversite ve bölüm adını giriniz.")));
                return;
              }
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('degisiklik_istekleri').add({
                  'userId': _userId,
                  'userEmail': FirebaseAuth.instance.currentUser?.email,
                  'userName': _adSoyadController.text,
                  'oldUniversity': _university,
                  'oldDepartment': _department,
                  'newUniversity': uniController.text.trim(),
                  'newDepartment': deptController.text.trim(),
                  'note': noteController.text.trim(),
                  'status': 'pending',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Talebiniz yöneticiye iletildi."), backgroundColor: AppColors.success));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                }
              }
            },
            child: const Text("Talebi Gönder"),
          ),
        ],
      ),
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.primary), title: const Text('Kameradan Çek'), onTap: () { Navigator.pop(context); _pickImageFromCamera(); }),
              ListTile(leading: const Icon(Icons.photo_library, color: AppColors.primary), title: const Text('Galeriden Seç'), onTap: () { Navigator.pop(context); _pickImageFromGallery(); }),
              ListTile(leading: const Icon(Icons.face, color: AppColors.primary), title: const Text('Hazır Avatar Seç'), onTap: () { Navigator.pop(context); _selectPresetAvatar(); }),
              if (_imageFile != null || _currentAvatarUrl != null)
                ListTile(leading: const Icon(Icons.delete, color: AppColors.error), title: const Text('Fotoğrafı Kaldır'), onTap: () { Navigator.pop(context); setState(() { _imageFile = null; _selectedPresetAvatarUrl = null; _isAvatarRemoved = true; }); }),
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
                    setState(() { _selectedPresetAvatarUrl = url; _imageFile = null; _isAvatarRemoved = false; });
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(backgroundImage: CachedNetworkImageProvider(url)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    await _processPickedImage(pickedFile);
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    await _processPickedImage(pickedFile);
  }

  Future<void> _processPickedImage(XFile? pickedFile) async {
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      file = await _compressImage(file);
      if (mounted) {
        setState(() { _imageFile = file; _selectedPresetAvatarUrl = null; _isAvatarRemoved = false; });
      }
    }
  }

  Future<String?> _uploadProfilePicture() async {
    if (_imageFile == null) return null;
    try {
      final storageRef = FirebaseStorage.instance.ref().child('profil_resimleri/$_userId.jpg');
      final uploadTask = storageRef.putFile(_imageFile!, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

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
    } else if (_imageFile != null) {
      newAvatarUrl = await _uploadProfilePicture();
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

  Widget _buildModernInput(TextEditingController controller, String label, dynamic iconData, {String? prefixText, int maxLines = 1, bool readOnly = false}) {
    final Widget prefixIconWidget = iconData is IconData
        ? Icon(iconData, size: 20, color: Colors.grey[600])
        : FaIcon(iconData, size: 20, color: Colors.grey[600]);
        
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: _isAvatarRemoved ? null : (_imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : _selectedPresetAvatarUrl != null
                            ? CachedNetworkImageProvider(_selectedPresetAvatarUrl!)
                            : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(_currentAvatarUrl!)
                                : null),
                      child: (_isAvatarRemoved || (_imageFile == null && _selectedPresetAvatarUrl == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)))
                          ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImageSourceActionSheet,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              _buildSectionTitle("Kişisel Bilgiler", Icons.person_outline),
              _buildModernInput(_adSoyadController, "Ad Soyad", Icons.person),
              _buildModernInput(_takmaAdController, "Takma Ad", Icons.alternate_email),
              _buildModernInput(_biyografiController, "Hakkımda", Icons.info_outline, maxLines: 3),

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
              
              // --- HESAP SİLME BUTONU (ANONİMLEŞTİRME UYARISI İLE) ---
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
    );
  }
}