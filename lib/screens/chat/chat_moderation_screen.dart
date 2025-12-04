import 'package:flutter/material.dart';

class ChatModerationScreen extends StatefulWidget {
  const ChatModerationScreen({super.key});

  @override
  State<ChatModerationScreen> createState() => _ChatModerationScreenState();
}

class _ChatModerationScreenState extends State<ChatModerationScreen> {
  final List<Map<String, dynamic>> rules = [
    {
      'title': 'Spam Kuralı',
      'desc': 'Aynı mesaj 3 kez gönderilirse blokla',
      'enabled': true,
    },
    {
      'title': 'Küfür Filtresi',
      'desc': 'Yasaklı kelimeler otomatik silinir',
      'enabled': true,
    },
    {
      'title': 'URL Kısıtlaması',
      'desc': 'Yalnızca moderatörler link paylaşabilir',
      'enabled': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Moderasyon'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rules.length,
        itemBuilder: (ctx, idx) {
          final rule = rules[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: SwitchListTile(
              title: Text(rule['title']),
              subtitle: Text(rule['desc']),
              value: rule['enabled'],
              onChanged: (v) => setState(() => rule['enabled'] = v),
            ),
          );
        },
      ),
    );
  }
}
