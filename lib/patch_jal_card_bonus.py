#!/usr/bin/env python3
"""
JALカードマイルボーナス修正パッチ
使い方: python patch_jal_card_bonus.py lib/simulation_screen.dart lib/flight_log_screen.dart
"""
import sys

if len(sys.argv) < 3:
    print("使い方: python patch_jal_card_bonus.py lib/simulation_screen.dart lib/flight_log_screen.dart")
    sys.exit(1)

sim_path = sys.argv[1]
flog_path = sys.argv[2]

# ========== 1. simulation_screen.dart ==========
with open(sim_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_sim = "        totalMiles = flightMiles + (flightMiles * statusBonusRate).round();"

new_sim = """          final jalCardBonusRate = {
            '-': 0.0,
            'JMB会員': 0.0,
            'JALカード普通会員': 0.10,
            'JALカードCLUB-A会員': 0.25,
            'JALカードCLUB-Aゴールド会員': 0.25,
            'JALカードプラチナ会員': 0.25,
            'JALグローバルクラブ会員(日本)': 0.25,
            'JALグローバルクラブ会員(海外)': 0.25,
            'JALカードNAVI会員': 0.10,
            'JAL CLUB EST 普通会員': 0.10,
            'JAL CLUB EST CLUB-A会員': 0.25,
            'JAL CLUB EST CLUB-A GOLD会員': 0.25,
            'JAL CLUB EST プラチナ会員': 0.25,
          }[selectedJALCard ?? '-'] ?? 0.0;
        totalMiles = flightMiles + (flightMiles * statusBonusRate).round() + (flightMiles * jalCardBonusRate).round();"""

if 'jalCardBonusRate' in content:
    print("⏭️  simulation_screen.dart: 適用済み")
elif old_sim in content:
    content = content.replace(old_sim, new_sim)
    print("✅ simulation_screen.dart: JALカードボーナス追加")
else:
    print("❌ simulation_screen.dart: パターンが見つからない")

with open(sim_path, 'w', encoding='utf-8') as f:
    f.write(content)

# ========== 2. flight_log_screen.dart ==========
with open(flog_path, 'r', encoding='utf-8') as f:
    content2 = f.read()

old_flog = "          final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();\n          miles = flightMiles;"

new_flog = """          final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();
          final jalStatusBonusRate = {
            '-': 0.0,
            'JMBダイヤモンド': 1.30,
            'JMBサファイア': 1.05,
            'JMBクリスタル': 0.55,
          }[jalStatus ?? '-'] ?? 0.0;
          final jalCardBonusRate = {
            '-': 0.0,
            'JMB会員': 0.0,
            'JALカード普通会員': 0.10,
            'JALカードCLUB-A会員': 0.25,
            'JALカードCLUB-Aゴールド会員': 0.25,
            'JALカードプラチナ会員': 0.25,
            'JALグローバルクラブ会員(日本)': 0.25,
            'JALグローバルクラブ会員(海外)': 0.25,
            'JALカードNAVI会員': 0.10,
            'JAL CLUB EST 普通会員': 0.10,
            'JAL CLUB EST CLUB-A会員': 0.25,
            'JAL CLUB EST CLUB-A GOLD会員': 0.25,
            'JAL CLUB EST プラチナ会員': 0.25,
          }[jalCard ?? '-'] ?? 0.0;
          miles = flightMiles + (flightMiles * jalStatusBonusRate).round() + (flightMiles * jalCardBonusRate).round();"""

if 'jalCardBonusRate' in content2:
    print("⏭️  flight_log_screen.dart: 適用済み")
elif old_flog in content2:
    content2 = content2.replace(old_flog, new_flog)
    print("✅ flight_log_screen.dart: JALカードボーナス追加")
else:
    print("❌ flight_log_screen.dart: パターンが見つからない")

with open(flog_path, 'w', encoding='utf-8') as f:
    f.write(content2)

print("\n完了")
