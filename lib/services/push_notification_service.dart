import 'dart:async'; 
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';// Arka plan mesaj işleyicisi
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
    try {
      await _requestPermission();
      _setupLocalNotifications();
      _handleForegroundMessages();

      // 1. Başlangıçta token'ı alıyoruz
      String? token;
      try {
        token = await _firebaseMessaging.getToken(vapidKey: null);
      } catch (e) {
        if (kDebugMode) {
          print("⚠️  FCM Token alınamadı (Google Play Services olmayabilir): $e");
        }
        // Token alınamazsa devam et, sadece bildir
        return;
      }
      
      if (token != null && kDebugMode) {
        print("✅ Cihaz FCM Token: $token");
      }

      // 2. Kullanıcı oturum durumunu dinliyoruz
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null && token != null) {
          await _safeSaveToken(user.uid, token!);
        }
      });

      // 3. Token yenilenirse
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        token = newToken;
        if (kDebugMode) print("✅ FCM Token Yenilendi: $newToken");
        
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _safeSaveToken(currentUser.uid, newToken);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("❌ Push notification servisi başlatma hatası: $e");
      }
    }
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
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true, 
        badge: true, 
        sound: true,
      );
      if (kDebugMode) {
        print('✅ Bildirim izni durumu: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Bildirim izni istenirken hata: $e');
      }
    }
  }

  void _setupLocalNotifications() {
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print("[TAP] Notification tapped: ${response.payload}");
        }
        // Handle payload here if needed
      },
      onDidReceiveBackgroundNotificationResponse: _notificationTapHandler,
    );
  }

  // Notification tap handler (static for background handling)
  @pragma('vm:entry-point')
  static void _notificationTapHandler(NotificationResponse response) {
    if (kDebugMode) {
      print("[BACKGROUND_TAP] Notification tapped in background: ${response.payload}");
    }
  }

  void _handleForegroundMessages() {
    _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("[FOREGROUND] Bildirim alındı: ${message.messageId}");
        print("[FOREGROUND] Type: ${message.data['type']}");
      }

      // Stream'e ekle (UI dinleyici için)
      _messageStreamController.add(message);

      final notification = message.notification;
      final android = message.notification?.android;

      // Android: Local notification göster
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title ?? "Kampüs Forum",
          notification.body ?? "Yeni bildiriminiz var",
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Kampüs Bildirimleri',
              importance: Importance.max,
              priority: Priority.high,
              icon: android.smallIcon,
              sound: const RawResourceAndroidNotificationSound('notification'),
              enableVibration: true,
              playSound: true,
            ),
            iOS: const DarwinNotificationDetails(
              sound: 'notification.aiff',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
        );

        if (kDebugMode) {
          print("[SUCCESS] Local notification gösterildi: ${notification.title}");
        }
      } else {
        if (kDebugMode) {
          print("[WARN] Notification veya Android detayı null: ${message.toMap()}");
        }
      }
    });

    // Handle notification taps (app in foreground)
    _localNotifications.getNotificationAppLaunchDetails().then((details) {
      if (details?.notificationResponse != null && kDebugMode) {
        print("[TAP] Notification tap detected: ${details?.notificationResponse?.payload}");
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