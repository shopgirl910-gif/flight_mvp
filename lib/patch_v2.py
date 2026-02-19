#!/usr/bin/env python3
"""
simulation_screen.dart パッチv2
1. おまかせ最適化のデフォルト運賃を運賃6に
2. 運賃6の表示名にプロモーション追加
3. 予定に追加ボタンでDB直接保存
使い方: python patch_v2.py lib/simulation_screen.dart
"""
import sys

if len(sys.argv) < 2:
    print("使い方: python patch_v2.py lib/simulation_screen.dart")
    sys.exit(1)

filepath = sys.argv[1]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

changes = 0

# === 修正1: 運賃6の表示名変更（全箇所） ===
old_unchin6 = "運賃6 (50%) スカイメイト等"
new_unchin6 = "運賃6 (50%) プロモーション、スカイメイト等"
count = content.count(old_unchin6)
if count > 0:
    content = content.replace(old_unchin6, new_unchin6)
    changes += 1
    print(f"✅ 1. 運賃6表示名変更 ({count}箇所)")
else:
    print("❌ 1. 運賃6表示名が見つからない")

# === 修正2: デフォルト運賃を運賃6に ===
old_default = "  String _optFareType = '';"
new_default = "  String _optFareType = '運賃6 (50%) プロモーション、スカイメイト等';"
if old_default in content:
    content = content.replace(old_default, new_default)
    changes += 1
    print("✅ 2. デフォルト運賃を運賃6に変更")
else:
    print("❌ 2. _optFareType初期値が見つからない")

# === 修正3: 航空会社変更時に運賃6をデフォルトに ===
old_reset = "_optFareType = '';"
new_reset = "_optFareType = (_optAirline == 'JAL') ? '運賃6 (50%) プロモーション、スカイメイト等' : '運賃7 (75%) スーパーバリュー、いっしょにマイル割';"
# Only replace the one in airline change handler (after _optAirline = v!)
old_airline_reset = """                              _optAirline = v!;
                              _optFareType = '';"""
new_airline_reset = """                              _optAirline = v!;
                              _optFareType = (v == 'JAL') ? '運賃6 (50%) プロモーション、スカイメイト等' : '運賃7 (75%) スーパーバリュー、いっしょにマイル割';"""
if old_airline_reset in content:
    content = content.replace(old_airline_reset, new_airline_reset)
    changes += 1
    print("✅ 3. 航空会社切替時デフォルト運賃設定")
else:
    print("❌ 3. 航空会社切替パターンが見つからない")

