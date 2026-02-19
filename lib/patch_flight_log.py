#!/usr/bin/env python3
"""
flight_log_screen.dart パッチスクリプト
使い方: python patch_flight_log.py lib/flight_log_screen.dart
"""
import sys

if len(sys.argv) < 2:
    print("使い方: python patch_flight_log.py lib/flight_log_screen.dart")
    sys.exit(1)

filepath = sys.argv[1]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

changes = 0

# === 修正1: 編集ボタン追加（シェアと削除の間） ===
old_share_delete = """                      OutlinedButton.icon(
                        onPressed: () => _shareToX(itinerary),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(l10n.share),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteItinerary(id),"""

new_share_edit_delete = """                      OutlinedButton.icon(
                        onPressed: () => _shareToX(itinerary),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(l10n.share),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showEditDialog(itinerary),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('編集'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: BorderSide(color: Colors.purple[200]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteItinerary(id),"""

if '_showEditDialog' not in content:
    if old_share_delete in content:
        content = content.replace(old_share_delete, new_share_edit_delete)
        changes += 1
        print("✅ 1. 編集ボタン追加")
    else:
        print("❌ 1. シェア/削除ボタンのパターンが見つからない")
else:
    print("⏭️  1. 編集ボタンは適用済み")

# === 修正2: 定数 + _showEditDialog メソッド追加 ===
# _buildLegSummary の直前に挿入

