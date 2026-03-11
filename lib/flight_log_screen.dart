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
import 'email_parse_dialog.dart';
import 'main.dart' show paintItBlackUpdateNotifier;

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
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        // 削除対象の旅程を取得
        final itinerary = await Supabase.instance.client
            .from('saved_itineraries')
            .select('legs, is_completed')
            .eq('id', id)
            .single();

        final isCompleted = itinerary['is_completed'] as bool? ?? false;
        final legs = itinerary['legs'] as List<dynamic>? ?? [];

        // 修行済みの場合、Paint it Black連携を確認
        Set<String> airportsToRemove = {};
        if (isCompleted && legs.isNotEmpty) {
          // 削除対象の旅程に含まれる空港コードを取得
          final airportsInThisItinerary = <String>{};
          for (final leg in legs) {
            final dep = leg['departure_airport'] as String? ?? '';
            final arr = leg['arrival_airport'] as String? ?? '';
            if (dep.isNotEmpty) airportsInThisItinerary.add(dep);
            if (arr.isNotEmpty) airportsInThisItinerary.add(arr);
          }

          // 他の修行済み旅程で使われている空港を取得
          final otherItineraries = await Supabase.instance.client
              .from('saved_itineraries')
              .select('legs')
              .eq('user_id', user.id)
              .eq('is_completed', true)
              .neq('id', id);

          final airportsInOtherItineraries = <String>{};
          for (final other in otherItineraries) {
            final otherLegs = other['legs'] as List<dynamic>? ?? [];
            for (final leg in otherLegs) {
              final dep = leg['departure_airport'] as String? ?? '';
              final arr = leg['arrival_airport'] as String? ?? '';
              if (dep.isNotEmpty) airportsInOtherItineraries.add(dep);
              if (arr.isNotEmpty) airportsInOtherItineraries.add(arr);
            }
          }

          // 他の旅程に含まれていない空港を削除対象に
          airportsToRemove = airportsInThisItinerary.difference(airportsInOtherItineraries);
        }

        // 旅程を削除
        await Supabase.instance.client
            .from('saved_itineraries')
            .delete()
            .eq('id', id);

        // Paint it Blackから空港を削除
        if (airportsToRemove.isNotEmpty) {
          await Supabase.instance.client
              .from('airport_checkins')
              .delete()
              .eq('user_id', user.id)
              .inFilter('airport_code', airportsToRemove.toList());
          
          // Paint it Black画面に更新を通知
          paintItBlackUpdateNotifier.value++;
        }

        _loadItineraries();
        if (mounted) {
          final message = airportsToRemove.isNotEmpty
              ? '${l10n.deleted}（Paint it Black: ${airportsToRemove.length}空港削除）'
              : l10n.deleted;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
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

    if (!mounted) return;
    
    // email_parse_dialogを表示して解析結果を受け取る
    final result = await showEmailParseDialog(context);
    
    if (result != null) {
      final legs = (result['legs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final emailText = result['emailText'] as String? ?? '';
      
      if (legs.isNotEmpty) {
        // 既存の保存処理を使用（FOP/マイル計算含む）
        await _saveEmailImportResult(legs, emailText: emailText);
        _loadItineraries();
      }
    }
  }

 
  // ============================================================
// flight_log_screen.dart の _mapFareType メソッドを差し替え
// 差し替え範囲: 行 559〜582
// ============================================================

  String _mapFareType(String airline, String rawFareType) {
    final raw = rawFareType.trim();
    if (raw.isEmpty) {
      return airline == 'JAL'
          ? fareTypesByAirline['JAL']![3]  // デフォルト: スペシャルセイバー
          : fareTypesByAirline['ANA']![6]; // デフォルト: ANA SUPER VALUE
    }

    if (airline == 'JAL') {
      final fareTypes = fareTypesByAirline['JAL']!;

      // 1. 完全一致チェック（運賃番号含む）
      for (final ft in fareTypes) {
        if (ft == raw) return ft;
      }

      // 2. キーワードマッチ（長い名前から先にチェック＝スペシャルセイバー→セイバーの順）
      if (raw.contains('スペシャルセイバー') || raw.contains('special_saver') || raw.contains('スペシャル')) {
        return fareTypes[3]; // 運賃4: スペシャルセイバー
      }
      if (raw.contains('フレックス') || raw.contains('flex') || raw.contains('普通運賃') || raw.contains('大人普通')) {
        return fareTypes[0]; // 運賃1: フレックス等
      }
      if (raw.contains('株主')) {
        return fareTypes[1]; // 運賃2: 株主割引
      }
      if (raw.contains('セイバー') || raw.contains('saver')) {
        return fareTypes[2]; // 運賃3: セイバー（スペシャルセイバーは上で処理済み）
      }
      if (raw.contains('包括') || raw.contains('パッケージ') || raw.contains('ツアー') || raw.contains('DP')) {
        return fareTypes[4]; // 運賃5: 包括旅行運賃
      }
      if (raw.contains('スカイメイト') || raw.contains('障がい') || raw.contains('介護') || raw.contains('離島')) {
        return fareTypes[5]; // 運賃6: スカイメイト等
      }

      return fareTypes[3]; // デフォルト: スペシャルセイバー
    } else {
      final fareTypes = fareTypesByAirline['ANA']!;

      // 1. 完全一致チェック
      for (final ft in fareTypes) {
        if (ft == raw) return ft;
      }

      // 2. 国際航空券（先にチェック）
      if (raw.contains('国際') || raw.contains('international')) {
        if (raw.contains('F') || raw.contains('A') || raw.contains('PC') || raw.contains('ファースト') || raw.contains('ビジネス')) {
          // F/Aクラスかどうかを判定
          if (RegExp(r'[FA]').hasMatch(raw) && (raw.contains('PC') || raw.contains('ファースト'))) {
            return fareTypes[8]; // 運賃9: 国際航空券(PC) F/A
          }
        }
        if (raw.contains('Y') || raw.contains('B') || raw.contains('M') || raw.contains('普通')) {
          return fareTypes[9]; // 運賃10
        }
        if (raw.contains('U') || raw.contains('H') || raw.contains('Q')) {
          return fareTypes[10]; // 運賃11
        }
        if (raw.contains('V') || raw.contains('W') || raw.contains('S')) {
          return fareTypes[11]; // 運賃12
        }
        if (raw.contains('L') || raw.contains('K')) {
          return fareTypes[12]; // 運賃13
        }
        return fareTypes[9]; // 国際デフォルト: 運賃10
      }

      // 3. 国内線キーワードマッチ
      if (raw.contains('プレミアム') && !raw.contains('SFC')) {
        if (raw.contains('株主') || raw.contains('VALUE PREMIUM')) {
          return fareTypes[1]; // 運賃2: プレミアム株主優待
        }
        return fareTypes[0]; // 運賃1: プレミアム運賃
      }
      if (raw.contains('FLEX') || raw.contains('フレックス') || raw.contains('Biz') || raw.contains('ビジネスきっぷ')) {
        return fareTypes[2]; // 運賃3: ANA FLEX
      }
      if (raw.contains('アイきっぷ')) {
        return fareTypes[3]; // 運賃4
      }
      if (raw.contains('SUPER VALUE') || raw.contains('いっしょにマイル') || raw.contains('スーパーバリュー')) {
        return fareTypes[6]; // 運賃7: ANA SUPER VALUE
      }
      if (raw.contains('TRANSIT') || raw.contains('トランジット')) {
        return fareTypes[5]; // 運賃6: VALUE TRANSIT
      }
      if (raw.contains('VALUE') || raw.contains('バリュー') || raw.contains('特割') || raw.contains('株主')) {
        return fareTypes[4]; // 運賃5: ANA VALUE
      }
      if (raw.contains('個人包括') || raw.contains('スマート') || raw.contains('U25') || raw.contains('シニア') || raw.contains('SALE')) {
        return fareTypes[7]; // 運賃8
      }

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
      } else if (passengerCount >= 2) {
      }

      // 3. 往復按分: 全レグ同一運賃 + メールに「往復」→ レグ数で割る
      if (legs.length >= 2 && emailText.contains('往復')) {
        final fares = legs.map((l) => l['fare'] as int? ?? 0).toList();
        final allSame = fares.every((f) => f == fares.first) && fares.first > 0;
        if (allSame) {
          final perLeg = (fares.first / legs.length).round();
          for (final leg in legs) {
            leg['fare'] = perLeg;
          }
        }
      }

      // 4. メール本文から「合計」金額を取得して適用
      // ただし、各レグに既に異なる運賃が設定されている場合はスキップ
      if (emailText.isNotEmpty) {
        // 各レグの運賃を確認
        final legFares = legs.map((l) => l['fare'] as int? ?? 0).toList();
        final hasIndividualFares = legFares.any((f) => f > 0) && 
            (legFares.toSet().length > 1 || legs.length == 1);
        
        if (!hasIndividualFares) {
          // 「合計XX,XXX円」または「合計XX円」を検出
          final totalMatch = RegExp(r'合計[：:\s]*([0-9,]+)\s*円').firstMatch(emailText);
          if (totalMatch != null) {
            final totalStr = totalMatch.group(1)!.replaceAll(',', '');
            final totalFare = int.tryParse(totalStr) ?? 0;
            if (totalFare > 0) {
              // 合計をレグ数で按分
              final perLeg = (totalFare / legs.length).round();
              for (final leg in legs) {
                leg['fare'] = perLeg;
              }
            }
          }
        } else {
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
      final jalCardType = profile['jal_card'] as String? ?? '-';
      final jalTourPremium = profile['jal_tour_premium'] as bool? ?? false;
      final anaStatus = profile['ana_status'] as String? ?? '-';
      final anaCardType = profile['ana_card'] as String? ?? '-';

      // ── 重複チェック ──
      final existingItineraries = await Supabase.instance.client
          .from('saved_itineraries')
          .select('legs')
          .eq('user_id', user.id);

      // 既存のフライトを集める（日付 + 便名）
      final existingFlights = <String>{};
      for (final itinerary in existingItineraries) {
        final existingLegs = itinerary['legs'] as List<dynamic>? ?? [];
        for (final leg in existingLegs) {
          final date = (leg['date'] ?? leg['flightDate'] ?? '').toString();
          final flightNumber = (leg['flight_number'] ?? leg['flightNumber'] ?? '').toString();
          if (date.isNotEmpty && flightNumber.isNotEmpty) {
            existingFlights.add('$date|$flightNumber');
          }
        }
      }

      // 新規レグの重複をチェック
      final duplicates = <String>[];
      for (final leg in legs) {
        final date = (leg['date'] ?? '').toString().replaceAll('/', '-');
        final flightNumber = (leg['flightNumber'] ?? '').toString();
        final key = '$date|$flightNumber';
        // 日付フォーマットの違いを考慮（YYYY/MM/DD と YYYY-MM-DD）
        final altKey = '${date.replaceAll('-', '/')}|$flightNumber';
        if (existingFlights.contains(key) || existingFlights.contains(altKey)) {
          duplicates.add('$date $flightNumber');
        }
      }

      if (duplicates.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ 重複: ${duplicates.join(', ')} は既に登録済みです'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return; // 保存しない
      }

      // 各レグのFOP/PP/マイルを計算
      final processedLegs = <Map<String, dynamic>>[];
      for (final leg in legs) {
        final airline = leg['airline'] as String;
        final departure = _normalizeAirportCode(leg['departure'] as String? ?? '');
        final arrival = _normalizeAirportCode(leg['arrival'] as String? ?? '');
        final rawFareType = leg['fareType'] as String? ?? '';
        final fareType = _mapFareType(airline, rawFareType);
        final seatClass = leg['seatClass'] as String? ?? '普通席';
        final fare = leg['fare'] as int? ?? 0;

        // 距離を取得（双方向検索）
        final distance = await _getRouteDistance(departure, arrival);

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
        int lsp = calculated['lsp'] ?? 0;

        // LSPは2024年1月1日以降のみ（JAL Life Status プログラム開始日）
        if (airline == 'JAL' && lsp > 0) {
          final dateStr = (leg['date'] ?? '').toString().replaceAll('/', '-');
          final flightDate = DateTime.tryParse(dateStr);
          if (flightDate != null && flightDate.isBefore(DateTime(2024, 1, 1))) {
            lsp = 0;
          }
        }

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
        // Paint it Black画面に更新を通知
        paintItBlackUpdateNotifier.value++;
      }
    } catch (e) {
      // チェックイン登録失敗は旅程保存に影響させない
      // チェックイン登録エラー
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

    // ステータス/カード編集用変数
    String editJalStatus = itinerary['jal_status'] as String? ?? '-';
    String editJalCard = itinerary['jal_card'] as String? ?? '-';
    String editAnaStatus = itinerary['ana_status'] as String? ?? '-';
    String editAnaCard = itinerary['ana_card'] as String? ?? '-';
    bool editJalTourPremium = itinerary['jal_tour_premium'] as bool? ?? false;

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

    // FOP/マイル/LSP手動入力用のcontroller
    final legFopControllers = List.generate(editableLegs.length, (i) {
      final fop = editableLegs[i]['manual_fop'] as int?;
      return TextEditingController(text: fop != null ? '$fop' : '');
    });
    final legMilesControllers = List.generate(editableLegs.length, (i) {
      final miles = editableLegs[i]['manual_miles'] as int?;
      return TextEditingController(text: miles != null ? '$miles' : '');
    });
    final legLspControllers = List.generate(editableLegs.length, (i) {
      final lsp = editableLegs[i]['manual_lsp'] as int?;
      return TextEditingController(text: lsp != null ? '$lsp' : '');
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
                    // ── ステータス/カード選択 ──
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '搭乗時のステータス/カード',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          // JAL
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('JAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: editJalCard,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    labelText: 'カード',
                                    labelStyle: TextStyle(fontSize: 10),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: '-', child: Text('なし')),
                                    DropdownMenuItem(value: 'jmb', child: Text('JMB会員')),
                                    DropdownMenuItem(value: 'jal_regular', child: Text('JAL普通')),
                                    DropdownMenuItem(value: 'jal_club_a', child: Text('CLUB-A')),
                                    DropdownMenuItem(value: 'jal_club_a_gold', child: Text('CLUB-Aゴールド')),
                                    DropdownMenuItem(value: 'jal_platinum', child: Text('プラチナ')),
                                    DropdownMenuItem(value: 'jgc_japan', child: Text('JGC(日本)')),
                                    DropdownMenuItem(value: 'jgc_overseas', child: Text('JGC(海外)')),
                                  ],
                                  onChanged: (v) => setDialogState(() => editJalCard = v ?? '-'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: editJalStatus,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    labelText: 'ステータス',
                                    labelStyle: TextStyle(fontSize: 10),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: [
                                    const DropdownMenuItem(value: '-', child: Text('なし')),
                                    const DropdownMenuItem(value: 'diamond', child: Text('ダイヤモンド')),
                                    if (editJalCard == 'jgc_japan' || editJalCard == 'jgc_overseas')
                                      const DropdownMenuItem(value: 'jgc_premier', child: Text('JGCプレミア')),
                                    const DropdownMenuItem(value: 'sapphire', child: Text('サファイア')),
                                    const DropdownMenuItem(value: 'crystal', child: Text('クリスタル')),
                                  ],
                                  onChanged: (v) => setDialogState(() => editJalStatus = v ?? '-'),
                                ),
                              ),
                            ],
                          ),
                          // ツアープレミアム
                          Row(
                            children: [
                              const SizedBox(width: 40), // JALラベル分のスペース
                              Checkbox(
                                value: editJalTourPremium,
                                onChanged: (v) => setDialogState(() => editJalTourPremium = v ?? false),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              const Text(
                                'JALカード ツアープレミアム',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // ANA
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('ANA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: editAnaCard,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    labelText: 'カード',
                                    labelStyle: TextStyle(fontSize: 10),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: '-', child: Text('なし')),
                                    DropdownMenuItem(value: 'amc', child: Text('AMC')),
                                    DropdownMenuItem(value: 'ana_regular', child: Text('ANA一般')),
                                    DropdownMenuItem(value: 'ana_wide', child: Text('ANAワイド')),
                                    DropdownMenuItem(value: 'ana_gold', child: Text('ANAゴールド')),
                                    DropdownMenuItem(value: 'ana_premium', child: Text('ANAプレミアム')),
                                    DropdownMenuItem(value: 'sfc_regular', child: Text('SFC一般')),
                                    DropdownMenuItem(value: 'sfc_gold', child: Text('SFCゴールド')),
                                    DropdownMenuItem(value: 'sfc_premium', child: Text('SFCプレミアム')),
                                  ],
                                  onChanged: (v) => setDialogState(() => editAnaCard = v ?? '-'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: editAnaStatus,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    labelText: 'ステータス',
                                    labelStyle: TextStyle(fontSize: 10),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: '-', child: Text('なし')),
                                    DropdownMenuItem(value: 'diamond_1', child: Text('ダイヤ(1年目)')),
                                    DropdownMenuItem(value: 'diamond_2', child: Text('ダイヤ(継続)')),
                                    DropdownMenuItem(value: 'platinum_1', child: Text('プラチナ(1年目)')),
                                    DropdownMenuItem(value: 'platinum_2', child: Text('プラチナ(継続)')),
                                    DropdownMenuItem(value: 'bronze_1', child: Text('ブロンズ(1年目)')),
                                    DropdownMenuItem(value: 'bronze_2', child: Text('ブロンズ(継続)')),
                                  ],
                                  onChanged: (v) => setDialogState(() => editAnaStatus = v ?? '-'),
                                ),
                              ),
                            ],
                          ),
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
                            const SizedBox(height: 8),
                            // ── 手動入力（FOP/マイル/LSP）──
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.purple[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '手動入力（空欄=自動計算）',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      // FOP/PP
                                      Expanded(
                                        child: TextField(
                                          controller: legFopControllers[originalIndex],
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 11),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                            labelText: airline == 'ANA' ? 'PP' : 'FOP',
                                            labelStyle: const TextStyle(fontSize: 10),
                                            hintText: '自動',
                                            hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                          ),
                                          onChanged: (v) {
                                            setDialogState(() {
                                              final val = int.tryParse(v);
                                              editableLegs[originalIndex]['manual_fop'] = val;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // マイル
                                      Expanded(
                                        child: TextField(
                                          controller: legMilesControllers[originalIndex],
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 11),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                            labelText: 'マイル',
                                            labelStyle: const TextStyle(fontSize: 10),
                                            hintText: '自動',
                                            hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                          ),
                                          onChanged: (v) {
                                            setDialogState(() {
                                              final val = int.tryParse(v);
                                              editableLegs[originalIndex]['manual_miles'] = val;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // LSP（JALのみ）
                                      if (airline == 'JAL')
                                        Expanded(
                                          child: TextField(
                                            controller: legLspControllers[originalIndex],
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(fontSize: 11),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                              labelText: 'LSP',
                                              labelStyle: const TextStyle(fontSize: 10),
                                              hintText: '自動',
                                              hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                            ),
                                            onChanged: (v) {
                                              setDialogState(() {
                                                final val = int.tryParse(v);
                                                editableLegs[originalIndex]['manual_lsp'] = val;
                                              });
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
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
        jalStatus: editJalStatus,
        jalCard: editJalCard,
        anaStatus: editAnaStatus,
        anaCard: editAnaCard,
        jalTourPremium: editJalTourPremium,
      );
    }
    itineraryFareController.dispose();
    for (final c in legFareControllers) {
      c.dispose();
    }
    for (final c in legFopControllers) {
      c.dispose();
    }
    for (final c in legMilesControllers) {
      c.dispose();
    }
    for (final c in legLspControllers) {
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
    String? jalStatus,
    String? jalCard,
    String? anaStatus,
    String? anaCard,
    bool jalTourPremium = false,
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
        jalCard: jalCard,
        anaCard: anaCard,
        jalStatus: jalStatus,
        anaStatus: anaStatus,
        jalTourPremium: jalTourPremium,
      );

      // 手動入力があれば優先、なければ自動計算値
      final manualFop = leg['manual_fop'] as int?;
      final manualMiles = leg['manual_miles'] as int?;
      final manualLsp = leg['manual_lsp'] as int?;

      int fop = manualFop ?? (calculated['fop'] ?? 0);
      int miles = manualMiles ?? (calculated['miles'] ?? 0);
      int lsp = manualLsp ?? (calculated['lsp'] ?? 0);

      // LSPは2024年1月1日以降のみ（JAL Life Status プログラム開始日）
      // ただし手動入力の場合はそのまま使用
      if (airline == 'JAL' && lsp > 0 && manualLsp == null) {
        final dateStr = (leg['date'] ?? leg['flightDate'] ?? '').toString().replaceAll('/', '-');
        final flightDate = DateTime.tryParse(dateStr);
        if (flightDate != null && flightDate.isBefore(DateTime(2024, 1, 1))) {
          lsp = 0;
        }
      }

      remainingLegs[i] = {
        ...leg,
        'fop': fop,
        'miles': miles,
        'lsp': lsp,
        // 手動入力値はDBに保存しない（毎回計算 or 入力）
      };
      // manual_*キーを削除（DBに保存しない）
      remainingLegs[i].remove('manual_fop');
      remainingLegs[i].remove('manual_miles');
      remainingLegs[i].remove('manual_lsp');
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
            'jal_status': jalStatus,
            'jal_card': jalCard,
            'ana_status': anaStatus,
            'ana_card': anaCard,
            'jal_tour_premium': jalTourPremium,
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
      // error fetching miles
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
    final isJGCOverseas = cardType == 'jgc_overseas';
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
        'jal_regular': 0.10,
        'jal_club_a': 0.25,
        'jal_club_a_gold': 0.25,
        'jal_platinum': 0.25,
        'jgc_japan': 0.35,
        'jgc_overseas': 0.0,
        'jal_navi': 0.10,
        'club_est_regular': 0.10,
        'club_est_club_a': 0.25,
        'club_est_gold': 0.25,
        'club_est_platinum': 0.25,
      };
      cardBonusRate = cardRates[cardType] ?? 0.0;
    }

    // ステータスボーナス率
    double statusBonusRate = 0.0;
    if (status != null) {
      const statusRates = {
        'diamond': 1.30,
        'jgc_premier': 1.05,
        'sapphire': 1.05,
        'crystal': 0.55,
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
        'amc_card': 0.0,
        'ana_regular': 0.10,
        'ana_student': 0.10,
        'ana_wide': 0.25,
        'ana_gold': 0.25,
        'ana_premium': 0.50,
        'sfc_regular': 0.35,
        'sfc_gold': 0.40,
        'sfc_premium': 0.50,
      };
      cardBonusRate = cardRates[cardType] ?? 0.0;
    }

    // ステータスボーナス率
    double statusBonusRate = 0.0;
    if (status != null) {
      const statusRates = {
        'diamond_1': 1.15,
        'diamond_2': 1.25,
        'platinum_1': 0.90,
        'platinum_2': 1.00,
        'bronze_1': 0.40,
        'bronze_2': 0.50,
      };
      statusBonusRate = statusRates[status] ?? 0.0;
    }

    // ゴールド/プレミアムカード + ステータスの場合 +5%
    final anaCardTypes = [
      '-',
      'amc_card',
      'ana_regular',
      'ana_student',
      'ana_wide',
      'ana_gold',
      'ana_premium',
      'sfc_regular',
      'sfc_gold',
      'sfc_premium',
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
}// ============================================================
// flight_log_screen.dart の _ShareDialog クラス全体を以下に差し替え
// 差し替え範囲: 行 3018〜ファイル末尾
// ============================================================

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

  // 搭乗日（任意）
  DateTime? _selectedDate;

  // 公開内容チェックボックス
  bool _showFopPp = true;
  bool _showMiles = true;
  bool _showStatus = true;

  // ユーザーステータス情報
  String _jalStatus = '';
  String _anaStatus = '';
  String _jalCard = '';
  String _anaCard = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await Supabase.instance.client
        .from('user_profiles')
        .select('jal_status, ana_status, jal_card, ana_card')
        .eq('id', user.id)
        .maybeSingle();
    if (profile != null && mounted) {
      setState(() {
        _jalStatus = profile['jal_status'] as String? ?? '';
        _anaStatus = profile['ana_status'] as String? ?? '';
        _jalCard = profile['jal_card'] as String? ?? '';
        _anaCard = profile['ana_card'] as String? ?? '';
      });
    }
  }

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

  String _statusToJapanese(String value) {
    const map = {
      // ステータス
      'diamond_1': 'ダイヤモンド(1年目)',
      'diamond_2': 'ダイヤモンド(継続)',
      'platinum_1': 'プラチナ(1年目)',
      'platinum_2': 'プラチナ(継続)',
      'bronze_1': 'ブロンズ(1年目)',
      'bronze_2': 'ブロンズ(継続)',
      'crystal': 'クリスタル',
      'sapphire': 'サファイア',
      'jgc_premier': 'JGCプレミア',
      // ANAカード
      'amc_card': 'AMCカード',
      'ana_regular': 'ANAカード一般',
      'ana_wide': 'ANAカードワイド',
      'ana_gold': 'ANAゴールド',
      'ana_premium': 'ANAプレミアム',
      'ana_student': 'ANAカード学生',
      'sfc_regular': 'SFC一般',
      'sfc_gold': 'SFCゴールド',
      'sfc_premium': 'SFCプレミアム',
      // JALカード
      'jmb': 'JMB会員',
      'jal_regular': 'JALカード普通',
      'jal_club_a': 'CLUB-A',
      'jal_club_a_gold': 'CLUB-Aゴールド',
      'jal_platinum': 'JALプラチナ',
      'jgc_japan': 'JGC(日本)',
      'jgc_overseas': 'JGC(海外)',
      'jal_navi': 'JAL NAVI',
      'club_est_regular': 'CLUB EST普通',
      'club_est_club_a': 'CLUB EST CLUB-A',
      'club_est_gold': 'CLUB EST GOLD',
      'club_est_platinum': 'CLUB ESTプラチナ',
      // 空値
      'なし': '',
      'NULL': '',
      '-': '',
    };
    return map[value] ?? value;
  }

  // ツイート用テキスト（簡略化: テーマ+日付+ルート+コメント+ハッシュタグ+URL）
  String _generateTweetText() {
    final itinerary = widget.itinerary;
    final theme = _themeController.text.trim();
    final comment = _commentController.text.trim();
    final title = _titleToJapanese(itinerary['title'] as String? ?? '');
    final fop = itinerary['total_fop'] as int? ?? 0;

    final buf = StringBuffer();
    if (theme.isNotEmpty) {
      buf.writeln('✈️【$theme】');
    } else {
      buf.writeln('✈️【修行プラン】');
    }
    if (_selectedDate != null) {
      final d = _selectedDate!;
      buf.writeln('📅 ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}');
    }
    buf.writeln('🛫 $title');

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
    final fop = itinerary['total_fop'] as int? ?? 0;
    final pp = itinerary['total_pp'] as int? ?? 0;
    final miles = itinerary['total_miles'] as int? ?? 0;
    final lsp = itinerary['total_lsp'] as int? ?? 0;
    final fare = itinerary['total_fare'] as int? ?? 0;
    final legs = itinerary['legs'] as List<dynamic>? ?? [];

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
      width: 400,
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
          // ── ヘッダー: 左上に #MRP + テーマ ──
          Text(
            '#MRP',
            style: TextStyle(
              color: primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            theme.isNotEmpty ? theme : '修行プラン',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey[800]),
          const SizedBox(height: 12),

          // ── 統計バッジ（チェックON時のみ表示） ──
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (_showFopPp && fop > 0) _statBadge('FOP', _formatNumber(fop), primaryColor),
              if (_showFopPp && pp > 0) _statBadge('PP', _formatNumber(pp), primaryColor),
              if (_showMiles) _statBadge('マイル', _formatNumber(miles), Colors.grey[400]!),
              if (_showFopPp && lsp > 0) _statBadge('LSP', '$lsp', Colors.amber),
            ],
          ),

          // ステータス表示（チェックON時のみ）
          if (_showStatus) ...[
            const SizedBox(height: 8),
            if (isJal || isMixed) ...[
              if (_jalStatus.isNotEmpty && _jalStatus != '-' && _jalStatus != 'なし')
                Text(
                  '🏅 JAL ${_statusToJapanese(_jalStatus)}${_jalCard.isNotEmpty && _jalCard != '-' && _jalCard != 'なし' && _jalCard != 'NULL' ? ' / ${_statusToJapanese(_jalCard)}' : ''}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
            ],
            if (isAna || isMixed) ...[
              if (_anaStatus.isNotEmpty && _anaStatus != '-' && _anaStatus != 'なし')
                Text(
                  '🏅 ANA ${_statusToJapanese(_anaStatus)}${_anaCard.isNotEmpty && _anaCard != '-' && _anaCard != 'なし' && _anaCard != 'NULL' ? ' / ${_statusToJapanese(_anaCard)}' : ''}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
            ],
          ],

          if (fare > 0 && _showFopPp) ...[
            const SizedBox(height: 8),
            Text(
              '💰 ¥${_formatNumber(fare)}${unitPrice.isNotEmpty ? "（$unitPrice）" : ""}',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey[800]),
          const SizedBox(height: 8),

          // ── レグ詳細（時刻+マイル列追加） ──
          // ヘッダー行
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text('便名', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
              ),
              SizedBox(
                width: 70,
                child: Text('区間', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
              ),
              SizedBox(
                width: 80,
                child: Text('出発-到着', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
              ),
              if (_showMiles)
                SizedBox(
                  width: 40,
                  child: Text('マイル', style: TextStyle(color: Colors.grey[600], fontSize: 9), textAlign: TextAlign.right),
                ),
              if (_showFopPp)
                Expanded(
                  child: Text(
                    fop > 0 ? 'FOP' : 'PP',
                    style: TextStyle(color: Colors.grey[600], fontSize: 9),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ...legs.asMap().entries.map((entry) {
            final l = entry.value as Map<String, dynamic>;
            final legAirline = l['airline'] as String? ?? '';
            final flightNum = l['flight_number'] as String? ?? '';
            final dep = l['departure_airport'] as String? ?? '';
            final arr = l['arrival_airport'] as String? ?? '';
            final depTime = l['departure_time'] as String? ?? '';
            final arrTime = l['arrival_time'] as String? ?? '';
            final legFop = l['fop'] as int? ?? 0;
            final legPp = l['pp'] as int? ?? 0;
            final legMiles = l['miles'] as int? ?? 0;
            final points = legFop > 0 ? legFop : legPp;
            final pointLabel = legFop > 0 ? 'FOP' : 'PP';

            final iataCode = legAirline == 'JAL' ? 'JL' : legAirline == 'ANA' ? 'NH' : legAirline;
            final displayFlight = flightNum.startsWith(iataCode)
                ? flightNum
                : '$iataCode$flightNum';

            // 時刻フォーマット（HH:MM-HH:MM）
            String timeStr = '';
            if (depTime.isNotEmpty && arrTime.isNotEmpty) {
              final dShort = depTime.length >= 5 ? depTime.substring(0, 5) : depTime;
              final aShort = arrTime.length >= 5 ? arrTime.substring(0, 5) : arrTime;
              timeStr = '$dShort-$aShort';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      displayFlight,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '$dep→$arr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (_showMiles)
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$legMiles',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  if (_showFopPp)
                    Expanded(
                      child: Text(
                        '$points $pointLabel',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
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

  // 日付ピッカー
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
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
                  hintText: '例: W杯追っかけ修行',
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
              const SizedBox(height: 12),

              // 搭乗日カレンダー（任意）
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '搭乗日（任意）',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _selectedDate = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.year}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.day.toString().padLeft(2, '0')}'
                        : '',
                    style: TextStyle(
                      color: _selectedDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 公開内容チェックボックス
              Text(
                '📋 画像に表示する内容',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 0,
                children: [
                  _buildCheckbox('FOP/PP', _showFopPp, (v) => setState(() => _showFopPp = v ?? true)),
                  _buildCheckbox('マイル数', _showMiles, (v) => setState(() => _showMiles = v ?? true)),
                  _buildCheckbox('ステータス', _showStatus, (v) => setState(() => _showStatus = v ?? true)),
                ],
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

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return SizedBox(
      width: 130,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}


