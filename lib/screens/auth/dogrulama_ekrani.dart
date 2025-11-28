import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';

class DogrulamaEkrani extends StatefulWidget {
  const DogrulamaEkrani({super.key}); 
  
  @override
  _DogrulamaEkraniState createState() => _DogrulamaEkraniState();
}

class _DogrulamaEkraniState extends State<DogrulamaEkrani> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _uniController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  
  bool _isSending = false;
  late Stream<DocumentSnapshot> _userStatusStream;
  
  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _userStatusStream = FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots();
    }
  }

  void _submitVerificationForm(String userId) async {
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty || _ageController.text.isEmpty || _uniController.text.isEmpty || _deptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun.")));
      return;
    }

    setState(() { _isSending = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      
      String newStatus = 'Pending';
      bool isVerified = false;
      
      // HİBRİT KONTROL
      // Sadece E-posta doğruluysa VE edu.tr ise Otomatik Onay
      if (user != null && user.emailVerified && (email.endsWith('.edu.tr') || email.endsWith('.edu'))) {
        newStatus = 'Verified';
        isVerified = true;
      }
      
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
        'status': newStatus, 
        'verified': isVerified,
        'submissionData': {
          'name': _nameController.text,
          'surname': _surnameController.text,
          'age': int.tryParse(_ageController.text) ?? 0,
          'university': _uniController.text,
          'department': _deptController.text,
        },
        'rejectionReason': null,
      });

      if (newStatus == 'Verified') {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-posta ile doğruladığınız için hesabınız otomatik onaylandı!"), backgroundColor: AppColors.success));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bilgileriniz alındı. SMS ile doğrulama yaptığınız için yönetici onayı bekleniyor.")));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if(mounted) setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Öğrenci Profilini Tamamla"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStatusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.hasError || snapshot.data!.data() == null) {
            return Center(child: ElevatedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text("Çıkış Yap")));
          }
          
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final status = userData['status'] ?? 'Unverified';

          if (status == 'Verified') {
            return const Center(child: Text("Yönlendiriliyor..."));
          } else if (status == 'Pending') {
            return _buildPendingView();
          } else if (status == 'Rejected') {
            return _buildRejectedView(userData['rejectionReason'] ?? 'Sebep belirtilmedi.', userId!);
          }

          // Form
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Son Bir Adım Kaldı!", 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)
                ),
                const SizedBox(height: 10),
                const Text(
                  "İletişim bilgilerini doğruladık. Şimdi profilini oluşturmak için bilgileri gir.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                
                _buildInput(_nameController, "İsim"),
                const SizedBox(height: 15),
                _buildInput(_surnameController, "Soyisim"),
                const SizedBox(height: 15),
                _buildInput(_ageController, "Yaş", isNumber: true),
                const SizedBox(height: 15),
                _buildInput(_uniController, "Okuduğun Üniversite"),
                const SizedBox(height: 15),
                _buildInput(_deptController, "Okuduğun Bölüm"),
                const SizedBox(height: 30),

                _isSending
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => _submitVerificationForm(userId!),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text("Kaydet ve Onaya Gönder", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                const SizedBox(height: 20),
                TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("Onay Bekleniyor", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Bilgileriniz yöneticilere iletildi. SMS ile doğrulama yaptıysanız manuel onay sürecindesiniz.", textAlign: TextAlign.center),
            const SizedBox(height: 40),
            TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView(String reason, String userId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text("Başvuru Reddedildi", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 15),
            Text(reason, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () { 
                FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({'status': 'Unverified'});
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), 
              child: const Text("Bilgileri Düzenle ve Tekrar Gönder", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
          ],
        ),
      ),
    );
  }
}