EDIT_DIALOG_CODE = '''
  // ========== 編集機能用定数 ==========
  static const Map<String, List<String>> _fareTypesByAirline = {
    'JAL': [
      '運賃1 (100%) フレックス等',
      '運賃2 (75%) 株主割引',
      '運賃3 (75%) セイバー',
      '運賃4 (75%) スペシャルセイバー',
      '運賃5 (50%) 包括旅行運賃',
      '運賃6 (50%) スカイメイト等',
    ],
    'ANA': [
      '運賃1 (150%) プレミアム運賃',
      '運賃2 (125%) プレミアム小児',
      '運賃3 (100%) 片道・往復',
      '運賃4 (100%) ビジネス',
      '運賃5 (75%) バリュー、株主優待',
      '運賃6 (75%) トランジット',
      '運賃7 (75%) スーパーバリュー、いっしょにマイル割',
      '運賃8 (150%) プレミアム株主',
      '運賃9 (100%) 普通株主',
      '運賃10 (70%) 特割プラス',
      '運賃11 (50%) スマートシニア',
      '運賃12 (30%) 個人包括',
    ],
  };
  static const Map<String, List<String>> _seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファーストクラス'],
    'ANA': ['普通席', 'プレミアムクラス'],
  };
  static const Map<String, int> _jalBonusFOP = {
    '運賃1': 400, '運賃2': 400, '運賃3': 200,
    '運賃4': 200, '運賃5': 0, '運賃6': 0,
  };
  static const Map<String, int> _anaBonusPoint = {
    '運賃1': 400, '運賃2': 400, '運賃3': 400, '運賃4': 0,
    '運賃5': 400, '運賃6': 200, '運賃7': 0, '運賃8': 0,
    '運賃9': 0, '運賃10': 0, '運賃11': 0, '運賃12': 0,
  };

  Future<void> _showEditDialog(Map<String, dynamic> itinerary) async {
    final id = itinerary['id'] as String;
    final legs = List<Map<String, dynamic>>.from(
      (itinerary['legs'] as List<dynamic>).map((l) => Map<String, dynamic>.from(l as Map)),
    );
    final jalCard = itinerary['jal_card'] as String?;
    final anaCard = itinerary['ana_card'] as String?;
    final jalStatus = itinerary['jal_status'] as String?;
    final anaStatus = itinerary['ana_status'] as String?;
    final jalTourPremium = itinerary['jal_tour_premium'] as bool? ?? false;

    final fareAmountControllers = legs.map((l) =>
      TextEditingController(text: (l['fare_amount'] as int? ?? 0) > 0 ? '${l['fare_amount']}' : ''),
    ).toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.purple, size: 20),
                SizedBox(width: 8),
                Text('旅程を編集', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: legs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final leg = entry.value;
                    final airline = leg['airline'] as String? ?? 'JAL';
                    final dep = leg['departure_airport'] as String? ?? '';
                    final arr = leg['arrival_airport'] as String? ?? '';
                    final fn = leg['flight_number'] as String? ?? '';
                    final fareType = leg['fare_type'] as String? ?? '';
                    final seatClass = leg['seat_class'] as String? ?? '';
                    final fareTypes = _fareTypesByAirline[airline] ?? [];
                    final seatClasses = _seatClassesByAirline[airline] ?? [];
                    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: airlineColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(airline, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(fn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Text('$dep → $arr', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: fareTypes.contains(fareType) ? fareType : null,
                            decoration: const InputDecoration(
                              labelText: '運賃種別',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 11, color: Colors.black),
                            items: fareTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(),
                            onChanged: (v) => setDialogState(() => leg['fare_type'] = v ?? ''),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: seatClasses.contains(seatClass) ? seatClass : null,
                                  decoration: const InputDecoration(
                                    labelText: '座席クラス',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black),
                                  items: seatClasses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (v) => setDialogState(() => leg['seat_class'] = v ?? ''),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: fareAmountControllers[i],
                                  decoration: const InputDecoration(
                                    labelText: '運賃(円)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    for (int i = 0; i < legs.length; i++) {
      legs[i]['fare_amount'] = int.tryParse(fareAmountControllers[i].text) ?? 0;
      fareAmountControllers[i].dispose();
    }

    if (result != true) return;

    try {
      int totalFop = 0, totalPp = 0, totalMiles = 0, totalLsp = 0, totalFare = 0;

      for (final leg in legs) {
        final airline = leg['airline'] as String? ?? 'JAL';
        final dep = leg['departure_airport'] as String? ?? '';
        final arr = leg['arrival_airport'] as String? ?? '';
        final fare = leg['fare_type'] as String? ?? '';
        final seat = leg['seat_class'] as String? ?? '';
        final fareAmount = leg['fare_amount'] as int? ?? 0;
        totalFare += fareAmount;

        if (dep.isEmpty || arr.isEmpty || fare.isEmpty) continue;

        final routeData = await Supabase.instance.client
            .from('routes')
            .select('distance_miles')
            .eq('departure_code', dep)
            .eq('arrival_code', arr)
            .maybeSingle();
        if (routeData == null) continue;
        final distance = routeData['distance_miles'] as int;

        double fareRate = 1.0;
        final rateMatch = RegExp(r'\\((\\d+)%\\)').firstMatch(fare);
        if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
        final fareNumber = fare.split(' ').first;

        int points = 0, miles = 0, lsp = 0;
        if (airline == 'JAL') {
          final seatBonusRate = {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seat] ?? 0.0;
          double effectiveFareRate = fareRate;
          if (jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5'))
            effectiveFareRate = 1.0;
          final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();
          final jalStatusBonusRate = {
            '-': 0.0,
            'JMBダイヤモンド': 1.30,
            'JMBサファイア': 1.05,
            'JMBクリスタル': 0.55,
          }[jalStatus ?? '-'] ?? 0.0;
          miles = flightMiles + (flightMiles * jalStatusBonusRate).round();
          points = (flightMiles * 2) + (_jalBonusFOP[fareNumber] ?? 0);
          lsp = (fareRate >= 0.5) ? 5 : 0;
          totalFop += points;
          totalLsp += lsp;
        } else {
          final anaCardBonusRate = {
            '-': 0.0,
            'AMCカード(提携カード含む)': 0.0,
            'ANAカード 一般': 0.10,
            'ANAカード 学生用': 0.10,
            'ANAカード ワイド': 0.25,
            'ANAカード ゴールド': 0.25,
            'ANAカード プレミアム': 0.50,
            'SFC 一般': 0.35,
            'SFC ゴールド': 0.40,
            'SFC プレミアム': 0.50,
          }[anaCard ?? '-'] ?? 0.0;
          final anaStatusBonusRate = {
            '-': 0.0,
            'ダイヤモンド(1年目)': 1.15,
            'ダイヤモンド(継続2年以上)': 1.25,
            'プラチナ(1年目)': 0.90,
            'プラチナ(継続2年以上)': 1.00,
            'ブロンズ(1年目)': 0.40,
            'ブロンズ(継続2年以上)': 0.50,
          }[anaStatus ?? '-'] ?? 0.0;
          final isGoldPremium = const [
            'ANAカード ゴールド', 'ANAカード プレミアム',
            'SFC ゴールド', 'SFC プレミアム',
          ].contains(anaCard ?? '-');
          final appliedRate = (isGoldPremium && anaStatusBonusRate > 0)
              ? anaStatusBonusRate + 0.05
              : (anaCardBonusRate > anaStatusBonusRate ? anaCardBonusRate : anaStatusBonusRate);
          miles = (distance * fareRate * (1 + appliedRate)).toInt();
          points = (distance * fareRate * 2 + (_anaBonusPoint[fareNumber] ?? 0)).toInt();
          totalPp += points;
        }
        totalMiles += miles;

        leg['fop'] = points;
        leg['miles'] = miles;
        leg['lsp'] = lsp;
      }

      await Supabase.instance.client.from('saved_itineraries').update({
        'legs': legs,
        'total_fop': totalFop,
        'total_pp': totalPp,
        'total_miles': totalMiles,
        'total_lsp': totalLsp,
        'total_fare': totalFare,
      }).eq('id', id);

      _loadItineraries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('旅程を更新しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

'''

if '_showEditDialog' not in content:
    # _buildLegSummary の直前に挿入
    anchor = '  Widget _buildLegSummary(Map<String, dynamic> leg) {'
    if anchor in content:
        content = content.replace(anchor, EDIT_DIALOG_CODE + anchor)
        changes += 1
        print("✅ 2. 編集ダイアログ + 定数追加")
    else:
        print("❌ 2. _buildLegSummary が見つからない")
else:
    print("⏭️  2. 編集ダイアログは適用済み")

# 保存
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n完了: {changes}件の修正を適用しました → {filepath}")
