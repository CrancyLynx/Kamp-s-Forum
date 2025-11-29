import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Hata Mesajlarını Türkçeleştirme
  String _handleError(Object e) {
    String msg = e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password': return 'Hatalı şifre.';
        case 'email-already-in-use': return 'Bu e-posta zaten kullanımda.';
        case 'invalid-email': return 'Geçersiz e-posta formatı.';
        case 'too-many-requests': return 'Çok fazla deneme yaptınız. Lütfen bekleyin.';
        case 'network-request-failed': return 'İnternet bağlantınızı kontrol edin.';
        case 'requires-recent-login': return 'Güvenlik gereği bu işlem için tekrar giriş yapmalısınız.';
        case 'credential-already-in-use': return 'Bu hesap bilgileri zaten kullanımda.';
        default: return 'Bir hata oluştu: ${e.message}';
      }
    }
    return msg;
  }

  // --- 1. ŞİFRE SIFIRLAMA (GÜÇLENDİRİLMİŞ) ---
  Future<String?> sendPasswordReset(String email) async {
    try {
      if (!email.contains('@')) return "Geçerli bir e-posta adresi girin.";
      
      // Kullanıcı veritabanında var mı kontrol et (Opsiyonel ama iyi bir UX için)
      final userQuery = await _firestore.collection('kullanicilar').where('email', isEqualTo: email).get();
      if (userQuery.docs.isEmpty) return "Bu e-posta adresi sistemimizde kayıtlı değil.";

      await _auth.sendPasswordResetEmail(email: email);
      return null; // Başarılı
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 2. GİRİŞ YAPMA (MFA KONTROLLÜ) ---
  // Dönüş: "success", "mfa_required" veya Hata Mesajı
  Future<String> signInWithEmail(String email, String password, bool rememberMe) async {
    try {
      // A. Şifre ile giriş dene
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // B. Beni Hatırla
      if (rememberMe) {
        await _storage.write(key: 'saved_email', value: email);
      } else {
        await _storage.delete(key: 'saved_email');
      }

      // C. MFA Kontrolü (Veritabanından ayarı çek)
      final userDoc = await _firestore.collection('kullanicilar').doc(cred.user!.uid).get();
      final isTwoFactorEnabled = userDoc.data()?['isTwoFactorEnabled'] ?? false;

      if (isTwoFactorEnabled) {
        // Eğer MFA açıksa, "mfa_required" döndür ki UI telefon kodu istesin
        return "mfa_required";
      }

      return "success";
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 3. KAYIT OLMA ---
  Future<String?> register({
    required String email,
    required String password,
    required String adSoyad,
    required String takmaAd,
    required String phone,
  }) async {
    try {
      final lowerEmail = email.toLowerCase();
      if (!(lowerEmail.endsWith('.edu.tr') || lowerEmail.endsWith('.edu'))) {
        return "Sadece üniversite e-postası (.edu veya .edu.tr) ile kayıt olabilirsiniz.";
      }

      final checkNick = await _firestore.collection('kullanicilar').where('takmaAd', isEqualTo: takmaAd).limit(1).get();
      if (checkNick.docs.isNotEmpty) return "Bu takma ad zaten alınmış.";

      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;

      if (user != null) {
        final adSoyadParts = adSoyad.split(' ');
        final sadeceAd = adSoyadParts.isNotEmpty ? adSoyadParts.first : '';

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
          'isTwoFactorEnabled': false, // Varsayılan kapalı
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'earnedBadges': [],
          'followers': [],
          'following': [],
          'savedPosts': []
        });
      }
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 4. YENİDEN KİMLİK DOĞRULAMA (RE-AUTH) ---
  // Kritik işlemlerden önce (MFA açma/kapama, hesap silme) şifre soracağız.
  Future<bool> reauthenticateUser(String password) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    try {
      AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true; // Şifre doğru
    } catch (e) {
      return false; // Şifre yanlış
    }
  }

  // --- 5. MFA DURUMUNU DEĞİŞTİR (AÇ/KAPA) ---
  Future<String?> toggleMFA(bool enable) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "Kullanıcı bulunamadı";

      // Eğer açılacaksa, önce telefon numarasının doğruluğundan emin olmalıyız (Basit kontrol)
      if (enable) {
        final doc = await _firestore.collection('kullanicilar').doc(user.uid).get();
        final phone = doc.data()?['phoneNumber'];
        if (phone == null || phone.toString().length < 10) {
          return "MFA açmak için geçerli bir telefon numarası kayıtlı olmalıdır.";
        }
      }

      await _firestore.collection('kullanicilar').doc(user.uid).update({
        'isTwoFactorEnabled': enable
      });
      return null; // Başarılı
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 6. TELEFON DOĞRULAMA (SMS) ---
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android otomatik doğrulama
        final user = _auth.currentUser;
        if (user != null) {
           await user.linkWithCredential(credential);
        } else {
           await _auth.signInWithCredential(credential);
        }
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

  // --- 7. DİĞER YARDIMCILAR ---
  Future<String?> signInGuest() async {
    try {
      await _auth.signInAnonymously();
      return null;
    } catch (e) { return _handleError(e); }
  }

  Future<String?> getSavedEmail() async {
    return await _storage.read(key: 'saved_email');
  }
  
  // Telefonla Giriş İçin Şifre Kontrolü
  Future<String?> validatePhonePassword(String phone, String password) async {
    try {
      final query = await _firestore.collection('kullanicilar').where('phoneNumber', isEqualTo: phone).limit(1).get();
      if (query.docs.isEmpty) return "Bu numara kayıtlı değil.";
      final email = query.docs.first['email'];
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; 
    } catch (e) { return _handleError(e); }
  }
}