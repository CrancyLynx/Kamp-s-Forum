import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // --- YARDIMCI: Hata Mesajlarını Türkçeleştirme ---
  String _handleError(Object e) {
    String msg = e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Kullanıcı bulunamadı.';
        case 'wrong-password': return 'Hatalı şifre.';
        case 'email-already-in-use': return 'Bu e-posta zaten kullanımda.';
        case 'invalid-email': return 'Geçersiz e-posta formatı.';
        case 'too-many-requests': return 'Çok fazla deneme yaptınız. Biraz bekleyin.';
        case 'network-request-failed': return 'İnternet bağlantınızı kontrol edin.';
        default: return 'Bir hata oluştu: ${e.message}';
      }
    }
    return msg;
  }

  // --- 1. E-POSTA GİRİŞİ ---
  Future<String?> signInWithEmail(String email, String password, bool rememberMe) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (rememberMe) {
        await _storage.write(key: 'saved_email', value: email);
      } else {
        await _storage.delete(key: 'saved_email');
      }
      return null; // Başarılı (Hata yok)
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

        // 1. Adımda güncellediğimiz role: 'user' yapısı ile kayıt
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

  // --- 5. KAYITLI E-POSTAYI GETİR ---
  Future<String?> getSavedEmail() async {
    return await _storage.read(key: 'saved_email');
  }

  // --- TELEFON GİRİŞİ İÇİN YARDIMCILAR ---
  // Telefondan maili bulur ve şifre ile geçici giriş yapar
  Future<String?> validatePhonePassword(String phone, String password) async {
    try {
      final query = await _firestore
          .collection('kullanicilar')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return "Bu numara ile kayıtlı kullanıcı bulunamadı.";

      final email = query.docs.first['email'];
      // Şifre kontrolü için giriş denemesi
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Başarılı
    } catch (e) {
      return _handleError(e);
    }
  }
}