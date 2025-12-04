import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../market/urun_detay_ekrani.dart';
import '../../utils/app_colors.dart';
import 'admin_helpers.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteContent(String collection, String docId) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      if (mounted) {
        showSnackBar(context: context, message: "✅ İçerik silindi", color: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Hata: $e", color: AppColors.error);
      }
    }
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('gonderiler')
          .doc(postId)
          .collection('yorumlar')
          .doc(commentId)
          .delete();
      await FirebaseFirestore.instance
          .collection('gonderiler')
          .doc(postId)
          .update({'commentCount': FieldValue.increment(-1)});
      if (mounted) {
        showSnackBar(context: context, message: "✅ Yorum silindi", color: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Hata: $e", color: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ModernSearchBar(
            controller: _searchController,
            hint: "Şikayet başlığı veya neden ara...",
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sikayetler')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: AppColors.error)),
                );
              }

              final allDocs = snapshot.data!.docs;
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['targetTitle'] ?? data['postTitle'] ?? '').toString().toLowerCase();
                final reason = (data['reason'] ?? '').toString().toLowerCase();
                final query = _searchController.text.toLowerCase();
                return title.contains(query) || reason.contains(query);
              }).toList();

              if (docs.isEmpty) {
                return EmptyState(
                  message: "Şikayet bulunamadı",
                  icon: Icons.security,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String type = data['targetType'] ?? 'post';

                  String typeLabel = 'Gönderi';
                  IconData typeIcon = Icons.article;
                  Color typeColor = Colors.blue;

                  if (type == 'comment') {
                    typeLabel = 'Yorum';
                    typeIcon = Icons.comment;
                    typeColor = Colors.orange;
                  }
                  if (type == 'product') {
                    typeLabel = 'Ürün';
                    typeIcon = Icons.shopping_bag;
                    typeColor = Colors.green;
                  }

                  return Card(
                    color: AppColors.error.withOpacity(0.05),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: typeColor.withOpacity(0.2),
                        child: Icon(typeIcon, color: typeColor),
                      ),
                      title: Text(
                        data['reason'] ?? 'Sebep yok',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Türü: $typeLabel | Şikayet Eden: ${data['reporterName']}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            "İçerik: ${data['targetTitle'] ?? data['postTitle'] ?? 'Başlık Yok'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: SizedBox(
                        width: 120,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Color(0xFF00BCD4)),
                              onPressed: () async {
                                final targetId = data['targetId'] ?? data['postId'];
                                if (type == 'post' || type == 'comment') {
                                  final postId = data['postId'] ?? targetId;
                                  final postDoc =
                                      await FirebaseFirestore.instance.collection('gonderiler').doc(postId).get();
                                  if (postDoc.exists && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GonderiDetayEkrani.fromDoc(postDoc),
                                      ),
                                    );
                                  }
                                } else if (type == 'product') {
                                  final prodDoc =
                                      await FirebaseFirestore.instance.collection('urunler').doc(targetId).get();
                                  if (prodDoc.exists && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UrunDetayEkrani(
                                          productId: targetId,
                                          productData: prodDoc.data()!,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              tooltip: "Görüntüle",
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: AppColors.error),
                              onPressed: () async {
                                final targetId = data['targetId'] ?? data['postId'];
                                final postId = data['postId'];
                                if (type == 'post') {
                                  await _deleteContent('gonderiler', targetId);
                                } else if (type == 'comment') {
                                  await _deleteComment(postId, targetId);
                                } else if (type == 'product') {
                                  await _deleteContent('urunler', targetId);
                                }
                                await doc.reference.delete();
                              },
                              tooltip: "Sil",
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: AppColors.success),
                              onPressed: () async {
                                await doc.reference.delete();
                                if (mounted) {
                                  showSnackBar(
                                    context: context,
                                    message: "✅ Şikayet çözüldü",
                                    color: AppColors.success,
                                  );
                                }
                              },
                              tooltip: "Çöz",
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
