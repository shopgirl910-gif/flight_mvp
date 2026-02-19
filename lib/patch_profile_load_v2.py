#!/usr/bin/env python3
"""
プロフィール設定をシミュレーション画面に反映（キー→表示名変換付き）
使い方: python patch_profile_load_v2.py lib/simulation_screen.dart
"""
import sys

if len(sys.argv) < 2:
    print("使い方: python patch_profile_load_v2.py lib/simulation_screen.dart")
    sys.exit(1)

filepath = sys.argv[1]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = """      if (airline != null && airline.isNotEmpty && legs.isNotEmpty) {
        setState(() {
          legs.first['airline'] = airline;
          _optAirline = airline;
        });
      }
    } catch (_) {}"""

new_block = """      if (airline != null && airline.isNotEmpty && legs.isNotEmpty) {
        setState(() {
          legs.first['airline'] = airline;
          _optAirline = airline;
        });
      }
      // プロフィールからカード・ステータスを読み込み（キー→表示名変換）
      const jalCardMap = {
        '-': '-', 'jmb': 'JMB会員', 'jal_regular': 'JALカード普通会員',
        'jal_club_a': 'JALカードCLUB-A会員', 'jal_club_a_gold': 'JALカードCLUB-Aゴールド会員',
        'jal_platinum': 'JALカードプラチナ会員',
        'jgc_japan': 'JALグローバルクラブ会員(日本)', 'jgc_overseas': 'JALグローバルクラブ会員(海外)',
        'jal_navi': 'JALカードNAVI会員',
        'jal_est_regular': 'JAL CLUB EST 普通会員', 'jal_est_club_a': 'JAL CLUB EST CLUB-A会員',
        'jal_est_gold': 'JAL CLUB EST CLUB-A GOLD会員', 'jal_est_platinum': 'JAL CLUB EST プラチナ会員',
      };
      const jalStatusMap = {
        '-': '-', 'diamond': 'JMBダイヤモンド', 'sapphire': 'JMBサファイア', 'crystal': 'JMBクリスタル',
      };
      const anaCardMap = {
        '-': '-', 'amc': 'AMCカード(提携カード含む)',
        'ana_regular': 'ANAカード 一般', 'ana_student': 'ANAカード 学生用',
        'ana_wide': 'ANAカード ワイド', 'ana_gold': 'ANAカード ゴールド', 'ana_premium': 'ANAカード プレミアム',
        'sfc_regular': 'SFC 一般', 'sfc_gold': 'SFC ゴールド', 'sfc_premium': 'SFC プレミアム',
      };
      const anaStatusMap = {
        '-': '-', 'diamond_1': 'ダイヤモンド(1年目)', 'diamond_2': 'ダイヤモンド(継続2年以上)',
        'platinum_1': 'プラチナ(1年目)', 'platinum_2': 'プラチナ(継続2年以上)',
        'bronze_1': 'ブロンズ(1年目)', 'bronze_2': 'ブロンズ(継続2年以上)',
      };
      final jalCardKey = res['jal_card'] as String? ?? '-';
      final jalStatusKey = res['jal_status'] as String? ?? '-';
      final anaCardKey = res['ana_card'] as String? ?? '-';
      final anaStatusKey = res['ana_status'] as String? ?? '-';
      final tourPrem = res['jal_tour_premium'] as bool? ?? false;
      setState(() {
        if (jalCardMap.containsKey(jalCardKey)) selectedJALCard = jalCardMap[jalCardKey];
        if (jalStatusMap.containsKey(jalStatusKey)) selectedJALStatus = jalStatusMap[jalStatusKey];
        if (anaCardMap.containsKey(anaCardKey)) selectedANACard = anaCardMap[anaCardKey];
        if (anaStatusMap.containsKey(anaStatusKey)) selectedANAStatus = anaStatusMap[anaStatusKey];
        jalTourPremium = tourPrem;
      });
    } catch (_) {}"""

# Check for v1 patch (already applied but wrong)
if 'jalCardMap' in content:
    print("⏭️  v2マッピング適用済み")
elif "res['jal_card']" in content and 'jalCardMap' not in content:
    # v1 patch applied - need to replace
    old_v1 = """      // JAL/ANAカード・ステータス・ツアープレミアム読み込み
      final jalCard = res['jal_card'] as String?;
      final anaCard = res['ana_card'] as String?;
      final jalSt = res['jal_status'] as String?;
      final anaSt = res['ana_status'] as String?;
      final tourPrem = res['jal_tour_premium'] as bool? ?? false;
      setState(() {
        if (jalCard != null && jalCard.isNotEmpty) selectedJALCard = jalCard;
        if (anaCard != null && anaCard.isNotEmpty) selectedANACard = anaCard;
        if (jalSt != null && jalSt.isNotEmpty) selectedJALStatus = jalSt;
        if (anaSt != null && anaSt.isNotEmpty) selectedANAStatus = anaSt;
        jalTourPremium = tourPrem;
      });
    } catch (_) {}"""
    
    new_v1_replacement = new_block.split("      // プロフィールからカード", 1)[1]
    new_v1_replacement = "      // プロフィールからカード" + new_v1_replacement
    
    if old_v1 in content:
        content = content.replace(old_v1, new_v1_replacement)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ v1パッチをv2（キー→表示名変換）に置換")
    else:
        print("❌ v1パッチのパターンが一致しない")
elif old_block in content:
    content = content.replace(old_block, new_block)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ プロフィール読み込み追加（キー→表示名変換付き）")
else:
    print("❌ パターンが見つからない")

print("\n完了")
