import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/guest_security_helper.dart';
import '../../widgets/app_header.dart';
// YENİ: Servis importu
import '../../services/image_compression_service.dart';

class UrunEklemeEkrani extends StatefulWidget {
  const UrunEklemeEkrani({super.key});

  @override
  State<UrunEklemeEkrani> createState() => _UrunEklemeEkraniState();
}

class _UrunEklemeEkraniState extends State<UrunEklemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _selectedCategory = 'Kitap';
  final List<String> _categories = ['Kitap', 'Notlar', 'Elektronik', 'Ev Eşyası', 'Giyim', 'Diğer'];
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isPickingImage = false;

  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 80 
      );
      if (pickedFile != null) {
        File original = File(pickedFile.path);
        // YENİ: Sıkıştırma işlemi
        File? compressed = await ImageCompressionService.compressImage(original);
        setState(() => _imageFile = compressed ?? original);
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir ürün resmi ekleyin.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Kullanıcı oturumu bulunamadı");

      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
      final userData = userDoc.data() ?? {}; 
      
      final String sellerName = userData['takmaAd'] ?? userData['ad'] ?? 'Anonim Satıcı';
      final String? sellerAvatar = userData['avatarUrl'];

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('urun_resimleri/${user.uid}-$timestamp.jpg');
      await ref.putFile(_imageFile!);
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('urunler').add({
        'sellerId': user.uid,
        'sellerName': sellerName,
        'sellerAvatar': sellerAvatar,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'price': int.tryParse(_priceController.text.trim()) ?? 0,
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isSold': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan başarıyla oluşturuldu! 🎉"), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // GUEST KONTROLÜ: Misafir kullanıcılar ürün ekleyemez
    if (GuestSecurityHelper.isGuest()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('İlan Ver'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.orange[400]),
              const SizedBox(height: 24),
              const Text(
                "İlan Ekleme Engellendi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "İlan eklemek için giriş yapmalısınız.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => GuestSecurityHelper.requireLogin(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text("Giriş Yap"),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: SimpleAppHeader(title: 'İlan Ver'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
                  ),
                  child: _imageFile == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]), 
                            const SizedBox(height: 8), 
                            Text("Kapak Fotoğrafı Ekle", style: TextStyle(color: Colors.grey[600]))
                          ]
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "İlan Başlığı", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Başlık gerekli" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Fiyat", border: OutlineInputBorder(), suffixText: "TL"),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Fiyat gerekli";
                        if (int.tryParse(v) == null) return "Geçerli bir sayı girin";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "Açıklama", border: OutlineInputBorder(), alignLabelWithHint: true),
                validator: (v) => v!.isEmpty ? "Açıklama gerekli" : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProduct,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Yayınla", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}