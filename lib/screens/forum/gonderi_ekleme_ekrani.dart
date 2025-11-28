import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'forum_sayfasi.dart'; 
import '../../utils/app_colors.dart';

class GonderiEklemeEkrani extends StatefulWidget {
  final String userName;
  const GonderiEklemeEkrani({super.key, required this.userName});

  @override
  State<GonderiEklemeEkrani> createState() => _GonderiEklemeEkraniState();
}

class _GonderiEklemeEkraniState extends State<GonderiEklemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _baslikController = TextEditingController();
  final _mesajController = TextEditingController();
  String _selectedCategory = kCategories.first;
  bool _isLoading = false;
  
  bool _isPickingImage = false; 
  bool _isAnonymous = false;

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  Future<void> _pickImages() async {
    if (_isPickingImage) return;
    
    if (_selectedImages.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("En fazla 2 resim ekleyebilirsiniz.")));
      return;
    }

    setState(() => _isPickingImage = true);

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 70);

      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var xfile in pickedFiles) {
            if (_selectedImages.length < 2) {
              _selectedImages.add(File(xfile.path));
            }
          }
        });
        
        if (pickedFiles.length > 2) {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sadece ilk 2 resim seçildi.")));
        }
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages(String userId) async {
    List<String> downloadUrls = [];
    
    for (var imageFile in _selectedImages) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = "$userId-$timestamp-${downloadUrls.length}.jpg";
        final ref = FirebaseStorage.instance.ref().child('gonderi_resimleri/$fileName');
        
        final uploadTask = ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e) {
        debugPrint("Resim yükleme hatası: $e");
      }
    }
    return downloadUrls;
  }

  Future<void> _gonderiEkle() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      final String displayName = _isAnonymous ? 'Anonim' : widget.userName;
      final String? currentAvatarUrl = _isAnonymous ? null : userData['avatarUrl'];
      final List<dynamic> authorBadges = _isAnonymous ? [] : (userData['earnedBadges'] ?? []);

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages(userId);
      }

      await FirebaseFirestore.instance.collection('gonderiler').add({
        'type': 'gonderi',
        'baslik': _baslikController.text.trim(),
        'mesaj': _mesajController.text.trim(),
        'ad': displayName,
        'realUsername': widget.userName, // YENİ: Admin için gerçek isim
        'userId': userId,
        'zaman': FieldValue.serverTimestamp(),
        'lastCommentTimestamp': FieldValue.serverTimestamp(),
        'commentCount': 0,
        'kategori': _selectedCategory,
        'avatarUrl': currentAvatarUrl,
        'authorBadges': authorBadges,
        'likes': [],
        'imageUrls': imageUrls,
        'isAnonymous': _isAnonymous,
      });

      final userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(userId);
      await userRef.update({'postCount': FieldValue.increment(1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yayınlandı!"), backgroundColor: AppColors.success));
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu."), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Konu Başlat", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading 
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : TextButton(
                    onPressed: _gonderiEkle,
                    style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: const Text("Paylaş", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Kategori Seç", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kCategories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        onSelected: (selected) => setState(() => _selectedCategory = category),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              
              _buildModernInput(controller: _baslikController, label: "Başlık", hint: "Konu ne hakkında?", icon: Icons.title),
              const SizedBox(height: 16),
              _buildModernInput(controller: _mesajController, label: "İçerik", hint: "Detayları buraya yaz...", icon: Icons.article_outlined, maxLines: 8),
              
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Görseller (Max 2)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (_selectedImages.length < 2)
                    TextButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                      label: const Text("Resim Ekle", style: TextStyle(color: AppColors.primary)),
                    ),
                ],
              ),
              
              const SizedBox(height: 10),

              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: SwitchListTile(
                  title: const Text("Anonim Olarak Paylaş (İtiraf)", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Adın ve profil resmin gizlenecek."),
                  value: _isAnonymous,
                  activeColor: AppColors.primary,
                  secondary: const Icon(Icons.visibility_off, color: Colors.grey),
                  onChanged: (val) {
                    setState(() {
                      _isAnonymous = val;
                      if(val) _selectedCategory = 'Diğer'; 
                    });
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({required TextEditingController controller, required String label, required String hint, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (v) => v!.trim().isEmpty ? "$label boş olamaz" : null,
      ),
    );
  }
}