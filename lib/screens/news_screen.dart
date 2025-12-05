// lib/screens/news_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/phase2_complete_models.dart';
import '../services/phase2_complete_services.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  final NewsService _newsService = NewsService();
  late TabController _tabController;
  List<NewsArticle> _allNews = [];
  List<NewsArticle> _filteredNews = [];
  bool _isLoading = true;

  final List<String> _categories = ['Hepsi', 'Haber', 'Duyuru', 'Etkinlik', 'Teknoloji'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    final news = await _newsService.getAllNews();
    setState(() {
      _allNews = news;
      _filteredNews = news;
      _isLoading = false;
    });
  }

  void _filterByCategory(int index) {
    if (index == 0) {
      setState(() => _filteredNews = _allNews);
    } else {
      final category = _categories[index].toLowerCase();
      setState(() => _filteredNews = _allNews.where((n) => n.category.toLowerCase() == category).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haberler'),
        bottom: TabBar(
          controller: _tabController,
          onTap: _filterByCategory,
          tabs: _categories.map((cat) => Tab(text: cat)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNews,
              child: ListView.builder(
                itemCount: _filteredNews.length,
                itemBuilder: (context, index) {
                  final article = _filteredNews[index];
                  return _buildNewsCard(article);
                },
              ),
            ),
    );
  }

  Widget _buildNewsCard(NewsArticle article) {
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
                  article.description,
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
                        '${article.sourceName} • ${article.views} görüntüleme',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(article.isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                      onPressed: () {
                        _newsService.toggleBookmark(article.id, !article.isBookmarked);
                        setState(() {
                          final index = _filteredNews.indexOf(article);
                          if (index != -1) {
                            _filteredNews[index] = NewsArticle(
                              id: article.id,
                              title: article.title,
                              description: article.description,
                              imageUrl: article.imageUrl,
                              sourceUrl: article.sourceUrl,
                              category: article.category,
                              publishedAt: article.publishedAt,
                              sourceName: article.sourceName,
                              views: article.views,
                              isBookmarked: !article.isBookmarked,
                            );
                          }
                        });
                      },
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
