import 'dart:async'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Uygulama tamamen kapatıldığında veya arka planda çalışırken gelen mesajları yönetir.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHander(RemoteMessage message) async {
  if (kDebugMode) {
    print("Arka plan mesajı alındı: ${message.messageId}");
  }
  // Bu fonksiyon, main.dart'ta FirebaseMessaging.onBackgroundMessage'e atanır.
}

class PushNotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  
  // onMessage stream'ini oluşturur.
  final _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessage => _messageStreamController.stream; 

  // Bildirim servisini başlatır
  Future<void> initialize() async {
    await _requestPermission();
    await _saveDeviceToken();
    _handleForegroundMessages();
  }
  
  // --- FCM Token'ı alır ve Firestore'a kaydeder (EKSİKSİZ GÖVDE) ---
  Future<void> _saveDeviceToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Kullanıcı henüz giriş yapmadıysa işlemi durdur.
    if (currentUser == null) return; 

    String? token = await _firebaseMessaging.getToken();

    if (token != null) {
      if (kDebugMode) {
        print("FCM Token: $token");
      }
      // Cloud Function'ın beklediği DİZİ (fcmTokens) yapısına ekle
      await FirebaseFirestore.instance.collection('kullanicilar').doc(currentUser.uid).set(
        {'fcmTokens': FieldValue.arrayUnion([token])}, 
        SetOptions(merge: true),
      );
    }
    // Token yenileme işlemini dinler
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print("FCM Token Yenilendi: $newToken");
      }
      FirebaseFirestore.instance.collection('kullanicilar').doc(currentUser.uid).set(
        {'fcmTokens': FieldValue.arrayUnion([newToken])}, 
        SetOptions(merge: true),
      );
    });
  }

  // --- İzinleri İster (EKSİKSİZ GÖVDE) ---
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true, 
      announcement: false, 
      badge: true, 
      carPlay: false, 
      criticalAlert: false, 
      provisional: false, 
      sound: true,
    );
    if (kDebugMode) {
      print('Kullanıcıya izin verildi: ${settings.authorizationStatus}');
    }
  }

  // --- Flutter Local Notifications için kurulum ---
  void _setupLocalNotifications() {
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitializationSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Bildirime tıklandığında yapılacaklar
      },
    );
  }

  // --- Ön plan mesajlarını yönetir ---
  void _handleForegroundMessages() {
    _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Stream'e olayı ekle (main.dart'taki listener'ı besler)
      _messageStreamController.add(message); 

      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        // Gelen bildirimi yerel bildirim olarak gösterir
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', 
              'Yüksek Önemli Bildirimler', 
              importance: Importance.max,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Uygulama açıldı: ${message.messageId}');
      }
    });
  }

  // Kullanıcı çıkış yaptığında token'ı siler
  Future<void> deleteDeviceToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentToken = await _firebaseMessaging.getToken();
    if (currentToken != null) {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(currentUser.uid).update(
        {'fcmTokens': FieldValue.arrayRemove([currentToken])},
      );
    }
    
    await _firebaseMessaging.deleteToken();
  }
  
  // Stream Controller'ı kapatmayı unutmayın (gereklilik)
  void dispose() {
    _messageStreamController.close();
  }
}