# === 修正4: _saveOptimalPlanメソッド追加 + ボタン変更 ===
# _transferToFreeDesignの直前に新メソッドを追加
save_method = '''
  Future<void> _saveOptimalPlan(OptimalPlan plan) async {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null && user.email != null && user.email!.isNotEmpty;
    if (!isLoggedIn) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('旅程を保存するにはログインが必要です'), backgroundColor: Colors.orange),
        );
      return;
    }
    final proService = ProService();
    if (!await proService.canSaveLog()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('無料版の制限'),
            content: const Text(
              '無料版は${ProService.freeLogLimit}旅程まで保存できます。\\n'
              'Pro版にアップグレードすると無制限に保存できます。',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
              ElevatedButton(
                onPressed: () { Navigator.pop(context); showProPurchaseDialog(context); },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('Pro版を見る', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final fareType = _optFareType;
      final seatClass = _optSeatClass;
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\\((\\d+)%\\)').firstMatch(fareType);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      final fareNumber = fareType.split(' ').first;

      final airports = <String>[];
      final legsJson = <Map<String, dynamic>>[];
      int totalFop = 0, totalMiles = 0, totalLsp = 0;

      for (final f in plan.flights) {
        if (airports.isEmpty || airports.last != f.departureCode) airports.add(f.departureCode);
        airports.add(f.arrivalCode);
        final distance = f.distanceMiles;

        int fop = 0, miles = 0, lsp = 0;
        if (_optAirline == 'JAL') {
          final seatBonusRate = {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seatClass] ?? 0.0;
          double effectiveFareRate = fareRate;
          if (jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5'))
            effectiveFareRate = 1.0;
          final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();
          final statusBonusRate = {
            '-': 0.0, 'JMBダイヤモンド': 1.30, 'JMBサファイア': 1.05, 'JMBクリスタル': 0.55,
          }[selectedJALStatus ?? '-'] ?? 0.0;
          final jalCardBonusRate = {
            '-': 0.0, 'JMB会員': 0.0,
            'JALカード普通会員': 0.10, 'JALカードCLUB-A会員': 0.25,
            'JALカードCLUB-Aゴールド会員': 0.25, 'JALカードプラチナ会員': 0.25,
            'JALグローバルクラブ会員(日本)': 0.25, 'JALグローバルクラブ会員(海外)': 0.25,
            'JALカードNAVI会員': 0.10,
            'JAL CLUB EST 普通会員': 0.10, 'JAL CLUB EST CLUB-A会員': 0.25,
            'JAL CLUB EST CLUB-A GOLD会員': 0.25, 'JAL CLUB EST プラチナ会員': 0.25,
          }[selectedJALCard ?? '-'] ?? 0.0;
          miles = flightMiles + (flightMiles * statusBonusRate).round() + (flightMiles * jalCardBonusRate).round();
          fop = (flightMiles * 2) + (jalBonusFOP[fareNumber] ?? 0);
          lsp = (fareRate >= 0.5) ? 5 : 0;
          totalFop += fop;
          totalLsp += lsp;
        } else {
          final cardBonusRate = {
            '-': 0.0, 'AMCカード(提携カード含む)': 0.0,
            'ANAカード 一般': 0.10, 'ANAカード 学生用': 0.10,
            'ANAカード ワイド': 0.25, 'ANAカード ゴールド': 0.25, 'ANAカード プレミアム': 0.50,
            'SFC 一般': 0.35, 'SFC ゴールド': 0.40, 'SFC プレミアム': 0.50,
          }[selectedANACard ?? '-'] ?? 0.0;
          final statusBonusRate = {
            '-': 0.0, 'ダイヤモンド(1年目)': 1.15, 'ダイヤモンド(継続2年以上)': 1.25,
            'プラチナ(1年目)': 0.90, 'プラチナ(継続2年以上)': 1.00,
            'ブロンズ(1年目)': 0.40, 'ブロンズ(継続2年以上)': 0.50,
          }[selectedANAStatus ?? '-'] ?? 0.0;
          final isGoldPremium = const ['ANAカード ゴールド', 'ANAカード プレミアム', 'SFC ゴールド', 'SFC プレミアム'].contains(selectedANACard ?? '-');
          final appliedRate = (isGoldPremium && statusBonusRate > 0)
              ? statusBonusRate + 0.05 : (cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate);
          miles = (distance * fareRate * (1 + appliedRate)).toInt();
          fop = (distance * fareRate * 2 + (anaBonusPoint[fareNumber] ?? 0)).toInt();
        }
        totalMiles += miles;

        legsJson.add({
          'airline': _optAirline,
          'date': _optDate,
          'flight_number': f.flightNumber,
          'departure_airport': f.departureCode,
          'arrival_airport': f.arrivalCode,
          'departure_time': f.departureTime,
          'arrival_time': f.arrivalTime,
          'fare_type': fareType,
          'seat_class': seatClass,
          'fare_amount': 0,
          'fop': fop,
          'miles': miles,
          'lsp': lsp,
        });
      }

      final title = '${airports.join("-")} ${plan.flights.length}レグ';
      await Supabase.instance.client.from('saved_itineraries').insert({
        'user_id': user!.id,
        'title': title,
        'legs': legsJson,
        'total_fop': _optAirline == 'JAL' ? totalFop : 0,
        'total_pp': _optAirline == 'ANA' ? totalFop : 0,
        'total_miles': totalMiles,
        'total_lsp': totalLsp,
        'total_fare': 0,
        'jal_card': selectedJALCard,
        'ana_card': selectedANACard,
        'jal_status': selectedJALStatus,
        'ana_status': selectedANAStatus,
        'jal_tour_premium': jalTourPremium,
        'is_completed': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$title」を予定に保存しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

'''

anchor = '  void _transferToFreeDesign(OptimalPlan plan) {'
if '_saveOptimalPlan' not in content:
    if anchor in content:
        content = content.replace(anchor, save_method + anchor)
        changes += 1
        print("✅ 4. _saveOptimalPlanメソッド追加")
    else:
        print("❌ 4. _transferToFreeDesign anchor見つからない")
else:
    print("⏭️  4. 適用済み")

# === 修正5: ボタンの onPressed を _saveOptimalPlan に変更 ===
old_btn = '_transferToFreeDesign(plan)'
new_btn = '_saveOptimalPlan(plan)'
count_btn = content.count(old_btn)
if count_btn > 0:
    content = content.replace(old_btn, new_btn)
    changes += 1
    print(f"✅ 5. ボタンを直接保存に変更 ({count_btn}箇所)")
else:
    print("❌ 5. _transferToFreeDesign(plan)が見つからない")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n完了: {changes}件の修正を適用しました → {filepath}")
