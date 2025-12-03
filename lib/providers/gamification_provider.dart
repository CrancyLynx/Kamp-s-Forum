import 'package:flutter/material.dart';
import '../models/gamification_model.dart';
import '../services/gamification_service.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationService _service = GamificationService();
  
  UserGamificationStatus? _status;
  UserGamificationStatus? get status => _status;
  
  Level? _currentLevelData;
  Level? get currentLevelData => _currentLevelData;

  // Stream aboneliği
  void startListening(String userId) {
    _service.getUserGamificationStatusStream(userId).listen((newStatus) {
      if (newStatus != null) {
        _status = newStatus;
        _currentLevelData = _service.getLevelData(newStatus.currentLevel);
        notifyListeners();
      }
    });
  }

  // XP Ekleme (UI'dan tetiklemek için)
  Future<void> earnXP(String userId, String type, int amount, String relatedId) async {
    await _service.addXP(userId, type, amount, relatedId);
  }
}