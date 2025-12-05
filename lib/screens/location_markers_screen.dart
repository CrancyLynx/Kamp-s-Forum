// lib/screens/location_markers_screen.dart
import 'package:flutter/material.dart';
import '../models/phase2_complete_models.dart';
import '../services/phase2_complete_services.dart';

class LocationMarkersScreen extends StatefulWidget {
  const LocationMarkersScreen({Key? key}) : super(key: key);

  @override
  State<LocationMarkersScreen> createState() => _LocationMarkersScreenState();
}

class _LocationMarkersScreenState extends State<LocationMarkersScreen> {
  final LocationService _locationService = LocationService();
  List<LocationMarker> _locations = [];
  bool _isLoading = true;
  String _selectedCategory = 'Hepsi';

  final List<String> _categories = ['Hepsi', 'Kütüphane', 'Yemekhane', 'Spor', 'Tiyatro', 'Diğer'];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    final locations = await _locationService.getAllLocations();
    setState(() {
      _locations = locations;
      _isLoading = false;
    });
  }

  Future<void> _filterByCategory(String category) async {
    setState(() {
      _isLoading = true;
      _selectedCategory = category;
    });
    
    List<LocationMarker> locations;
    if (category == 'Hepsi') {
      locations = await _locationService.getAllLocations();
    } else {
      locations = await _locationService.getLocationsByCategory(category);
    }
    
    setState(() {
      _locations = locations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampus Haritası'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category Filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => _filterByCategory(category),
                  ),
                );
              },
            ),
          ),
          // Location List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _locations.isEmpty
                    ? Center(
                        child: Text('${_selectedCategory} kategorisinde konum bulunamadı'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLocations,
                        child: ListView.builder(
                          itemCount: _locations.length,
                          itemBuilder: (context, index) {
                            final location = _locations[index];
                            return _buildLocationCard(location);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add location dialog
          _showAddLocationDialog();
        },
        child: const Icon(Icons.add_location),
      ),
    );
  }

  Widget _buildLocationCard(LocationMarker location) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (location.imageUrls.isNotEmpty)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: PageView.builder(
                itemCount: location.imageUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    location.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey, child: const Icon(Icons.image_not_supported));
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  location.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(location.category),
                      avatar: const Icon(Icons.category, size: 18),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${location.rating.toStringAsFixed(1)}/5'),
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

  void _showAddLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konum Ekle'),
        content: const Text('Yeni konum ekleme özelliği yakında gelecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
