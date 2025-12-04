import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class EmojiPickerWidget extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;

  const EmojiPickerWidget({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  State<EmojiPickerWidget> createState() => _EmojiPickerWidgetState();
}

class _EmojiPickerWidgetState extends State<EmojiPickerWidget> {
  // Sık kullanılan emoji'ler (hardcoded başlangıç)
  final List<String> frequentEmojis = [
    '😂', '❤️', '😍', '🔥', '👍', '😢', '😡', '🤔',
    '👌', '💯', '🎉', '😎', '🤮', '😴', '🙏', '😘',
  ];

  // Kategoriler ve emoji'ler
  late Map<String, List<String>> emojiCategories = {
    'Çok Kullanılan': frequentEmojis,
    'Yüzler': ['😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰'],
    'Göstüren': ['👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞', '🫰', '🤟', '🤘', '🤙', '👍', '👎'],
    'Sevgiler': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '💕', '💞', '💓', '💗', '💖', '💘'],
    'Aktiviteler': ['⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎳', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏'],
    'Objeler': ['⌚', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️', '🗜️', '💽', '💾', '💿', '📀', '🧮'],
  };

  String selectedCategory = 'Çok Kullanılan';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kategori seçimi
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: emojiCategories.keys.map((category) {
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => selectedCategory = category);
                    },
                    backgroundColor: Colors.transparent,
                    selectedColor: AppColors.primary.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Emoji grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              padding: const EdgeInsets.all(8),
              children: (emojiCategories[selectedCategory] ?? [])
                  .map((emoji) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        widget.onEmojiSelected(emoji);
                        // Pop ekran kapat
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// İçeri işlenmiş emoji picker dialog
void showEmojiPicker(BuildContext context, Function(String) onSelected) {
  showModalBottomSheet(
    context: context,
    builder: (context) => EmojiPickerWidget(
      onEmojiSelected: onSelected,
    ),
  );
}
