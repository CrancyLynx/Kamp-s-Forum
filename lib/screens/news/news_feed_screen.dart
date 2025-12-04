import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/phase2_models.dart';

// Basit bir haber servisi (mevcut news_service.dart yerine)
class NewsServiceWrapper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<News>> getActiveNewsStream() {
    return _firestore
        .collection('news')
        .where('expiresAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => News.fromFirestore(doc))
            .toList());
  }

  Stream<List<News>> getNewsByCategory(String category) {
    return _firestore
        .collection('news')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => News.fromFirestore(doc))
            .toList());
  }
}

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({Key? key}) : super(key: key);

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  String selectedCategory = 'tumunu-goster';
  final newsService = NewsServiceWrapper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haber & Duyurular'),
        elevation: 0,
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  _buildCategoryChip('Tümünü Göster', 'tumunu-goster'),
                  _buildCategoryChip('Akademik', 'akademik'),
                  _buildCategoryChip('Etkinlik', 'etkinlik'),
                  _buildCategoryChip('Bildirim', 'bildirim'),
                  _buildCategoryChip('Özel', 'ozel'),
                ],
              ),
            ),
          ),
          // News List
          Expanded(
            child: selectedCategory == 'tumunu-goster'
                ? _buildAllNewsList()
                : _buildCategoryNewsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: selectedCategory == category,
        onSelected: (selected) {
          setState(() {
            selectedCategory = category;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.teal,
        labelStyle: TextStyle(
          color: selectedCategory == category ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildAllNewsList() {
    return StreamBuilder<List<News>>(
      stream: newsService.getActiveNewsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.newspaper, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Haber bulunamadı',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildNewsCard(snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildCategoryNewsList() {
    return StreamBuilder<List<News>>(
      stream: newsService.getNewsByCategory(selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.newspaper, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Bu kategoride haber yok',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildNewsCard(snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildNewsCard(News news) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (news.imageUrl.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                image: DecorationImage(
                  image: NetworkImage(news.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  // Pinned Badge
                  if (news.isPinned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '📌 SABİTLENDİ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(news.category),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    news.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  news.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Content Preview
                Text(
                  news.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(news.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          news.viewCount.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'akademik':
        return Colors.blue;
      case 'etkinlik':
        return Colors.purple;
      case 'bildirim':
        return Colors.orange;
      case 'ozel':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
