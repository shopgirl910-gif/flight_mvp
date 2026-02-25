import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'app_config.dart';

/// MRPアプリ共通ロゴWidget
/// X(@mrunplanner)のプロフィール画像を再現
/// 使用例: MrpLogo(size: 80)
class MrpLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const MrpLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7B1FA2), // Purple 700
            Color(0xFF6A1B9A), // Purple 800
            Color(0xFF4A148C), // Purple 900
          ],
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF7B1FA2).withOpacity(0.3),
                  blurRadius: size * 0.15,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 飛行機アイコン（上部）
          Positioned(
            top: size * 0.15,
            child: Transform.rotate(
              angle: 45 * math.pi / 180, // 右肩上がり
              child: Icon(
                Icons.flight,
                size: size * 0.42,
                color: Colors.white,
              ),
            ),
          ),
          // MRPテキスト + ゴールド下線（下部）
          Positioned(
            bottom: size * 0.12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MRP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: size * 0.02,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: size * 0.02),
                Container(
                  width: size * 0.35,
                  height: size * 0.025,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.01),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFD4A017), // Dark gold
                        Color(0xFFFFD700), // Gold
                        Color(0xFFD4A017), // Dark gold
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AppBar用の小さいロゴ（テキスト付き）
class MrpLogoWithText extends StatelessWidget {
  const MrpLogoWithText({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MrpLogo(size: 36, showShadow: false),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MRP',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            Text(
              'Mileage Run Planner',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
            Text(
              'v${AppConfig.version}',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.normal,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
