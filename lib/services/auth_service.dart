import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Hata mesajlarını Türkçeleştirme yardımcısı
  String _handleError(Object e) {
    String msg = e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Kullanıcı bulunamadı.';
        case 'wrong-password': return 'Hatalı şifre.';
        case 'email-already-in-use': return 'Bu e-posta zaten kullanımda.';
        case 'invalid-email': return 'Geçersiz e-posta formatı.';
        case 'too-many-requests': return 'Çok fazla deneme yaptınız. Lütfen bekleyin.';
        case 'network-request-failed': return 'İnternet bağlantınızı kontrol edin.';
        case 'requires-recent-login': return 'Bu işlem için tekrar giriş yapmalısınız.';
        default: return 'Bir hata oluştu: ${e.message}';
      }
    }
    return msg;
  }

  // --- 1. NORMAL GİRİŞ (MFA KONTROLLÜ) ---
  // Dönüş Değeri: 
  // - "success": Giriş başarılı, direkt içeri al.
  // - "mfa_required": Şifre doğru ama SMS doğrulaması lazım.
  // - Hata Mesajı: Giriş başarısız.
  Future<String> signInWithEmail(String email, String password, bool rememberMe) async {
    try {
      // 1. Şifre Kontrolü
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // 2. Beni Hatırla
      if (rememberMe) {
        await _storage.write(key: 'saved_email', value: email);
      } else {
        await _storage.delete(key: 'saved_email');
      }

      // 3. MFA (2 Aşamalı Doğrulama) Kontrolü
      // Kullanıcının ayarlarında 2FA açık mı diye bakıyoruz.
      final userDoc = await _firestore.collection('kullanicilar').doc(cred.user!.uid).get();
      final isTwoFactorEnabled = userDoc.data()?['isTwoFactorEnabled'] ?? false;

      if (isTwoFactorEnabled) {
        // Oturumu geçici olarak açık tutuyoruz ama UI tarafında SMS ekranına yönlendireceğiz.
        return "mfa_required";
      }

      return "success";
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 2. KAYIT OLMA ---
  Future<String?> register({
    required String email,
    required String password,
    required String adSoyad,
    required String takmaAd,
    required String phone,
  }) async {
    try {
      // Üniversite mail kontrolü
      final lowerEmail = email.toLowerCase();
      if (!(lowerEmail.endsWith('.edu.tr') || lowerEmail.endsWith('.edu'))) {
        return "Sadece üniversite e-postası (.edu veya .edu.tr) ile kayıt olabilirsiniz.";
      }

      // Şifre Politikası Kontrolü
      if (password.length < 8) return "Şifre en az 8 karakter olmalıdır.";
      if (!password.contains(RegExp(r'[A-Z]'))) return "Şifre en az bir büyük harf içermelidir.";
      if (!password.contains(RegExp(r'[a-z]'))) return "Şifre en az bir küçük harf içermelidir.";
      if (!password.contains(RegExp(r'[0-9]'))) return "Şifre en az bir rakam içermelidir.";
      // İsteğe bağlı: if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return "Şifre en az bir özel karakter içermelidir.";

      // Takma ad kontrolü
      final checkNick = await _firestore
          .collection('kullanicilar')
          .where('takmaAd', isEqualTo: takmaAd)
          .limit(1)
          .get();
      
      if (checkNick.docs.isNotEmpty) return "Bu takma ad zaten alınmış.";

      // Kullanıcı oluşturma
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;

      if (user != null) {
        final adSoyadParts = adSoyad.split(' ');
        final sadeceAd = adSoyadParts.isNotEmpty ? adSoyadParts.first : '';

        // Varsayılan ayarlarla kayıt (2FA kapalı başlar)
        await _firestore.collection('kullanicilar').doc(user.uid).set({
          'email': email,
          'phoneNumber': phone,
          'takmaAd': takmaAd,
          'ad': sadeceAd,
          'fullName': adSoyad,
          'kayit_tarihi': FieldValue.serverTimestamp(),
          'verified': false,
          'status': 'Unverified',
          'role': 'user',
          'isTwoFactorEnabled': false, // MFA varsayılan kapalı
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'earnedBadges': [],
          'followers': [],
          'following': [],
          'savedPosts': []
        });
      }
      return null; // Başarılı
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 3. MİSAFİR GİRİŞİ ---
  Future<String?> signInGuest() async {
    try {
      await _auth.signInAnonymously();
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 4. ŞİFRE SIFIRLAMA ---
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 5. KRİTİK İŞLEM İÇİN YENİDEN KİMLİK DOĞRULAMA (Re-Auth) ---
  // Öneri 2: Şifre değişimi gibi işlemlerde bunu çağıracaksın.
  Future<bool> reauthenticateUser(String password) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    try {
      AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true; // Doğrulandı
    } catch (e) {
      return false; // Şifre yanlış
    }
  }

  // --- 6. TELEFON DOĞRULAMA (SMS GÖNDERME) ---
  // MFA için veya telefonla giriş için kullanılır.
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android'de otomatik doğrulama olursa burası çalışır
        await _auth.currentUser?.linkWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(_handleError(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<String?> getSavedEmail() async {
    return await _storage.read(key: 'saved_email');
  }
}