import 'package:flutter/material.dart';

/// Phase 2-4 Sistemleri Entegrasyon Paneli
class Phase2to4IntegrationPanel extends StatefulWidget {
  const Phase2to4IntegrationPanel({super.key});

  @override
  State<Phase2to4IntegrationPanel> createState() => _Phase2to4IntegrationPanelState();
}

class _Phase2to4IntegrationPanelState extends State<Phase2to4IntegrationPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Phase 2: 10 systems, Phase 3: 8 systems, Phase 4: 7 systems = 25 total
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "📚 Tüm Sistemler",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              indicatorColor: const Color(0xFF00BCD4),
              indicatorWeight: 3,
              labelColor: const Color(0xFF00BCD4),
              unselectedLabelColor: Colors.grey[400],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(text: "Haberler"),
                Tab(text: "Konumlar"),
                Tab(text: "Aktiviteler"),
                Tab(text: "İstatistikler"),
                Tab(text: "Yorumlar"),
                Tab(text: "Şablonlar"),
                Tab(text: "Kayıtlı"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlaceholder("📰 Haberler & Duyurular", "Phase 2 - Haber yönetim sistemi"),
                  _buildPlaceholder("🗺️ Kampüs Konumları", "Phase 2 - Harita işaretleyicileri"),
                  _buildPlaceholder("📅 Aktivite Zaman Çizelgesi", "Phase 2 - Kullanıcı aktiviteleri"),
                  _buildPlaceholder("📊 İstatistikler", "Phase 2 - Kullanıcı ve forum istatistikleri"),
                  _buildPlaceholder("⭐ Yer Yorumları", "Phase 2 - Kampüs yerleri hakkında yorumlar"),
                  _buildPlaceholder("📧 Bildirim Şablonları", "Phase 2 - Bildirim özelleştirmesi"),
                  _buildPlaceholder("❤️ Kayıtlı Gönderiler", "Phase 4 - Kaydedilen gönderiler"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title, String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_circle_rounded, size: 100, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Yakında Kullanılabilir"),
          ),
        ],
      ),
    );
  }
}
