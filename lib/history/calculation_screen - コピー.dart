import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalculationScreen extends StatefulWidget {
  const CalculationScreen({super.key});

  @override
  State<CalculationScreen> createState() => _CalculationScreenState();
}

class _CalculationScreenState extends State<CalculationScreen> {
  // レグデータ（シンプルなMapで管理）
  List<Map<String, dynamic>> legs = [];
  
  // 各レグ用のコントローラー（indexをキーにして管理）
  Map<int, TextEditingController> dateControllers = {};
  Map<int, TextEditingController> flightNumberControllers = {};
  Map<int, TextEditingController> departureTimeControllers = {};
  Map<int, TextEditingController> arrivalTimeControllers = {};
  
  int _legIdCounter = 0;
  bool isLoading = false;

  // マスターデータ
  final List<String> airlines = ['JAL', 'ANA'];
  final Map<String, List<String>> fareTypesByAirline = {
    'JAL': ['ウルトラ先得', '先得割引', '特便割引', '普通運賃'],
    'ANA': ['旅割', 'ビジネスきっぷ', 'ANA VALUE', '普通運賃'],
  };
  final Map<String, List<String>> seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファースト'],
    'ANA': ['普通席', 'プレミアムクラス'],
  };
  final List<String> airports = ['HND', 'NRT', 'OKA', 'CTS', 'FUK', 'KIX', 'NGO'];

  @override
  void initState() {
    super.initState();
    _addLeg();
  }

  @override
  void dispose() {
    // 全コントローラーを破棄
    dateControllers.values.forEach((c) => c.dispose());
    flightNumberControllers.values.forEach((c) => c.dispose());
    departureTimeControllers.values.forEach((c) => c.dispose());
    arrivalTimeControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _addLeg() {
    final legId = _legIdCounter++;
    
    // コントローラーを作成
    dateControllers[legId] = TextEditingController();
    flightNumberControllers[legId] = TextEditingController();
    departureTimeControllers[legId] = TextEditingController();
    arrivalTimeControllers[legId] = TextEditingController();
    
    setState(() {
      legs.add({
        'id': legId,
        'airline': 'JAL',
        'departureAirport': '',
        'arrivalAirport': '',
        'fareType': '',
        'seatClass': '',
        'calculatedFOP': null,
        'calculatedMiles': null,
      });
    });
  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    
    // コントローラーを破棄
    dateControllers[legId]?.dispose();
    flightNumberControllers[legId]?.dispose();
    departureTimeControllers[legId]?.dispose();
    arrivalTimeControllers[legId]?.dispose();
    
    dateControllers.remove(legId);
    flightNumberControllers.remove(legId);
    departureTimeControllers.remove(legId);
    arrivalTimeControllers.remove(legId);
    
    setState(() {
      legs.removeAt(index);
    });
  }

  // 便名から時刻表データを取得
  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(
    String airline,
    String flightNumber,
  ) async {
    try {
      print('検索: airline=$airline, flightNumber=$flightNumber');
      
      final response = await Supabase.instance.client
          .from('schedules')
          .select()
          .eq('airline_code', airline)
          .eq('flight_number', flightNumber)
          .eq('is_active', true)
          .maybeSingle();

      print('DB結果: $response');
      return response;
    } catch (e) {
      print('時刻表取得エラー: $e');
      return null;
    }
  }

  // 便名入力時に自動補完
  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int;
    final airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '';
    
    print('=== 自動補完開始 ===');
    print('legId: $legId');
    print('airline: $airline');
    print('flightNumber: $flightNumber');
    
    if (flightNumber.isEmpty) {
      print('便名が空です');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('便名を入力してください')),
      );
      return;
    }

    final schedule = await _fetchScheduleByFlightNumber(airline, flightNumber);

    if (schedule != null) {
      print('補完データ: $schedule');
      
      setState(() {
        legs[index]['departureAirport'] = schedule['departure_code'];
        legs[index]['arrivalAirport'] = schedule['arrival_code'];
      });
      
      // コントローラーに時刻をセット（秒を削除）
      String depTime = schedule['departure_time'] ?? '';
      String arrTime = schedule['arrival_time'] ?? '';

      // "06:00:00" → "06:00" に変換
      if (depTime.length > 5) depTime = depTime.substring(0, 5);
      if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);

      departureTimeControllers[legId]?.text = depTime;
      arrivalTimeControllers[legId]?.text = arrTime;
      
      print('補完完了!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$flightNumber便の情報を自動入力しました')),
        );
      }
    } else {
      print('便が見つかりませんでした');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('便が見つかりませんでした')),
        );
      }
    }
    
    print('=== 自動補完終了 ===');
  }

  Future<void> _calculateFOP() async {
    setState(() => isLoading = true);

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final departureAirport = leg['departureAirport'] as String;
      final arrivalAirport = leg['arrivalAirport'] as String;
      final fareType = leg['fareType'] as String;
      final seatClass = leg['seatClass'] as String;
      final airline = leg['airline'] as String;

      if (departureAirport.isEmpty ||
          arrivalAirport.isEmpty ||
          fareType.isEmpty ||
          seatClass.isEmpty) {
        continue;
      }

      try {
        // 区間距離取得
        final routeData = await Supabase.instance.client
            .from('routes')
            .select('distance_miles')
            .eq('departure_code', departureAirport)
            .eq('arrival_code', arrivalAirport)
            .maybeSingle();

        if (routeData == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$departureAirport → $arrivalAirport のルートデータがありません')),
            );
          }
          continue;
        }

        final distance = routeData['distance_miles'] as int;

        // 運賃種別の積算率取得
        final fareData = await Supabase.instance.client
            .from('fare_types')
            .select('rate')
            .eq('airline_code', airline)
            .eq('fare_type_name', fareType)
            .maybeSingle();

        if (fareData == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$fareType の運賃データがありません')),
            );
          }
          continue;
        }

        final fareRate = (fareData['rate'] as num).toDouble();

        // FOP計算
        final baseFOP = (distance * fareRate).round();
        final bonusFOP = (baseFOP * 0.5).round();
        
        setState(() {
          legs[i]['calculatedFOP'] = baseFOP + bonusFOP;
          legs[i]['calculatedMiles'] = distance;
        });
      } catch (e) {
        print('FOP計算エラー: $e');
      }
    }

    setState(() => isLoading = false);
  }

  int get totalFOP => legs.fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get totalMiles => legs.fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修行旅程作成'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // レグ一覧
                  ...legs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final leg = entry.value;
                    return _buildLegCard(context, leg, index);
                  }),

                  const SizedBox(height: 8),

                  // ボタン行（レグ追加 + 計算）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // レグ追加ボタン
                      ElevatedButton.icon(
                        onPressed: _addLeg,
                        icon: const Icon(Icons.add),
                        label: const Text('レグを追加'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 計算ボタン
                      ElevatedButton(
                        onPressed: _calculateFOP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: const Text(
                          '計算',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 合計表示
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('合計FOP', style: TextStyle(fontSize: 12)),
                            Text(
                              '$totalFOP',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('合計マイル', style: TextStyle(fontSize: 12)),
                            Text(
                              '$totalMiles',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildLegCard(BuildContext context, Map<String, dynamic> leg, int index) {
    final legId = leg['id'] as int;
    final airline = leg['airline'] as String;
    final fareTypes = fareTypesByAirline[airline] ?? [];
    final seatClasses = seatClassesByAirline[airline] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('レグ ${index + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (legs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeLeg(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 1行目: 航空会社、日付、便名、検索ボタン
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 航空会社
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('航空会社', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: airline,
                        items: airlines.map((code) {
                          return DropdownMenuItem(value: code, child: Text(code));
                        }).toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            legs[index]['airline'] = value!;
                            legs[index]['fareType'] = '';
                            legs[index]['seatClass'] = '';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 日付
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('日付', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: dateControllers[legId],
                        decoration: const InputDecoration(
                          hintText: 'MM/DD',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // 便名
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('便名', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: flightNumberControllers[legId],
                        decoration: const InputDecoration(
                          hintText: '901',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onFieldSubmitted: (value) async {
                          await _autoFillFromFlightNumber(index);
                        },
                      ),
                    ],
                  ),
                ),

                // 検索ボタン
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: () async {
                      await _autoFillFromFlightNumber(index);
                    },
                    child: const Text('検索'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2行目: 出発地、時刻、→、到着地、時刻
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 出発地
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('出発地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: (leg['departureAirport'] as String).isEmpty ? null : leg['departureAirport'] as String,
                        items: airports.map((code) {
                          return DropdownMenuItem(value: code, child: Text(code));
                        }).toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            legs[index]['departureAirport'] = value ?? '';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 出発時刻
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: departureTimeControllers[legId],
                        decoration: const InputDecoration(
                          hintText: 'HH:MM',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // 矢印
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Icon(Icons.arrow_forward),
                ),

                // 到着地
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('到着地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: (leg['arrivalAirport'] as String).isEmpty ? null : leg['arrivalAirport'] as String,
                        items: airports.map((code) {
                          return DropdownMenuItem(value: code, child: Text(code));
                        }).toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            legs[index]['arrivalAirport'] = value ?? '';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 到着時刻
                SizedBox(
                  width: 80,//100→80に変更
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: arrivalTimeControllers[legId],
                        decoration: const InputDecoration(
                          hintText: 'HH:MM',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 3行目: 運賃種別、座席クラス、計算結果
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 運賃種別
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('運賃種別', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: fareTypes.contains(leg['fareType']) ? leg['fareType'] as String : null,
                        items: fareTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            legs[index]['fareType'] = value ?? '';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 座席クラス
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('座席クラス', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: seatClasses.contains(leg['seatClass']) ? leg['seatClass'] as String : null,
                        items: seatClasses.map((cls) {
                          return DropdownMenuItem(value: cls, child: Text(cls));
                        }).toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            legs[index]['seatClass'] = value ?? '';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 計算結果
                if (leg['calculatedFOP'] != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FOP: ${leg['calculatedFOP']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('マイル: ${leg['calculatedMiles']}'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}