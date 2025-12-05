import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/content_models.dart';
    import '../../services/content_services.dart';
import '../../utils/app_colors.dart';

/// Harita Konumları - Location Markers Screen
class LocationMarkersScreen extends StatefulWidget {
  const LocationMarkersScreen({super.key});

  @override
  State<LocationMarkersScreen> createState() => _LocationMarkersScreenState();
}

class _LocationMarkersScreenState extends State<LocationMarkersScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🗺️ Kampüs Konumları',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: StreamBuilder<List<LocationMarker>>(
              stream: LocationMarkerService.getAllMarkers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }

                var markers = snapshot.data ?? [];

                if (_selectedCategory != null) {
                  markers = markers.where((m) => m.category == _selectedCategory).toList();
                }

                if (markers.isEmpty) {
                  return const Center(child: Text('Konum bulunamadı'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: markers.length,
                  itemBuilder: (context, index) => _buildMarkerCard(markers[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewLocation,
        tooltip: 'Yeni Konum Ekle',
        child: const Icon(Icons.add_location_rounded),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('Tümü'),
              selected: _selectedCategory == null,
              onSelected: (selected) => setState(() => _selectedCategory = null),
            ),
            const SizedBox(width: 8),
            ...['Yemek', 'Kütüphane', 'Lab', 'Spor', 'Oto Park']
                .map((cat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (selected) =>
                            setState(() => _selectedCategory = selected ? cat : null),
                      ),
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerCard(LocationMarker marker) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.2),
          child: const Icon(Icons.location_on_rounded, color: AppColors.primary),
        ),
        title: Text(marker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 ${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}'),
            if (marker.description != null) Text(marker.description!),
          ],
        ),
        trailing: Chip(label: Text(marker.category)),
        onTap: () => _showLocationDetail(marker),
      ),
    );
  }

  void _showLocationDetail(LocationMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(marker.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori: ${marker.category}'),
            const SizedBox(height: 8),
            Text('Koordinatlar: ${marker.latitude}, ${marker.longitude}'),
            if (marker.description != null) ...[
              const SizedBox(height: 8),
              Text('Açıklama: ${marker.description}'),
            ],
            if (marker.openingHours != null) ...[
              const SizedBox(height: 8),
              Text('Saatler: ${marker.openingHours}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openInMaps(marker);
            },
            icon: const Icon(Icons.map_rounded),
            label: const Text('Haritada Aç'),
          ),
        ],
      ),
    );
  }

  void _addNewLocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Konum Ekle'),
        content: const Text('Konum ekleme özelliği yakında gelecek'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _openInMaps(LocationMarker marker) {
    // TODO: Harita uygulamasında aç
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${marker.name} haritada açılacak')),
    );
  }
}
