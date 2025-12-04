import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

/**
 * COMPLETE INTEGRATION EXAMPLE
 * 
 * Bu kod gösteriyor ki:
 * 1. Flutter (Dart) ← User interaction
 * 2. Cloud Functions (Node.js) ← Backend processing
 * 3. Vision API ← Image analysis
 * 4. Türkçe Message ← User feedback
 * 
 * Hepsi birlikte çalışıyor! ✅
 */

class CompleteIntegrationExample extends StatefulWidget {
  @override
  _CompleteIntegrationExampleState createState() => 
    _CompleteIntegrationExampleState();
}

class _CompleteIntegrationExampleState 
    extends State<CompleteIntegrationExample> {
  
  final _cloudFunctions = FirebaseFunctions.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  dynamic _analysisResult;
  
  // ════════════════════════════════════════════════════════
  // STEP 1: USER INTERACTION (Flutter UI)
  // ════════════════════════════════════════════════════════
  
  Future<void> _pickAndAnalyzeImage() async {
    try {
      // 1.1 Kullanıcı galeri açar
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      
      if (pickedFile == null) return;
      
      setState(() {
        _selectedImage = File(pickedFile.path);
        _statusMessage = '📷 Görsel seçildi, analiz ediliyor...';
        _isLoading = true;
        _isSuccess = false;
      });
      
      // STEP 2: FIREBASE FUNCTION ÇAĞRI
      // ════════════════════════════════════════════════════════
      
      // 2.1 Resmi Firebase Storage'a yükle (temporary)
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref()
        .child('temp_analysis')
        .child('$fileName.jpg');
      
      final uploadTask = ref.putFile(_selectedImage!);
      
      // 2.2 Upload tamamlanmasını bekle
      await uploadTask.whenComplete(() {});
      
      // 2.3 Upload edilen dosyanın URL'sini al
      final imageUrl = await ref.getDownloadURL();
      
      print('[Flutter] Görsel yüklendi: $imageUrl');
      
      // STEP 3: CLOUD FUNCTION ÇAĞRISI
      // ════════════════════════════════════════════════════════
      
      setState(() {
        _statusMessage = '🔍 Görsel Vision API ile analiz ediliyor...';
      });
      
      // Bu fonksiyon Firebase'de çalışan Cloud Function'ı çağırıyor
      // Fonksiyon: functions/index.js → exports.analyzeImageBeforeUpload
      
      final response = await _cloudFunctions
        .httpsCallable('analyzeImageBeforeUpload')
        .call({'imageUrl': imageUrl});
      
      print('[Flutter] Cloud Function cevabı alındı:');
      print(response.data);
      
      // STEP 4: BACKEND PROCESSING (Cloud Function'da)
      // ════════════════════════════════════════════════════════
      // 
      // functions/index.js'de şu yaşanıyor:
      //
      // 1. Cache kontrol (MD5 hash)
      //    if (cached) → return cached result (< 0.5 sec)
      //
      // 2. Kota kontrolü
      //    if (quota_exceeded) → return auto-approved
      //
      // 3. Vision API çağrısı
      //    visionClient.annotateImage(request)
      //    → Safe search detection
      //    → Adult, Racy, Violence, Medical kontrol
      //
      // 4. User-friendly response oluşturma
      //    return createUserFriendlyResponse(
      //      success: boolean,
      //      message: "✅ Görsel güvenli" veya "⚠️ Uygunsuz içerik",
      //      errorCode: "image_unsafe" veya null,
      //      ...
      //    )
      //
      // STEP 5: RESPONSE HANDLING (Flutter)
      // ════════════════════════════════════════════════════════
      
      setState(() {
        _analysisResult = response;
        _isLoading = false;
      });
      
      // 5.1 Response durumunu kontrol et
      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        _handleSuccessfulAnalysis(responseData);
      } else {
        _handleFailedAnalysis(responseData);
      }
      
    } catch (e) {
      // Network veya diğer hatalar
      setState(() {
        _statusMessage = '⚠️ Hata: ${e.toString()}';
        _isSuccess = false;
        _isLoading = false;
      });
      
      print('[ERROR] $e');
    }
  }
  
  // ════════════════════════════════════════════════════════
  // ADIM 5.1: BAŞARILI ANALIZ
  // ════════════════════════════════════════════════════════
  
  void _handleSuccessfulAnalysis(Map<String, dynamic> response) {
    final message = response['message'] ?? '';
    final scores = response['data']?['scores'] ?? {};
    final cached = response['data']?['cached'] ?? false;
    
    // Kullanıcı-dostu mesaj göster
    String displayMessage = '✅ Görsel Güvenli!\n\n$message';
    
    // Cache hit gösterilsin mi?
    if (cached) {
      displayMessage += '\n\n⚡ Önceki analiz kullanıldı (hızlı!)';
    }
    
    setState(() {
      _statusMessage = displayMessage;
      _isSuccess = true;
    });
    
    print('[SUCCESS] Görsel analiz başarılı');
    print('Scores: $scores');
    
    // Kullanıcı resmi yükleyebilir
    _showUploadConfirmationDialog();
  }
  
  // ════════════════════════════════════════════════════════
  // ADIM 5.2: BAŞARISIZ ANALIZ (UNSAFE CONTENT)
  // ════════════════════════════════════════════════════════
  
  void _handleFailedAnalysis(Map<String, dynamic> response) {
    final message = response['message'] ?? 'Uygunsuz içerik tespit edildi';
    final errorCode = response['errorCode'] ?? 'unknown';
    final reasons = response['data']?['blockedReasons'] ?? [];
    
    // Error code'a göre özel mesaj
    String displayMessage = '';
    
    switch (errorCode) {
      case 'image_unsafe':
        displayMessage = '⚠️ Görsel uygunsuz içerik içeriyor:\n\n';
        for (var reason in reasons) {
          displayMessage += '🔴 $reason\n';
        }
        displayMessage += '\nLütfen başka bir görsel seçin.';
        break;
        
      case 'quota_exceeded':
        displayMessage = '🔴 Görsel kontrol kotası doldu!\n\n'
          'Sonraki ay yeniden deneyin.\n\n'
          '(Sistem otomatik onay verdi)';
        break;
        
      case 'network_error':
        displayMessage = '🔌 Bağlantı hatası!\n\n'
          'İnterneti kontrol edin ve tekrar deneyin.';
        break;
        
      default:
        displayMessage = message;
    }
    
    setState(() {
      _statusMessage = displayMessage;
      _isSuccess = false;
    });
    
    print('[UNSAFE] $errorCode - $message');
    print('Reasons: $reasons');
    
    // Kullanıcı başka görsel seçmeli
    _showRetryDialog();
  }
  
  // ════════════════════════════════════════════════════════
  // UI DIALOGS
  // ════════════════════════════════════════════════════════
  
  void _showUploadConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('✅ Görsel Güvenli'),
          content: Text(
            'Bu görsel paylaşım için uygun.\n\n'
            'Şimdi yüklemek ister misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _uploadApprovedImage();
              },
              child: Text('Yükle'),
            ),
          ],
        );
      },
    );
  }
  
  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('⚠️ Görsel Reddedildi'),
          content: Text(_statusMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Kapat'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndAnalyzeImage();
              },
              child: Text('Başka Görsel Seç'),
            ),
          ],
        );
      },
    );
  }
  
  // ════════════════════════════════════════════════════════
  // ONAYLANAN GÖRSELİ YÜKLE
  // ════════════════════════════════════════════════════════
  
  Future<void> _uploadApprovedImage() async {
    if (_selectedImage == null) return;
    
    try {
      setState(() {
        _statusMessage = '📤 Görsel yükleniyor...';
        _isLoading = true;
      });
      
      // Görseli kendi klasörüne yükle
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref()
        .child('gonderiler')
        .child(fileName + '.jpg');
      
      await ref.putFile(_selectedImage!);
      
      setState(() {
        _statusMessage = '✅ Görsel başarıyla yüklendi!';
        _isSuccess = true;
        _isLoading = false;
        _selectedImage = null;
      });
      
      print('[SUCCESS] Görsel yükleme tamamlandı');
      
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Yükleme hatası: $e';
        _isSuccess = false;
        _isLoading = false;
      });
      
      print('[ERROR] Upload failed: $e');
    }
  }
  
  // ════════════════════════════════════════════════════════
  // UI RENDER
  // ════════════════════════════════════════════════════════
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📸 Görsel Yükleme'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Seçilen görsel preview
              if (_selectedImage != null) ...[
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.file(_selectedImage!),
                ),
                SizedBox(height: 16),
              ],
              
              // Status mesajı
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green[50] : Colors.orange[50],
                  border: Border.all(
                    color: _isSuccess ? Colors.green : Colors.orange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage.isEmpty 
                    ? '📷 Başlamak için bir görsel seçin'
                    : _statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isSuccess ? Colors.green[900] : Colors.orange[900],
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickAndAnalyzeImage,
                      icon: Icon(Icons.image),
                      label: Text('Galeri'),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Analysis sonuçları
              if (_analysisResult != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analiz Sonuçları:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _analysisResult.toString(),
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// INTEGRATION SUMMARY
// ════════════════════════════════════════════════════════
//
// Bu örnek gösteriyor:
//
// 1. FLUTTER (Dart) - User Interface
//    - Görsel seçme (ImagePicker)
//    - Loading states
//    - User messages (Türkçe)
//    - Dialog boxes
//
// 2. FIREBASE STORAGE
//    - Görselleri upload etme
//    - Download URL alma
//
// 3. CLOUD FUNCTIONS (Node.js)
//    - analyzeImageBeforeUpload() çağrısı
//    - Vision API ile analiz
//    - Cache sistemi
//    - Kota kontrolü
//    - User-friendly response döndürme
//
// 4. GOOGLE VISION API
//    - Safe search detection
//    - Adult/Racy/Violence kontrol
//
// 5. USER EXPERIENCE
//    - Clear Türkçe mesajlar
//    - Success/Error states
//    - Retry options
//    - Fast cache hits
//
// ════════════════════════════════════════════════════════
// RESULT: ✅ COMPLETE INTEGRATION WORKING!
// ════════════════════════════════════════════════════════
