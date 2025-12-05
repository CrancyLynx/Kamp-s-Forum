import 'package:flutter/material.dart';
import '../profile/leaderboard_ekrani.dart';

/// Phase 2-4 Sistemleri Entegrasyon Paneli - Refactored
/// 3 ana kategori: Gamification (3), Safety (1), Analytics (3)
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
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
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
              // Gamification (3)
              Tab(text: "🎮 Puanlar"),
              Tab(text: "🏆 Başarılar"),
              Tab(text: "🎁 Ödüller"),
              // Safety (1)
              Tab(text: "🛡️ Güvenlik"),
              // Analytics (3)
              Tab(text: "🔍 Trendler"),
              Tab(text: "🤖 AI"),
              Tab(text: "💰 Mali"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. Points System (Gamification)
                _buildPointsTab(),
                // 2. Achievements System (Gamification)
                _buildAchievementsTab(),
                // 3. Rewards System (Gamification)
                _buildRewardsTab(),
                // 4. Ride Complaints (Safety)
                _buildSafetyTab(),
                // 5. Search Analytics (Analytics)
                _buildSearchTrendsTab(),
                // 6. AI Metrics (Analytics)
                _buildAiMetricsTab(),
                // 7. Financial (Analytics)
                _buildFinancialTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // GAMIFICATION SECTION
  
  Widget _buildPointsTab() {
    return _buildSystemPanel(
      title: '⭐ Puan Sistemi',
      description: 'Kullanıcı puanları ve seviye ilerlemesi',
      emoji: '💫',
      children: [
        _buildInfoCard('🎯 Puan Nedir?', 'Forumda gönderi yaparak, yorum yazarak ve başarıları açarak puan kazanın'),
        _buildInfoCard('📊 Seviyeler', '0-100 puan: Level 1, 100-250: Level 2, 250+: Level 3+ devam eden ilerlemeler'),
        _buildInfoCard('🏅 Ödüller', 'Her 100 puan başarısında özel rozetler ve ödüller açılır'),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.bar_chart),
          label: const Text('Sıralamayı Gör'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaderboardEkrani()),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsTab() {
    return _buildSystemPanel(
      title: '🏆 Başarılar (Rozetler)',
      description: 'Özel görevleri tamamlayarak rozet açın',
      emoji: '🎖️',
      children: [
        _buildInfoCard('🎯 Başarıyı Nasıl Açarım?', 'Belirli şartları yerine getirerek rozet açabilirsiniz (ilk gönderi, 10 beğeni, vs.)'),
        _buildInfoCard('⭐ Rarity Seviyeleri', 'Her rozetlinin sırlı seviyeleri vardır: Common, Uncommon, Rare, Epic, Legendary'),
        _buildInfoCard('💝 Başarı Ödülleri', 'Her başarıyı açtığınızda bonus puan ve özel görseller kazanırsınız'),
        _buildInfoCard('🤫 Gizli Başarılar', 'Bazı başarılar gizlidir - onları açmaya çalışın!'),
      ],
    );
  }

  Widget _buildRewardsTab() {
    return _buildSystemPanel(
      title: '🎁 Ödüller Mağazası',
      description: 'Puanlarınızla özel ödüller alın',
      emoji: '🎀',
      children: [
        _buildInfoCard('💰 Puan Harcama', 'Kazandığınız puanları bu mağazada harcayarak özel ödüller alabilirsiniz'),
        _buildInfoCard('🏪 Mağaza Ürünleri', 'Özel avatarlar, tema paketleri, premium özellikleri açabilirsiniz'),
        _buildInfoCard('📅 Sınırlı Teklifler', 'Her ay yeni ve sınırlı ödüller eklenirler - hızlı davranın!'),
        _buildInfoCard('🎯 İpucu', 'Ödülleri akıllıca seçin - bazıları sınırlı sayıda mevcuttur'),
      ],
    );
  }

  // SAFETY SECTION

  Widget _buildSafetyTab() {
    return _buildSystemPanel(
      title: '🛡️ Sürüş Güvenliği',
      description: 'Tehlikeli sürüş davranışlarını bildirin',
      emoji: '🚗',
      children: [
        _buildInfoCard('⚠️ Şikayet Nedir?', 'Hız yapma, tehlikeli sürüş ve güvenlik sorunlarını bildirip track edebilirsiniz'),
        _buildInfoCard('🚨 Şiddeti Belirtme', '1-5 arası şiddet seviyesi seçerek sorunun ciddiyetini gösterin'),
        _buildInfoCard('👥 Tanık Ekleme', 'Olay şahitlerine referanslar ekleyerek iddialarınızı güçlendirin'),
        _buildInfoCard('📋 İzleme', 'Şikayetinizin durumunu gerçek zamanda takip edebilirsiniz'),
      ],
    );
  }

  // ANALYTICS SECTION

  Widget _buildSearchTrendsTab() {
    return _buildSystemPanel(
      title: '🔍 Arama Trendleri',
      description: 'Popüler aramalar ve trendler',
      emoji: '📈',
      children: [
        _buildInfoCard('🔥 Trend Nedir?', 'En sık araşan konuları ve popüler kelimeleri görmek'),
        _buildInfoCard('📊 Analiz', 'Hangi konulara ilgi olduğunu verilerle takip edin'),
        _buildInfoCard('💡 İlham Al', 'Popüler konuları öğrenerek yeni gönderi fikirler bulun'),
        _buildInfoCard('🎯 Optimize Et', 'Trendleri bilin ve kendi içeriğinizi optimize edin'),
      ],
    );
  }

  Widget _buildAiMetricsTab() {
    return _buildSystemPanel(
      title: '🤖 AI Model Metrikleri',
      description: 'Yapay zeka performansı ve istatistikler',
      emoji: '🔬',
      children: [
        _buildInfoCard('📊 Model Başarısı', 'Sistem yapay zekasının ne kadar iyi çalıştığını görmek'),
        _buildInfoCard('⚡ İşlem Hızı', 'İstekler ne kadar hızlı işleniyor ve sistem durumu nedir'),
        _buildInfoCard('📈 Yükselişler', 'AI modeli sürekli geliştirilir ve iyileştirilir'),
        _buildInfoCard('🔧 Optimizasyon', 'Sistem performansı maksimum düzeyinde tutulur'),
      ],
    );
  }

  Widget _buildFinancialTab() {
    return _buildSystemPanel(
      title: '💰 Mali Raporlar',
      description: 'Gelir ve gider analizi',
      emoji: '💵',
      children: [
        _buildInfoCard('📊 Finansal Veriler', 'Sistem gelir/giderleri ve mali durumu görmek'),
        _buildInfoCard('📈 Grafikler', 'Zaman içinde finansal trendleri visual olarak görmek'),
        _buildInfoCard('🏦 Kategori Analizi', 'Masraflar ne kategorilere dağılıyor, gelir nerelerden geliyor'),
        _buildInfoCard('📋 Raporlar', 'Detaylı finansal raporları indirip paylaşabilirsiniz'),
      ],
    );
  }

  Widget _buildSystemPanel({
    required String title,
    required String description,
    required String emoji,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
