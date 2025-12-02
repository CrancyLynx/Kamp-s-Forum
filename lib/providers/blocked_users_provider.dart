import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedUsersProvider with ChangeNotifier {
  List<String> _blockedUserIds = [];
  StreamSubscription? _blockedUsersSubscription;

  List<String> get blockedUserIds => _blockedUserIds;

  void startListening(String? userId) {
    // Stop any previous listener
    stopListening();

    if (userId == null || userId.isEmpty) {
      _blockedUserIds = [];
      Future.microtask(() => notifyListeners());
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('kullanicilar').doc(userId);
    _blockedUsersSubscription = docRef.snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        _blockedUserIds = List<String>.from(data['blockedUsers'] ?? []);
      } else {
        _blockedUserIds = [];
      }
      Future.microtask(() => notifyListeners());
    }, onError: (error) {
      _blockedUserIds = [];
      Future.microtask(() => notifyListeners());
      print("BlockedUsersProvider error: $error");
    });
  }

  void stopListening() {
    _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription = null;
  }

  bool isUserBlocked(String? userId) {
    if (userId == null) return false;
    return _blockedUserIds.contains(userId);
  }
}
