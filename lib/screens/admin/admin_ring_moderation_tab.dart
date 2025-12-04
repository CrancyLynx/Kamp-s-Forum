import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/ring_moderation_service.dart';
import '../../services/ring_notification_service.dart';
import '../../utils/app_colors.dart';
import 'admin_helpers.dart';

class AdminRingModerationTab extends StatefulWidget {
  const AdminRingModerationTab({super.key});

  @override
  State<AdminRingModerationTab> createState() => _AdminRingModerationTabState();
}

class _AdminRingModerationTabState extends State<AdminRingModerationTab> {
  Future<void> _approveRingPhoto(String photoId, String universityName, String uploaderName) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await RingModerationService.approvePendingPhoto(
        photoId: photoId,
        adminUserId: currentUser.uid,
        adminName: currentUser.displayName ?? 'Admin',
      );

      if (success) {
        await RingNotificationService.notifyUploaderPhotoApproved(
          uploaderUserId: '',
          uploaderName: uploaderName,
          universityName: universityName,
          approverName: currentUser.displayName ?? 'Admin',
        );

        await RingNotificationService.notifyUniversityUsersAboutNewRingInfo(
          universityName: universityName,
          uploaderName: uploaderName,
        );

        if (mounted) {
          showSnackBar(
            context: context,
            message: "✅ Fotoğraf onaylandı",
            color: AppColors.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Hata: $e", color: AppColors.error);
      }
    }
  }

  Future<void> _rejectRingPhoto(String photoId, String rejectionReason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final photoDoc = await FirebaseFirestore.instance.collection('pending_ring_photos').doc(photoId).get();
      if (!photoDoc.exists) return;

      final photoData = photoDoc.data() as Map<String, dynamic>;
      final universityName = photoData['universityName'] as String;
      final uploaderUserId = photoData['uploadedBy'] as String;
      final uploaderName = photoData['uploaderName'] as String;

      final success = await RingModerationService.rejectPendingPhoto(
        photoId: photoId,
        adminUserId: currentUser.uid,
        adminName: currentUser.displayName ?? 'Admin',
        rejectionReason: rejectionReason,
      );

      if (success) {
        await RingNotificationService.notifyUploaderPhotoRejected(
          uploaderUserId: uploaderUserId,
          uploaderName: uploaderName,
          universityName: universityName,
          rejectionReason: rejectionReason,
          approverName: currentUser.displayName ?? 'Admin',
        );

        if (mounted) {
          showSnackBar(
            context: context,
            message: "❌ Fotoğraf reddedildi",
            color: AppColors.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Hata: $e", color: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: const Color(0xFF00BCD4),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF00BCD4),
            tabs: const [
              Tab(icon: Icon(Icons.schedule_rounded), text: "Beklemede"),
              Tab(icon: Icon(Icons.check_circle_rounded), text: "Onaylı"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingRingPhotos(),
                _buildApprovedRingPhotos(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRingPhotos() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: RingModerationService.getPendingPhotos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return EmptyState(
            message: "İncelenecek fotoğraf yok",
            icon: Icons.image_not_supported_rounded,
          );
        }

        final pendingPhotos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pendingPhotos.length,
          itemBuilder: (context, index) {
            final photo = pendingPhotos[index];
            final universityName = photo['universityName'] as String? ?? 'Bilinmiyor';
            final uploaderName = photo['uploaderName'] as String? ?? 'Anonim';
            final photoUrl = photo['photoUrl'] as String? ?? '';
            final photoId = photo['id'] as String? ?? '';
            final uploadedAt = (photo['uploadedAt'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.broken_image, size: 64, color: Colors.grey[300]),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🏫 $universityName",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Yükleyen: $uploaderName",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        if (uploadedAt != null)
                          Text(
                            "Tarih: ${DateFormat('dd MMM yyyy, HH:mm').format(uploadedAt)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveRingPhoto(photoId, universityName, uploaderName),
                            icon: const Icon(Icons.check_circle),
                            label: const Text("Onayla"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showRejectReasonDialog(
                                context: context,
                                onReject: (reason) => _rejectRingPhoto(photoId, reason),
                              );
                            },
                            icon: const Icon(Icons.cancel),
                            label: const Text("Reddet"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedRingPhotos() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: RingModerationService.getApprovedPhotos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return EmptyState(
            message: "Onaylı fotoğraf yok",
            icon: Icons.check_circle_outline_rounded,
          );
        }

        final approvedPhotos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: approvedPhotos.length,
          itemBuilder: (context, index) {
            final photo = approvedPhotos[index];
            final universityName = photo['university'] as String? ?? 'Bilinmiyor';
            final photoUrl = photo['imageUrl'] as String? ?? '';
            final updaterName = photo['updaterName'] as String? ?? 'Anonim';
            final approverName = photo['approvedByName'] as String? ?? 'Bilinmiyor';
            final lastUpdated = (photo['lastUpdated'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.broken_image, size: 64, color: Colors.grey[300]),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "✅ $universityName",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Yükleyen: $updaterName",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          "Onaylayan: $approverName",
                          style: const TextStyle(fontSize: 13, color: Colors.green),
                        ),
                        if (lastUpdated != null)
                          Text(
                            "Tarih: ${DateFormat('dd MMM yyyy, HH:mm').format(lastUpdated)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

