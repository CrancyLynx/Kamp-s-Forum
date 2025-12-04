// lib/screens/image_upload_example.dart
// ============================================================
// Görsel Yükleme Ekranı - BASIT ÖRNEK
// ============================================================

import 'package:flutter/material.dart';

class ImageUploadExample extends StatefulWidget {
  @override
  State<ImageUploadExample> createState() => _ImageUploadExampleState();
}

class _ImageUploadExampleState extends State<ImageUploadExample> {
  String _statusMessage = '📷 Görsel seçmek için butona basın';
  bool _isSuccess = false;

  void _onUploadPressed() {
    setState(() {
      _statusMessage = '⏳ Görsel analiz ediliyor...';
      _isSuccess = false;
    });
    
    // Simüle et: 2 saniye sonra başarı mesajı
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _statusMessage = '✅ Görsel kontrol geçti! Paylaşmaya hazır.';
        _isSuccess = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Görsel Yükle'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ===== Görsel Placeholder =====
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.blue[50],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 80, color: Colors.blue),
                    SizedBox(height: 12),
                    Text(
                      'Görsel seçilmedi',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // ===== Butonlar =====
            ElevatedButton.icon(
              onPressed: _onUploadPressed,
              icon: Icon(Icons.photo),
              label: Text('Galeriden Seç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _onUploadPressed,
              icon: Icon(Icons.camera_alt),
              label: Text('Kamera ile Çek'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 24),
            
            // ===== Durum Mesajı =====
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSuccess ? Colors.green[50] : Colors.amber[50],
                border: Border.all(
                  color: _isSuccess ? Colors.green : Colors.amber,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: _isSuccess ? Colors.green[700] : Colors.amber[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            
            // ===== Bilgi Kutusu =====
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
                    'ℹ️ Bu Ekran Neler Yapıyor?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Görsel seç (galeri/kamera)\n'
                    '2. Firebase Storage\'a yükle\n'
                    '3. Cloud Function çağır\n'
                    '4. Vision API güvenlik kontrol\n'
                    '5. Kota kontrol et\n'
                    '6. Sonuç göster (✅/⚠️)',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NASIL KULLANILIR?
// ============================================================
/*
Ana uygulamada (main.dart):

import 'package:kampus_yardim/screens/image_upload_example.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImageUploadExample(),
    );
  }
}

Aynı yöntemle diğer ekranlar da oluşturulur:
- ProfileScreen (Profil güncelleme)
- ForumScreen (Forum mesajları)
- NotificationScreen (Bildirimler)
- AdminDashboard (Admin paneli)
*/
