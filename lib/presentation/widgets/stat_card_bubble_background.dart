import 'dart:math' as math;
import 'package:flutter/material.dart';

class StatCardBubbleBackground extends StatefulWidget {
  final Color color;
  const StatCardBubbleBackground({Key? key, required this.color}) : super(key: key);

  @override
  _StatCardBubbleBackgroundState createState() => _StatCardBubbleBackgroundState();
}

class _StatCardBubbleBackgroundState extends State<StatCardBubbleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 8)
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double phase = _controller.value * 2 * math.pi;
          return Stack(
            children: [
              Positioned(
                left: -20 + 20 * math.sin(phase),
                top: -20 + 20 * math.cos(phase),
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.15)),
                ),
              ),
              Positioned(
                right: -30 + 30 * math.cos(phase),
                bottom: -40 + 30 * math.sin(phase),
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.15)),
                ),
              ),
              Positioned(
                left: 60 + 15 * math.cos(phase * 1.5),
                bottom: 10 + 15 * math.sin(phase * 1.5),
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.1)),
                ),
              ),
              Positioned(
                right: 40 + 10 * math.sin(phase * 2),
                top: 10 + 10 * math.cos(phase * 2),
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.1)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
