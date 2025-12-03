import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'forum_sayfasi.dart'; 
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';  // YENİ: Modern header widget'ı
// YENİ: Servis importu
import '../../services/image_compression_service.dart';
import '../../services/gamification_service.dart'; // ✅ XP SİSTEMİ

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("En fazla 2 resim ekleyebilirsiniz."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPickingImage = true);

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 85);

      if (pickedFiles.isNotEmpty) {
        for (var xfile in pickedFiles) {
          if (_selectedImages.length >= 2) break;

          try {
            File originalFile = File(xfile.path);
            
            // Dosya boyutu kontrolü (10MB max)
            final int fileSizeInBytes = originalFile.lengthSync();
            const int maxFileSizeInBytes = 10 * 1024 * 1024;
            
            if (fileSizeInBytes > maxFileSizeInBytes) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Resim boyutu 10MB'dan küçük olmalıdır."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              continue;
            }

            // Resim sıkıştırma
            File? compressedFile = await ImageCompressionService.compressImage(originalFile);
            
            setState(() {
              _selectedImages.add(compressedFile ?? originalFile);
            });
          } catch (e) {
            debugPrint("Resim işleme hatası: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Resim işlenemedi: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        
        if (pickedFiles.length > 2 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sadece ilk 2 resim seçildi."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resim seçilmedi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    
    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final imageFile = _selectedImages[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = "$userId-$timestamp-$i.jpg";
        final ref = FirebaseStorage.instance.ref().child('gonderi_resimleri/$fileName');
        
        final uploadTask = ref.putFile(
          imageFile,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'uploadedAt': timestamp.toString()},
          ),
        );
        
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
        
        debugPrint('Resim yüklendi: $url');
      } on FirebaseException catch (e) {
        debugPrint("Firebase resim yükleme hatası: ${e.code} - ${e.message}");
      } catch (e) {
        debugPrint("Resim yükleme hatası: $e");
      }
    }
    return downloadUrls;
  }

  Future<void> _gonderiEkle() async {
    // Form validasyonu
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen tüm alanları doldurun."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Başlık validasyonu
    final baslik = _baslikController.text.trim();
    if (baslik.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Başlık en az 3 karakter olmalıdır."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mesaj validasyonu
    final mesaj = _mesajController.text.trim();
    if (mesaj.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mesaj en az 5 karakter olmalıdır."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) {
        throw Exception('Kullanıcı oturumu sona erdi.');
      }

      // Kullanıcı bilgilerini al
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('Kullanıcı profili bulunamadı.');
      }

      final userData = userDoc.data() ?? {};
      
      final String displayName = _isAnonymous ? 'Anonim' : widget.userName;
      final String? currentAvatarUrl = _isAnonymous ? null : userData['avatarUrl'];
      final List<dynamic> authorBadges = _isAnonymous ? [] : (userData['earnedBadges'] ?? []);

      // Resim yükle
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages(userId);
        
        // ✅ DÜZELTME: Resim yükleme başarısızlığını kontrol et
        if (imageUrls.length < _selectedImages.length) {
          final failedCount = _selectedImages.length - imageUrls.length;
          
          // Kullanıcıya sor
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Resim Yükleme Hatası"),
              content: Text("$failedCount resim yüklenemedi. Gönderi resimsiz veya eksik resimle paylaşılsın mı?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("İptal"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Devam Et"),
                ),
              ],
            ),
          );
          
          if (shouldContinue != true) {
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }
      }

      // Gönderiyi oluştur
      await FirebaseFirestore.instance.collection('gonderiler').add({
        'type': 'gonderi',
        'baslik': baslik,
        'mesaj': mesaj,
        'ad': displayName,
        'realUsername': widget.userName,
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
        'isPinned': false,
      });

      // Kullanıcının gönderi sayısını güncelle
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
        'postCount': FieldValue.increment(1),
      });

      // ✅ XP EKLE: Gönderi paylaşma ödülü (10 XP)
      try {
        await GamificationService().addXP(
          userId,
          'post_created',
          10,
          'post-${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        debugPrint('XP ekleme hatası (gönderi): $e');
        // XP hatası gönderi eklemeyi engellemez
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gönderi yayınlandı!"),
            backgroundColor: AppColors.success,
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop();
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase hatası: ${e.code} - ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gönderi ekleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata oluştu: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppHeader(
        title: 'Konu Başlat',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading 
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
                : TextButton(
                    onPressed: _gonderiEkle,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: const Text("Paylaş", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
