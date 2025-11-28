import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Uygulama başlatıldığında çağrılır
  void configure() {
    WidgetsBinding.instance.addObserver(this);
    setUserOnline(true);
  }

  // Uygulama durumunu dinler (Arka plana atıldı mı, açıldı mı?)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setUserOnline(true); // Uygulama açıldı -> Çevrimiçi
    } else {
      setUserOnline(false); // Uygulama alta atıldı/kapandı -> Çevrimdışı
    }
  }

  Future<void> setUserOnline(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('kullanicilar').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Presence update error: $e");
    }
  }
}