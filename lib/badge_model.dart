import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'app_colors.dart';

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
  // Gelecekte eklenecek diğer rozetler buraya gelebilir...
];