import 'package:flutter/material.dart';
import '../../models/content_models.dart';
    import '../../services/content_services.dart';
import '../../utils/app_colors.dart';

class LocationMarkersScreen extends StatefulWidget {
  const LocationMarkersScreen({super.key});

  @override
  State<LocationMarkersScreen> createState() => _LocationMarkersScreenState();
}

class _LocationMarkersScreenState extends State<LocationMarkersScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['all', 'canteen', 'library', 'classroom', 'event', 'custom'];

  final Map<String, String> _categoryLabels = {
    'all': '🗺️ Tümü',
    'canteen': '🍽️ Cantina',
    'library': '📚 Kütüphane',
    'classroom': '🏫 Sınıf',
    'event': '🎉 Etkinlik',
    'custom': '📍 Diğer',
  };

  final Map<String, Color> _categoryColors = {
    'canteen': Colors.orangeAccent,
    'library': Colors.purpleAccent,
    'classroom': Colors.blueAccent,
    'event': Colors.redAccent,
    'custom': Colors.greenAccent,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampüs Konumları'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Konum adı ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_categoryLabels[category] ?? category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = selected ? category : 'all');
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primary.withOpacity(0.3),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LocationMarker>>(
              stream: _selectedCategory == 'all'
                  ? LocationMarkerService.getAllMarkers()
                  : LocationMarkerService.getMarkersByType(_selectedCategory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final filtered = snapshot.data!
                    .where((marker) =>
                        marker.name.toLowerCase().contains(_searchQuery) ||
                        marker.description.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState('Aranan konum bulunamadı');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final marker = filtered[index];
                    return _buildMarkerCard(marker);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerCard(LocationMarker marker) {
    final categoryColor = _categoryColors[marker.iconType] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMarkerDetails(marker),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForType(marker.iconType),
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marker.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          marker.category,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                marker.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    '${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkerDetails(LocationMarker marker) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _categoryColors[marker.iconType]?.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(marker.iconType),
                    color: _categoryColors[marker.iconType],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        marker.category,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('📝 Açıklama', marker.description),
            const SizedBox(height: 12),
            _detailRow('🏷️ Tür', marker.iconType),
            const SizedBox(height: 12),
            _detailRow('📍 Koordinatlar', '${marker.latitude}, ${marker.longitude}'),
            const SizedBox(height: 12),
            _detailRow('✅ Durum', marker.isActive ? 'Aktif' : 'Pasif'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.map),
                    label: const Text('Haritada Aç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Yönlendir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildEmptyState([String message = 'Henüz konum eklenmemiş']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'canteen':
        return Icons.restaurant;
      case 'library':
        return Icons.menu_book;
      case 'classroom':
        return Icons.school;
      case 'event':
        return Icons.celebration;
      default:
        return Icons.location_on;
    }
  }
}
