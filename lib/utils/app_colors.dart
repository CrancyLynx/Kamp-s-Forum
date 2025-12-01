import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan renkleri merkezi olarak yöneten sınıf.
class AppColors {
  // Ana Renkler
  static const Color primary = Color(0xFF673AB7); // Colors.deepPurple
  static const Color primaryLight = Color(0xFFD1C4E9); // Colors.deepPurple.shade100
  static const Color primaryLighter = Color(0xFFEDE7F6); // Colors.deepPurple.shade50
  static const Color primaryDark = Color(0xFF512DA8); // Colors.deepPurple.shade700
  static const Color primaryDarker = Color(0xFF311B92); // Colors.deepPurple.shade900
  static const Color primaryAccent = Color(0xFFFFD740); // Colors.amberAccent

  // Nötr Renkler
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color black87 = Colors.black87;
  static const Color transparent = Colors.transparent;

  // Gri Tonları
  static const Color greyLight = Color(0xFFF5F5F5); // Colors.grey.shade100
  static const Color greyMedium = Color(0xFFE0E0E0); // Colors.grey.shade300
  static const Color greyText = Color(0xFF757575); // Colors.grey.shade600
  static const Color greyDark = Color(0xFF616161); // Colors.grey.shade700
  static const Color greyDarker = Color(0xFF424242); // Colors.grey.shade800
  static const Color greyDarkest = Color(0xFF303030); // Colors.grey.shade850

  // Durum ve Bildirim Renkleri
  static const Color success = Color(0xFF43A047); // Colors.green.shade600
  static const Color error = Color(0xFFE53935); // Colors.red.shade600
  static const Color warning = Color(0xFFF57C00); // Colors.orange.shade700
  static const Color info = Colors.blue;

  // Rozet Renkleri
  static const Color badgeAdmin = Color(0xFF1976D2); // Colors.blue.shade700
  static const Color badgeVerified = Color(0xFF43A047); // Colors.green.shade600
  static const Color badgePopularAuthor = Color(0xFF8E24AA); // Colors.purple.shade600
  static const Color badgeAuthor = Color(0xFFF57C00); // Colors.orange.shade700
  static const Color badgePhenomenon = Color(0xFFEC407A); // Colors.pink.shade500
  static const Color badgeVeteran = Color(0xFF6D4C41); // Colors.brown.shade600
  static const Color badgeNewUser = Color(0xFF26A69A); // Colors.teal.shade400

  // Diğer Renkler
  static const Color blueGrey = Colors.blueGrey;
  static const Color like = Color(0xFFF44336); // Colors.red
  static const Color chatBubbleMe = Color(0xFF673AB7); // Colors.deepPurple
  static const Color chatBubbleOther = Color(0xFFE0E0E0);

  // DÜZELTME: null yerine sabit bir koyu renk atandı.
  static const Color textDark = Color(0xFF212121); 
}