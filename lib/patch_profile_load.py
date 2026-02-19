#!/usr/bin/env python3
"""
プロフィール設定のカード/ステータスをシミュレーション画面に反映するパッチ
使い方: python patch_profile_load.py lib/simulation_screen.dart
"""
import sys

if len(sys.argv) < 2:
    print("使い方: python patch_profile_load.py lib/simulation_screen.dart")
    sys.exit(1)

filepath = sys.argv[1]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_profile = """      if (airline != null && airline.isNotEmpty && legs.isNotEmpty) {
        setState(() {
          legs.first['airline'] = airline;
          _optAirline = airline;
        });
      }
    } catch (_) {}"""

new_profile = """      if (airline != null && airline.isNotEmpty && legs.isNotEmpty) {
        setState(() {
          legs.first['airline'] = airline;
          _optAirline = airline;
        });
      }
      // JAL/ANAカード・ステータス・ツアープレミアム読み込み
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

if 'jal_card' in content.split('_loadUserProfile')[1].split('_initAirlineAirports')[0] if '_loadUserProfile' in content else '':
    print("⏭️  適用済み")
elif old_profile in content:
    content = content.replace(old_profile, new_profile)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ プロフィールからカード/ステータス読み込み追加")
else:
    print("❌ パターンが見つからない")

print("\n完了")
