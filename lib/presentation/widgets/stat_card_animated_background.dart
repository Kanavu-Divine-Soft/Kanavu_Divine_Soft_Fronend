import 'dart:math' as math;
import 'package:flutter/material.dart';

class StatCardAnimatedBackground extends StatefulWidget {
  final Color color;
  const StatCardAnimatedBackground({Key? key, required this.color}) : super(key: key);

  @override
  _StatCardAnimatedBackgroundState createState() => _StatCardAnimatedBackgroundState();
}

class _StatCardAnimatedBackgroundState extends State<StatCardAnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A 3-second cycle: 1.5 seconds of shine, 1.5 seconds of pause
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 3500)
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
          // Shine moves across in the first half of the animation
          double progress = (_controller.value * 2).clamp(0.0, 1.0);
          
          return Stack(
            children: [
              // Subtle background pulse
              Positioned(
                right: -20,
                top: -20,
                child: Transform.scale(
                  scale: 1.0 + 0.1 * math.sin(_controller.value * 2 * math.pi),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.08),
                    ),
                  ),
                ),
              ),
              // Shine sweep effect
              if (progress > 0.0 && progress < 1.0)
                Positioned(
                  top: -100,
                  bottom: -100,
                  left: -200 + (progress * 800),
                  width: 80,
                  child: Transform.rotate(
                    angle: math.pi / 5, // ~36 degrees
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withOpacity(0.0),
                            widget.color.withOpacity(0.2),
                            widget.color.withOpacity(0.0),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
