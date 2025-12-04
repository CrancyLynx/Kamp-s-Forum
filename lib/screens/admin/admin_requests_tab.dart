import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../utils/app_colors.dart';
import 'admin_helpers.dart';

class AdminRequestsTab extends StatefulWidget {
  const AdminRequestsTab({super.key});

  @override
  State<AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<AdminRequestsTab> {
  Future<void> _deleteContent(String collection, String docId, String successMsg) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      if (mounted) {
        showSnackBar(context: context, message: "✅ $successMsg", color: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Silme hatası: $e", color: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('degisiklik_istekleri').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return EmptyState(
            message: "İncelenmesi gereken talep yok",
            icon: Icons.mark_email_read,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Color(0xFF00BCD4), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          data['userName'] ?? 'Kullanıcı',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        if (data['timestamp'] != null)
                          Text(
                            timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'tr'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Bilgi Karşılaştırması
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ESKİ BİLGİ",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['oldUniversity'] ?? '-',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                data['oldDepartment'] ?? '-',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "YENİ BİLGİ",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['newUniversity'] ?? '-',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.end,
                              ),
                              Text(
                                data['newDepartment'] ?? '-',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Butonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _deleteContent('degisiklik_istekleri', doc.id, 'Talep reddedildi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text("❌ Reddet"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await FirebaseFirestore.instance.collection('kullanicilar').doc(data['userId']).update({
                                'submissionData.university': data['newUniversity'],
                                'submissionData.department': data['newDepartment'],
                                'universite': data['newUniversity'],
                                'bolum': data['newDepartment'],
                              });
                              await doc.reference.delete();
                              if (mounted) {
                                showSnackBar(
                                  context: context,
                                  message: "✅ Bilgiler güncellendi",
                                  color: AppColors.success,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                showSnackBar(
                                  context: context,
                                  message: "❌ Hata: $e",
                                  color: AppColors.error,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("✅ Onayla"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
