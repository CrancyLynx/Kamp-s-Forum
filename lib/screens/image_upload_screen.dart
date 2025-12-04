// lib/screens/image_upload_screen.dart
// ============================================================
// Görsel Yükleme Ekranı (Flutter Widget)
// Cloud Functions ile entegrasyon örneği
// ============================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/firebase_functions_service.dart';

class ImageUploadScreen extends StatefulWidget {
  @override
  _ImageUploadScreenState createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  final FirebaseFunctionsService _functionsService = 
    FirebaseFunctionsService();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  
  // ============================================================
  // Image Seçme Fonksiyonları
  // ============================================================
  
  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _statusMessage = '📷 Görsel seçildi';
          _isSuccess = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Görsel seçme hatası: $e';
        _isSuccess = false;
      });
    }
  }
  
  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _statusMessage = '📷 Görsel seçildi';
          _isSuccess = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Kamera hatası: $e';
        _isSuccess = false;
      });
    }
  }
  
  // ============================================================
  // Görsel Kontrolü & Yükleme
  // ============================================================
  
  Future<void> _analyzeAndUploadImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📷 Lütfen önce görsel seçin')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = '⏳ Görsel analiz ediliyor...';
    });
    
    try {
      // 1. Görsel yükleme progresini göster
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref()
        .child('gonderiler')
        .child(fileName + '.jpg');
      
      // 2. Dosyayı yükle (temporary)
      final uploadTask = ref.putFile(_selectedImage!);
      
      // 3. Upload progress'i takip et
      uploadTask.snapshotEvents.listen((event) {
        final progress = (event.bytesTransferred / event.totalBytes * 100).round();
        setState(() {
          _statusMessage = '📤 Yükleniyor: %$progress';
        });
      });
      
      // 4. Upload tamamlanmasını bekle
      final snapshot = await uploadTask;
      
      // 5. Yüklenen dosyanın URL'sini al
      final imageUrl = await snapshot.ref.getDownloadURL();
      print('[UI] Görsel yüklendi: $imageUrl');
      
      setState(() {
        _statusMessage = '🔍 Güvenlik kontrolü yapılıyor...';
      });
      
      // 6. Cloud Function'ı çağır (güvenlik kontrolü)
      final result = await _functionsService.analyzeImageBeforeUpload(imageUrl);
      
      // 7. Sonucu göster
      if (result['success']) {
        setState(() {
          _isLoading = false;
          _statusMessage = result['message'] ?? '✅ Görsel kontrol geçti!';
          _isSuccess = true;
        });
        
        // İsteğe bağlı: XP ekle
        await _functionsService.addXp(operationType: 'post_created');
        
        // Başarı dialog'ı göster
        _showSuccessDialog();
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = result['message'] ?? '⚠️ Görsel kontrol başarısız';
          _isSuccess = false;
        });
        
        // Başarısız dialog'ı göster
        _showErrorDialog(result['message'] ?? 'Bilinmeyen hata');
      }
    } catch (e) {
      print('[ERROR] Upload hatası: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Yükleme hatası: $e';
        _isSuccess = false;
      });
    }
  }
  
  // ============================================================
  // Dialog'lar
  // ============================================================
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Başarılı'),
        content: Text(_statusMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Foruma geri dön veya sonraki adım
            },
            child: Text('Devam Et'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Başka görsel seçmeye izin ver
            },
            child: Text('Başka Görsel Seç'),
          ),
        ],
      ),
    );
  }
  
  void _showQuotaWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Aylık Limit'),
        content: Text(
          'Görsel kontrol aylık limitine yaklaştı.\n\n'
          'Sonraki ay yeniden deneyin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }
  
  // ============================================================
  // UI Build
  // ============================================================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Görsel Yükle'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== Görsel Önizlemesi =====
              if (_selectedImage != null)
                Column(
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Görsel seçilmedi',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // ===== Görsel Seçme Butonları =====
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickImageFromGallery,
                      icon: Icon(Icons.photo),
                      label: Text('Galeri'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickImageFromCamera,
                      icon: Icon(Icons.camera_alt),
                      label: Text('Kamera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // ===== Yükle & Kontrol Butonu =====
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeAndUploadImage,
                icon: _isLoading 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(Icons.check),
                label: Text(_isLoading ? 'İşleniyor...' : 'Yükle & Kontrol Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLoading ? Colors.grey : Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              
              // ===== Durum Mesajı =====
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green[50] : Colors.red[50],
                    border: Border.all(
                      color: _isSuccess ? Colors.green : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isSuccess ? Colors.green[700] : Colors.red[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              SizedBox(height: 16),
              
              // ===== Bilgi Box =====
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ℹ️ Görsel Gereksinimleri:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Maksimum boyut: 10 MB\n'
                      '• Desteklenen formatlar: JPG, PNG, GIF, WebP\n'
                      '• Uygunsuz içerik: Otomatik kontrol\n'
                      '• Hızlı yükleme: Cache sistemi',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
