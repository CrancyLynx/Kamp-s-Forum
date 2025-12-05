// lib/screens/news_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_models.dart';
import '../services/content_services.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'Hepsi';

  final List<String> _categories = ['Hepsi', 'akademik', 'etkinlik', 'bildirim', 'ozel'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haberler'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() => _selectedCategory = _categories[index]);
          },
          tabs: _categories.map((cat) => Tab(text: cat == 'Hepsi' ? 'Hepsi' : cat)).toList(),
        ),
      ),
      body: StreamBuilder<List<News>>(
        stream: _selectedCategory == 'Hepsi'
            ? NewsService.getActiveNews()
            : NewsService.getNewsByCategory(_selectedCategory),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Haber bulunamadı'));
          }

          final news = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              itemCount: news.length,
              itemBuilder: (context, index) {
                final article = news[index];
                return _buildNewsCard(article);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(News article) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: article.imageUrl,
              placeholder: (context, url) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => Container(height: 200, color: Colors.grey),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  article.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${article.category} • ${article.viewCount} görüntüleme',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}
