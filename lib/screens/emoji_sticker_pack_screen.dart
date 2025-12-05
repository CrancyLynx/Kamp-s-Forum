// lib/screens/emoji_sticker_pack_screen.dart
import 'package:flutter/material.dart';
import '../models/phase2_complete_models.dart';
import '../services/phase2_complete_services.dart';

class EmojiStickerPackScreen extends StatefulWidget {
  const EmojiStickerPackScreen({Key? key}) : super(key: key);

  @override
  State<EmojiStickerPackScreen> createState() => _EmojiStickerPackScreenState();
}

class _EmojiStickerPackScreenState extends State<EmojiStickerPackScreen> {
  final EmojiStickerService _emojiService = EmojiStickerService();
  List<EmojiStickerPack> _packs = [];
  bool _isLoading = true;
  String _selectedCategory = 'Hepsi';

  final List<String> _categories = ['Hepsi', 'Popüler', 'Yeni', 'Oyunlar', 'Animeler', 'Özel'];

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    setState(() => _isLoading = true);
    final packs = await _emojiService.getAllPacks();
    setState(() {
      _packs = packs;
      _isLoading = false;
    });
  }

  Future<void> _filterByCategory(String category) async {
    setState(() {
      _isLoading = true;
      _selectedCategory = category;
    });

    List<EmojiStickerPack> packs;
    if (category == 'Hepsi') {
      packs = await _emojiService.getAllPacks();
    } else {
      packs = await _emojiService.getPacksByCategory(category);
    }

    setState(() {
      _packs = packs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emoji ve Etiket Paketleri'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => _filterByCategory(category),
                  ),
                );
              }).toList(),
            ),
          ),
          // Pack Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _packs.isEmpty
                    ? Center(
                        child: Text('${_selectedCategory} kategorisinde paket bulunamadı'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPacks,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: _packs.length,
                          itemBuilder: (context, index) {
                            final pack = _packs[index];
                            return _buildPackCard(pack);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(EmojiStickerPack pack) {
    return GestureDetector(
      onTap: () => _showPackDetails(pack),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: Image.network(
                  pack.packageIcon,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.image_not_supported));
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${pack.downloads} indir',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (pack.isOfficial)
                        const Icon(Icons.verified, size: 16, color: Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPackDetails(EmojiStickerPack pack) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: Image.network(pack.packageIcon),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${pack.downloads} indirme',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Paket İçeriği (${pack.stickerUrls.length} etiket)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 1,
                ),
                itemCount: pack.stickerUrls.take(6).length,
                itemBuilder: (context, index) {
                  return Image.network(
                    pack.stickerUrls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image_not_supported);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _emojiService.incrementDownloads(pack.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paket indirildi!')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Paketi İndir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
