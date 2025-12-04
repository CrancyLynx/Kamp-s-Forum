import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/giris_ekrani.dart';

/// Guest/Anonymous kullanıcılarının protected features'a erişimini kontrol eden utility
class GuestSecurityHelper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Kullanıcının authenticated olup olmadığını kontrol et
  static bool isAuthenticated() {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Kullanıcının guest olup olmadığını kontrol et
  static bool isGuest() {
    final user = _auth.currentUser;
    return user == null || user.isAnonymous;
  }

  /// Guest kontrolü - eğer guest ise giriş dialogu göster
  static Future<bool> requireLogin(BuildContext context, {
    String title = "Giriş Gerekli",
    String message = "Bu özelliği kullanmak için giriş yapmalısınız.",
  }) async {
    if (isAuthenticated()) {
      return true; // Authenticated kullanıcı
    }

    // Guest kullanıcı - dialog göster
    final shouldLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Devam Et (Misafir)"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Giriş Yap"),
          ),
        ],
      ),
    ) ?? false;

    if (shouldLogin && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const GirisEkrani()),
      );
    }

    return false;
  }

  /// Guest-unfriendly işlemler için snackbar göster
  static void showGuestMessage(BuildContext context, {
    String message = "Bu özellik giriş yapan kullanıcılar için dir.",
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: "Giriş Yap",
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GirisEkrani()),
            );
          },
        ),
      ),
    );
  }

  /// Guest işlemlerini engelle (navigation yerine error göster)
  static Future<void> showGuestBlockedDialog(BuildContext context, {
    String title = "Misafir Erişimi Engellendi",
    String message = "Bu işlemi yapabilmek için giriş yapmalısınız.",
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GirisEkrani()),
              );
            },
            child: const Text("Giriş Yap"),
          ),
        ],
      ),
    );
  }

  /// Eğer guest ise işlemi blok et (silent return)
  static bool blockIfGuest(BuildContext context) {
    if (isGuest()) {
      showGuestMessage(context);
      return true; // Bloked
    }
    return false; // Not blocked - proceed
  }
}
