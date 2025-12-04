import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';

class RingSeferleriSheet extends StatefulWidget {
  final String universityName; // Kullanıcının üniversitesi buraya gelecek

  const RingSeferleriSheet({super.key, required this.universityName});

  @override
  State<RingSeferleriSheet> createState() => _RingSeferleriSheetState();
}

class _RingSeferleriSheetState extends State<RingSeferleriSheet> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // Fotoğraf Yükleme Fonksiyonu
  Future<void> _uploadScheduleImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Storage'a Yükle
      final File file = File(pickedFile.path);
      // Dosya ismini üniversite adına göre yapıyoruz ki hep üzerine yazsın (tek güncel tarife olsun)
      // veya tarih ekleyerek arşivleyebilirsiniz. Şimdilik 'current' mantığıyla gidiyoruz.
      final String path = 'ulasim_tarifeleri/${widget.universityName}_tarife.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);
      
      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();

      // 2. Firestore'a Kaydet (Kimin ne zaman güncellediği bilgisiyle)
      await FirebaseFirestore.instance.collection('ulasim_bilgileri').doc(widget.universityName).set({
        'university': widget.universityName,
        'imageUrl': downloadUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updaterName': user.displayName ?? 'Bir Öğrenci',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarife güncellendi! Teşekkürler."), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata oluştu: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Daha yüksek bir panel
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tutamaç
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Başlık Alanı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${widget.universityName} Ulaşım", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text("Ring / Servis Tarifesi", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Görüntüleme Alanı
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('ulasim_bilgileri').doc(widget.universityName).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Veri Yoksa (Henüz kimse yüklememişse)
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildEmptyState();
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final String imageUrl = data['imageUrl'];
                final String updaterName = data['updaterName'] ?? 'Anonim';
                final Timestamp? timestamp = data['lastUpdated'];
                
                String timeAgo = '';
                if (timestamp != null) {
                  timeAgo = DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
                }

                return Column(
                  children: [
                    // Bilgi Çubuğu
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: Colors.amber.withOpacity(0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Son güncelleme: $updaterName ($timeAgo)",
                              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Resim (Zoomlanabilir)
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain, // Resmi sığdır
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Alt Buton (Yükle/Güncelle)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadScheduleImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.add_a_photo),
              label: Text(_isUploading ? "Yükleniyor..." : "Güncel Tarifeyi Yükle"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Uzgun_bay mascot with asset fallback
            Image.asset(
              'assets/images/uzgun_bay.png',
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey[300]);
              },
            ),
            const SizedBox(height: 16),
            Text(
              "Henüz tarife eklenmemiş 😢",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${widget.universityName} için güncel ring/servis saatlerinin fotoğrafını ilk sen yükle, kahraman ol! 🦸‍♂️",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}