import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';

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

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
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
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
      final userData = userDoc.data()!;

      // 1. Resmi Yükle
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('urun_resimleri/${user.uid}-$timestamp.jpg');
      await ref.putFile(_imageFile!);
      final imageUrl = await ref.getDownloadURL();

      // 2. Veritabanına Ekle
      await FirebaseFirestore.instance.collection('urunler').add({
        'sellerId': user.uid,
        'sellerName': userData['takmaAd'] ?? userData['ad'],
        'sellerAvatar': userData['avatarUrl'],
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'price': int.parse(_priceController.text.trim()),
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isSold': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlan başarıyla oluşturuldu!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("İlan Ver"), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RESİM SEÇİCİ
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
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text("Kapak Fotoğrafı Ekle", style: TextStyle(color: Colors.grey))])
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // BİLGİ GİRİŞLERİ
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
                      decoration: const InputDecoration(labelText: "Fiyat (₺)", border: OutlineInputBorder(), suffixText: "TL"),
                      validator: (v) => v!.isEmpty ? "Fiyat gerekli" : null,
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