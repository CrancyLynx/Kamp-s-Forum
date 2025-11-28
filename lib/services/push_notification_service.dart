import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// Arka plan işleyicisi (Bu fonksiyon en üstte olmalı, class içinde değil)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("Arka Plan Bildirimi Geldi: ${message.messageId}");
  }
  // Burada yerel bildirim göstermeye gerek yok, Firebase zaten sistem tepsisine atıyor.
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Stream Controller: Gelen mesajları UI'ya aktarmak için
  // Broadcast stream kullanıyoruz ki birden fazla yer dinleyebilsin
  final _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;

  Future<void> initialize() async {
    // 1. İzin İste (iOS ve Android 13+ için kritik)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Bildirim izni verildi.');
      await _saveTokenToDatabase();
    } else {
      print('Bildirim izni reddedildi.');
    }

    // 2. Ön Plan (Foreground) Dinleyicisi
    // Uygulama açıkken bildirim gelince bu çalışır
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Ön plan bildirimi alındı: ${message.notification?.title}');
      // Stream'e ekle, main.dart bunu yakalayacak
      _messageStreamController.add(message);
    });

    // 3. Arka Plandan Açılış (Background/Terminated -> Open)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Bildirime tıklanarak açıldı: ${message.data}');
      // Burada navigasyon işlemleri yapılabilir (örn: sohbete git)
    });
    
    // Uygulama tamamen kapalıyken açıldıysa
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Uygulama kapalıyken bildirime tıklandı: ${message.data}');
      }
    });
  }

  Future<void> _saveTokenToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Token al
    String? token = await _fcm.getToken();
    if (token == null) return;

    final userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid);
    
    // Token dizisine ekle (ArrayUnion tekrarı önler)
    await userRef.update({
      'fcmTokens': FieldValue.arrayUnion([token])
    }).catchError((e) => print("Token kaydetme hatası: $e"));
  }
}