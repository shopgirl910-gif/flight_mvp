import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';
import 'package:flutter/services.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> legs = [];
  int? expandedLegId;

  Map<int, TextEditingController> dateControllers = {};
  Map<int, TextEditingController> flightNumberControllers = {};
  Map<int, TextEditingController> departureTimeControllers = {};
  Map<int, TextEditingController> arrivalTimeControllers = {};
  Map<int, TextEditingController> fareAmountControllers = {};
  Map<int, TextEditingController> departureAirportControllers = {};
  Map<int, TextEditingController> arrivalAirportControllers = {};
  Map<int, FocusNode> departureAirportFocusNodes = {};
  Map<int, FocusNode> arrivalAirportFocusNodes = {};

  Map<int, List<Map<String, dynamic>>> availableFlights = {};
  Map<int, List<String>> availableDestinations = {};
  Map<int, String?> legWarnings = {};
  Map<String, List<String>> airlineAirports = {};

  int _legIdCounter = 0;
  bool isLoading = false;
  String? errorMessage;

  String? selectedJALCard;
  String? selectedANACard;
  String? selectedJALStatus;
  String? selectedANAStatus;
  bool jalTourPremium = false;
  bool jalShoppingMilePremium = false;
  
  // モバイル版設定パネル展開状態
  bool _jalSettingsExpanded = false;
  bool _anaSettingsExpanded = false;

  final List<String> jalCardTypes = [
    'JMB会員',
    'JALカード普通会員',
    'JALカードCLUB-A会員',
    'JALカードCLUB-Aゴールド会員',
    'JALカードプラチナ会員',
    'JALグローバルクラブ会員(日本)',
    'JALグローバルクラブ会員(海外)',
    'JALカードNAVI会員',
    'JAL CLUB EST 普通会員',
    'JAL CLUB EST CLUB-A会員',
    'JAL CLUB EST CLUB-A GOLD会員',
    'JAL CLUB EST プラチナ会員',
  ];
  final List<String> anaCardTypes = [
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
  final List<String> jalStatusTypes = [
    '-',
    'JMBダイヤモンド',
    'JMBサファイア',
    'JMBクリスタル',
  ];
  final List<String> anaStatusTypes = [
    '-',
    'ダイヤモンド(1年目)',
    'ダイヤモンド(継続2年以上)',
    'プラチナ(1年目)',
    'プラチナ(継続2年以上)',
    'ブロンズ(1年目)',
    'ブロンズ(継続2年以上)',
  ];

  final List<String> majorAirports = [
    'HND',
    'NRT',
    'ITM',
    'KIX',
    'NGO',
    'CTS',
    'FUK',
    'OKA',
  ];
  static const String airportDivider = '---';
  final List<String> regionalAirports = [
    'WKJ',
    'MBE',
    'MMB',
    'SHB',
    'AKJ',
    'OKD',
    'OBO',
    'KUH',
    'HKD',
    'OIR',
    'AOJ',
    'MSJ',
    'HNA',
    'AXT',
    'ONJ',
    'SYO',
    'GAJ',
    'SDJ',
    'FKS',
    'HAC',
    'NKM',
    'FSZ',
    'MMJ',
    'NTQ',
    'TOY',
    'KMQ',
    'SHM',
    'UKB',
    'TJH',
    'TTJ',
    'YGJ',
    'OKI',
    'IZO',
    'OKJ',
    'HIJ',
    'IWK',
    'UBJ',
    'TKS',
    'TAK',
    'KCZ',
    'MYJ',
    'KKJ',
    'HSG',
    'NGS',
    'KMJ',
    'OIT',
    'KMI',
    'KOJ',
    'AXJ',
    'IKI',
    'TSJ',
    'FUJ',
    'TNE',
    'KUM',
    'ASJ',
    'KKX',
    'TKN',
    'RNJ',
    'OGN',
    'MMY',
    'ISG',
    'UEO',
    'KTD',
    'MMD',
    'TRA',
    'AGJ',
    'KJP',
    'HTR',
    'SHI',
    'IEJ',
  ];
  List<String> get airports => [
    ...majorAirports,
    airportDivider,
    ...regionalAirports,
  ];

  final Map<String, String> airportNames = {
    'HND': '羽田',
    'NRT': '成田',
    'KIX': '関西',
    'ITM': '伊丹',
    'NGO': '中部',
    'CTS': '新千歳',
    'FUK': '福岡',
    'OKA': '那覇',
    'NGS': '長崎',
    'KMJ': '熊本',
    'OIT': '大分',
    'MYJ': '松山',
    'HIJ': '広島',
    'TAK': '高松',
    'KCZ': '高知',
    'TKS': '徳島',
    'KOJ': '鹿児島',
    'SDJ': '仙台',
    'AOJ': '青森',
    'AKJ': '旭川',
    'AXT': '秋田',
    'GAJ': '山形',
    'KIJ': '新潟',
    'TOY': '富山',
    'KMQ': '小松',
    'FSZ': '静岡',
    'MMB': '女満別',
    'OBO': '帯広',
    'KUH': '釧路',
    'HKD': '函館',
    'ISG': '石垣',
    'MMY': '宮古',
    'UBJ': '山口宇部',
    'IWK': '岩国',
    'OKJ': '岡山',
    'TTJ': '鳥取',
    'YGJ': '米子',
    'IZO': '出雲',
    'NKM': '県営名古屋',
    'UKB': '神戸',
    'HSG': '佐賀',
    'KMI': '宮崎',
    'ASJ': '奄美',
    'TKN': '徳之島',
    'OKI': '隠岐',
    'FKS': '福島',
    'HNA': '花巻',
    'MSJ': '三沢',
    'ONJ': '大館能代',
    'SHM': '南紀白浜',
    'NTQ': '能登',
    'KKJ': '北九州',
    'TNE': '種子島',
    'KUM': '屋久島',
    'RNJ': '与論',
    'OGN': '与那国',
    'HAC': '八丈島',
    'MBE': '紋別',
    'SHB': '中標津',
    'WKJ': '稚内',
    'OKD': '丘珠',
    'IKI': '壱岐',
    'TSJ': '対馬',
    'FUJ': '五島福江',
    'OIR': '奥尻',
    'SYO': '庄内',
    'MMJ': '松本',
    'AXJ': '天草',
    'TJH': '但馬',
    'KKX': '喜界',
    'UEO': '久米島',
    'KTD': '北大東',
    'MMD': '南大東',
    'AGJ': '粟国',
    'KJP': '慶良間',
    'TRA': '多良間',
    'HTR': '波照間',
    'SHI': '下地島',
    'IEJ': '伊江島',
  };
  final List<String> airlines = ['JAL', 'ANA'];
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
      '運賃2 (125%) プレミアム小児',
      '運賃3 (100%) 片道・往復',
      '運賃4 (100%) ビジネス',
      '運賃5 (75%) 特割A',
      '運賃6 (75%) 特割B',
      '運賃7 (75%) 特割C',
      '運賃8 (50%) いっしょにマイル割',
      '運賃9 (150%) プレミアム株主',
      '運賃10 (100%) 普通株主',
      '運賃11 (70%) 特割プラス',
      '運賃12 (50%) スマートシニア',
      '運賃13 (30%) 個人包括',
    ],
  };
  final Map<String, List<String>> seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファーストクラス'],
    'ANA': ['普通席', 'プレミアムクラス'],
  };
  final Map<String, int> jalBonusFOP = {
    '運賃1': 400,
    '運賃2': 400,
    '運賃3': 200,
    '運賃4': 200,
    '運賃5': 0,
    '運賃6': 0,
  };
  final Map<String, int> anaBonusPoint = {
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

  // ANAプレミアムクラス専用運賃（運賃1, 2, 9）
  static const Set<String> anaPremiumFares = {'運賃1', '運賃2', '運賃9'};
  bool _isAnaPremiumFare(String fareType) {
    return fareType.startsWith('運賃1 ') ||
        fareType.startsWith('運賃2 ') ||
        fareType.startsWith('運賃9 ');
  }

  // Hapitasリンク
  static const String _hapitasUrl =
      'https://px.a8.net/svt/ejp?a8mat=45KL8I+5JG97E+1LP8+CALN5';
  Future<void> _openHapitas() async {
    final uri = Uri.parse(_hapitasUrl);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    _initAirlineAirports();
    _addLeg();
  }

  Future<void> _initAirlineAirports() async {
    await _fetchAirlineAirports('JAL');
    await _fetchAirlineAirports('ANA');
  }

  Future<List<String>> _fetchAirlineAirports(String airline) async {
    if (airlineAirports.containsKey(airline)) return airlineAirports[airline]!;
    try {
      final response = await Supabase.instance.client
          .from('schedules')
          .select('departure_code')
          .eq('airline_code', airline)
          .eq('is_active', true);
      final codes =
          (response as List)
              .map((r) => r['departure_code'] as String)
              .toSet()
              .toList()
            ..sort();
      setState(() => airlineAirports[airline] = codes);
      return codes;
    } catch (e) {
      return airports;
    }
  }

  @override
  void dispose() {
    for (var c in dateControllers.values) c.dispose();
    for (var c in flightNumberControllers.values) c.dispose();
    for (var c in departureTimeControllers.values) c.dispose();
    for (var c in arrivalTimeControllers.values) c.dispose();
    for (var c in fareAmountControllers.values) c.dispose();
    for (var c in departureAirportControllers.values) c.dispose();
    for (var c in arrivalAirportControllers.values) c.dispose();
    for (var f in departureAirportFocusNodes.values) f.dispose();
    for (var f in arrivalAirportFocusNodes.values) f.dispose();
    super.dispose();
  }

  void _addLeg() {
    final legId = _legIdCounter++;
    dateControllers[legId] = TextEditingController();
    flightNumberControllers[legId] = TextEditingController();
    departureTimeControllers[legId] = TextEditingController();
    arrivalTimeControllers[legId] = TextEditingController();
    fareAmountControllers[legId] = TextEditingController();
    departureAirportControllers[legId] = TextEditingController();
    arrivalAirportControllers[legId] = TextEditingController();
    departureAirportFocusNodes[legId] = FocusNode();
    arrivalAirportFocusNodes[legId] = FocusNode();
    String airline = 'JAL',
        departureAirport = '',
        arrivalAirport = '',
        date = '';
    if (legs.isNotEmpty) {
      final prevLeg = legs.last;
      final prevLegId = prevLeg['id'] as int;
      airline = prevLeg['airline'] as String;
      departureAirport = prevLeg['arrivalAirport'] as String;
      arrivalAirport = prevLeg['departureAirport'] as String;
      date = dateControllers[prevLegId]?.text ?? '';
    }
    dateControllers[legId]?.text = date;
    departureAirportControllers[legId]?.text = departureAirport;
    arrivalAirportControllers[legId]?.text = arrivalAirport;
    setState(() {
      legs.add({
        'id': legId,
        'airline': airline,
        'departureAirport': departureAirport,
        'arrivalAirport': arrivalAirport,
        'fareType': '',
        'seatClass': '',
        'calculatedFOP': null,
        'calculatedMiles': null,
        'calculatedLSP': null,
      });
      expandedLegId = legId;
    });
    if (departureAirport.isNotEmpty) _fetchAvailableFlights(legs.length - 1);
  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    dateControllers[legId]?.dispose();
    flightNumberControllers[legId]?.dispose();
    departureTimeControllers[legId]?.dispose();
    arrivalTimeControllers[legId]?.dispose();
    fareAmountControllers[legId]?.dispose();
    departureAirportControllers[legId]?.dispose();
    arrivalAirportControllers[legId]?.dispose();
    departureAirportFocusNodes[legId]?.dispose();
    arrivalAirportFocusNodes[legId]?.dispose();
    dateControllers.remove(legId);
    flightNumberControllers.remove(legId);
    departureTimeControllers.remove(legId);
    arrivalTimeControllers.remove(legId);
    fareAmountControllers.remove(legId);
    departureAirportControllers.remove(legId);
    arrivalAirportControllers.remove(legId);
    departureAirportFocusNodes.remove(legId);
    arrivalAirportFocusNodes.remove(legId);
    availableFlights.remove(legId);
    availableDestinations.remove(legId);
    setState(() {
      legs.removeAt(index);
      if (expandedLegId == legId)
        expandedLegId = legs.isNotEmpty ? legs.last['id'] as int : null;
    });
  }

  void _clearFlightInfo(int index, int legId) {
    setState(() {
      legs[index]['departureAirport'] = '';
      legs[index]['arrivalAirport'] = '';
      legs[index]['calculatedFOP'] = null;
      legs[index]['calculatedMiles'] = null;
      legs[index]['calculatedLSP'] = null;
      availableFlights[legId] = [];
      availableDestinations[legId] = [];
      legWarnings[legId] = null;
    });
    flightNumberControllers[legId]?.text = '';
    departureTimeControllers[legId]?.text = '';
    arrivalTimeControllers[legId]?.text = '';
    departureAirportControllers[legId]?.text = '';
    arrivalAirportControllers[legId]?.text = '';
  }

  void _clearLeg(int index, int legId) {
    _clearFlightInfo(index, legId);
    setState(() {
      legs[index]['fareType'] = '';
      legs[index]['seatClass'] = '';
    });
    dateControllers[legId]?.text = '';
    fareAmountControllers[legId]?.text = '';
  }

  String _addMinutes(String time, int minutes) {
    if (time.isEmpty || !time.contains(':')) return time;
    final parts = time.split(':');
    int hour = int.tryParse(parts[0]) ?? 0, min = int.tryParse(parts[1]) ?? 0;
    min += minutes;
    while (min >= 60) {
      min -= 60;
      hour += 1;
    }
    if (hour >= 24) hour -= 24;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  bool _isTimeAfterOrEqual(String time1, String time2) {
    if (time1.isEmpty ||
        time2.isEmpty ||
        !time1.contains(':') ||
        !time2.contains(':'))
      return true;
    final parts1 = time1.split(':'), parts2 = time2.split(':');
    return (int.tryParse(parts1[0]) ?? 0) * 60 +
            (int.tryParse(parts1[1]) ?? 0) >=
        (int.tryParse(parts2[0]) ?? 0) * 60 + (int.tryParse(parts2[1]) ?? 0);
  }

  // ======== 時刻表選択ルール ========
  // 1. 入力日を含む運航期間がある → その期間を使用
  // 2. ない場合 → 入力日以降で最初に始まる期間を探す
  // 3. それもない場合 → 入力日以前で最後に終わる期間を使用
  List<Map<String, dynamic>> _filterFlightsByDateRule(
    List<Map<String, dynamic>> flights,
    String targetDate,
  ) {
    final flightsByRoute = <String, List<Map<String, dynamic>>>{};
    for (var flight in flights) {
      final key = '${flight['flight_number']}_${flight['arrival_code']}';
      flightsByRoute.putIfAbsent(key, () => []);
      flightsByRoute[key]!.add(flight);
    }
    final result = <Map<String, dynamic>>[];
    for (var entry in flightsByRoute.entries) {
      final routeFlights = entry.value;
      // 1. 入力日を含む期間
      var selected = routeFlights
          .where(
            (f) =>
                (f['period_start'] as String).compareTo(targetDate) <= 0 &&
                (f['period_end'] as String).compareTo(targetDate) >= 0,
          )
          .toList();
      if (selected.isNotEmpty) {
        result.add(selected.first);
        continue;
      }
      // 2. 入力日以降で最初の期間
      selected = routeFlights
          .where((f) => (f['period_start'] as String).compareTo(targetDate) > 0)
          .toList();
      if (selected.isNotEmpty) {
        selected.sort(
          (a, b) => (a['period_start'] as String).compareTo(
            b['period_start'] as String,
          ),
        );
        result.add(selected.first);
        continue;
      }
      // 3. 入力日以前で最後の期間
      selected = routeFlights
          .where((f) => (f['period_end'] as String).compareTo(targetDate) < 0)
          .toList();
      if (selected.isNotEmpty) {
        selected.sort(
          (a, b) =>
              (b['period_end'] as String).compareTo(a['period_end'] as String),
        );
        result.add(selected.first);
      }
    }
    return result;
  }

  Map<String, dynamic>? _selectScheduleByDateRule(
    List<Map<String, dynamic>> schedules,
    String targetDate,
  ) {
    if (schedules.isEmpty) return null;
    // 1. 入力日を含む期間
    var selected = schedules
        .where(
          (s) =>
              (s['period_start'] as String).compareTo(targetDate) <= 0 &&
              (s['period_end'] as String).compareTo(targetDate) >= 0,
        )
        .toList();
    if (selected.isNotEmpty) return selected.first;
    // 2. 入力日以降で最初の期間
    selected = schedules
        .where((s) => (s['period_start'] as String).compareTo(targetDate) > 0)
        .toList();
    if (selected.isNotEmpty) {
      selected.sort(
        (a, b) => (a['period_start'] as String).compareTo(
          b['period_start'] as String,
        ),
      );
      return selected.first;
    }
    // 3. 入力日以前で最後の期間
    selected = schedules
        .where((s) => (s['period_end'] as String).compareTo(targetDate) < 0)
        .toList();
    if (selected.isNotEmpty) {
      selected.sort(
        (a, b) =>
            (b['period_end'] as String).compareTo(a['period_end'] as String),
      );
      return selected.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(
    String airline,
    String flightNumber,
    String date,
  ) async {
    try {
      final targetDate = date.isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : date.replaceAll('/', '-');
      final response = await Supabase.instance.client
          .from('schedules')
          .select()
          .eq('airline_code', airline)
          .eq('flight_number', flightNumber)
          .eq('is_active', true);
      return _selectScheduleByDateRule(
        (response as List).cast<Map<String, dynamic>>(),
        targetDate,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int,
        airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '',
        date = dateControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) {
      setState(() => errorMessage = '便名を入力してください');
      return;
    }
    final schedule = await _fetchScheduleByFlightNumber(
      airline,
      flightNumber,
      date,
    );
    if (schedule != null) {
      String depTime = schedule['departure_time'] ?? '',
          arrTime = schedule['arrival_time'] ?? '';
      if (depTime.length > 5) depTime = depTime.substring(0, 5);
      if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
      final depCode = schedule['departure_code'] as String,
          arrCode = schedule['arrival_code'] as String;
      setState(() {
        legs[index]['departureAirport'] = depCode;
        legs[index]['arrivalAirport'] = arrCode;
        errorMessage = null;
      });
      departureTimeControllers[legId]?.text = depTime;
      arrivalTimeControllers[legId]?.text = arrTime;
      departureAirportControllers[legId]?.text = depCode;
      arrivalAirportControllers[legId]?.text = arrCode;
      if ((schedule['remarks'] as String? ?? '').isNotEmpty)
        setState(() => legWarnings[legId] = '⚠️ 一部期間で時刻変更あり');
      await _fetchAvailableFlights(index);
      if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
      _calculateSingleLeg(index);
    } else {
      setState(() => errorMessage = '$flightNumber便が見つかりません');
    }
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final leg = legs[index];
    final legId = leg['id'] as int, airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String,
        arrival = leg['arrivalAirport'] as String;
    final dateText = dateControllers[legId]?.text ?? '';
    if (departure.isEmpty) {
      setState(() {
        availableFlights[legId] = [];
        availableDestinations[legId] = [];
      });
      return;
    }
    final targetDate = dateText.isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : dateText.replaceAll('/', '-');
    try {
      final allFlightsResponse = await Supabase.instance.client
          .from('schedules')
          .select()
          .eq('airline_code', airline)
          .eq('departure_code', departure)
          .eq('is_active', true)
          .order('departure_time');
      var allFlights = _filterFlightsByDateRule(
        (allFlightsResponse as List).cast<Map<String, dynamic>>(),
        targetDate,
      );
      final seenAll = <String>{};
      allFlights = allFlights.where((flight) {
        String depTime = flight['departure_time'] ?? '';
        if (depTime.length > 5) depTime = depTime.substring(0, 5);
        final key = '${depTime}_${flight['arrival_code']}';
        if (seenAll.contains(key)) return false;
        seenAll.add(key);
        return true;
      }).toList();
      final destinations =
          allFlights.map((f) => f['arrival_code'] as String).toSet().toList()
            ..sort();
      var filteredFlights = arrival.isNotEmpty
          ? allFlights.where((f) => f['arrival_code'] == arrival).toList()
          : allFlights;
      if (index > 0) {
        final prevLeg = legs[index - 1];
        final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String,
            prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          filteredFlights = filteredFlights.where((flight) {
            String depTime = flight['departure_time'] ?? '';
            if (depTime.length > 5) depTime = depTime.substring(0, 5);
            return _isTimeAfterOrEqual(depTime, minDepartureTime);
          }).toList();
        }
      }
      setState(() {
        availableFlights[legId] = filteredFlights;
        availableDestinations[legId] = destinations;
      });
    } catch (e) {
      setState(() {
        availableFlights[legId] = [];
        availableDestinations[legId] = [];
      });
    }
  }

  Future<void> _calculateSingleLeg(int index) async {
    final leg = legs[index];
    final dep = leg['departureAirport'] as String,
        arr = leg['arrivalAirport'] as String;
    final fare = leg['fareType'] as String,
        seat = leg['seatClass'] as String,
        airline = leg['airline'] as String;
    if (dep.isEmpty || arr.isEmpty || fare.isEmpty || seat.isEmpty) return;
    try {
      final routeData = await Supabase.instance.client
          .from('routes')
          .select('distance_miles')
          .eq('departure_code', dep)
          .eq('arrival_code', arr)
          .maybeSingle();
      if (routeData == null) return;
      final distance = routeData['distance_miles'] as int;
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      final fareNumber = fare.split(' ').first;
      int totalPoints = 0, totalMiles = 0, totalLSP = 0;
      if (airline == 'JAL') {
        final seatBonusRate =
            {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seat] ?? 0.0;
        // JALカードボーナス率（EST系は+5%）
        final cardBonusRate =
            {
              '-': 0.0,
              'JMB会員': 0.0,
              'JALカード普通会員': 0.10,
              'JALカードCLUB-A会員': 0.25,
              'JALカードCLUB-Aゴールド会員': 0.25,
              'JALカードプラチナ会員': 0.25,
              'JALグローバルクラブ会員(日本)': 0.35,
              'JALグローバルクラブ会員(海外)': 0.0,
              'JALカードNAVI会員': 0.10,
              'JAL CLUB EST 普通会員': 0.15,
              'JAL CLUB EST CLUB-A会員': 0.30,
              'JAL CLUB EST CLUB-A GOLD会員': 0.30,
              'JAL CLUB EST プラチナ会員': 0.30,
            }[selectedJALCard ?? '-'] ??
            0.0;
        final statusBonusRate =
            {
              '-': 0.0,
              'JMBダイヤモンド': 1.30,
              'JMBサファイア': 1.05,
              'JMBクリスタル': 0.55,
            }[selectedJALStatus ?? '-'] ??
            0.0;
        final appliedBonusRate = cardBonusRate > statusBonusRate
            ? cardBonusRate
            : statusBonusRate;

        // フライトマイル（元の積算率ベース、FOP計算にも使用）
        final flightMiles = (distance * (fareRate + seatBonusRate)).round();

        // ツアープレミアム判定（運賃4,5が対象）
        final isTourPremiumTarget =
            jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5');

        if (isTourPremiumTarget) {
          // ツアプレ適用時: フライトマイル + ツアプレボーナス + カードボーナス
          final tourPremiumBonus = (distance * (1.0 - fareRate)).round();
          final cardBonus = (flightMiles * appliedBonusRate + 0.5).toInt();
          totalMiles = flightMiles + tourPremiumBonus + cardBonus;
        } else {
          // 通常計算
          totalMiles =
              flightMiles + (flightMiles * appliedBonusRate + 0.5).toInt();
        }
        // FOP計算: ツアプレ影響なし、常に元の積算率ベース
        totalPoints = (flightMiles * 2) + (jalBonusFOP[fareNumber] ?? 0);
        totalLSP = (fareRate >= 0.5) ? 5 : 0;
      } else {
        // +5%対象カード判定（ゴールド/プレミアム系）
        final isGoldPremium = {
          'ANAカード ゴールド',
          'ANAカード プレミアム',
          'SFC ゴールド',
          'SFC プレミアム',
        }.contains(selectedANACard);
        final cardBonusRate =
            {
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
            }[selectedANACard ?? '-'] ??
            0.0;
        final statusBonusRate =
            {
              '-': 0.0,
              'ダイヤモンド(1年目)': 1.15,
              'ダイヤモンド(継続2年以上)': 1.25,
              'プラチナ(1年目)': 0.90,
              'プラチナ(継続2年以上)': 1.00,
              'ブロンズ(1年目)': 0.40,
              'ブロンズ(継続2年以上)': 0.50,
            }[selectedANAStatus ?? '-'] ??
            0.0;
        // 適用ボーナス率：ゴールド/プレミアム系+ステータス保有時は+5%
        final hasStatus = statusBonusRate > 0.0;
        final appliedBonusRate = (isGoldPremium && hasStatus)
            ? statusBonusRate + 0.05
            : (cardBonusRate > statusBonusRate
                  ? cardBonusRate
                  : statusBonusRate);
        // 段階的切り捨て（公式計算方法に準拠）
        final flightMiles = (distance * fareRate).toInt();
        final bonusMiles = (flightMiles * appliedBonusRate).toInt();
        totalMiles = flightMiles + bonusMiles;
        totalPoints =
            ((distance * fareRate * 2) + (anaBonusPoint[fareNumber] ?? 0))
                .toInt();
      }
      setState(() {
        legs[index]['calculatedFOP'] = totalPoints;
        legs[index]['calculatedMiles'] = totalMiles;
        legs[index]['calculatedLSP'] = totalLSP;
      });
    } catch (e) {}
  }

  void _recalculateAllLegs() {
    for (int i = 0; i < legs.length; i++) _calculateSingleLeg(i);
  }

  void _onJALCardChanged(String? v) {
    setState(() => selectedJALCard = v);
    _recalculateAllLegs();
  }

  void _onJALStatusChanged(String? v) {
    setState(() => selectedJALStatus = v);
    _recalculateAllLegs();
  }

  void _onANACardChanged(String? v) {
    setState(() => selectedANACard = v);
    _recalculateAllLegs();
  }

  void _onANAStatusChanged(String? v) {
    setState(() => selectedANAStatus = v);
    _recalculateAllLegs();
  }

  void _onJALTourPremiumChanged(bool? v) {
    setState(() => jalTourPremium = v ?? false);
    _recalculateAllLegs();
  }

  void _onJALShoppingMilePremiumChanged(bool? v) {
    setState(() => jalShoppingMilePremium = v ?? false);
  }

  Future<void> _saveItinerary() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ログインが必要です'),
            content: const Text('旅程を保存するにはログインしてください。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AuthScreen(
                        onAuthSuccess: () {
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
                child: const Text('ログイン'),
              ),
            ],
          ),
        );
      }
      return;
    }
    final userId = user.id;
    final validLegs = legs
        .where((leg) => leg['calculatedFOP'] != null)
        .toList();
    if (validLegs.isEmpty) {
      setState(() => errorMessage = '保存するレグがありません');
      return;
    }
    setState(() => isLoading = true);
    try {
      final airports = <String>[];
      for (var leg in validLegs) {
        final dep = leg['departureAirport'] as String,
            arr = leg['arrivalAirport'] as String;
        if (airports.isEmpty || airports.last != dep) airports.add(dep);
        airports.add(arr);
      }
      final title = '${airports.join("-")} ${validLegs.length}レグ';
      final legsJson = validLegs.map((leg) {
        final legId = leg['id'] as int;
        return {
          'airline': leg['airline'],
          'date': dateControllers[legId]?.text ?? '',
          'flight_number': flightNumberControllers[legId]?.text ?? '',
          'departure_airport': leg['departureAirport'],
          'arrival_airport': leg['arrivalAirport'],
          'departure_time': departureTimeControllers[legId]?.text ?? '',
          'arrival_time': arrivalTimeControllers[legId]?.text ?? '',
          'fare_type': leg['fareType'],
          'seat_class': leg['seatClass'],
          'fare_amount':
              int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0,
          'fop': leg['calculatedFOP'],
          'miles': leg['calculatedMiles'],
          'lsp': leg['calculatedLSP'],
        };
      }).toList();
      await Supabase.instance.client.from('saved_itineraries').insert({
        'user_id': userId,
        'title': title,
        'legs': legsJson,
        'total_fop': jalFOP,
        'total_pp': anaPP,
        'total_miles': jalMiles + anaMiles,
        'total_lsp': jalTotalLSP,
        'total_fare': jalFare + anaFare,
        'jal_card': selectedJALCard,
        'ana_card': selectedANACard,
        'jal_status': selectedJALStatus,
        'ana_status': selectedANAStatus,
        'jal_tour_premium': jalTourPremium,
        'jal_shopping_mile_premium': jalShoppingMilePremium,
      });
      setState(() {
        isLoading = false;
        errorMessage = null;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$title」を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '保存に失敗しました: $e';
      });
    }
  }

  void _downloadCsv() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ログインが必要です'),
            content: const Text('CSVをダウンロードするにはログインしてください。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AuthScreen(
                        onAuthSuccess: () {
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
                child: const Text('ログイン'),
              ),
            ],
          ),
        );
      }
      return;
    }
    final validLegs = legs
        .where((leg) => leg['calculatedFOP'] != null)
        .toList();
    if (validLegs.isEmpty) {
      setState(() => errorMessage = 'ダウンロードするレグがありません');
      return;
    }

    final csvRows = <String>[];
    csvRows.add('日付,航空会社,便名,出発地,到着地,出発時刻,到着時刻,運賃種別,座席クラス,運賃,FOP/PP,マイル,LSP');
    for (var leg in validLegs) {
      final legId = leg['id'] as int;
      final airline = leg['airline'] as String;
      csvRows.add(
        [
          dateControllers[legId]?.text ?? '',
          airline,
          flightNumberControllers[legId]?.text ?? '',
          leg['departureAirport'],
          leg['arrivalAirport'],
          departureTimeControllers[legId]?.text ?? '',
          arrivalTimeControllers[legId]?.text ?? '',
          '"${leg['fareType']}"',
          leg['seatClass'],
          fareAmountControllers[legId]?.text ?? '0',
          '${leg['calculatedFOP'] ?? 0}',
          '${leg['calculatedMiles'] ?? 0}',
          airline == 'JAL' ? '${leg['calculatedLSP'] ?? 0}' : '-',
        ].join(','),
      );
    }
    csvRows.add('');
    csvRows.add(
      '合計,,,,,,,,,${jalFare + anaFare},FOP:$jalFOP / PP:$anaPP,${jalMiles + anaMiles},$jalTotalLSP',
    );

    final csvContent = csvRows.join('\n');
    final bom = [0xEF, 0xBB, 0xBF];
    final bytes = Uint8List.fromList([...bom, ...utf8.encode(csvContent)]);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'flight_simulation_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      )
      ..click();
    html.Url.revokeObjectUrl(url);

    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSVをダウンロードしました'),
          backgroundColor: Colors.green,
        ),
      );
  }

  String _formatNumber(int number) => number == 0
      ? '0'
      : number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  int get jalFOP => legs
      .where((l) => l['airline'] == 'JAL')
      .fold<int>(0, (s, l) => s + ((l['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs
      .where((l) => l['airline'] == 'JAL')
      .fold<int>(0, (s, l) => s + ((l['calculatedMiles'] as int?) ?? 0));
  int get jalFlightLSP => legs
      .where((l) => l['airline'] == 'JAL')
      .fold<int>(0, (s, l) => s + ((l['calculatedLSP'] as int?) ?? 0));
  bool get isAutoShoppingMilePremium {
    final c = selectedJALCard ?? '-';
    return c.contains('ゴールド') ||
        c.contains('プラチナ') ||
        c.contains('JAL CLUB EST') ||
        c == 'JALカードNAVI会員';
  }

  bool get isShoppingMileEligible {
    final c = selectedJALCard ?? '-';
    return c != '-' && c != 'JMB会員';
  }

  bool get isShoppingMilePremiumActive =>
      isAutoShoppingMilePremium || jalShoppingMilePremium;
  int get jalShoppingMiles => !isShoppingMileEligible
      ? 0
      : (isShoppingMilePremiumActive ? jalFare ~/ 100 : jalFare ~/ 200);
  int get jalShoppingLSP => (jalShoppingMiles ~/ 2000) * 5;
  int get jalTotalLSP => jalFlightLSP + jalShoppingLSP;
  int get jalCount => legs
      .where((l) => l['airline'] == 'JAL' && l['calculatedFOP'] != null)
      .length;
  int get jalFare {
    int s = 0;
    for (var l in legs) {
      if (l['airline'] != 'JAL') continue;
      s += int.tryParse(fareAmountControllers[l['id'] as int]?.text ?? '') ?? 0;
    }
    return s;
  }

  String get jalUnitPrice =>
      (jalFare > 0 && jalFOP > 0) ? (jalFare / jalFOP).toStringAsFixed(1) : '-';
  int get anaPP => legs
      .where((l) => l['airline'] == 'ANA')
      .fold<int>(0, (s, l) => s + ((l['calculatedFOP'] as int?) ?? 0));
  int get anaMiles => legs
      .where((l) => l['airline'] == 'ANA')
      .fold<int>(0, (s, l) => s + ((l['calculatedMiles'] as int?) ?? 0));
  int get anaCount => legs
      .where((l) => l['airline'] == 'ANA' && l['calculatedFOP'] != null)
      .length;
  int get anaFare {
    int s = 0;
    for (var l in legs) {
      if (l['airline'] != 'ANA') continue;
      s += int.tryParse(fareAmountControllers[l['id'] as int]?.text ?? '') ?? 0;
    }
    return s;
  }

  String get anaUnitPrice =>
      (anaFare > 0 && anaPP > 0) ? (anaFare / anaPP).toStringAsFixed(1) : '-';
  List<String> _getSortedAirportList(List<String> inputList) {
    final m = majorAirports.where((a) => inputList.contains(a)).toList(),
        r = regionalAirports.where((a) => inputList.contains(a)).toList();
    if (m.isEmpty) return r;
    if (r.isEmpty) return m;
    return [...m, airportDivider, ...r];
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    try {
      final p = text.split('/');
      if (p.length == 3)
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (e) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryBar(isMobile),
              ...legs.asMap().entries.map(
                (e) => _buildLegCard(context, e.value, e.key, isMobile),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ========== UI WIDGETS (Part 2に続く) ==========

  Widget _buildSummaryBar(bool isMobile) {
    if (isMobile) {
      final hasJAL = legs.any((l) => l['airline'] == 'JAL'),
          hasANA = legs.any((l) => l['airline'] == 'ANA');
      return Column(
        children: [
          if (hasJAL) _buildMobileSummaryCard('JAL', Colors.red),
          if (hasJAL && hasANA) const SizedBox(height: 6),
          if (hasANA) _buildMobileSummaryCard('ANA', Colors.blue),
          const SizedBox(height: 10),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'JALカード',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _openHapitas,
                      child: Text(
                        '💡カード未発行の方',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.red.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedJALCard,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    menuWidth: 250,
                    hint: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '選択',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    selectedItemBuilder: (c) => jalCardTypes
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: jalCardTypes
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onJALCardChanged,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: jalTourPremium,
                      onChanged: _onJALTourPremiumChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'ツアープレミアム',
                    style: TextStyle(fontSize: 9, color: Colors.red),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value:
                          isAutoShoppingMilePremium || jalShoppingMilePremium,
                      onChanged: isAutoShoppingMilePremium
                          ? null
                          : _onJALShoppingMilePremiumChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ショッピングマイルP',
                    style: TextStyle(
                      fontSize: 9,
                      color: isAutoShoppingMilePremium
                          ? Colors.grey
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildCompactDropdown(
            'JALステータス',
            120,
            selectedJALStatus,
            jalStatusTypes,
            Colors.red,
            _onJALStatusChanged,
          ),
          _buildMiniStat('FOP', _formatNumber(jalFOP), Colors.red),
          _buildMiniStat('マイル', _formatNumber(jalMiles), Colors.red),
          _buildMiniStat(
            'LSP',
            '${_formatNumber(jalFlightLSP)}+${_formatNumber(jalShoppingLSP)}',
            Colors.red,
          ),
          _buildMiniStat('レグ', '$jalCount', Colors.red),
          _buildMiniStat(
            '総額',
            jalFare > 0 ? '¥${_formatNumber(jalFare)}' : '-',
            Colors.red,
          ),
          _buildMiniStat(
            '単価',
            jalUnitPrice != '-' ? '¥$jalUnitPrice' : '-',
            Colors.red,
          ),
          Container(width: 1, height: 36, color: Colors.grey[300]),
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ANAカード',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _openHapitas,
                      child: Text(
                        '💡カード未発行の方',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedANACard,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    menuWidth: 250,
                    hint: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '選択',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    selectedItemBuilder: (c) => anaCardTypes
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: anaCardTypes
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onANACardChanged,
                  ),
                ),
              ],
            ),
          ),
          _buildCompactDropdown(
            'ANAステータス',
            140,
            selectedANAStatus,
            anaStatusTypes,
            Colors.blue,
            _onANAStatusChanged,
          ),
          _buildMiniStat('PP', _formatNumber(anaPP), Colors.blue),
          _buildMiniStat('マイル', _formatNumber(anaMiles), Colors.blue),
          _buildMiniStat('レグ', '$anaCount', Colors.blue),
          _buildMiniStat(
            '総額',
            anaFare > 0 ? '¥${_formatNumber(anaFare)}' : '-',
            Colors.blue,
          ),
          _buildMiniStat(
            '単価',
            anaUnitPrice != '-' ? '¥$anaUnitPrice' : '-',
            Colors.blue,
          ),
          Container(width: 1, height: 36, color: Colors.grey[300]),
          ElevatedButton.icon(
            onPressed: _saveItinerary,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _downloadCsv,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummaryCard(String airline, Color color) {
    final isJAL = airline == 'JAL',
        fop = isJAL ? jalFOP : anaPP,
        count = isJAL ? jalCount : anaCount,
        unitPrice = isJAL ? jalUnitPrice : anaUnitPrice;
    final isExpanded = isJAL ? _jalSettingsExpanded : _anaSettingsExpanded;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isJAL) {
                _jalSettingsExpanded = !_jalSettingsExpanded;
              } else {
                _anaSettingsExpanded = !_anaSettingsExpanded;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(8),
                bottom: Radius.circular(isExpanded ? 0 : 8),
              ),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Text(
                  airline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${isJAL ? "FOP" : "PP"}: ${_formatNumber(fop)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text('$countレグ', style: TextStyle(fontSize: 11, color: color)),
                if (unitPrice != '-') ...[
                  const SizedBox(width: 8),
                  Text('¥$unitPrice', style: TextStyle(fontSize: 11, color: color)),
                ],
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.settings,
                  size: 16,
                  color: color.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _buildMobileSettingsPanel(airline, color),
      ],
    );
  }

  Widget _buildMobileSettingsPanel(String airline, Color color) {
    final isJAL = airline == 'JAL';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isJAL ? [
          // JAL設定
          _buildMobileSettingDropdown('カード種別', selectedJALCard, jalCardTypes, color, _onJALCardChanged),
          const SizedBox(height: 8),
          _buildMobileSettingDropdown('ステータス', selectedJALStatus, jalStatusTypes, color, _onJALStatusChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: jalTourPremium,
                        onChanged: _onJALTourPremiumChanged,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('ツアープレミアム', style: TextStyle(fontSize: 11, color: color)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isAutoShoppingMilePremium || jalShoppingMilePremium,
                        onChanged: isAutoShoppingMilePremium ? null : _onJALShoppingMilePremiumChanged,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ショッピングマイルP',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAutoShoppingMilePremium ? Colors.grey : color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStatMobile('マイル', _formatNumber(jalMiles), color),
              _buildMiniStatMobile('LSP', '${_formatNumber(jalFlightLSP)}+${_formatNumber(jalShoppingLSP)}', color),
              _buildMiniStatMobile('総額', jalFare > 0 ? '¥${_formatNumber(jalFare)}' : '-', color),
            ],
          ),
        ] : [
          // ANA設定
          _buildMobileSettingDropdown('カード種別', selectedANACard, anaCardTypes, color, _onANACardChanged),
          const SizedBox(height: 8),
          _buildMobileSettingDropdown('ステータス', selectedANAStatus, anaStatusTypes, color, _onANAStatusChanged),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStatMobile('マイル', _formatNumber(anaMiles), color),
              _buildMiniStatMobile('総額', anaFare > 0 ? '¥${_formatNumber(anaFare)}' : '-', color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSettingDropdown(String label, String? value, List<String> items, Color color, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('選択', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            selectedItemBuilder: (c) => items.map((e) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            )).toList(),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatMobile(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCompactDropdown(
    String label,
    double width,
    String? value,
    List<String> items,
    Color labelColor,
    void Function(String?) onChanged,
  ) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 26,
            decoration: BoxDecoration(
              border: Border.all(color: labelColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Colors.grey[600],
              ),
              menuWidth: width + 100,
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '選択',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
              selectedItemBuilder: (c) => items
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 10)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );

  Widget _buildLegCard(
    BuildContext context,
    Map<String, dynamic> leg,
    int index,
    bool isMobile,
  ) {
    final legId = leg['id'] as int,
        airline = leg['airline'] as String,
        fop = leg['calculatedFOP'] as int?,
        miles = leg['calculatedMiles'] as int?,
        lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        isExpanded = expandedLegId == legId;
    final dep = leg['departureAirport'] as String,
        arr = leg['arrivalAirport'] as String,
        flightNum = flightNumberControllers[legId]?.text ?? '';
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded ? airlineColor : airlineColor.withOpacity(0.3),
            width: isExpanded ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () =>
                  setState(() => expandedLegId = isExpanded ? null : legId),
              borderRadius: BorderRadius.circular(isExpanded ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? airlineColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(11),
                    topRight: const Radius.circular(11),
                    bottomLeft: Radius.circular(isExpanded ? 0 : 11),
                    bottomRight: Radius.circular(isExpanded ? 0 : 11),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: airlineColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        airline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (dep.isNotEmpty && arr.isNotEmpty) ...[
                      Text(
                        '$dep → $arr',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (flightNum.isNotEmpty)
                        Text(
                          ' ($flightNum)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ] else
                      Text(
                        'レグ ${index + 1}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    const Spacer(),
                    if (fop != null) ...[
                      Text(
                        '${_formatNumber(fop)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: airlineColor,
                        ),
                      ),
                      Text(
                        airline == 'JAL' ? ' FOP' : ' PP',
                        style: TextStyle(fontSize: 10, color: airlineColor),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: airlineColor,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              _buildMobileExpandedContent(
                leg,
                legId,
                index,
                fop,
                miles,
                lsp,
                airline,
              ),
          ],
        ),
      );
    }
    return _buildDesktopLegCard(context, leg, index);
  }

  Widget _buildMobileFlightNumberField(
    TextEditingController controller,
    VoidCallback onSubmit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '便名',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus && controller.text.isNotEmpty) onSubmit();
            },
            child: TextFormField(
              controller: controller,
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              onFieldSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileExpandedContent(
    Map<String, dynamic> leg,
    int legId,
    int index,
    int? fop,
    int? miles,
    int? lsp,
    String airline,
  ) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop != null && fop > 0)
        ? (fare / fop).toStringAsFixed(1)
        : '-';
    final currentFareType = leg['fareType'] as String;
    final currentSeatClass = leg['seatClass'] as String;
    List<String> availableFareTypes = fareTypesByAirline[airline] ?? [];
    if (airline == 'ANA') {
      if (currentSeatClass == 'プレミアムクラス') {
        availableFareTypes = availableFareTypes
            .where((f) => _isAnaPremiumFare(f))
            .toList();
      } else if (currentSeatClass == '普通席') {
        availableFareTypes = availableFareTypes
            .where((f) => !_isAnaPremiumFare(f))
            .toList();
      }
    }
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMobileAirlineDropdown(leg['airline'] as String, (
                  v,
                ) {
                  if (v != null && v != leg['airline']) {
                    _clearFlightInfo(index, legId);
                    setState(() {
                      legs[index]['airline'] = v;
                      legs[index]['fareType'] = '';
                      legs[index]['seatClass'] = '';
                    });
                  }
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildMobileDatePicker(
                  '日付',
                  dateControllers[legId]!,
                  context,
                  index,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: _buildMobileFlightNumberField(
                  flightNumberControllers[legId]!,
                  () => _autoFillFromFlightNumber(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileAirportSelector(
                  '出発',
                  departureAirportControllers[legId]!,
                  departureAirportFocusNodes[legId]!,
                  airlineAirports[airline] ?? airports,
                  (v) {
                    if (v != null) {
                      _clearFlightInfo(index, legId);
                      departureAirportControllers[legId]?.text = v;
                      setState(() => legs[index]['departureAirport'] = v);
                      _fetchAvailableFlights(index);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
              Expanded(
                child: _buildMobileDestinationSelector(leg, legId, index),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileFlightTimeDropdown(leg, legId, index),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileTextField(
                  '到着時刻',
                  arrivalTimeControllers[legId]!,
                  'HH:MM',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildMobileDropdown('運賃種別', currentFareType, availableFareTypes, (
            v,
          ) {
            if (v != null) {
              setState(() {
                legs[index]['fareType'] = v;
                if (airline == 'ANA') {
                  if (_isAnaPremiumFare(v)) {
                    legs[index]['seatClass'] = 'プレミアムクラス';
                  } else {
                    legs[index]['seatClass'] = '普通席';
                  }
                }
              });
              _calculateSingleLeg(index);
            }
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileDropdown(
                  '座席クラス',
                  currentSeatClass,
                  seatClassesByAirline[airline] ?? [],
                  (v) {
                    if (v != null) {
                      setState(() {
                        legs[index]['seatClass'] = v;
                        if (airline == 'ANA') {
                          if (v == 'プレミアムクラス' &&
                              !_isAnaPremiumFare(currentFareType)) {
                            legs[index]['fareType'] = '';
                          }
                          if (v == '普通席' &&
                              _isAnaPremiumFare(currentFareType)) {
                            legs[index]['fareType'] = '';
                          }
                        }
                      });
                      _calculateSingleLeg(index);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileTextField(
                  '運賃(円)',
                  fareAmountControllers[legId]!,
                  '',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (fop != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: airlineColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_formatNumber(fop)} ${airline == "JAL" ? "FOP" : "PP"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_formatNumber(miles ?? 0)}マイル',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                      if (airline == 'JAL' && lsp != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${lsp}LSP',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (fare > 0)
                    Text(
                      '¥$unitPrice/${airline == "JAL" ? "FOP" : "PP"}',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => _clearLeg(index, legId),
                    child: Text(
                      'クリア',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  if (legs.length > 1)
                    TextButton(
                      onPressed: () => _removeLeg(index),
                      child: const Text(
                        '削除',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _addLeg,
                    child: Text(
                      '+ 追加',
                      style: TextStyle(color: Colors.green[700], fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _saveItinerary,
                    child: Text(
                      '保存',
                      style: TextStyle(color: Colors.purple[700], fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _downloadCsv,
                    child: Text(
                      'CSV',
                      style: TextStyle(color: Colors.teal[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAirlineDropdown(
    String value,
    void Function(String?) onChanged,
  ) {
    final currentValue = value.isEmpty ? null : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '航空会社',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: currentValue,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '選択',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            selectedItemBuilder: (c) => airlines
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 12,
                          color: e == 'JAL' ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
            items: airlines
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(
                        fontSize: 12,
                        color: e == 'JAL' ? Colors.red : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged, {
    Color? color,
  }) {
    final currentValue = value.isEmpty || !items.contains(value) ? null : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: currentValue,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '選択',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            selectedItemBuilder: (c) => items
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 12,
                          color: color ?? Colors.black,
                          fontWeight: color != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(
                        fontSize: 12,
                        color: color ?? Colors.black,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileAirportSelector(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    final airportList = items.where((e) => e != airportDivider).toList();
    final effectiveList = airportList.isNotEmpty
        ? airportList
        : [...majorAirports, ...regionalAirports];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        _buildMobileAirportAutocomplete(
          controller: controller,
          focusNode: focusNode,
          airportList: effectiveList,
          onSelected: (code) => onChanged(code),
        ),
      ],
    );
  }

  Widget _buildMobileDestinationSelector(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final destinations = (availableDestinations[legId] ?? [])
        .where((e) => e != airportDivider)
        .toList();
    final sortedDestinations = _getSortedAirportList(destinations);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '到着',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        _buildMobileAirportAutocomplete(
          controller: arrivalAirportControllers[legId]!,
          focusNode: arrivalAirportFocusNodes[legId]!,
          airportList: sortedDestinations
              .where((e) => e != airportDivider)
              .toList(),
          onSelected: (code) {
            arrivalAirportControllers[legId]?.text = code;
            setState(() => legs[index]['arrivalAirport'] = code);
            _fetchAvailableFlights(index);
            _calculateSingleLeg(index);
          },
        ),
      ],
    );
  }

  Widget _buildMobileAirportAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> airportList,
    required void Function(String) onSelected,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        final input = textEditingValue.text.toUpperCase();
        if (input.isEmpty)
          return _getSortedAirportList(
            airportList,
          ).where((e) => e != airportDivider);
        return airportList.where((code) {
          final name = airportNames[code] ?? '';
          return code.contains(input) || name.contains(input);
        });
      },
      displayStringForOption: (code) => code,
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: '選択',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onFieldSubmitted: (value) {
                          final code = value.toUpperCase();
                          if (airportNames.containsKey(code)) onSelected(code);
                        },
                      ),
                      if (textController.text.isNotEmpty &&
                          airportNames[textController.text.toUpperCase()] !=
                              null)
                        Text(
                          airportNames[textController.text.toUpperCase()]!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
      optionsViewBuilder: (context, onAutoSelected, options) {
        final sortedOptions = _getSortedAirportList(options.toList());
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: sortedOptions.length,
                itemBuilder: (context, i) {
                  final code = sortedOptions[i];
                  if (code == airportDivider)
                    return Container(
                      height: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                    );
                  return InkWell(
                    onTap: () => onAutoSelected(code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            airportNames[code] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: onSelected,
    );
  }

  Widget _buildMobileFlightTimeDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final flights = availableFlights[legId] ?? [],
        currentTime = departureTimeControllers[legId]?.text ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '出発時刻',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: null,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                currentTime.isEmpty ? '選択' : currentTime,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: currentTime.isEmpty ? Colors.grey[500] : Colors.black,
                ),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: '__clear__',
                child: Text('-', style: TextStyle(fontSize: 12)),
              ),
              ...flights.map((flight) {
                String depTime = flight['departure_time'] ?? '';
                if (depTime.length > 5) depTime = depTime.substring(0, 5);
                final arrCode = flight['arrival_code'] ?? '';
                return DropdownMenuItem(
                  value: '${flight['id']}',
                  child: Text(
                    '${airportNames[arrCode] ?? arrCode} $depTime',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == '__clear__') {
                _clearFlightInfo(index, legId);
                return;
              }
              final flight = flights.firstWhere(
                (f) => f['id'].toString() == value,
                orElse: () => {},
              );
              if (flight.isNotEmpty) {
                String depTime = flight['departure_time'] ?? '',
                    arrTime = flight['arrival_time'] ?? '';
                if (depTime.length > 5) depTime = depTime.substring(0, 5);
                if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
                departureTimeControllers[legId]?.text = depTime;
                arrivalTimeControllers[legId]?.text = arrTime;
                flightNumberControllers[legId]?.text =
                    flight['flight_number'] ?? '';
                setState(
                  () => legs[index]['arrivalAirport'] =
                      flight['arrival_code'] ?? '',
                );
                arrivalAirportControllers[legId]?.text =
                    flight['arrival_code'] ?? '';
                if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
                _calculateSingleLeg(index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTextField(
    String label,
    TextEditingController controller,
    String hint, {
    void Function(String)? onChanged,
    void Function(String)? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus && onSubmit != null && controller.text.isNotEmpty)
                onSubmit(controller.text);
            },
            child: TextFormField(
              controller: controller,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              onChanged: onChanged,
              onFieldSubmitted: onSubmit,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDatePicker(
    String label,
    TextEditingController controller,
    BuildContext context,
    int index,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '選択',
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              suffixIcon: Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _parseDate(controller.text) ?? now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('ja'),
              );
              if (picked != null) {
                controller.text =
                    '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
                setState(() {});
                _fetchAvailableFlights(index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLegCard(
    BuildContext context,
    Map<String, dynamic> leg,
    int index,
  ) {
    final legId = leg['id'] as int,
        airline = leg['airline'] as String,
        fop = leg['calculatedFOP'] as int?,
        miles = leg['calculatedMiles'] as int?,
        lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        warning = legWarnings[legId];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: airlineColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (warning != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      warning,
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                onPressed: _addLeg,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('レグ追加'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _clearLeg(index, legId),
                child: Text(
                  'クリア',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              if (legs.length > 1)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  onPressed: () => _removeLeg(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '削除',
                ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDesktopAirlineDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopDatePicker(
                  '日付',
                  130,
                  dateControllers[legId]!,
                  context,
                  index,
                ),
                const SizedBox(width: 8),
                _buildDesktopFlightNumberField(legId, index),
                const SizedBox(width: 8),
                _buildDesktopDepartureDropdown(leg, legId, index),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                _buildDesktopDestinationDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopFlightTimeDropdown(leg, legId, index),
                const SizedBox(width: 4),
                _buildDesktopArrivalTimeField(legId),
                const SizedBox(width: 8),
                _buildDesktopFareTypeDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopSeatClassDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopTextField(
                  '運賃',
                  70,
                  fareAmountControllers[legId]!,
                  '',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(width: 8),
                if (fop != null)
                  _buildDesktopPointsDisplay(airline, fop, miles, lsp, legId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPointsDisplay(
    String airline,
    int fop,
    int? miles,
    int? lsp,
    int legId,
  ) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop > 0)
            ? (fare / fop).toStringAsFixed(1)
            : '-',
        pointLabel = airline == 'JAL' ? 'FOP' : 'PP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: airlineColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (airline == 'JAL')
            Text(
              '$pointLabel: $fop  マイル: $miles  LSP: ${lsp ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            )
          else
            Text(
              '$pointLabel: $fop  マイル: $miles',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          if (fare > 0)
            Text(
              '単価: ¥$unitPrice/$pointLabel',
              style: const TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopAirlineDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String;
    return SizedBox(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '航空会社',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: airline.isEmpty ? null : airline,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('選択', style: TextStyle(fontSize: 12)),
              ),
              selectedItemBuilder: (c) => airlines
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 12,
                            color: e == 'JAL' ? Colors.red : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: airlines
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 12,
                          color: e == 'JAL' ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null && v != airline) {
                  _clearFlightInfo(index, legId);
                  setState(() {
                    legs[index]['airline'] = v;
                    legs[index]['fareType'] = '';
                    legs[index]['seatClass'] = '';
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDepartureDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String,
        airportList =
            (airlineAirports[airline] ??
                    [...majorAirports, ...regionalAirports])
                .where((e) => e != airportDivider)
                .toList();
    return SizedBox(
      width: 85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出発地',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _buildAirportAutocomplete(
            controller: departureAirportControllers[legId]!,
            focusNode: departureAirportFocusNodes[legId]!,
            airportList: airportList,
            onSelected: (code) {
              _clearFlightInfo(index, legId);
              departureAirportControllers[legId]?.text = code;
              setState(() => legs[index]['departureAirport'] = code);
              _fetchAvailableFlights(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDestinationDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final destinations = (availableDestinations[legId] ?? [])
        .where((e) => e != airportDivider)
        .toList();
    final sortedDestinations = _getSortedAirportList(
      destinations,
    ).where((e) => e != airportDivider).toList();
    return SizedBox(
      width: 85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '到着地',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _buildAirportAutocomplete(
            controller: arrivalAirportControllers[legId]!,
            focusNode: arrivalAirportFocusNodes[legId]!,
            airportList: sortedDestinations,
            onSelected: (code) {
              arrivalAirportControllers[legId]?.text = code;
              setState(() => legs[index]['arrivalAirport'] = code);
              _fetchAvailableFlights(index);
              _calculateSingleLeg(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAirportAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> airportList,
    required void Function(String) onSelected,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        final input = textEditingValue.text.toUpperCase();
        if (input.isEmpty)
          return _getSortedAirportList(
            airportList,
          ).where((e) => e != airportDivider);
        return airportList.where((code) {
          final name = airportNames[code] ?? '';
          return code.contains(input) || name.contains(input);
        });
      },
      displayStringForOption: (code) => code,
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) => Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextFormField(
              controller: textController,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 12),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: '選択',
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
              onFieldSubmitted: (value) {
                final code = value.toUpperCase();
                if (airportNames.containsKey(code)) onSelected(code);
              },
            ),
          ),
      optionsViewBuilder: (context, onAutoSelected, options) {
        final sortedOptions = _getSortedAirportList(options.toList());
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 160),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: sortedOptions.length,
                itemBuilder: (context, i) {
                  final code = sortedOptions[i];
                  if (code == airportDivider)
                    return Container(
                      height: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                    );
                  return InkWell(
                    onTap: () => onAutoSelected(code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        '$code ${airportNames[code] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: onSelected,
    );
  }

  Widget _buildDesktopFlightTimeDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final flights = availableFlights[legId] ?? [],
        airline = leg['airline'] as String,
        currentTime = departureTimeControllers[legId]?.text ?? '';
    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出発時刻',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              key: ValueKey('flight_time_${legId}_$airline'),
              value: null,
              isExpanded: true,
              underline: const SizedBox(),
              menuWidth: 150,
              hint: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  currentTime.isEmpty ? '選択' : currentTime,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: '__clear__',
                  child: Text('-', style: TextStyle(fontSize: 12)),
                ),
                ...flights.map((flight) {
                  String depTime = flight['departure_time'] ?? '';
                  if (depTime.length > 5) depTime = depTime.substring(0, 5);
                  final arrCode = flight['arrival_code'] ?? '';
                  return DropdownMenuItem(
                    value: '${flight['id']}',
                    child: Text(
                      '${airportNames[arrCode] ?? arrCode} $depTime',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == '__clear__') {
                  _clearFlightInfo(index, legId);
                  return;
                }
                final flight = flights.firstWhere(
                  (f) => f['id'].toString() == value,
                  orElse: () => {},
                );
                if (flight.isNotEmpty) {
                  String depTime = flight['departure_time'] ?? '',
                      arrTime = flight['arrival_time'] ?? '';
                  if (depTime.length > 5) depTime = depTime.substring(0, 5);
                  if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
                  departureTimeControllers[legId]?.text = depTime;
                  arrivalTimeControllers[legId]?.text = arrTime;
                  flightNumberControllers[legId]?.text =
                      flight['flight_number'] ?? '';
                  setState(
                    () => legs[index]['arrivalAirport'] =
                        flight['arrival_code'] ?? '',
                  );
                  arrivalAirportControllers[legId]?.text =
                      flight['arrival_code'] ?? '';
                  if (index + 1 < legs.length)
                    _fetchAvailableFlights(index + 1);
                  _calculateSingleLeg(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopArrivalTimeField(int legId) => SizedBox(
    width: 65,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '到着時刻',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: arrivalTimeControllers[legId],
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'HH:MM',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopSeatClassDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String,
        seatClass = leg['seatClass'] as String,
        seatClasses = seatClassesByAirline[airline] ?? [];
    final currentFareType = leg['fareType'] as String;
    final currentValue = seatClass.isEmpty || !seatClasses.contains(seatClass)
        ? null
        : seatClass;
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '座席クラス',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              underline: const SizedBox(),
              menuWidth: 150,
              hint: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('選択', style: TextStyle(fontSize: 10)),
              ),
              selectedItemBuilder: (c) => seatClasses
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: seatClasses
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 10)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    legs[index]['seatClass'] = v;
                    if (airline == 'ANA') {
                      if (v == 'プレミアムクラス' &&
                          !_isAnaPremiumFare(currentFareType)) {
                        legs[index]['fareType'] = '';
                      }
                      if (v == '普通席' && _isAnaPremiumFare(currentFareType)) {
                        legs[index]['fareType'] = '';
                      }
                    }
                  });
                  _calculateSingleLeg(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTextField(
    String label,
    double width,
    TextEditingController controller,
    String hint, {
    void Function(String)? onChanged,
  }) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopFlightNumberField(int legId, int index) => SizedBox(
    width: 60,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '便名',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                final flightNumber = flightNumberControllers[legId]?.text ?? '';
                if (flightNumber.isNotEmpty) _autoFillFromFlightNumber(index);
              }
            },
            child: TextFormField(
              controller: flightNumberControllers[legId],
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
              onFieldSubmitted: (_) => _autoFillFromFlightNumber(index),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopDatePicker(
    String label,
    double width,
    TextEditingController controller,
    BuildContext context,
    int index,
  ) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: '選択',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 14),
            ),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _parseDate(controller.text) ?? now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('ja'),
              );
              if (picked != null) {
                controller.text =
                    '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
                setState(() {});
                _fetchAvailableFlights(index);
              }
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopFareTypeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String, fareType = leg['fareType'] as String;
    final currentSeatClass = leg['seatClass'] as String;
    List<String> fareTypes = fareTypesByAirline[airline] ?? [];
    if (airline == 'ANA') {
      if (currentSeatClass == 'プレミアムクラス') {
        fareTypes = fareTypes.where((f) => _isAnaPremiumFare(f)).toList();
      } else if (currentSeatClass == '普通席') {
        fareTypes = fareTypes.where((f) => !_isAnaPremiumFare(f)).toList();
      }
    }
    final currentValue = fareType.isEmpty || !fareTypes.contains(fareType) ? null : fareType;
    return SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('運賃種別', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 250, hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 10))), selectedItemBuilder: (c) => fareTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(), items: fareTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(), onChanged: (v) { 
          if (v != null) { 
            setState(() {
              legs[index]['fareType'] = v;
              if (airline == 'ANA') {
                if (_isAnaPremiumFare(v)) {
                  legs[index]['seatClass'] = 'プレミアムクラス';
                } else {
                  legs[index]['seatClass'] = '普通席';
                }
              }
            });
            _calculateSingleLeg(index); 
          } 
        }))]));
  }
}
