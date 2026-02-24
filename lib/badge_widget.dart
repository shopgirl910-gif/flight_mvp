import 'package:flutter/material.dart';

/// ランク定義
enum BadgeRank {
  none,      // 未達成
  bronze,    // ブロンズ
  silver,    // シルバー
  gold,      // ゴールド
  platinum,  // プラチナ
  diamond,   // ダイヤモンド
}

/// ランク別カラー
Color getRankColor(BadgeRank rank) {
  switch (rank) {
    case BadgeRank.none:
      return const Color(0xFF555555);  // 暗いグレー（ほぼ見えない）
    case BadgeRank.bronze:
      return const Color(0xFFCD7F32);  // 銅色
    case BadgeRank.silver:
      return const Color(0xFFFFFFFF);  // 白（シルバー）
    case BadgeRank.gold:
      return const Color(0xFFFFD700);  // 金色
    case BadgeRank.platinum:
      return const Color(0xFF00BFFF);  // 青（プラチナ）
    case BadgeRank.diamond:
      return const Color(0xFFFF69B4);  // ピンク（ダイヤモンド）
  }
}

/// ランク名（日本語）
String getRankNameJa(BadgeRank rank) {
  switch (rank) {
    case BadgeRank.none:
      return '未達成';
    case BadgeRank.bronze:
      return 'ブロンズ';
    case BadgeRank.silver:
      return 'シルバー';
    case BadgeRank.gold:
      return 'ゴールド';
    case BadgeRank.platinum:
      return 'プラチナ';
    case BadgeRank.diamond:
      return 'ダイヤモンド';
  }
}

/// ランク名（英語）
String getRankNameEn(BadgeRank rank) {
  switch (rank) {
    case BadgeRank.none:
      return 'Not achieved';
    case BadgeRank.bronze:
      return 'Bronze';
    case BadgeRank.silver:
      return 'Silver';
    case BadgeRank.gold:
      return 'Gold';
    case BadgeRank.platinum:
      return 'Platinum';
    case BadgeRank.diamond:
      return 'Diamond';
  }
}

/// 空港数からランク判定
BadgeRank getAirportRank(int count) {
  if (count >= 50) return BadgeRank.diamond;
  if (count >= 30) return BadgeRank.platinum;
  if (count >= 20) return BadgeRank.gold;
  if (count >= 10) return BadgeRank.silver;
  if (count >= 5) return BadgeRank.bronze;
  return BadgeRank.none;
}

/// レグ数からランク判定
BadgeRank getLegRank(int count) {
  if (count >= 200) return BadgeRank.diamond;
  if (count >= 100) return BadgeRank.platinum;
  if (count >= 50) return BadgeRank.gold;
  if (count >= 30) return BadgeRank.silver;
  if (count >= 10) return BadgeRank.bronze;
  return BadgeRank.none;
}

/// クイズ正解数からランク判定
BadgeRank getQuizRank(int count) {
  if (count >= 100) return BadgeRank.diamond;
  if (count >= 50) return BadgeRank.platinum;
  if (count >= 30) return BadgeRank.gold;
  if (count >= 15) return BadgeRank.silver;
  if (count >= 5) return BadgeRank.bronze;
  return BadgeRank.none;
}

/// 次のランクまでの必要数を取得
int getNextTarget(BadgeRank currentRank, String category) {
  final thresholds = {
    'airport': [5, 10, 20, 30, 50],
    'leg': [10, 30, 50, 100, 200],
    'quiz': [5, 15, 30, 50, 100],
  };
  
  final list = thresholds[category]!;
  final index = currentRank.index; // none=0, bronze=1, ...
  
  if (index >= list.length) return list.last; // ダイヤモンド達成済み
  return list[index];
}

/// バッジウィジェット
class RankBadge extends StatelessWidget {
  final IconData icon;
  final BadgeRank rank;
  final String category; // 'airport', 'leg', 'quiz'
  final int currentCount;
  final bool isJapanese;
  final VoidCallback? onTap;

  const RankBadge({
    super.key,
    required this.icon,
    required this.rank,
    required this.category,
    required this.currentCount,
    required this.isJapanese,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = getRankColor(rank);
    
    return GestureDetector(
      onTap: onTap ?? () => _showDetailDialog(context),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: rankColor.withOpacity(0.3),
          border: Border.all(color: rankColor, width: 1.5),
        ),
        child: Icon(
          icon,
          size: 16,
          color: rankColor,
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    final rankName = isJapanese ? getRankNameJa(rank) : getRankNameEn(rank);
    final nextTarget = getNextTarget(rank, category);
    final isDiamond = rank == BadgeRank.diamond;
    
    String categoryName;
    String unit;
    switch (category) {
      case 'airport':
        categoryName = isJapanese ? '空港踏破' : 'Airports';
        unit = isJapanese ? '空港' : 'airports';
        break;
      case 'leg':
        categoryName = isJapanese ? 'フライト' : 'Flights';
        unit = isJapanese ? 'レグ' : 'legs';
        break;
      case 'quiz':
        categoryName = isJapanese ? 'クイズ' : 'Quiz';
        unit = isJapanese ? '問正解' : 'correct';
        break;
      default:
        categoryName = '';
        unit = '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: getRankColor(rank), size: 28),
            const SizedBox(width: 8),
            Text(categoryName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 現在のランク
            Row(
              children: [
                Text(
                  isJapanese ? '現在のランク: ' : 'Current Rank: ',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  rankName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getRankColor(rank),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 進捗
            Text(
              '$currentCount $unit',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // プログレスバー
            if (!isDiamond) ...[
              LinearProgressIndicator(
                value: currentCount / nextTarget,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(getRankColor(rank)),
              ),
              const SizedBox(height: 4),
              Text(
                isJapanese
                    ? '次のランクまで: あと${nextTarget - currentCount}$unit'
                    : 'Next rank: ${nextTarget - currentCount} more $unit',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ] else ...[
              Text(
                isJapanese ? '🎉 最高ランク達成！' : '🎉 Max rank achieved!',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isJapanese ? '閉じる' : 'Close'),
          ),
        ],
      ),
    );
  }
}

/// 3つのバッジをまとめて表示
class BadgeRow extends StatelessWidget {
  final int airportCount;
  final int legCount;
  final int quizCount;
  final bool isJapanese;

  const BadgeRow({
    super.key,
    required this.airportCount,
    required this.legCount,
    required this.quizCount,
    required this.isJapanese,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RankBadge(
          icon: Icons.location_on,
          rank: getAirportRank(airportCount),
          category: 'airport',
          currentCount: airportCount,
          isJapanese: isJapanese,
        ),
        RankBadge(
          icon: Icons.flight,
          rank: getLegRank(legCount),
          category: 'leg',
          currentCount: legCount,
          isJapanese: isJapanese,
        ),
        RankBadge(
          icon: Icons.school,
          rank: getQuizRank(quizCount),
          category: 'quiz',
          currentCount: quizCount,
          isJapanese: isJapanese,
        ),
      ],
    );
  }
}
