import 'package:flutter/material.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _notifEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Tercihleri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Bildirimleri Aç/Kapat'),
            value: _notifEnabled,
            onChanged: (v) {
              setState(() => _notifEnabled = v);
            },
          ),
          const Divider(),
          CheckboxListTile(
            title: const Text('Yorum Bildirimleri'),
            value: true,
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }
}
