import 'dart:async'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Arka plan mesaj işleyicisi (Main.dart içinde tanımlı olmalı)
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

  // --- DÜZELTİLMİŞ INITIALIZE FONKSİYONU ---
  Future<void> initialize() async {
    await _requestPermission();
    _handleForegroundMessages();

    // 1. Başlangıçta token'ı alıyoruz
    String? token = await _firebaseMessaging.getToken();
    
    if (token != null && kDebugMode) {
      print("Cihaz FCM Token: $token");
    }

    // 2. Kullanıcı oturum durumunu dinliyoruz
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // HATA BURADAYDI: token değişkeni aşağıda güncellendiği için Dart null olabilir sanıyordu.
      // ÇÖZÜM: 'token!' kullanarak null olmadığını garanti ettik.
      if (user != null && token != null) {
        _saveTokenToFirestore(user.uid, token!); 
      }
    });

    // 3. Token yenilenirse (Uygulama silinip yüklenirse vs.)
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      token = newToken; // Local değişkeni güncelliyoruz
      if (kDebugMode) print("FCM Token Yenilendi: $newToken");
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _saveTokenToFirestore(currentUser.uid, newToken);
      }
    });
  }
  
  // Firestore'a kaydetme fonksiyonu
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).set(
        {'fcmTokens': FieldValue.arrayUnion([token])}, 
        SetOptions(merge: true),
      );
      if (kDebugMode) print("Token başarıyla kullanıcıya eklendi: $userId");
    } catch (e) {
      if (kDebugMode) print("Token kaydetme hatası: $e");
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

    final currentToken = await _firebaseMessaging.getToken();
    if (currentToken != null) {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(currentUser.uid).update(
        {'fcmTokens': FieldValue.arrayRemove([currentToken])},
      );
    }
  }
  
  void dispose() {
    _messageStreamController.close();
  }
}