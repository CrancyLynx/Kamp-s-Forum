import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_preference_model.dart';
import '../../utils/app_colors.dart';

class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<NotificationSettingsDialog> {
  late NotificationPreference preferences;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('notification_preferences')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        preferences = NotificationPreference.fromFirestore(snapshot);
      } else {
        // Varsayılan ayarlar
        preferences = NotificationPreference(
          id: userId,
          userId: userId,
          pushNotifications: true,
          emailNotifications: false,
          smsNotifications: false,
          soundEnabled: true,
          vibrationEnabled: true,
          newsNotifications: true,
          chatNotifications: true,
          forumNotifications: true,
          badgeNotifications: true,
          eventNotifications: true,
          gameNotifications: true,
          quietHoursEnabled: false,
          quietHoursStart: '22:00',
          quietHoursEnd: '08:00',
          frequency: 'instant',
          userNotifications: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Bildirim ayarları yükleme hatası: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('notification_preferences')
          .doc(userId)
          .set(preferences.toFirestore(), SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim ayarları kaydedildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AlertDialog(
      title: const Text('Bildirim Ayarları'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Temel ayarlar
            _buildSwitchTile(
              'Push Bildirimleri',
              preferences.pushNotifications,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  pushNotifications: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            _buildSwitchTile(
              'Ses Etkinleştir',
              preferences.soundEnabled,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  soundEnabled: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            _buildSwitchTile(
              'Titreşim Etkinleştir',
              preferences.vibrationEnabled,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  vibrationEnabled: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            const Divider(height: 24),
            
            // Kategori bildirimleri
            const Text('Kategori Bildirimleri', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildSwitchTile(
              'Forum Bildirimleri',
              preferences.forumNotifications,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  forumNotifications: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            _buildSwitchTile(
              'Sohbet Bildirimleri',
              preferences.chatNotifications,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  chatNotifications: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            _buildSwitchTile(
              'Haber Bildirimleri',
              preferences.newsNotifications,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  newsNotifications: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            _buildSwitchTile(
              'Rozet Bildirimleri',
              preferences.badgeNotifications,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  badgeNotifications: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            const Divider(height: 24),
            
            // Sessiz Saatler
            const Text('Sessiz Saatler', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildSwitchTile(
              'Sessiz Saatleri Etkinleştir',
              preferences.quietHoursEnabled,
              (value) {
                setState(() => preferences = preferences.copyWith(
                  quietHoursEnabled: value,
                  updatedAt: DateTime.now(),
                ));
              },
            ),
            if (preferences.quietHoursEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Başlangıç: ${''} (örn: 22:00)'),
                      subtitle: Text(preferences.quietHoursStart ?? '22:00'),
                      onTap: () {
                        _editTime(
                          preferences.quietHoursStart ?? '22:00',
                          (time) {
                            setState(() => preferences = preferences.copyWith(
                              quietHoursStart: time,
                              updatedAt: DateTime.now(),
                            ));
                          },
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Bitiş: (örn: 08:00)'),
                      subtitle: Text(preferences.quietHoursEnd ?? '08:00'),
                      onTap: () {
                        _editTime(
                          preferences.quietHoursEnd ?? '08:00',
                          (time) {
                            setState(() => preferences = preferences.copyWith(
                              quietHoursEnd: time,
                              updatedAt: DateTime.now(),
                            ));
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _savePreferences();
            if (mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  void _editTime(String initialTime, Function(String) onSave) {
    final controller = TextEditingController(text: initialTime);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saat Ayarla'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'HH:mm (örn: 22:00)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
