import 'package:flutter/material.dart';


/// ListView içindeki elemanlara basit bir giriş animasyonu (fade ve slide)
/// eklemek için kullanılan yeniden kullanılabilir bir widget.
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    // Her elemanın biraz gecikmeyle başlaması için bir gecikme ekliyoruz.
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(_animation),
        child: widget.child,
      ),
    );
  }
}