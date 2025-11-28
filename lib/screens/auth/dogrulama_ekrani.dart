import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DogrulamaEkrani extends StatefulWidget {
  const DogrulamaEkrani({super.key}); 
  
  @override
  _DogrulamaEkraniState createState() => _DogrulamaEkraniState();
}

class _DogrulamaEkraniState extends State<DogrulamaEkrani> {
  // FORM KONTROLÜ İÇİN GEREKLİ ALANLAR
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _uniController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  
  bool _isSending = false;
  
  // Firestore'dan kullanıcının güncel durumunu çeken akış
  late Stream<DocumentSnapshot> _userStatusStream;
  
  @override
  void initState() {
    super.initState();
    // Kullanıcı UID'si ile Firestore'dan durumunu dinliyoruz.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _userStatusStream = FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots();
    }
  }

  // FONKSİYON: FORM BİLGİLERİNİ GÖNDERME
  void _submitVerificationForm(String userId) async {
    // Basit doğrulama: Tüm alanlar dolu mu?
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty || _ageController.text.isEmpty || _uniController.text.isEmpty || _deptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun.")),
      );
      return;
    }

    setState(() { _isSending = true; });

    try {
      // FIRESTORE GÜNCELLEMESİ: Verileri kaydet ve durumu 'Pending' yap.
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(userId)
          .update({
            'status': 'Pending', // Onay bekleniyor
            'submissionData': { // Kullanıcının gönderdiği tüm form verileri
              'name': _nameController.text,
              'surname': _surnameController.text,
              'age': int.tryParse(_ageController.text) ?? 0,
              'university': _uniController.text,
              'department': _deptController.text,
            },
            'rejectionReason': null, // Eskiden reddedildiyse sebebi silinir
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Başvuru başarıyla gönderildi! Onay bekleniyor...")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Başvuru gönderme hatası: $e")),
      );
    } finally {
      if(mounted) setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Öğrenci Doğrulama Formu"),
        backgroundColor: Colors.red[700],
        automaticallyImplyLeading: false, 
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStatusStream, // Durumu dinliyoruz
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // HATA ÇÖZÜMÜ: Kullanıcı verisi yüklenemediğinde çıkış butonu göster
          if (!snapshot.hasData || snapshot.hasError || snapshot.data!.data() == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Hata: Kullanıcı verisi yüklenemedi. Lütfen tekrar deneyin.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: const Text("Çıkış Yap", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final status = userData['status'] ?? 'Unverified'; // Yeni durum alanı

          // --- DURUM KONTROLÜ VE EKRAN YÖNLENDİRMESİ ---

          if (status == 'Verified') {
            // Kullanıcı onaylandıysa ve yanlışlıkla bu sayfadaysa
            return const Center(child: Text("Başvurunuz Onaylandı. Lütfen uygulamayı yeniden başlatın."));
          } else if (status == 'Pending') {
            // BAŞVURU GÖNDERİLMİŞ, BEKLEMEDE EKRANI
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text("Başvurunuz Yönetici Onayı Bekliyor.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("Lütfen sabırla bekleyiniz. Onaylandığınızda foruma otomatik yönlendirileceksiniz.", textAlign: TextAlign.center),
                    const SizedBox(height: 40),
                    TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
                  ],
                ),
              ),
            );
          } else if (status == 'Rejected') {
            // BAŞVURU REDDEDİLMİŞ, SEBEBİ GÖSTERME
            final rejectionReason = userData['rejectionReason'] ?? 'Sebep belirtilmedi.';
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel, size: 80, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text("Başvurunuz Reddedildi.", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 15),
                    const Text("Yönetici Notu:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(rejectionReason, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () { 
                        // Reddedildikten sonra tekrar formu açmak için status'ü sıfırla
                        FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({'status': 'Unverified'});
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), 
                      child: const Text("Formu Tekrar Doldur", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
                  ],
                ),
              ),
            );
          }

          // BAŞLANGIÇ FORMU (Henüz Gönderilmedi VEYA Reddedildi)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Öğrenci Bilgilerini Giriniz", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 20),
                
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "İsim", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _surnameController, decoration: const InputDecoration(labelText: "Soyisim", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Yaş", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _uniController, decoration: const InputDecoration(labelText: "Okuduğu Üniversite", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _deptController, decoration: const InputDecoration(labelText: "Okuduğu Bölüm", border: OutlineInputBorder())),
                const SizedBox(height: 30),

                _isSending
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => _submitVerificationForm(userId!),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: const Text("Başvuruyu Gönder", style: TextStyle(color: Colors.white, fontSize: 18)),
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
}