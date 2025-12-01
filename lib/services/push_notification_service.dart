import 'dart:async'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Arka plan mesaj işleyicisi
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHander(RemoteMessage message) async {
  if (kDebugMode) {
    print("Arka plan mesajı alındı: ${message.messageId}");
  }
}

class PushNotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  
  final _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessage => _messageStreamController.stream; 

  Future<void> initialize() async {
    await _requestPermission();
    _handleForegroundMessages();

    // 1. Başlangıçta token'ı alıyoruz
    String? token = await _firebaseMessaging.getToken();
    
    if (token != null && kDebugMode) {
      print("Cihaz FCM Token: $token");
    }

    // 2. Kullanıcı oturum durumunu dinliyoruz
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && token != null) {
        // KRİTİK DÜZELTME: Hemen yazmaya çalışma. Profilin oluşmasını bekle.
        // Yeni kayıt sırasında AuthService profil oluştururken çakışma olmaması için
        // veritabanında dokümanın varlığını kontrol ediyoruz.
        await _safeSaveToken(user.uid, token!);
      }
    });

    // 3. Token yenilenirse
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      token = newToken;
      if (kDebugMode) print("FCM Token Yenilendi: $newToken");
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _safeSaveToken(currentUser.uid, newToken);
      }
    });
  }
  
  // GÜVENLİ TOKEN KAYDETME
  Future<void> _safeSaveToken(String userId, String token) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('kullanicilar').doc(userId);
      
      // Dokümanın var olup olmadığını kontrol et (Retry mekanizması ile)
      // Yeni kayıtlarda profilin yazılması 1-2 saniye sürebilir.
      bool docExists = false;
      for (int i = 0; i < 5; i++) {
        final doc = await docRef.get();
        if (doc.exists) {
          docExists = true;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      if (docExists) {
        await docRef.update({
          'fcmTokens': FieldValue.arrayUnion([token])
        });
        if (kDebugMode) print("Token başarıyla kullanıcıya eklendi: $userId");
      } else {
        // Doküman hala yoksa, AuthService henüz oluşturmamış olabilir veya misafir kullanıcısıdır.
        // Bu durumda yazma yapmıyoruz ki 'PERMISSION_DENIED' hatası alıp auth akışını bozmayalım.
        if (kDebugMode) print("Kullanıcı profili bulunamadı, token yazılmadı (Güvenli çıkış).");
      }
    } catch (e) {
      if (kDebugMode) print("Token kaydetme hatası (Önemsiz): $e");
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true, 
      badge: true, 
      sound: true,
    );
    if (kDebugMode) {
      print('Bildirim izni durumu: ${settings.authorizationStatus}');
    }
  }

  void _setupLocalNotifications() {
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitializationSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    _localNotifications.initialize(initializationSettings);
  }

  void _handleForegroundMessages() {
    _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _messageStreamController.add(message); 

      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', 
              'Kampüs Bildirimleri', 
              importance: Importance.max,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });
  }

  Future<void> deleteDeviceToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final currentToken = await _firebaseMessaging.getToken();
      if (currentToken != null) {
        await FirebaseFirestore.instance.collection('kullanicilar').doc(currentUser.uid).update(
          {'fcmTokens': FieldValue.arrayRemove([currentToken])},
        );
      }
    } catch (_) {}
  }
  
  void dispose() {
    _messageStreamController.close();
  }
}