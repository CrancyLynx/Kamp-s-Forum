import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';

/// Bir rozeti temsil eden model sınıfı.
class Badge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Uygulamada mevcut olan tüm rozetlerin listesi.
/// Yeni bir rozet eklemek için bu listeye eklemeniz yeterlidir.
const List<Badge> allBadges = [
  Badge(
    id: 'admin',
    name: 'Yönetici',
    description: 'Uygulama yöneticisi olduğunuzu gösterir.',
    icon: FontAwesomeIcons.shieldHalved,
    color: AppColors.primary,
  ),
  Badge(
    id: 'pioneer',
    name: 'Öncü',
    description: 'İlk gönderini paylaşarak topluluğa ilk adımı at.',
    icon: FontAwesomeIcons.featherPointed,
    color: Colors.brown,
  ),
  Badge(
    id: 'commentator_rookie',
    name: 'Sohbet Meraklısı',
    description: 'Topluluğa katılarak 10 yoruma ulaş.',
    icon: FontAwesomeIcons.comments,
    color: Colors.teal,
  ),
  Badge(
    id: 'commentator_pro',
    name: 'Fikir Lideri',
    description: 'Düşüncelerini paylaşarak 50 yoruma ulaş.',
    icon: FontAwesomeIcons.commentDots,
    color: Colors.indigo,
  ),
  Badge(
    id: 'popular_author',
    name: 'Popüler Yazar',
    description: 'Gönderilerinle topluluktan 50 beğeni al.',
    icon: FontAwesomeIcons.solidStar,
    color: Colors.amber,
  ),
  Badge(
    id: 'campus_phenomenon',
    name: 'Kampüs Fenomeni',
    description: 'İçeriklerinle ilham vererek 250 beğeniye ulaş.',
    icon: FontAwesomeIcons.fire,
    color: Colors.deepOrange,
  ),
  Badge(
    id: 'veteran',
    name: 'Usta',
    description: 'Forumda tecrübeni konuşturarak 50 gönderi paylaş.',
    icon: FontAwesomeIcons.userGraduate,
    color: Colors.blueGrey,
  ),
  
  // ✅ YENİ ROZETLER
  Badge(
    id: 'early_bird',
    name: 'Sabahçı Kuş',
    description: 'Sabah erkenden aktif ol ve 20 gönderi paylaş.',
    icon: FontAwesomeIcons.sun,
    color: Colors.orange,
  ),
  Badge(
    id: 'night_owl',
    name: 'Gece Kuşu',
    description: 'Gece geç saatlerde aktif ol ve 20 gönderi paylaş.',
    icon: FontAwesomeIcons.moon,
    color: Colors.indigo,
  ),
  Badge(
    id: 'helper',
    name: 'Yardımsever',
    description: 'Diğer kullanıcılara yardım et, 100 yorum yap.',
    icon: FontAwesomeIcons.handshake,
    color: Colors.green,
  ),
  Badge(
    id: 'social_butterfly',
    name: 'Sosyal Kelebek',
    description: '30 farklı kullanıcıya yorum yap.',
    icon: FontAwesomeIcons.userGroup,
    color: Colors.pink,
  ),
  Badge(
    id: 'curious',
    name: 'Meraklı',
    description: '50 farklı konuya bak ve katıl.',
    icon: FontAwesomeIcons.magnifyingGlass,
    color: Colors.purple,
  ),
  Badge(
    id: 'loyal_member',
    name: 'Sadık Üye',
    description: '30 gün üst üste giriş yap.',
    icon: FontAwesomeIcons.calendar,
    color: Colors.blue,
  ),
  Badge(
    id: 'question_master',
    name: 'Soru Ustası',
    description: '25 soru sorarak topluluğa katkı sağla.',
    icon: FontAwesomeIcons.circleQuestion,
    color: Colors.cyan,
  ),
  Badge(
    id: 'problem_solver',
    name: 'Çözüm Odaklı',
    description: '50 soruya cevap vererek yardım et.',
    icon: FontAwesomeIcons.lightbulb,
    color: Colors.yellow,
  ),
  Badge(
    id: 'trending_topic',
    name: 'Trend Yaratıcı',
    description: 'Bir konun 100+ görüntülenmesini sağla.',
    icon: FontAwesomeIcons.chartLine,
    color: Colors.redAccent,
  ),
  Badge(
    id: 'friendly',
    name: 'Arkadaş Canlısı',
    description: '10 kullanıcıyı takip et.',
    icon: FontAwesomeIcons.heart,
    color: Colors.pinkAccent,
  ),
  Badge(
    id: 'influencer',
    name: 'Etkileyici',
    description: '50 takipçiye ulaş.',
    icon: FontAwesomeIcons.trophy,
    color: Colors.amber,
  ),
  Badge(
    id: 'perfectionist',
    name: 'Mükemmeliyetçi',
    description: '10 gönderin hepsi 10+ beğeni alsın.',
    icon: FontAwesomeIcons.gem,
    color: Colors.deepPurple,
  ),
];
