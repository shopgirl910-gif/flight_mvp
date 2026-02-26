import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'pro_service.dart';
import 'dart:ui' as ui;
import 'dart:js_util' as js_util;
import 'package:flutter/rendering.dart';
import 'pro_purchase_screen.dart';
import 'pro_purchase_dialog.dart';
import 'auth_screen.dart';

class FlightLogScreen extends StatefulWidget {
  const FlightLogScreen({super.key});

  @override
  State<FlightLogScreen> createState() => FlightLogScreenState();
}

class FlightLogScreenState extends State<FlightLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> completedItineraries = [];
  List<Map<String, dynamic>> plannedItineraries = [];
  bool isLoading = true;
  String? errorMessage;
  String? _expandedId;

  // 空港コード→日本語名マップ（例: HND→羽田, OKA→那覇）
  Map<String, String> _airportNameMap = {};

  /// 空港名/コードを3レターコードに正規化
  String _normalizeAirportCode(String input) {
    if (input.isEmpty) return input;
    // 既に3レターコードならそのまま
    if (RegExp(r'^[A-Z]{3}$').hasMatch(input)) return input;

    const nameToCode = {
      '羽田': 'HND', '成田': 'NRT', '関西': 'KIX', '伊丹': 'ITM',
      '新千歳': 'CTS', '千歳': 'CTS', '福岡': 'FUK', '那覇': 'OKA',
      '中部': 'NGO', '名古屋': 'NGO', '小牧': 'NKM', '県営名古屋': 'NKM',
      '小松': 'KMQ', '鹿児島': 'KOJ', '宮崎': 'KMI', '大分': 'OIT',
      '熊本': 'KMJ', '長崎': 'NGS', '松山': 'MYJ', '高松': 'TAK',
      '高知': 'KCZ', '広島': 'HIJ', '岡山': 'OKJ', '出雲': 'IZO',
      '鳥取': 'TTJ', '秋田': 'AXT', '山形': 'GAJ', '青森': 'AOJ',
      '花巻': 'HNA', '仙台': 'SDJ', '新潟': 'KIJ', '富山': 'TOY',
      '能登': 'NTQ', '石垣': 'ISG', '宮古': 'MMY', '奄美': 'ASJ',
      '徳島': 'TKS', '北九州': 'KKJ', '佐賀': 'HSG', '対馬': 'TSJ',
      '壱岐': 'IKI', '五島': 'FUJ', '種子島': 'TNE', '屋久島': 'KUM',
      '久米島': 'UEO', '女満別': 'MMB', '旭川': 'AKJ', '釧路': 'KUH',
      '帯広': 'OBO', '函館': 'HKD', '稚内': 'WKJ', '利尻': 'RIS',
      '紋別': 'MBE', '中標津': 'SHB', '神戸': 'UKB', '南紀白浜': 'SHM',
      '但馬': 'TJH', '下地島': 'SHI', '多良間': 'TRA',
      '東京(羽田)': 'HND', '東京（羽田）': 'HND',
      '大阪(関西)': 'KIX', '大阪（関西）': 'KIX',
      '大阪(伊丹)': 'ITM', '大阪（伊丹）': 'ITM',
      '札幌(新千歳)': 'CTS', '札幌（新千歳）': 'CTS',
      '名古屋(中部)': 'NGO', '名古屋（中部）': 'NGO',
    };

    if (nameToCode.containsKey(input)) return nameToCode[input]!;
    final cleaned = input.replaceAll(' ', '');
    if (nameToCode.containsKey(cleaned)) return nameToCode[cleaned]!;

    // 括弧内抽出（「東京(羽田)」→「羽田」→HND）
    final match = RegExp(r'[（(](.+?)[）)]').firstMatch(input);
    if (match != null) {
      final inner = match.group(1)!;
      if (nameToCode.containsKey(inner)) return nameToCode[inner]!;
    }

    // _airportNameMapの逆引き
    for (final entry in _airportNameMap.entries) {
      if (entry.value == input || entry.value == cleaned) return entry.key;
    }

    return input;
  }

  /// 距離を取得（双方向検索）
  Future<int> _getRouteDistance(String departure, String arrival) async {
    if (departure.isEmpty || arrival.isEmpty) return 0;
    // 正方向
    final res = await Supabase.instance.client
        .from('routes')
        .select('distance_miles')
        .eq('departure_code', departure)
        .eq('arrival_code', arrival)
        .maybeSingle();
    if (res != null && (res['distance_miles'] as int? ?? 0) > 0) {
      return res['distance_miles'] as int;
    }
    // 逆方向フォールバック
    final rev = await Supabase.instance.client
        .from('routes')
        .select('distance_miles')
        .eq('departure_code', arrival)
        .eq('arrival_code', departure)
        .maybeSingle();
    return rev?['distance_miles'] as int? ?? 0;
  }

  // 累計統計（修行済みのみ）

  // 運賃種別・座席クラス定義
  final Map<String, List<String>> fareTypesByAirline = {
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
      '運賃2 (125%) プレミアム株主優待/VALUE PREMIUM',
      '運賃3 (100%) ANA FLEX/ビジネスきっぷ/Biz',
      '運賃4 (100%) 各種アイきっぷ',
      '運賃5 (75%) ANA VALUE/株主優待',
      '運賃6 (75%) ANA VALUE TRANSIT',
      '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割',
      '運賃8 (50%) 個人包括/スマートU25/スマートシニア/SALE',
      '運賃9 (150%) 国際航空券(PC) F/A',
      '運賃10 (100%) 国際航空券(普通) Y/B/M',
      '運賃11 (70%) 国際航空券(普通) U/H/Q',
      '運賃12 (50%) 国際航空券(普通) V/W/S',
      '運賃13 (30%) 国際航空券(普通) L/K',
    ],
  };
  final Map<String, List<String>> seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファーストクラス'],
    'ANA': ['普通席', 'プレミアムクラス'],
  };
  int totalFOP = 0;
  int totalPP = 0;
  int totalMiles = 0;
  int totalLSP = 0;
  int totalLegs = 0;
  int totalFlights = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _loadItineraries();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) _loadItineraries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void refresh() => _loadItineraries();

  /// "HND-OKA-MMY-OKA-HND 8レグ" → "羽田-那覇-宮古-那覇-羽田 8レグ"
  String _titleToJapanese(String title) {
    if (_airportNameMap.isEmpty) return title;
    // タイトル末尾の " Nレグ" 部分を分離
    final legMatch = RegExp(r'(\s+\d+レグ)$').firstMatch(title);
    final routePart = legMatch != null ? title.substring(0, legMatch.start) : title;
    final legSuffix = legMatch != null ? legMatch.group(0)! : '';
    // 各空港コードを日本語名に変換
    final converted = routePart.split('-').map((code) {
      return _airportNameMap[code] ?? code;
    }).join('-');
    return '$converted$legSuffix';
  }

  void showPlannedTab({String? expandId}) {
    _loadItineraries().then((_) {
      if (expandId != null) {
        setState(() => _expandedId = expandId);
      }
    });
    _tabController.animateTo(1);
  }

  void showCompletedTab({String? expandId}) {
    _loadItineraries().then((_) {
      if (expandId != null) {
        setState(() => _expandedId = expandId);
      }
    });
    _tabController.animateTo(0);
  }

  Future<void> _loadItineraries() async {
    setState(() => isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        setState(() {
          completedItineraries = [];
          plannedItineraries = [];
          _resetTotals();
          isLoading = false;
          errorMessage = null;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('saved_itineraries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // 空港名マップを取得（未取得の場合のみ）
      if (_airportNameMap.isEmpty) {
        try {
          final airports = await Supabase.instance.client
              .from('airports')
              .select('code, name_ja');
          for (final a in airports) {
            final code = a['code'] as String? ?? '';
            final nameJa = a['name_ja'] as String? ?? '';
            if (code.isNotEmpty && nameJa.isNotEmpty) {
              // "東京（羽田）" → "羽田", "大阪（関西）" → "関西" のように括弧内を使う
              final match = RegExp(r'[（(](.+?)[）)]').firstMatch(nameJa);
              _airportNameMap[code] = match != null ? match.group(1)! : nameJa;
            }
          }
        } catch (_) {
          // 取得失敗してもコード表示のままフォールバック
        }
      }

      final list = List<Map<String, dynamic>>.from(response);

      final completed = list.where((it) => it['is_completed'] == true).toList();
      final planned = list.where((it) => it['is_completed'] != true).toList();

      _calculateTotals(completed);

      setState(() {
        completedItineraries = completed;
        plannedItineraries = planned;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'データの読み込みに失敗しました: $e';
      });
    }
  }

  void _resetTotals() {
    totalFOP = 0;
    totalPP = 0;
    totalMiles = 0;
    totalLSP = 0;
    totalLegs = 0;
    totalFlights = 0;
    _jalMiles = 0;
    _jalLegs = 0;
    _anaMiles = 0;
    _anaLegs = 0;
  }

  // JAL/ANA別の統計
  int _jalMiles = 0;
  int _jalLegs = 0;
  int _anaMiles = 0;
  int _anaLegs = 0;

  void _calculateTotals(List<Map<String, dynamic>> list) {
    _resetTotals();
    for (var it in list) {
      totalFOP += (it['total_fop'] as int?) ?? 0;
      totalPP += (it['total_pp'] as int?) ?? 0;
      totalMiles += (it['total_miles'] as int?) ?? 0;
      totalLSP += (it['total_lsp'] as int?) ?? 0;
      final legs = it['legs'] as List<dynamic>? ?? [];
      totalLegs += legs.length;

      // JAL/ANA別にカウント
      for (var leg in legs) {
        final l = leg as Map<String, dynamic>;
        final airline = l['airline'] as String? ?? '';
        final miles = l['miles'] as int? ?? 0;
        if (airline == 'JAL') {
          _jalMiles += miles;
          _jalLegs++;
        } else if (airline == 'ANA') {
          _anaMiles += miles;
          _anaLegs++;
        }
      }
    }
    totalFlights = list.length;
  }

  Future<void> _markAsCompleted(String id) async {
    try {
      await Supabase.instance.client
          .from('saved_itineraries')
          .update({'is_completed': true})
          .eq('id', id);
      _loadItineraries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('修行済みに移動しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移動に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteItinerary(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text(l10n.deleteItineraryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('saved_itineraries')
            .delete()
            .eq('id', id);
        _loadItineraries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleted),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteFailed(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // メールから入力（Pro版限定）
  Future<void> _showEmailImportDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null && user.email != null && user.email!.isNotEmpty;

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メールから入力するにはログインが必要です'),
            backgroundColor: Colors.orange,
          ),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              onAuthSuccess: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _showEmailImportDialogInternal();
                });
              },
            ),
          ),
        );
      }
      return;
    }

    _showEmailImportDialogInternal();
  }

  Future<void> _showEmailImportDialogInternal() async {
    final isPro = await ProService().isPro();
    
    if (!isPro) {
      if (mounted) {
        await showProPurchaseDialog(context);
      }
      return;
    }

    final controller = TextEditingController();
    if (!mounted) return;
    
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.email, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('メールから入力', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JAL/ANAの予約確認メールを貼り付けてください（AI解析）',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'メール本文をここに貼り付け...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) {
                          setDialogState(() => errorMsg = 'メール本文を貼り付けてください');
                          return;
                        }
                        setDialogState(() {
                          isLoading = true;
                          errorMsg = null;
                        });
                        try {
                          final response = await Supabase.instance.client.functions.invoke(
                            'swift-endpoint',
                            body: {'emailText': controller.text},
                          );
                          if (response.status != 200) {
                            throw Exception(response.data['error'] ?? '解析に失敗しました');
                          }
                          final data = response.data as Map<String, dynamic>;
                          final parsedLegs = (data['legs'] as List<dynamic>)
                              .map((e) => Map<String, dynamic>.from(e as Map))
                              .map((l) {
                                final airline = l['airline'] as String? ?? 'JAL';
                                var flightNum = (l['flight_number'] ?? '').toString();
                                if (flightNum.isNotEmpty && RegExp(r'^\d+$').hasMatch(flightNum)) {
                                  flightNum = '$airline$flightNum';
                                }
                                return {
                                  'airline': airline,
                                  'date': l['date'],
                                  'flightNumber': flightNum,
                                  'departure': _normalizeAirportCode((l['departure'] ?? '').toString()),
                                  'arrival': _normalizeAirportCode((l['arrival'] ?? '').toString()),
                                  'departureTime': l['departure_time'] ?? '',
                                  'arrivalTime': l['arrival_time'] ?? '',
                                  'seatClass': (l['seat_class'] == 'ファースト') ? 'ファーストクラス' : (l['seat_class'] ?? '普通席'),
                                  'fareType': _mapFareType(airline, l['fare_type'] as String? ?? ''),
                                  'fare': l['fare'] ?? 0,
                                };
                              })
                              .toList();
                          if (dialogContext.mounted) Navigator.pop(dialogContext, parsedLegs);
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            errorMsg = 'AI解析エラー: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('AI解析', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
    final emailText = controller.text;
    controller.dispose();

    if (result != null && result.isNotEmpty) {
      await _saveEmailImportResult(result, emailText: emailText);
    } else if (result != null && result.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フライト情報が見つかりませんでした'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  String _mapFareType(String airline, String rawFareType) {
    if (airline == 'JAL') {
      final fareTypes = fareTypesByAirline['JAL']!;
      for (final ft in fareTypes) {
        if (ft.contains(rawFareType) || rawFareType.contains(ft.split(' ').last)) {
          return ft;
        }
      }
      if (rawFareType.contains('セイバー') || rawFareType.contains('saver')) return fareTypes[3];
      if (rawFareType.contains('株主')) return fareTypes[1];
      return fareTypes[3]; // デフォルト: スペシャルセイバー
    } else {
      final fareTypes = fareTypesByAirline['ANA']!;
      for (final ft in fareTypes) {
        if (ft.contains(rawFareType) || rawFareType.contains(ft.split(' ').last)) {
          return ft;
        }
      }
      if (rawFareType.contains('SUPER VALUE') || rawFareType.contains('いっしょにマイル')) return fareTypes[6];
      if (rawFareType.contains('VALUE')) return fareTypes[4];
      if (rawFareType.contains('株主')) return fareTypes[4];
      return fareTypes[6]; // デフォルト: ANA SUPER VALUE
    }
  }

  /// レグの日付が過去かどうか判定（複数フォーマット対応）
  bool _isLegDatePast(Map<String, dynamic> leg) {
    final dateStr = leg['date'] as String? ?? '';
    if (dateStr.isEmpty) return false;
    final parsed = _parseDateFlexible(dateStr);
    if (parsed == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return parsed.isBefore(todayOnly);
  }

  /// 複数の日付フォーマットに対応するパーサー
  DateTime? _parseDateFlexible(String dateStr) {
    if (dateStr.isEmpty) return null;
    final s = dateStr.trim();
    try {
      // 1) "2024年11月7日" / "2024年11月07日（木）" 形式
      final jaMatch = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(s);
      if (jaMatch != null) {
        return DateTime(
          int.parse(jaMatch.group(1)!),
          int.parse(jaMatch.group(2)!),
          int.parse(jaMatch.group(3)!),
        );
      }

      // 2) "2024/11/07" or "2024-11-07" 形式
      final normalized = s.replaceAll('-', '/');
      final parts = normalized.split('/');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        if (y > 1900 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }

      // 3) ISO 8601 フォールバック
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveEmailImportResult(List<Map<String, dynamic>> legs, {String emailText = ''}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // ── 運賃按分処理 ──

      // 1. 人数検出（厳密なパターンのみ）
      int passengerCount = 1;

      // パターン1: 「大人：3名」「小人：1名」等の明示的な人数表記
      final adultMatch = RegExp(r'大人[：:]\s*(\d+)名').firstMatch(emailText);
      final childMatch = RegExp(r'小[人児][：:]\s*(\d+)名').firstMatch(emailText);
      if (adultMatch != null || childMatch != null) {
        passengerCount = (adultMatch != null ? int.parse(adultMatch.group(1)!) : 0)
            + (childMatch != null ? int.parse(childMatch.group(1)!) : 0);
      }

      // パターン2: 「＜お客様氏名＞」セクション内の「様」カウント
      if (passengerCount <= 1) {
        final nameSection = RegExp(r'お客様氏名[＞>）\)]?([\s\S]*?)(?:＜|<|予約番号|フライト詳細)')
            .firstMatch(emailText);
        if (nameSection != null) {
          final section = nameSection.group(1) ?? '';
          final samaCount = RegExp(r'様').allMatches(section).length;
          if (samaCount >= 2) {
            passengerCount = samaCount;
          }
        }
      }

      debugPrint('👥 検出搭乗者数: $passengerCount名');

      // 2. 人数按分（「N名×金額」は1人分なので割らない、それ以外は全員分→割る）
      final hasPerPersonFormat = RegExp(r'\d+名[×x]').hasMatch(emailText);
      if (passengerCount >= 2 && !hasPerPersonFormat) {
        for (final leg in legs) {
          final fare = leg['fare'] as int? ?? 0;
          if (fare > 0) {
            final perPerson = (fare / passengerCount).round();
            leg['fare'] = perPerson;
          }
        }
        debugPrint('👥 合計表記 → 運賃を$passengerCount名で按分');
      } else if (passengerCount >= 2) {
        debugPrint('👥 N名×金額表記 → 按分なし');
      }

      // 3. 往復按分: 全レグ同一運賃 + メールに「往復」→ レグ数で割る
      if (legs.length >= 2 && emailText.contains('往復')) {
        final fares = legs.map((l) => l['fare'] as int? ?? 0).toList();
        final allSame = fares.every((f) => f == fares.first) && fares.first > 0;
        if (allSame) {
          final perLeg = (fares.first / legs.length).round();
          debugPrint('💰 往復運賃按分: ${fares.first}円 ÷ ${legs.length}レグ = $perLeg円/レグ');
          for (final leg in legs) {
            leg['fare'] = perLeg;
          }
        }
      }

      // ユーザープロファイルを取得
      final profileRes = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final profile = profileRes ?? {};
      final jalStatus = profile['jal_status'] as String? ?? '-';
      final jalCardType = profile['jal_card_type'] as String? ?? '-';
      final jalTourPremium = profile['jal_tour_premium'] as bool? ?? false;
      final anaStatus = profile['ana_status'] as String? ?? '-';
      final anaCardType = profile['ana_card_type'] as String? ?? '-';

      // 各レグのFOP/PP/マイルを計算
      final processedLegs = <Map<String, dynamic>>[];
      for (final leg in legs) {
        final airline = leg['airline'] as String;
        final departure = _normalizeAirportCode(leg['departure'] as String? ?? '');
        final arrival = _normalizeAirportCode(leg['arrival'] as String? ?? '');
        final fareType = leg['fareType'] as String? ?? '';
        final seatClass = leg['seatClass'] as String? ?? '普通席';
        final fare = leg['fare'] as int? ?? 0;

        // 距離を取得（双方向検索）
        final distance = await _getRouteDistance(departure, arrival);

        debugPrint('  📏 $departure→$arrival distance=$distance');

        final calculated = _calculateLeg(
          airline: airline,
          baseMiles: distance,
          fareType: fareType,
          seatClass: seatClass,
          jalStatus: jalStatus,
          jalCard: jalCardType,
          jalTourPremium: jalTourPremium,
          anaStatus: anaStatus,
          anaCard: anaCardType,
        );

        final fop = calculated['fop'] ?? 0;
        final miles = calculated['miles'] ?? 0;
        final lsp = calculated['lsp'] ?? 0;

        processedLegs.add({
          'airline': airline,
          'departure_airport': departure,
          'arrival_airport': arrival,
          'flight_number': leg['flightNumber'] ?? '',
          'date': leg['date'] ?? '',
          'departure_time': leg['departureTime'] ?? '',
          'arrival_time': leg['arrivalTime'] ?? '',
          'fare_type': fareType,
          'seat_class': seatClass,
          'fare_amount': fare,
          'fop': fop,
          'miles': miles,
          'lsp': lsp,
          'distance': distance,
        });
      }

      // 過去日付と未来日付でレグを分離
      final pastLegs = processedLegs.where((l) => _isLegDatePast(l)).toList();
      final futureLegs = processedLegs.where((l) => !_isLegDatePast(l)).toList();

      debugPrint('📧 メール解析結果: 全${processedLegs.length}レグ → 過去${pastLegs.length} / 未来${futureLegs.length}');
      for (final l in processedLegs) {
        debugPrint('  ${l['departure_airport']}→${l['arrival_airport']} date="${l['date']}" isPast=${_isLegDatePast(l)}');
      }

      int savedCount = 0;
      int completedCount = 0;
      int plannedCount = 0;
      String? lastSavedId;
      String? completedId;
      String? plannedId;

      // --- 過去日付レグ → 修行済みとして保存 ---
      if (pastLegs.isNotEmpty) {
        completedId = await _saveItineraryGroup(user.id, pastLegs, isCompleted: true);
        completedCount = pastLegs.length;
        savedCount += completedCount;

        // Paint it Black連携: 空港チェックイン自動登録
        await _registerAirportCheckins(user.id, pastLegs);
      }

      // --- 未来日付レグ → 予定として保存 ---
      if (futureLegs.isNotEmpty) {
        plannedId = await _saveItineraryGroup(user.id, futureLegs, isCompleted: false);
        plannedCount = futureLegs.length;
        savedCount += plannedCount;
      }

      // タブ遷移ロジック:
      //   過去のみ → 修行済みタブ
      //   未来のみ → 予定タブ
      //   混在     → 予定タブ
      final int targetTab;
      if (futureLegs.isNotEmpty) {
        targetTab = 1; // 予定タブ
        lastSavedId = plannedId;
      } else {
        targetTab = 0; // 修行済みタブ
        lastSavedId = completedId;
      }

      if (mounted) {
        // フィードバックメッセージ
        final messages = <String>[];
        if (completedCount > 0) messages.add('$completedCountレグを修行済みに登録');
        if (plannedCount > 0) messages.add('$plannedCountレグを予定に登録');
        final msg = messages.join('、');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $msg しました${completedCount > 0 ? '（🗾 Paint it Black反映）' : ''}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadItineraries();
        _tabController.animateTo(targetTab);
        if (lastSavedId != null) {
          setState(() => _expandedId = lastSavedId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// レグ群を1つの旅程として保存
  Future<String> _saveItineraryGroup(
    String userId,
    List<Map<String, dynamic>> legs, {
    required bool isCompleted,
  }) async {
    int totalFop = 0;
    int totalPp = 0;
    int totalMiles = 0;
    int totalLsp = 0;
    int totalFare = 0;

    for (final l in legs) {
      final airline = l['airline'] as String? ?? '';
      final fop = l['fop'] as int? ?? 0;
      final miles = l['miles'] as int? ?? 0;
      final lsp = l['lsp'] as int? ?? 0;
      final fare = l['fare_amount'] as int? ?? 0;

      if (airline == 'JAL') {
        totalFop += fop;
      } else {
        totalPp += fop;
      }
      totalMiles += miles;
      totalLsp += lsp;
      totalFare += fare;
    }

    // タイトル生成
    final routeCodes = legs.map((l) => l['departure_airport']).toList();
    if (legs.isNotEmpty) routeCodes.add(legs.last['arrival_airport']);
    final title = '${routeCodes.join('-')} ${legs.length}レグ';

    final response = await Supabase.instance.client.from('saved_itineraries').insert({
      'user_id': userId,
      'title': title,
      'legs': legs,
      'total_fop': totalFop,
      'total_pp': totalPp,
      'total_miles': totalMiles,
      'total_lsp': totalLsp,
      'total_fare': totalFare,
      'is_completed': isCompleted,
    }).select().single();

    return response['id'] as String;
  }

  /// Paint it Black連携: 修行済みフライトの空港をチェックイン登録
  Future<void> _registerAirportCheckins(
    String userId,
    List<Map<String, dynamic>> completedLegs,
  ) async {
    try {
      // 全レグの出発地・到着地を収集（重複排除）
      final airportCodes = <String>{};
      for (final l in completedLegs) {
        final dep = l['departure_airport'] as String? ?? '';
        final arr = l['arrival_airport'] as String? ?? '';
        if (dep.isNotEmpty) airportCodes.add(dep);
        if (arr.isNotEmpty) airportCodes.add(arr);
      }
      if (airportCodes.isEmpty) return;

      // 既にチェックイン済みの空港を取得
      final existing = await Supabase.instance.client
          .from('airport_checkins')
          .select('airport_code')
          .eq('user_id', userId);

      final existingCodes =
          (existing as List).map((e) => e['airport_code'] as String).toSet();

      // 未チェックインの空港のみ対象
      final newAirports = airportCodes.difference(existingCodes);
      if (newAirports.isEmpty) return;

      // 空港の緯度経度を取得
      final airports = await Supabase.instance.client
          .from('airports')
          .select('code, latitude, longitude')
          .inFilter('code', newAirports.toList());

      final airportMap = <String, Map<String, dynamic>>{};
      for (final a in (airports as List)) {
        airportMap[a['code'] as String] = Map<String, dynamic>.from(a);
      }

      // バッチINSERT
      final checkins = <Map<String, dynamic>>[];
      for (final code in newAirports) {
        final airport = airportMap[code];
        // フライト日付を取得（該当空港を含む最初のレグ）
        final relatedLeg = completedLegs.firstWhere(
          (l) => l['departure_airport'] == code || l['arrival_airport'] == code,
          orElse: () => completedLegs.first,
        );
        final rawDate = relatedLeg['date'] as String? ?? '';
        final parsedDate = _parseDateFlexible(rawDate);
        final dateIso = parsedDate != null
            ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
            : '';

        checkins.add({
          'user_id': userId,
          'airport_code': code,
          'checkin_at': dateIso.isNotEmpty
              ? '${dateIso}T12:00:00+09:00'
              : DateTime.now().toIso8601String(),
          'checkin_date': dateIso.isNotEmpty ? dateIso : null,
          'latitude': airport?['latitude'] ?? 0.0,
          'longitude': airport?['longitude'] ?? 0.0,
        });
      }

      if (checkins.isNotEmpty) {
        await Supabase.instance.client.from('airport_checkins').insert(checkins);
      }
    } catch (e) {
      // チェックイン登録失敗は旅程保存に影響させない
      debugPrint('Paint it Black チェックイン登録エラー: $e');
    }
  }

  Future<void> _exportCsv(Map<String, dynamic> itinerary) async {
    // Pro判定
    final isPro = await ProService().isPro();
    if (!isPro) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pro版限定機能'),
          content: const Text('CSVエクスポートはPro版の機能です。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProPurchaseScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Pro版を見る'),
            ),
          ],
        ),
      );
      return;
    }

    final buf = StringBuffer();
    buf.write('\uFEFF');
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    final hasJal = legs.any(
      (l) => (l as Map<String, dynamic>)['airline'] == 'JAL',
    );

    buf.writeln(
      hasJal
          ? '航空会社,日付,便名,出発空港,到着空港,出発時刻,到着時刻,運賃種別,座席クラス,運賃(円),FOP/PP,マイル,LSP'
          : '航空会社,日付,便名,出発空港,到着空港,出発時刻,到着時刻,運賃種別,座席クラス,運賃(円),PP,マイル',
    );

    for (var leg in legs) {
      final l = leg as Map<String, dynamic>;
      final airline = l['airline'] ?? '';
      final date = l['date'] ?? '';
      final flightNum = l['flight_number'] ?? '';
      final dep = l['departure_airport'] ?? '';
      final arr = l['arrival_airport'] ?? '';
      final depTime = l['departure_time'] ?? '';
      final arrTime = l['arrival_time'] ?? '';
      final fareType = (l['fare_type'] as String? ?? '').replaceAll(',', ' ');
      final seatClass = l['seat_class'] ?? '';
      final fare = l['fare_amount'] ?? 0;
      final fop = l['fop'] ?? 0;
      final miles = l['miles'] ?? 0;
      final lsp = l['lsp'] ?? 0;
      buf.writeln(
        hasJal
            ? '$airline,$date,$flightNum,$dep,$arr,$depTime,$arrTime,$fareType,$seatClass,$fare,$fop,$miles,$lsp'
            : '$airline,$date,$flightNum,$dep,$arr,$depTime,$arrTime,$fareType,$seatClass,$fare,$fop,$miles',
      );
    }

    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final title = (itinerary['title'] as String? ?? 'flight_log').replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-]'),
      '_',
    );
    final now = DateTime.now();
    final filename =
        'MRP_${title}_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.csv';
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSVをダウンロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _shareToX(Map<String, dynamic> itinerary) {
    showDialog(
      context: context,
      builder: (context) => _ShareDialog(itinerary: itinerary, airportNameMap: _airportNameMap),
    );
  }

  String _formatNumber(int number) {
    if (number == 0) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  // 日付をyy/mm/dd形式で表示
  String _formatDateShort(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      // 2026/01/21 or 2026-01-21 形式に対応
      final normalized = dateStr.replaceAll('-', '/');
      final parts = normalized.split('/');
      if (parts.length == 3) {
        final year = parts[0].length == 4 ? parts[0].substring(2) : parts[0];
        return '$year/${parts[1]}/${parts[2]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  DateTime? _getFirstLegDate(Map<String, dynamic> itinerary) {
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    if (legs.isEmpty) return null;
    final firstLeg = legs.first as Map<String, dynamic>;
    final dateStr = firstLeg['date'] as String?;
    if (dateStr == null || dateStr.isEmpty) return null;
    return _parseDateFlexible(dateStr);
  }

  bool _isPastDate(Map<String, dynamic> itinerary) {
    final date = _getFirstLegDate(itinerary);
    if (date == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return date.isBefore(todayOnly);
  }

  bool _hasDate(Map<String, dynamic> itinerary) {
    return _getFirstLegDate(itinerary) != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadItineraries,
              child: Text(l10n.reload),
            ),
          ],
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;

    if (!isLoggedIn) {
      return _buildNotLoggedInView(l10n);
    }

    return Column(
      children: [
        Container(
          color: Colors.purple[50],
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.purple[700],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.purple[700],
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text('修行済み (${completedItineraries.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 6),
                    Text('予定 (${plannedItineraries.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildCompletedTab(l10n), _buildPlannedTab(l10n)],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTab(AppLocalizations l10n) {
    if (completedItineraries.isEmpty) {
      return Column(
        children: [
          // メールから入力ボタン（修行済みタブ）
          _buildEmailImportButton(),
          Expanded(
            child: _buildEmptyTabView('修行済みの旅程はありません', Icons.flight_land),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItineraries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return CustomScrollView(
            slivers: [
              // メールから入力ボタン（修行済みタブ）
              SliverToBoxAdapter(child: _buildEmailImportButton()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 0),
                  child: _buildSummaryCard(l10n, isMobile),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItineraryCard(
                      completedItineraries[index],
                      isMobile,
                      isCompleted: true,
                    ),
                    childCount: completedItineraries.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlannedTab(AppLocalizations l10n) {
    if (plannedItineraries.isEmpty) {
      return Column(
        children: [
          // メールから入力ボタン
          _buildEmailImportButton(),
          Expanded(
            child: _buildEmptyTabView(
              '予定の旅程はありません\nシミュレーションから追加してください',
              Icons.flight_takeoff,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItineraries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return CustomScrollView(
            slivers: [
              // メールから入力ボタン
              SliverToBoxAdapter(child: _buildEmailImportButton()),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItineraryCard(
                      plannedItineraries[index],
                      isMobile,
                      isCompleted: false,
                    ),
                    childCount: plannedItineraries.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  /// 「予約メールから入力」共通ボタン（修行済み・予定タブ両方で使用）
  Widget _buildEmailImportButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showEmailImportDialog,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email, size: 18),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Pro', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          label: const Text('予約メールから入力'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTabView(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedInView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff,
                size: 48,
                color: Colors.purple[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.loginRequiredToSaveItineraries,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loginFromTopRight,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n, bool isMobile) {
    final hasJAL = totalFOP > 0 || _jalLegs > 0;
    final hasANA = totalPP > 0 || _anaLegs > 0;

    // JALのみ
    if (hasJAL && !hasANA) {
      return _buildSingleAirlineSummary(
        l10n,
        isMobile,
        isJAL: true,
        points: totalFOP,
        miles: _jalMiles,
        lsp: totalLSP,
        legs: _jalLegs,
      );
    }

    // ANAのみ
    if (hasANA && !hasJAL) {
      return _buildSingleAirlineSummary(
        l10n,
        isMobile,
        isJAL: false,
        points: totalPP,
        miles: _anaMiles,
        lsp: 0,
        legs: _anaLegs,
      );
    }

    // 混在: 上下分割
    return Column(
      children: [
        // JAL（赤）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[700]!, Colors.red[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.yellow,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'JAL 修行実績',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: isMobile ? 16 : 32,
                runSpacing: 8,
                children: [
                  _buildStatItemInline('FOP', totalFOP),
                  _buildStatItemInline(l10n.miles, _jalMiles),
                  _buildStatItemInline(l10n.legs, _jalLegs),
                  if (totalLSP > 0) _buildStatItemInline('LSP', totalLSP),
                ],
              ),
            ],
          ),
        ),
        // ANA（青）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.yellow,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ANA 修行実績',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: isMobile ? 16 : 32,
                runSpacing: 8,
                children: [
                  _buildStatItemInline('PP', totalPP),
                  _buildStatItemInline(l10n.miles, _anaMiles),
                  _buildStatItemInline(l10n.legs, _anaLegs),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItemInline(String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
        ),
        Text(
          _formatNumber(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleAirlineSummary(
    AppLocalizations l10n,
    bool isMobile, {
    required bool isJAL,
    required int points,
    required int miles,
    required int lsp,
    required int legs,
  }) {
    final colors = isJAL
        ? [Colors.red[700]!, Colors.red[500]!]
        : [Colors.blue[700]!, Colors.blue[500]!];
    final shadowColor = isJAL ? Colors.red : Colors.blue;
    final pointLabel = isJAL ? 'FOP' : 'PP';
    final airlineName = isJAL ? 'JAL' : 'ANA';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.yellow, size: 24),
              const SizedBox(width: 8),
              Text(
                '$airlineName 修行実績',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: isMobile ? 16 : 32,
            runSpacing: 12,
            children: [
              _buildStatItem(pointLabel, points),
              _buildStatItem(l10n.miles, miles),
              _buildStatItem(l10n.legs, legs),
              if (isJAL && lsp > 0) _buildStatItem('LSP', lsp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          _formatNumber(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItineraryCard(
    Map<String, dynamic> itinerary,
    bool isMobile, {
    required bool isCompleted,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final id = itinerary['id'] as String;
    final title = _titleToJapanese(itinerary['title'] as String? ?? l10n.untitled);
    final totalFop = itinerary['total_fop'] as int? ?? 0;
    final totalPp = itinerary['total_pp'] as int? ?? 0;
    final totalMiles = itinerary['total_miles'] as int? ?? 0;
    final totalLsp = itinerary['total_lsp'] as int? ?? 0;
    final totalFare = itinerary['total_fare'] as int? ?? 0;
    final createdAt = _formatDate(itinerary['created_at'] as String?);
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    final isExpanded = _expandedId == id;

    final isPast = _isPastDate(itinerary);
    final hasDate = _hasDate(itinerary);

    String unitPrice = '-';
    if (totalFare > 0 && (totalFop > 0 || totalPp > 0)) {
      // レグ運賃の入力状況を確認
      int legFareSum = 0;
      int legFareCount = 0;
      int farePointsSum = 0;
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final legFare = legMap['fare_amount'] as int? ?? 0;
        if (legFare > 0) {
          legFareSum += legFare;
          legFareCount++;
          farePointsSum += (legMap['pp'] as int? ?? 0) > 0
              ? (legMap['pp'] as int? ?? 0)
              : (legMap['fop'] as int? ?? 0);
        }
      }

      if (legFareCount == 0 && totalFare > 0) {
        // 旅程総額入力モード: total_fareを全レグのポイント合計で割る
        final allPoints = totalFop > 0 ? totalFop : totalPp;
        if (allPoints > 0) {
          unitPrice = '¥${(totalFare / allPoints).toStringAsFixed(1)}';
        }
      } else if (legFareCount == legs.length && farePointsSum > 0) {
        // 全レグ運賃入力モード: 合算して単価表示
        unitPrice = '¥${(legFareSum / farePointsSum).toStringAsFixed(1)}';
      }
      // 一部レグのみ入力: 旅程単価は表示しない（unitPrice = '-'のまま）
    }

    String dateDisplay = createdAt;
    Widget? dateBadge;
    if (!isCompleted) {
      if (!hasDate) {
        dateBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '📅 予定',
            style: TextStyle(fontSize: 10, color: Colors.purple[700]),
          ),
        );
      } else if (isPast) {
        dateBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '過去日付',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandedId = isExpanded ? null : id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dateBadge != null) ...[
                        dateBadge,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        dateDisplay,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (totalFop > 0)
                        _buildStatChip(
                          'FOP',
                          _formatNumber(totalFop),
                          Colors.red,
                        ),
                      if (totalPp > 0)
                        _buildStatChip(
                          'PP',
                          _formatNumber(totalPp),
                          Colors.blue,
                        ),
                      _buildStatChip(
                        l10n.miles,
                        _formatNumber(totalMiles),
                        Colors.orange,
                      ),
                      if (totalLsp > 0)
                        _buildStatChip(
                          'LSP',
                          _formatNumber(totalLsp),
                          Colors.purple,
                        ),
                      if (totalFare > 0)
                        _buildStatChip(
                          '',
                          '¥${_formatNumber(totalFare)}',
                          Colors.green,
                        ),
                      if (unitPrice != '-')
                        _buildUnitPriceChip(
                          unitPrice,
                          totalFop > 0 ? 'FOP' : 'PP',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isCompleted && isPast) ...[
            Container(height: 1, color: Colors.grey[200]),
            InkWell(
              onTap: () => _markAsCompleted(id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green[600]!, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '搭乗済み → 修行済みに移動',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (isExpanded) ...[
            Container(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...legs.map(
                    (leg) => _buildLegSummary(leg as Map<String, dynamic>),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportCsv(itinerary),
                        icon: const Icon(Icons.download, size: 16),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('CSV'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple[700],
                          side: BorderSide(color: Colors.purple[200]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _shareToX(itinerary),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(l10n.share),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showItineraryEditDialog(itinerary),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('編集'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple[700],
                          side: BorderSide(color: Colors.purple[200]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteItinerary(id),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(l10n.delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red[200]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitPriceChip(String value, String pointType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow[600]!, width: 0.5),
      ),
      child: Text(
        '$value/$pointType',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.yellow[900],
        ),
      ),
    );
  }

  Widget _buildLegSummary(Map<String, dynamic> leg) {
    final airline = leg['airline'] as String? ?? '';
    final dep = leg['departure_airport'] as String? ?? '';
    final arr = leg['arrival_airport'] as String? ?? '';
    final flightNumber = leg['flight_number'] as String? ?? '';
    final date = leg['date'] as String? ?? '';
    final depTime = leg['departure_time'] as String? ?? '';
    final arrTime = leg['arrival_time'] as String? ?? '';
    final fop = leg['fop'] as int? ?? 0;
    final miles = leg['miles'] as int? ?? 0;
    final lsp = leg['lsp'] as int? ?? 0;
    final fareAmount = leg['fare_amount'] as int? ?? 0;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final pointLabel = airline == 'JAL' ? 'FOP' : 'PP';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 行1: 日付 便名 出発地 出発時刻 → 到着地 到着時刻
          Row(
            children: [
              if (date.isNotEmpty) ...[
                Text(
                  _formatDateShort(date),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
              ],
              SizedBox(
                width: 46,
                child: Text(
                  flightNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: airlineColor,
                  ),
                ),
              ),
              Text(dep, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              if (depTime.isNotEmpty)
                Text(' $depTime', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
              ),
              Text(arr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              if (arrTime.isNotEmpty)
                Text(' $arrTime', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 2),
          // 行2: FOP/PP マイル LSP
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Text(
                  '$pointLabel ${_formatNumber(fop)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: airlineColor),
                ),
                const SizedBox(width: 8),
                Text(
                  'マイル ${_formatNumber(miles)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
                if (airline == 'JAL' && lsp > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${lsp}LSP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple[700]),
                  ),
                ],
              ],
            ),
          ),
          // 行3（運賃入力済みレグのみ）: 運賃・単価
          if (fareAmount > 0 && fop > 0) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '¥${_formatNumber(fareAmount)}'
                '  ${(fareAmount / fop).toStringAsFixed(1)}円/$pointLabel'
                '${miles > 0 ? "  ${(fareAmount / miles).toStringAsFixed(1)}円/マイル" : ""}',
                style: TextStyle(fontSize: 10, color: Colors.green[700]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 旅程全体の編集ダイアログ（全レグ一覧形式）
  Future<void> _showItineraryEditDialog(Map<String, dynamic> itinerary) async {
    final itineraryId = itinerary['id'];
    final title = _titleToJapanese(itinerary['title'] as String? ?? '');

    // 編集用にレグをコピー
    List<Map<String, dynamic>> editableLegs = List<Map<String, dynamic>>.from(
      (itinerary['legs'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    // 削除予定のインデックスを追跡
    Set<int> deletedIndices = {};

    // 旅程総額の初期値を判定
    // レグに運賃が入っている → レグ入力モード
    // total_fareがあるがレグ運賃が全て0 → 旅程総額モード
    final existingTotalFare = itinerary['total_fare'] as int? ?? 0;
    final hasAnyLegFare = editableLegs.any(
      (l) => (l['fare_amount'] as int? ?? 0) > 0,
    );
    int itineraryFareAmount = (!hasAnyLegFare && existingTotalFare > 0)
        ? existingTotalFare
        : 0;
    final itineraryFareController = TextEditingController(
      text: itineraryFareAmount > 0 ? '$itineraryFareAmount' : '',
    );

    // レグ運賃用のcontrollerを事前生成（rebuild時の再生成を防止）
    final legFareControllers = List.generate(editableLegs.length, (i) {
      final fare = editableLegs[i]['fare_amount'] as int? ?? 0;
      return TextEditingController(text: fare > 0 ? '$fare' : '');
    });

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 削除されていないレグのみ表示
          final visibleLegs = editableLegs
              .asMap()
              .entries
              .where((e) => !deletedIndices.contains(e.key))
              .toList();

          // レグ運賃の合計と入力済み数を計算
          int legFareSum = 0;
          int legFareCount = 0;
          for (final entry in visibleLegs) {
            final fare = entry.value['fare_amount'] as int? ?? 0;
            if (fare > 0) {
              legFareSum += fare;
              legFareCount++;
            }
          }
          final hasLegFares = legFareCount > 0;
          final hasItineraryFare = itineraryFareAmount > 0;

          // 排他制御: レグ運賃入力あり→旅程総額はロック（自動合算表示）
          //          旅程総額入力あり→レグ運賃はロック
          final isItineraryFareLocked = hasLegFares;
          final isLegFareLocked = hasItineraryFare;

          // 旅程総額の表示テキスト
          String itineraryFareDisplayNote = '';
          Color itineraryFareNoteColor = Colors.grey[600]!;
          if (isItineraryFareLocked) {
            if (legFareCount == visibleLegs.length) {
              itineraryFareDisplayNote = '（${visibleLegs.length}レグ合計）';
              itineraryFareNoteColor = Colors.green[700]!;
            } else {
              itineraryFareDisplayNote = '（$legFareCount/${visibleLegs.length}レグ入力済み）';
              itineraryFareNoteColor = Colors.orange[800]!;
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit, color: Colors.purple[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '旅程を編集',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    // ── 旅程総額入力フィールド ──
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '旅程総額:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              if (isItineraryFareLocked) ...[
                                // レグ運賃入力済み→自動合算表示（ロック）
                                Text(
                                  '¥${_formatNumber(legFareSum)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.lock, size: 14, color: Colors.grey[400]),
                              ] else ...[
                                // 旅程総額を直接入力
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: itineraryFareController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      suffixText: '円',
                                      suffixStyle: const TextStyle(fontSize: 12),
                                      hintText: '0',
                                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                    ),
                                    onChanged: (v) {
                                      setDialogState(() {
                                        itineraryFareAmount = int.tryParse(v) ?? 0;
                                        // 旅程総額入力時、レグ運賃をクリア
                                        if (itineraryFareAmount > 0) {
                                          for (int i = 0; i < editableLegs.length; i++) {
                                            editableLegs[i]['fare_amount'] = 0;
                                            legFareControllers[i].clear();
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (itineraryFareDisplayNote.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              itineraryFareDisplayNote,
                              style: TextStyle(fontSize: 10, color: itineraryFareNoteColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // ── レグ一覧 ──
                    ...visibleLegs.map((entry) {
                      final originalIndex = entry.key;
                      final leg = entry.value;
                      final airline = leg['airline'] as String? ?? 'JAL';
                      final flightNumber =
                          leg['flight_number'] as String? ?? '';
                      final dep = leg['departure_airport'] as String? ?? '';
                      final arr = leg['arrival_airport'] as String? ?? '';
                      final fareTypes = fareTypesByAirline[airline] ?? [];
                      final seatClasses = seatClassesByAirline[airline] ?? [];

                      String currentFareType =
                          leg['fare_type'] as String? ?? '';
                      String currentSeatClass =
                          leg['seat_class'] as String? ?? '';

                      if (!fareTypes.contains(currentFareType) &&
                          fareTypes.isNotEmpty) {
                        currentFareType = fareTypes.first;
                        editableLegs[originalIndex]['fare_type'] =
                            currentFareType;
                      }
                      if (!seatClasses.contains(currentSeatClass) &&
                          seatClasses.isNotEmpty) {
                        currentSeatClass = seatClasses.first;
                        editableLegs[originalIndex]['seat_class'] =
                            currentSeatClass;
                      }

                      final airlineColor = airline == 'JAL'
                          ? Colors.red
                          : Colors.blue;

                      return Container(
                        key: ValueKey('leg_edit_$originalIndex'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // フライト情報ヘッダー
                            Row(
                              children: [
                                Icon(
                                  Icons.flight,
                                  size: 16,
                                  color: airlineColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  flightNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: airlineColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$dep → $arr',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const Spacer(),
                                // 削除ボタン
                                IconButton(
                                  onPressed: visibleLegs.length > 1
                                      ? () {
                                          setDialogState(() {
                                            deletedIndices.add(originalIndex);
                                          });
                                        }
                                      : null,
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: visibleLegs.length > 1
                                        ? Colors.red
                                        : Colors.grey[400],
                                  ),
                                  tooltip: visibleLegs.length > 1
                                      ? '削除'
                                      : '最後のレグは削除できません',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 運賃種別
                            Row(
                              children: [
                                const SizedBox(
                                  width: 70,
                                  child: Text(
                                    '運賃種別:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: DropdownButton<String>(
                                      value: currentFareType,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      isDense: true,
                                      hint: const Text(
                                        '選択',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      items: fareTypes
                                          .map(
                                            (f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(
                                                f,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setDialogState(() {
                                            editableLegs[originalIndex]['fare_type'] =
                                                v;
                                            if (airline == 'ANA') {
                                              editableLegs[originalIndex]['seat_class'] =
                                                  _anaSeatClassForFare(v);
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 座席クラス
                            Row(
                              children: [
                                const SizedBox(
                                  width: 70,
                                  child: Text(
                                    '座席:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: DropdownButton<String>(
                                      value: currentSeatClass,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      isDense: true,
                                      hint: const Text(
                                        '選択',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      items: seatClasses
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                s,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setDialogState(() {
                                            editableLegs[originalIndex]['seat_class'] =
                                                v;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 運賃（円）— 旅程総額入力時はグレーアウト
                            Row(
                              children: [
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    '運賃:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLegFareLocked ? Colors.grey[400] : null,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    enabled: !isLegFareLocked,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLegFareLocked ? Colors.grey[400] : null,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      filled: isLegFareLocked,
                                      fillColor: Colors.grey[100],
                                      suffixText: '円',
                                      suffixStyle: TextStyle(
                                        fontSize: 12,
                                        color: isLegFareLocked ? Colors.grey[400] : null,
                                      ),
                                      hintText: isLegFareLocked ? '──' : '0',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    controller: legFareControllers[originalIndex],
                                    onChanged: (v) {
                                      setDialogState(() {
                                        editableLegs[originalIndex]['fare_amount'] =
                                            int.tryParse(v) ?? 0;
                                        // レグ運賃入力時、旅程総額をクリア
                                        if ((int.tryParse(v) ?? 0) > 0) {
                                          itineraryFareAmount = 0;
                                          itineraryFareController.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                if (isLegFareLocked) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.lock, size: 14, color: Colors.grey[400]),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (deletedIndices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${deletedIndices.length}件のレグが削除されます',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('キャンセル', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('再計算して保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await _updateItineraryLegs(
        itineraryId,
        editableLegs,
        deletedIndices,
        itinerary,
        itineraryFareAmount: itineraryFareAmount,
      );
    }
    itineraryFareController.dispose();
    for (final c in legFareControllers) {
      c.dispose();
    }
  }

  // 旅程のレグを更新（削除と再計算を含む）
  Future<void> _updateItineraryLegs(
    String itineraryId,
    List<Map<String, dynamic>> editableLegs,
    Set<int> deletedIndices,
    Map<String, dynamic> itinerary, {
    int itineraryFareAmount = 0,
  }) async {
    // 削除されていないレグのみ残す
    final remainingLegs = <Map<String, dynamic>>[];
    for (int i = 0; i < editableLegs.length; i++) {
      if (!deletedIndices.contains(i)) {
        remainingLegs.add(editableLegs[i]);
      }
    }

    if (remainingLegs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('少なくとも1つのレグが必要です'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 各レグを再計算
    for (int i = 0; i < remainingLegs.length; i++) {
      final leg = remainingLegs[i];
      final airline = leg['airline'] as String? ?? 'JAL';
      final dep = leg['departure_airport'] as String? ?? '';
      final arr = leg['arrival_airport'] as String? ?? '';
      final fareType = leg['fare_type'] as String? ?? '';
      final seatClass = leg['seat_class'] as String? ?? '';

      final baseMiles = await _getBaseMiles(airline, dep, arr);

      final calculated = _calculateLeg(
        airline: airline,
        baseMiles: baseMiles,
        fareType: fareType,
        seatClass: seatClass,
        jalCard: itinerary['jal_card'] as String?,
        anaCard: itinerary['ana_card'] as String?,
        jalStatus: itinerary['jal_status'] as String?,
        anaStatus: itinerary['ana_status'] as String?,
        jalTourPremium: itinerary['jal_tour_premium'] as bool? ?? false,
      );

      remainingLegs[i] = {
        ...leg,
        'fop': calculated['fop'],
        'miles': calculated['miles'],
        'lsp': calculated['lsp'],
      };
    }

    // 合計を再計算（JALはFOP、ANAはPPに分離）
    int totalFop = 0, totalPp = 0, totalMiles = 0, totalLsp = 0, totalFare = 0;
    for (final l in remainingLegs) {
      final legAirline = l['airline'] as String? ?? '';
      final legPoints = (l['fop'] as int? ?? 0);
      if (legAirline == 'ANA') {
        totalPp += legPoints;
      } else {
        totalFop += legPoints;
      }
      totalMiles += (l['miles'] as int? ?? 0);
      totalLsp += (l['lsp'] as int? ?? 0);
      totalFare += (l['fare_amount'] as int? ?? 0);
    }

    // 旅程総額が直接入力されている場合はそちらを使用し、レグ運賃をクリア
    if (itineraryFareAmount > 0) {
      totalFare = itineraryFareAmount;
      for (int i = 0; i < remainingLegs.length; i++) {
        remainingLegs[i]['fare_amount'] = 0;
      }
    }

    try {
      await Supabase.instance.client
          .from('saved_itineraries')
          .update({
            'legs': remainingLegs,
            'total_fop': totalFop,
            'total_pp': totalPp,
            'total_miles': totalMiles,
            'total_lsp': totalLsp,
            'total_fare': totalFare,
          })
          .eq('id', itineraryId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletedIndices.isNotEmpty
                  ? '${deletedIndices.length}件削除し、再計算して保存しました'
                  : '再計算して保存しました',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadItineraries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _anaSeatClassForFare(String fareType) {
    final fareNumber = fareType.split(' ').first;
    if (fareNumber == '運賃1' || fareNumber == '運賃2' || fareNumber == '運賃9') {
      return 'プレミアムクラス';
    }
    return '普通席';
  }

  Future<int> _getBaseMiles(String airline, String dep, String arr) async {
    try {
      final response = await Supabase.instance.client
          .from('routes')
          .select('distance_miles')
          .eq('departure_code', dep)
          .eq('arrival_code', arr)
          .maybeSingle();
      if (response != null) {
        return response['distance_miles'] as int? ?? 0;
      }
      final reverse = await Supabase.instance.client
          .from('routes')
          .select('distance_miles')
          .eq('departure_code', arr)
          .eq('arrival_code', dep)
          .maybeSingle();
      if (reverse != null) {
        return reverse['distance_miles'] as int? ?? 0;
      }
    } catch (e) {
      print('Error fetching miles: $e');
    }
    return 0;
  }

  Map<String, int> _calculateLeg({
    required String airline,
    required int baseMiles,
    required String fareType,
    required String seatClass,
    String? jalCard,
    String? anaCard,
    String? jalStatus,
    String? anaStatus,
    bool jalTourPremium = false,
  }) {
    if (airline == 'JAL') {
      return _calculateJAL(
        baseMiles: baseMiles,
        fareType: fareType,
        seatClass: seatClass,
        cardType: jalCard,
        status: jalStatus,
        tourPremium: jalTourPremium,
      );
    } else {
      return _calculateANA(
        baseMiles: baseMiles,
        fareType: fareType,
        seatClass: seatClass,
        cardType: anaCard,
        status: anaStatus,
      );
    }
  }

  Map<String, int> _calculateJAL({
    required int baseMiles,
    required String fareType,
    required String seatClass,
    String? cardType,
    String? status,
    bool tourPremium = false,
  }) {
    // JGCカード(海外)の場合のみ、ツアープレミアムは無効
    final isJGCOverseas = cardType == 'JALグローバルクラブ会員(海外)';
    final effectiveTourPremium = isJGCOverseas ? false : tourPremium;

    double fareRate = 1.0;
    final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fareType);
    if (rateMatch != null) {
      fareRate = int.parse(rateMatch.group(1)!) / 100.0;
    }

    // 座席ボーナス率
    double seatBonusRate = 0.0;
    if (seatClass == 'ファーストクラス') {
      seatBonusRate = 0.50;
    } else if (seatClass == 'クラスJ') {
      seatBonusRate = 0.10;
    }

    // フライトマイル = 区間マイル × (運賃率 + 座席ボーナス率)
    final flightMiles = (baseMiles * (fareRate + seatBonusRate)).round();

    // ツアープレミアムボーナス（対象運賃：運賃4、運賃5のみ）
    final fareNumber = fareType.split(' ').first;
    int tourPremiumBonus = 0;
    if (effectiveTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5')) {
      tourPremiumBonus = baseMiles - (baseMiles * fareRate).round();
    }

    // カードボーナス率
    double cardBonusRate = 0.0;
    if (cardType != null) {
      const cardRates = {
        'JALカード普通会員': 0.10,
        'JALカードCLUB-A会員': 0.25,
        'JALカードCLUB-Aゴールド会員': 0.25,
        'JALカードプラチナ会員': 0.25,
        'JALグローバルクラブ会員(日本)': 0.35,
        'JALグローバルクラブ会員(海外)': 0.0,
        'JALカードNAVI会員': 0.10,
        'JAL CLUB EST 普通会員': 0.10,
        'JAL CLUB EST CLUB-A会員': 0.25,
        'JAL CLUB EST CLUB-A GOLD会員': 0.25,
        'JAL CLUB EST プラチナ会員': 0.25,
      };
      cardBonusRate = cardRates[cardType] ?? 0.0;
    }

    // ステータスボーナス率
    double statusBonusRate = 0.0;
    if (status != null) {
      const statusRates = {
        'JMBダイヤモンド': 1.30,
        'JGCプレミア': 1.05,
        'JMBサファイア': 1.05,
        'JMBクリスタル': 0.55,
      };
      statusBonusRate = statusRates[status] ?? 0.0;
    }

    // ボーナスマイル = フライトマイル × (カードとステータスの高い方)
    // ※ツアプレボーナスにはボーナス率は適用されない
    final appliedBonusRate = cardBonusRate > statusBonusRate
        ? cardBonusRate
        : statusBonusRate;
    final bonusMiles = (flightMiles * appliedBonusRate).round();

    // 合計マイル = フライトマイル + ツアプレボーナス + ボーナスマイル
    final totalMiles = flightMiles + tourPremiumBonus + bonusMiles;

    // FOP = フライトマイル × 2 + 運賃ボーナス（ツアプレは影響しない）
    final fopBase = flightMiles * 2;
    const fareFOPBonus = {
      '運賃1': 400,
      '運賃2': 400,
      '運賃3': 200,
      '運賃4': 200,
      '運賃5': 0,
      '運賃6': 0,
    };
    final fareBonusFOP = fareFOPBonus[fareNumber] ?? 0;
    final totalFOP = fopBase + fareBonusFOP;

    // LSP: 国内線搭乗ポイント（運賃率50%以上で5ポイント）
    int lsp = (fareRate >= 0.5) ? 5 : 0;

    return {'fop': totalFOP, 'miles': totalMiles, 'lsp': lsp};
  }

  Map<String, int> _calculateANA({
    required int baseMiles,
    required String fareType,
    required String seatClass,
    String? cardType,
    String? status,
  }) {
    double fareRate = 1.0;
    final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fareType);
    if (rateMatch != null) {
      fareRate = int.parse(rateMatch.group(1)!) / 100.0;
    }

    final flightMiles = (baseMiles * fareRate).toInt();

    // カードボーナス率
    double cardBonusRate = 0.0;
    if (cardType != null) {
      const cardRates = {
        'AMCカード(提携カード含む)': 0.0,
        'ANAカード 一般': 0.10,
        'ANAカード 学生用': 0.10,
        'ANAカード ワイド': 0.25,
        'ANAカード ゴールド': 0.25,
        'ANAカード プレミアム': 0.50,
        'SFC 一般': 0.35,
        'SFC ゴールド': 0.40,
        'SFC プレミアム': 0.50,
      };
      cardBonusRate = cardRates[cardType] ?? 0.0;
    }

    // ステータスボーナス率
    double statusBonusRate = 0.0;
    if (status != null) {
      const statusRates = {
        'ダイヤモンド(1年目)': 1.15,
        'ダイヤモンド(継続2年以上)': 1.25,
        'プラチナ(1年目)': 0.90,
        'プラチナ(継続2年以上)': 1.00,
        'ブロンズ(1年目)': 0.40,
        'ブロンズ(継続2年以上)': 0.50,
      };
      statusBonusRate = statusRates[status] ?? 0.0;
    }

    // ゴールド/プレミアムカード + ステータスの場合 +5%
    final anaCardTypes = [
      '-',
      'AMCカード(提携カード含む)',
      'ANAカード 一般',
      'ANAカード 学生用',
      'ANAカード ワイド',
      'ANAカード ゴールド',
      'ANAカード プレミアム',
      'SFC 一般',
      'SFC ゴールド',
      'SFC プレミアム',
    ];
    final cardIdx = anaCardTypes.indexOf(cardType ?? '-');
    final isGoldPremium =
        cardIdx == 5 || cardIdx == 6 || cardIdx == 8 || cardIdx == 9;
    final appliedRate = (isGoldPremium && statusBonusRate > 0)
        ? statusBonusRate + 0.05
        : (cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate);

    // ANA公式準拠: マイルは2段階切り捨て、PPは1式切り捨て
    final bonusMiles = (flightMiles * appliedRate).toInt();
    final totalMiles = flightMiles + bonusMiles;

    // PP = 区間マイル × 運賃率 × 2 + 搭乗ポイント
    final fareNumber = fareType.split(' ').first;
    const farePPBonus = {
      '運賃1': 400,
      '運賃2': 400,
      '運賃3': 400,
      '運賃4': 0,
      '運賃5': 400,
      '運賃6': 200,
      '運賃7': 0,
      '運賃8': 0,
      '運賃9': 0,
      '運賃10': 0,
      '運賃11': 0,
      '運賃12': 0,
      '運賃13': 0,
    };
    final bonusPP = farePPBonus[fareNumber] ?? 0;
    final totalPP = (baseMiles * fareRate * 2 + bonusPP).toInt();

    return {'fop': totalPP, 'miles': totalMiles, 'lsp': 0};
  }
}

// シェアダイアログ（画像シェア方式）
class _ShareDialog extends StatefulWidget {
  final Map<String, dynamic> itinerary;
  final Map<String, String> airportNameMap;

  const _ShareDialog({required this.itinerary, required this.airportNameMap});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _themeController = TextEditingController();
  final _commentController = TextEditingController();
  final _cardKey = GlobalKey();
  bool _isCapturing = false;

  @override
  void dispose() {
    _themeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number == 0) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _titleToJapanese(String title) {
    final map = widget.airportNameMap;
    if (map.isEmpty) return title;
    final legMatch = RegExp(r'(\s+\d+レグ)$').firstMatch(title);
    final routePart = legMatch != null ? title.substring(0, legMatch.start) : title;
    final legSuffix = legMatch != null ? legMatch.group(0)! : '';
    final converted = routePart.split('-').map((code) => map[code] ?? code).join('-');
    return '$converted$legSuffix';
  }

  // ツイート用テキスト（概要のみ・常に280文字以内）
  String _generateTweetText() {
    final itinerary = widget.itinerary;
    final theme = _themeController.text.trim();
    final comment = _commentController.text.trim();
    final title = _titleToJapanese(itinerary['title'] as String? ?? '');
    final fop = itinerary['total_fop'] as int? ?? 0;
    final pp = itinerary['total_pp'] as int? ?? 0;
    final miles = itinerary['total_miles'] as int? ?? 0;
    final lsp = itinerary['total_lsp'] as int? ?? 0;
    final legs = itinerary['legs'] as List<dynamic>? ?? [];

    String dateStr = '';
    if (legs.isNotEmpty) {
      final firstLeg = legs.first as Map<String, dynamic>;
      dateStr = firstLeg['date'] as String? ?? '';
    }

    final buf = StringBuffer();
    if (theme.isNotEmpty) {
      buf.writeln('✈️【$theme】');
    } else {
      buf.writeln('✈️【修行プラン】');
    }
    if (dateStr.isNotEmpty) buf.writeln('📅 $dateStr');
    buf.writeln('🛫 $title');

    if (fop > 0 && pp > 0) {
      buf.writeln(
        '📊 FOP: ${_formatNumber(fop)} / PP: ${_formatNumber(pp)} / マイル: ${_formatNumber(miles)}',
      );
    } else if (fop > 0) {
      buf.write('📊 FOP: ${_formatNumber(fop)} / マイル: ${_formatNumber(miles)}');
      if (lsp > 0) buf.write(' / ${lsp}LSP');
      buf.writeln();
    } else if (pp > 0) {
      buf.writeln('📊 PP: ${_formatNumber(pp)} / マイル: ${_formatNumber(miles)}');
    }

    if (comment.isNotEmpty) buf.writeln('💬 $comment');
    buf.writeln();
    final airline = fop > 0 ? 'JAL' : 'ANA';
    buf.writeln('#MRP修行プラン #${airline}修行');
    buf.write('mrunplanner.com');

    return buf.toString();
  }

  // シェアカード画像Widget
  Widget _buildShareCard() {
    final itinerary = widget.itinerary;
    final theme = _themeController.text.trim();
    final comment = _commentController.text.trim();
    final title = _titleToJapanese(itinerary['title'] as String? ?? '');
    final fop = itinerary['total_fop'] as int? ?? 0;
    final pp = itinerary['total_pp'] as int? ?? 0;
    final miles = itinerary['total_miles'] as int? ?? 0;
    final lsp = itinerary['total_lsp'] as int? ?? 0;
    final fare = itinerary['total_fare'] as int? ?? 0;
    final legs = itinerary['legs'] as List<dynamic>? ?? [];

    String dateStr = '';
    if (legs.isNotEmpty) {
      final firstLeg = legs.first as Map<String, dynamic>;
      dateStr = firstLeg['date'] as String? ?? '';
    }

    // 単価計算
    String unitPrice = '';
    if (fare > 0 && (fop > 0 || pp > 0)) {
      int farePoints = 0;
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final legFare = legMap['fare_amount'] as int? ?? 0;
        if (legFare > 0) {
          farePoints += (legMap['pp'] as int? ?? 0) > 0
              ? (legMap['pp'] as int? ?? 0)
              : (legMap['fop'] as int? ?? 0);
        }
      }
      if (farePoints > 0) {
        final pointLabel = pp > 0 && fop == 0 ? 'PP' : 'FOP';
        unitPrice = '¥${(fare / farePoints).toStringAsFixed(1)}/$pointLabel';
      }
    }
    final isJal = fop > 0 && pp == 0;
    final isAna = pp > 0 && fop == 0;
    final isMixed = fop > 0 && pp > 0;
    final primaryColor = isMixed
        ? const Color(0xFF9933CC)
        : isJal
        ? const Color(0xFFCC0000)
        : const Color(0xFF00BFFF);
    final bgColors = isMixed
        ? [const Color(0xFF1A0019), const Color(0xFF2D002D)]
        : isJal
        ? [const Color(0xFF1A0000), const Color(0xFF2D0000)]
        : [const Color(0xFF000D1A), const Color(0xFF001A33)];

    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgColors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ヘッダー ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  theme.isNotEmpty ? theme : '修行プラン',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MRP',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '📅 $dateStr',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          // ルート
          Text(
            '🛫 $title',
            style: TextStyle(
              color: primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey[800]),
          const SizedBox(height: 12),

          // ── 統計バッジ ──
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (fop > 0) _statBadge('FOP', _formatNumber(fop), primaryColor),
              if (pp > 0) _statBadge('PP', _formatNumber(pp), primaryColor),
              _statBadge('マイル', _formatNumber(miles), Colors.grey[400]!),
              if (lsp > 0) _statBadge('LSP', '$lsp', Colors.amber),
            ],
          ),
          if (fare > 0) ...[
            const SizedBox(height: 8),
            Text(
              '💰 ¥${_formatNumber(fare)}${unitPrice.isNotEmpty ? "（$unitPrice）" : ""}',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey[800]),
          const SizedBox(height: 8),

          // ── レグ詳細 ──
          ...legs.asMap().entries.map((entry) {
            final l = entry.value as Map<String, dynamic>;
            final legAirline = l['airline'] as String? ?? '';
            final flightNum = l['flight_number'] as String? ?? '';
            final dep = l['departure_airport'] as String? ?? '';
            final arr = l['arrival_airport'] as String? ?? '';
            final legFop = l['fop'] as int? ?? 0;
            final legPp = l['pp'] as int? ?? 0;
            final points = legFop > 0 ? legFop : legPp;
            final pointLabel = legFop > 0 ? 'FOP' : 'PP';

            // IATA コード化: JAL→JL, ANA→NH
            final iataCode = legAirline == 'JAL' ? 'JL' : legAirline == 'ANA' ? 'NH' : legAirline;
            final displayFlight = '$iataCode$flightNum';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      displayFlight,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$dep → $arr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '$points $pointLabel',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── コメント ──
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.grey[800]),
            const SizedBox(height: 8),
            Text(
              '💬 $comment',
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
          ],

          const SizedBox(height: 16),
          // ── フッター ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#MRP修行プラン',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
              Text(
                'mrunplanner.com',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _share() async {
    setState(() => _isCapturing = true);
    try {
      // Overlay で画面外にカードをレンダリング（ダイアログの高さ制約を回避）
      final captureKey = GlobalKey();
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999,
          top: -9999,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: captureKey,
              child: _buildShareCard(),
            ),
          ),
        ),
      );
      Overlay.of(context).insert(overlayEntry);
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary =
          captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        overlayEntry.remove();
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      overlayEntry.remove();

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final tweetText = _generateTweetText();

      // Web Share API（モバイル対応）
      if (js_util.hasProperty(html.window.navigator, 'share')) {
        final file = html.File([bytes], 'mrp_share.png', {'type': 'image/png'});
        final shareData = js_util.jsify({
          'text': tweetText,
          'files': [file],
        });
        final canShare = js_util.callMethod<bool>(
          html.window.navigator,
          'canShare',
          [shareData],
        );
        if (canShare) {
          if (mounted) Navigator.pop(context);
          await js_util.promiseToFuture(
            js_util.callMethod(html.window.navigator, 'share', [shareData]),
          );
          return;
        }
      }

      // フォールバック（デスクトップ）: 画像DL + Twitter Intent
      final blob = html.Blob([bytes], 'image/png');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final cardTitle = (widget.itinerary['title'] as String? ?? 'share')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final now = DateTime.now();
      final filename =
          'MRP_${cardTitle}_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.png';
      html.AnchorElement(href: blobUrl)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(blobUrl);

      final encodedText = Uri.encodeComponent(tweetText);
      final tweetUrl = 'https://twitter.com/intent/tweet?text=$encodedText';
      if (mounted) Navigator.pop(context);
      await launchUrl(
        Uri.parse(tweetUrl),
        mode: LaunchMode.externalApplication,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📎 画像をダウンロードしました。ツイートに添付してください'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.share, color: Colors.blue),
          SizedBox(width: 8),
          Text('Xでシェア', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // テーマ入力
              TextField(
                controller: _themeController,
                decoration: const InputDecoration(
                  labelText: 'テーマ（任意）',
                  hintText: '例: W毎追っかけ修行',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // コメント入力
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'コメント（任意）',
                  hintText: '例: 初修行完了！',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // ── 画像プレビュー ──
              Text(
                '📸 シェア画像プレビュー',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(key: _cardKey, child: _buildShareCard()),
              ),

              const SizedBox(height: 16),

              // ── ツイートテキストプレビュー ──
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ツイートテキスト',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _generateTweetText(),
                      style: const TextStyle(fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_generateTweetText().length}/280文字',
                        style: TextStyle(
                          fontSize: 10,
                          color: _generateTweetText().length > 280
                              ? Colors.red
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton.icon(
          onPressed: _isCapturing ? null : _share,
          icon: _isCapturing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, size: 18),
          label: Text(_isCapturing ? '生成中...' : 'シェア'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
