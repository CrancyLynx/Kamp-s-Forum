import 'package:flutter/material.dart';

/// Emoji paket ekranı - Sticker koleksiyonunu göster
class EmojiStickerScreen extends StatefulWidget {
  const EmojiStickerScreen({super.key});

  @override
  State<EmojiStickerScreen> createState() => _EmojiStickerScreenState();
}

class _EmojiStickerScreenState extends State<EmojiStickerScreen> {
  final List<Map<String, dynamic>> emojiPacks = [
    {'name': 'Klasik Emojiler', 'count': 120, 'icon': '😀'},
    {'name': 'Sevgi Paketi', 'count': 45, 'icon': '❤️'},
    {'name': 'Aktivite Stickerleri', 'count': 80, 'icon': '⚽'},
    {'name': 'Doğa Teması', 'count': 60, 'icon': '🌸'},
    {'name': 'Yemek & İçecek', 'count': 95, 'icon': '🍔'},
    {'name': 'Hayvanlar', 'count': 70, 'icon': '🐶'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emoji & Stickerler'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: emojiPacks.length,
        itemBuilder: (ctx, idx) {
          final pack = emojiPacks[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Text(
                pack['icon'],
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(pack['name']),
              subtitle: Text('${pack['count']} emoji'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${pack['name']} seçildi')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
