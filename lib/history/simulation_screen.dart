import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> legs = [];
  
  Map<int, TextEditingController> dateControllers = {};
  Map<int, TextEditingController> flightNumberControllers = {};
  Map<int, TextEditingController> departureTimeControllers = {};
  Map<int, TextEditingController> arrivalTimeControllers = {};
  Map<int, TextEditingController> fareAmountControllers = {};
  
  Map<int, List<Map<String, dynamic>>> availableFlights = {};
  Map<int, List<String>> availableDestinations = {};
  
  int _legIdCounter = 0;
  bool isLoading = false;
  String? errorMessage;

  String? selectedJALCard;
  String? selectedANACard;
  String? selectedJALStatus;
  String? selectedANAStatus;
  bool jalTourPremium = false; // JALカードツアープレミアム

  // 航空会社別の出発空港リスト（動的取得）
  List<String> jalDepartureAirports = [];
  List<String> anaDepartureAirports = [];

  final List<String> jalCardTypes = ['-', 'JMB会員', 'JALカード普通会員', 'JALカードCLUB-A会員', 'JALカードCLUB-Aゴールド会員', 'JALカードプラチナ会員', 'JALグローバルクラブ会員(日本)', 'JALグローバルクラブ会員(海外)', 'JALカードNAVI会員', 'JAL CLUB EST 普通会員', 'JAL CLUB EST CLUB-A会員', 'JAL CLUB EST CLUB-A GOLD会員', 'JAL CLUB EST プラチナ会員'];
  final List<String> anaCardTypes = ['-', 'AMCカード(提携カード含む)', 'ANAカード 一般', 'ANAカード 学生用', 'ANAカード ワイド', 'ANAカード ゴールド', 'ANAカード プレミアム', 'SFC 一般', 'SFC ゴールド', 'SFC プレミアム'];
  final List<String> jalStatusTypes = ['-', 'JMBダイヤモンド', 'JMBサファイア', 'JMBクリスタル'];
  final List<String> anaStatusTypes = ['-', 'ダイヤモンド(1年目)', 'ダイヤモンド(継続2年以上)', 'プラチナ(1年目)', 'プラチナ(継続2年以上)', 'ブロンズ(1年目)', 'ブロンズ(継続2年以上)'];
  final List<String> airports = [
    // 主要空港
    'HND', 'NRT',  // 東京
    'ITM', 'KIX', 'UKB',  // 大阪
    'CTS', 'OKD',  // 札幌
    'NGO', 'NKM',  // 名古屋
    'FUK',  // 福岡
    'OKA',  // 沖縄
    // 北海道（北から）
    'WKJ', 'MBE', 'MMB', 'SHB', 'KUH', 'OBO', 'AKJ', 'HKD', 'OIR',
    // 東北（北から）
    'AOJ', 'MSJ', 'HNA', 'AXT', 'ONJ', 'GAJ', 'SDJ', 'FKS',
    // 関東・中部
    'HAC', 'FSZ', 'MMJ', 'NTQ', 'TOY', 'KMQ', 'SHM',
    // 中国・四国
    'TTJ', 'YGJ', 'IZO', 'OKJ', 'HIJ', 'IWK', 'UBJ', 'TKS', 'TAK', 'KCZ', 'MYJ',
    // 九州（北から）
    'KKJ', 'HSG', 'NGS', 'KMJ', 'OIT', 'KMI', 'KOJ', 'AXJ',
    // 離島
    'IKI', 'TSJ', 'FUJ', 'TNE', 'KUM', 'ASJ', 'KKX', 'TKN', 'OGN', 'MMY', 'ISG', 'RNJ',
  ];
  final Map<String, String> airportNames = {
    'HND': '羽田', 'NRT': '成田', 'KIX': '関西', 'ITM': '伊丹', 'NGO': '中部', 'CTS': '新千歳', 'FUK': '福岡', 'OKA': '那覇',
    'NGS': '長崎', 'KMJ': '熊本', 'OIT': '大分', 'MYJ': '松山', 'HIJ': '広島', 'TAK': '高松', 'KCZ': '高知', 'TKS': '徳島', 'KOJ': '鹿児島',
    'SDJ': '仙台', 'AOJ': '青森', 'AKJ': '旭川', 'AXT': '秋田', 'GAJ': '山形', 'KIJ': '新潟', 'TOY': '富山', 'KMQ': '小松', 'FSZ': '静岡',
    'MMB': '女満別', 'OBO': '帯広', 'KUH': '釧路', 'HKD': '函館', 'ISG': '石垣', 'MMY': '宮古', 'UBJ': '山口宇部', 'IWK': '岩国',
    'OKJ': '岡山', 'TTJ': '鳥取', 'YGJ': '米子', 'IZO': '出雲', 'NKM': '県営名古屋', 'UKB': '神戸', 'HSG': '佐賀', 'KMI': '宮崎',
    'ASJ': '奄美', 'TKN': '徳之島', 'OKI': '隠岐', 'FKS': '福島', 'HNA': '花巻', 'MSJ': '三沢', 'ONJ': '大館能代', 'SHM': '南紀白浜',
    'NTQ': '能登', 'KKJ': '北九州', 'TNE': '種子島', 'KUM': '屋久島', 'RNJ': '与論', 'OGN': '与那国', 'HAC': '八丈島',
    'MBE': '紋別', 'SHB': '中標津', 'WKJ': '稚内', 'OKD': '丘珠', 'IKI': '壱岐', 'TSJ': '対馬', 'FUJ': '五島福江', 'OIR': '奥尻',
    'SYO': '庄内', 'MMJ': '松本', 'AXJ': '天草', 'TJH': '但馬', 'KKX': '喜界',
  };
  final List<String> airlines = ['JAL', 'ANA'];
  final Map<String, List<String>> fareTypesByAirline = {
    'JAL': ['運賃1 (100%) フレックス等', '運賃2 (75%) 株主割引', '運賃3 (75%) セイバー', '運賃4 (75%) スペシャルセイバー', '運賃5 (50%) 包括旅行運賃', '運賃6 (50%) スカイメイト等'],
    'ANA': ['運賃1 (150%) プレミアム運賃', '運賃2 (125%) プレミアム小児', '運賃3 (100%) 片道・往復', '運賃4 (100%) ビジネス', '運賃5 (75%) 特割A', '運賃6 (75%) 特割B', '運賃7 (75%) 特割C', '運賃8 (50%) いっしょにマイル割', '運賃9 (150%) プレミアム株主', '運賃10 (100%) 普通株主', '運賃11 (70%) 特割プラス', '運賃12 (50%) スマートシニア', '運賃13 (30%) 個人包括'],
  };
  final Map<String, List<String>> seatClassesByAirline = {'JAL': ['普通席', 'クラスJ', 'ファーストクラス'], 'ANA': ['普通席', 'プレミアムクラス']};

  // JAL搭乗ボーナスFOP（運賃種別で決定）
  final Map<String, int> jalBonusFOP = {'運賃1': 400, '運賃2': 400, '運賃3': 200, '運賃4': 200, '運賃5': 0, '運賃6': 0};
  
  // ANA搭乗ポイント（運賃種別で決定）
  final Map<String, int> anaBonusPoint = {'運賃1': 400, '運賃2': 400, '運賃3': 400, '運賃4': 0, '運賃5': 400, '運賃6': 200, '運賃7': 0, '運賃8': 0, '運賃9': 0, '運賃10': 0, '運賃11': 0, '運賃12': 0, '運賃13': 0};

  @override
  void initState() { super.initState(); _addLeg(); _loadAirlineAirports(); }

  Future<void> _loadAirlineAirports() async {
    try {
      // JALの出発空港を取得
      final jalResponse = await Supabase.instance.client
          .from('schedules')
          .select('departure_code')
          .eq('airline_code', 'JAL')
          .eq('is_active', true);
      final jalAirports = (jalResponse as List)
          .map((e) => e['departure_code'] as String)
          .where((code) => airportNames.containsKey(code))
          .toSet()
          .toList();
      jalAirports.sort();

      // ANAの出発空港を取得
      final anaResponse = await Supabase.instance.client
          .from('schedules')
          .select('departure_code')
          .eq('airline_code', 'ANA')
          .eq('is_active', true);
      final anaAirports = (anaResponse as List)
          .map((e) => e['departure_code'] as String)
          .where((code) => airportNames.containsKey(code))
          .toSet()
          .toList();
      anaAirports.sort();

      setState(() {
        jalDepartureAirports = jalAirports;
        anaDepartureAirports = anaAirports;
      });
    } catch (e) {
      // エラー時はairportsリストをそのまま使用
      setState(() {
        jalDepartureAirports = airports;
        anaDepartureAirports = airports;
      });
    }
  }

  @override
  void dispose() {
    dateControllers.values.forEach((c) => c.dispose());
    flightNumberControllers.values.forEach((c) => c.dispose());
    departureTimeControllers.values.forEach((c) => c.dispose());
    arrivalTimeControllers.values.forEach((c) => c.dispose());
    fareAmountControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _addLeg() {
    final legId = _legIdCounter++;
    dateControllers[legId] = TextEditingController();
    flightNumberControllers[legId] = TextEditingController();
    departureTimeControllers[legId] = TextEditingController();
    arrivalTimeControllers[legId] = TextEditingController();
    fareAmountControllers[legId] = TextEditingController();
    String airline = 'JAL'; String departureAirport = ''; String arrivalAirport = ''; String date = '';
    if (legs.isNotEmpty) {
      final prevLeg = legs.last; final prevLegId = prevLeg['id'] as int;
      airline = prevLeg['airline'] as String;
      departureAirport = prevLeg['arrivalAirport'] as String;
      arrivalAirport = prevLeg['departureAirport'] as String;
      date = dateControllers[prevLegId]?.text ?? '';
    }
    dateControllers[legId]?.text = date;
    setState(() { legs.add({'id': legId, 'airline': airline, 'departureAirport': departureAirport, 'arrivalAirport': arrivalAirport, 'fareType': '', 'seatClass': '', 'calculatedFOP': null, 'calculatedMiles': null}); });
    if (departureAirport.isNotEmpty) _fetchAvailableFlights(legs.length - 1);
  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    dateControllers[legId]?.dispose(); flightNumberControllers[legId]?.dispose(); departureTimeControllers[legId]?.dispose(); arrivalTimeControllers[legId]?.dispose(); fareAmountControllers[legId]?.dispose();
    dateControllers.remove(legId); flightNumberControllers.remove(legId); departureTimeControllers.remove(legId); arrivalTimeControllers.remove(legId); fareAmountControllers.remove(legId);
    availableFlights.remove(legId); availableDestinations.remove(legId);
    setState(() => legs.removeAt(index));
  }

  void _clearFlightInfo(int index, int legId) {
    setState(() { legs[index]['departureAirport'] = ''; legs[index]['arrivalAirport'] = ''; legs[index]['calculatedFOP'] = null; legs[index]['calculatedMiles'] = null; availableFlights[legId] = []; availableDestinations[legId] = []; });
    flightNumberControllers[legId]?.text = ''; departureTimeControllers[legId]?.text = ''; arrivalTimeControllers[legId]?.text = '';
  }

  void _clearLeg(int index, int legId) {
    _clearFlightInfo(index, legId);
    setState(() { legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; });
    dateControllers[legId]?.text = ''; fareAmountControllers[legId]?.text = '';
  }

  String _addMinutes(String time, int minutes) {
    if (time.isEmpty || !time.contains(':')) return time;
    final parts = time.split(':'); int hour = int.tryParse(parts[0]) ?? 0; int min = int.tryParse(parts[1]) ?? 0;
    min += minutes; while (min >= 60) { min -= 60; hour += 1; } if (hour >= 24) hour -= 24;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  bool _isTimeAfterOrEqual(String time1, String time2) {
    if (time1.isEmpty || time2.isEmpty || !time1.contains(':') || !time2.contains(':')) return true;
    final parts1 = time1.split(':'); final parts2 = time2.split(':');
    final minutes1 = (int.tryParse(parts1[0]) ?? 0) * 60 + (int.tryParse(parts1[1]) ?? 0);
    final minutes2 = (int.tryParse(parts2[0]) ?? 0) * 60 + (int.tryParse(parts2[1]) ?? 0);
    return minutes1 >= minutes2;
  }

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(String airline, String flightNumber) async {
    try { return await Supabase.instance.client.from('schedules').select().eq('airline_code', airline).eq('flight_number', flightNumber).eq('is_active', true).maybeSingle(); } catch (e) { return null; }
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int;
    final airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) { setState(() => errorMessage = '便名を入力してください'); return; }
    final schedule = await _fetchScheduleByFlightNumber(airline, flightNumber);
    if (schedule != null) {
      String depTime = schedule['departure_time'] ?? ''; String arrTime = schedule['arrival_time'] ?? '';
      if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
      final depCode = schedule['departure_code'] as String; final arrCode = schedule['arrival_code'] as String;
      setState(() { legs[index]['departureAirport'] = depCode; legs[index]['arrivalAirport'] = arrCode; errorMessage = null; });
      departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime;
      await _fetchAvailableFlights(index);
      if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
      _calculateSingleLeg(index);
    } else { setState(() => errorMessage = '$flightNumber便が見つかりません'); }
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final leg = legs[index]; final legId = leg['id'] as int; final airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String; final arrival = leg['arrivalAirport'] as String;
    if (departure.isEmpty) { setState(() { availableFlights[legId] = []; availableDestinations[legId] = []; }); return; }
    try {
      var query = Supabase.instance.client.from('schedules').select().eq('airline_code', airline).eq('departure_code', departure).eq('is_active', true);
      if (arrival.isNotEmpty) query = query.eq('arrival_code', arrival);
      final response = await query.order('departure_time');
      List<Map<String, dynamic>> flights = (response as List).cast<Map<String, dynamic>>();
      if (index > 0) {
        final prevLeg = legs[index - 1]; final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String; final prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          flights = flights.where((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); return _isTimeAfterOrEqual(depTime, minDepartureTime); }).toList();
        }
      }
      final destinations = flights.map((f) => f['arrival_code'] as String).where((code) => airportNames.containsKey(code)).toSet().toList(); destinations.sort();
      setState(() { availableFlights[legId] = flights; availableDestinations[legId] = destinations; });
    } catch (e) { setState(() { availableFlights[legId] = []; availableDestinations[legId] = []; }); }
  }

  Future<void> _calculateSingleLeg(int index) async {
    final leg = legs[index]; final dep = leg['departureAirport'] as String; final arr = leg['arrivalAirport'] as String;
    final fare = leg['fareType'] as String; final seat = leg['seatClass'] as String; final airline = leg['airline'] as String;
    if (dep.isEmpty || arr.isEmpty || fare.isEmpty || seat.isEmpty) return;

    try {
      final routeData = await Supabase.instance.client.from('routes').select('distance_miles').eq('departure_code', dep).eq('arrival_code', arr).maybeSingle();
      if (routeData == null) return;
      final distance = routeData['distance_miles'] as int;

      // 運賃種別名から積算率を抽出
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;

      // 運賃番号を抽出（例: "運賃1 (100%)" → "運賃1"）
      final fareNumber = fare.split(' ').first;

      int totalPoints = 0;
      int totalMiles = 0;

      if (airline == 'JAL') {
        // === JAL計算 ===
        // 座席ボーナス率
        final seatBonusRate = {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seat] ?? 0.0;
        
        // JALカードツアープレミアム適用時、運賃4,5は積算率100%
        double effectiveFareRate = fareRate;
        if (jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5')) {
          effectiveFareRate = 1.0;
        }

        // フライトマイル = round(区間マイル × (積算率 + 座席ボーナス率))
        final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();

        // ステータスボーナス率
        final statusBonusRate = {'-': 0.0, 'JMBダイヤモンド': 1.30, 'JMBサファイア': 1.05, 'JMBクリスタル': 0.55}[selectedJALStatus ?? '-'] ?? 0.0;

        // マイルUPボーナス = round(フライトマイル × ステータスボーナス率)
        final mileUpBonus = (flightMiles * statusBonusRate).round();

        // 合計マイル
        totalMiles = flightMiles + mileUpBonus;

        // 搭乗ボーナスFOP（運賃種別で決定）
        final bonusFOP = jalBonusFOP[fareNumber] ?? 0;

        // FOP = (フライトマイル × 2) + 搭乗ボーナス
        totalPoints = (flightMiles * 2) + bonusFOP;

      } else {
        // === ANA計算 ===
        // フライトマイル = int(区間マイル × 積算率)
        final flightMiles = (distance * fareRate).toInt();

        // カードボーナス率
        final cardBonusRate = {'-': 0.0, 'AMCカード(提携カード含む)': 0.0, 'ANAカード 一般': 0.10, 'ANAカード 学生用': 0.10, 'ANAカード ワイド': 0.25, 'ANAカード ゴールド': 0.25, 'ANAカード プレミアム': 0.50, 'SFC 一般': 0.35, 'SFC ゴールド': 0.40, 'SFC プレミアム': 0.50}[selectedANACard ?? '-'] ?? 0.0;

        // ステータスボーナス率
        final statusBonusRate = {'-': 0.0, 'ダイヤモンド(1年目)': 1.15, 'ダイヤモンド(継続2年以上)': 1.25, 'プラチナ(1年目)': 0.90, 'プラチナ(継続2年以上)': 1.00, 'ブロンズ(1年目)': 0.40, 'ブロンズ(継続2年以上)': 0.50}[selectedANAStatus ?? '-'] ?? 0.0;

        // 適用ボーナス率 = max(カードボーナス率, ステータスボーナス率)
        final effectiveBonusRate = cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate;

        // マイルUPボーナス = int(フライトマイル × 適用ボーナス率)
        final mileUpBonus = (flightMiles * effectiveBonusRate).toInt();

        // 合計マイル
        totalMiles = flightMiles + mileUpBonus;

        // 搭乗ポイント（運賃種別で決定）
        final bonusPoint = anaBonusPoint[fareNumber] ?? 0;

        // PP = int((区間マイル × 積算率 × 2) + 搭乗ポイント)
        totalPoints = ((distance * fareRate * 2) + bonusPoint).toInt();
      }

      setState(() { legs[index]['calculatedFOP'] = totalPoints; legs[index]['calculatedMiles'] = totalMiles; });
    } catch (e) {}
  }

  void _recalculateAllLegs() { for (int i = 0; i < legs.length; i++) _calculateSingleLeg(i); }
  void _onJALCardChanged(String? v) { setState(() => selectedJALCard = v); _recalculateAllLegs(); }
  void _onJALStatusChanged(String? v) { setState(() => selectedJALStatus = v); _recalculateAllLegs(); }
  void _onANACardChanged(String? v) { setState(() => selectedANACard = v); _recalculateAllLegs(); }
  void _onANAStatusChanged(String? v) { setState(() => selectedANAStatus = v); _recalculateAllLegs(); }
  void _onJALTourPremiumChanged(bool? v) { setState(() => jalTourPremium = v ?? false); _recalculateAllLegs(); }

  String _formatNumber(int number) { if (number == 0) return '0'; return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'); }

  Future<void> _saveToSupabase() async {
    final validLegs = legs.where((leg) => leg['calculatedFOP'] != null).toList();
    if (validLegs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存するレグがありません'), backgroundColor: Colors.orange));
      return;
    }
    try {
      for (var leg in validLegs) {
        final legId = leg['id'] as int;
        await Supabase.instance.client.from('flight_records').insert({
          'flight_date': dateControllers[legId]?.text ?? '',
          'airline': leg['airline'],
          'flight_number': flightNumberControllers[legId]?.text ?? '',
          'departure_airport': leg['departureAirport'],
          'arrival_airport': leg['arrivalAirport'],
          'departure_time': departureTimeControllers[legId]?.text ?? '',
          'arrival_time': arrivalTimeControllers[legId]?.text ?? '',
          'fare_type': leg['fareType'],
          'seat_class': leg['seatClass'],
          'fare_amount': int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0,
          'fop_pp': leg['calculatedFOP'],
          'miles': leg['calculatedMiles'],
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${validLegs.length}件のレグを保存しました'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存エラー: $e'), backgroundColor: Colors.red));
    }
  }

  void _exportToCsv() {
    final validLegs = legs.where((leg) => leg['calculatedFOP'] != null).toList();
    if (validLegs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エクスポートするレグがありません'), backgroundColor: Colors.orange));
      return;
    }
    final csvRows = <String>[];
    csvRows.add('日付,航空会社,便名,出発地,到着地,出発時刻,到着時刻,運賃種別,座席クラス,運賃,FOP/PP,マイル');
    for (var leg in validLegs) {
      final legId = leg['id'] as int;
      final row = [
        dateControllers[legId]?.text ?? '',
        leg['airline'],
        flightNumberControllers[legId]?.text ?? '',
        leg['departureAirport'],
        leg['arrivalAirport'],
        departureTimeControllers[legId]?.text ?? '',
        arrivalTimeControllers[legId]?.text ?? '',
        leg['fareType'],
        leg['seatClass'],
        fareAmountControllers[legId]?.text ?? '0',
        leg['calculatedFOP']?.toString() ?? '',
        leg['calculatedMiles']?.toString() ?? '',
      ].join(',');
      csvRows.add(row);
    }
    final csvContent = csvRows.join('\n');
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute('download', 'flight_plan_${DateTime.now().toIso8601String().substring(0, 10)}.csv')..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSVをダウンロードしました'), backgroundColor: Colors.green));
  }

  int get jalFOP => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get jalCount => legs.where((leg) => leg['airline'] == 'JAL' && leg['calculatedFOP'] != null).length;
  int get jalFare { int sum = 0; for (var leg in legs) { if (leg['airline'] != 'JAL') continue; final legId = leg['id'] as int; sum += int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0; } return sum; }
  String get jalUnitPrice => (jalFare > 0 && jalFOP > 0) ? (jalFare / jalFOP).toStringAsFixed(1) : '-';
  int get anaPP => legs.where((leg) => leg['airline'] == 'ANA').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get anaMiles => legs.where((leg) => leg['airline'] == 'ANA').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get anaCount => legs.where((leg) => leg['airline'] == 'ANA' && leg['calculatedFOP'] != null).length;
  int get anaFare { int sum = 0; for (var leg in legs) { if (leg['airline'] != 'ANA') continue; final legId = leg['id'] as int; sum += int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0; } return sum; }
  String get anaUnitPrice => (anaFare > 0 && anaPP > 0) ? (anaFare / anaPP).toStringAsFixed(1) : '-';

  // ツアープレミアムが有効かどうか
  bool get isTourPremiumEnabled {
    // JALクレジットカードホルダー（JMB会員、-以外）
    final isJALCardHolder = selectedJALCard != null && selectedJALCard != '-' && selectedJALCard != 'JMB会員';
    // JALのレグで運賃4か運賃5が選択されている
    final hasEligibleFare = legs.any((leg) {
      if (leg['airline'] != 'JAL') return false;
      final fareType = leg['fareType'] as String;
      return fareType.startsWith('運賃4') || fareType.startsWith('運賃5');
    });
    return isJALCardHolder && hasEligibleFare;
  }

  Widget _buildTourPremiumCheckbox() {
    final enabled = isTourPremiumEnabled;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 20, height: 20, child: Checkbox(
        value: jalTourPremium && enabled,
        onChanged: enabled ? _onJALTourPremiumChanged : null,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      )),
      const SizedBox(width: 4),
      Text('ツアープレミアム', style: TextStyle(fontSize: 9, color: enabled ? Colors.red : Colors.grey)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _buildCompactDropdown('JALカード', 150, selectedJALCard, jalCardTypes, Colors.red, _onJALCardChanged),
            // JALカードツアープレミアム チェックボックス（条件付き）
            _buildTourPremiumCheckbox(),
            _buildCompactDropdown('JALステータス', 120, selectedJALStatus, jalStatusTypes, Colors.red, _onJALStatusChanged),
            _buildMiniStat('FOP', _formatNumber(jalFOP), Colors.red),
            _buildMiniStat('マイル', _formatNumber(jalMiles), Colors.red),
            _buildMiniStat('レグ', '$jalCount', Colors.red),
            _buildMiniStat('総額', jalFare > 0 ? '¥${_formatNumber(jalFare)}' : '-', Colors.red),
            _buildMiniStat('単価', jalUnitPrice != '-' ? '¥$jalUnitPrice' : '-', Colors.red),
            Container(width: 1, height: 36, color: Colors.grey[300]),
            _buildCompactDropdown('ANAカード', 150, selectedANACard, anaCardTypes, Colors.blue, _onANACardChanged),
            _buildCompactDropdown('ANAステータス', 140, selectedANAStatus, anaStatusTypes, Colors.blue, _onANAStatusChanged),
            _buildMiniStat('PP', _formatNumber(anaPP), Colors.blue),
            _buildMiniStat('マイル', _formatNumber(anaMiles), Colors.blue),
            _buildMiniStat('レグ', '$anaCount', Colors.blue),
            _buildMiniStat('総額', anaFare > 0 ? '¥${_formatNumber(anaFare)}' : '-', Colors.blue),
            _buildMiniStat('単価', anaUnitPrice != '-' ? '¥$anaUnitPrice' : '-', Colors.blue),
          ]),
        ),
        ...legs.asMap().entries.map((e) => _buildLegCard(context, e.value, e.key)),
        if (errorMessage != null) Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: _saveToSupabase,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _exportToCsv,
            icon: const Icon(Icons.download),
            label: const Text('CSVエクスポート'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildCompactDropdown(String label, double width, String? value, List<String> items, Color labelColor, void Function(String?) onChanged) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor)),
      const SizedBox(height: 2),
      Container(height: 26, decoration: BoxDecoration(border: Border.all(color: labelColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: value, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]), menuWidth: width + 100,
          hint: Padding(padding: const EdgeInsets.only(left: 4), child: Text('選択', style: TextStyle(fontSize: 10, color: Colors.grey[600]))),
          selectedItemBuilder: (context) => items.map((e) => Padding(padding: const EdgeInsets.only(left: 4), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10, color: Colors.black), overflow: TextOverflow.ellipsis)))).toList(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10, color: Colors.black)))).toList(),
          onChanged: onChanged,
        ),
      ),
    ]));
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _buildPointsDisplay(String airline, int fop, int? miles, int legId) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final fareText = fareAmountControllers[legId]?.text ?? '';
    final fare = int.tryParse(fareText) ?? 0;
    final unitPrice = (fare > 0 && fop > 0) ? (fare / fop).toStringAsFixed(1) : '-';
    final pointLabel = airline == 'JAL' ? 'FOP' : 'PP';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$pointLabel: $fop', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          Text('マイル: $miles', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          if (fare > 0) Text('単価: ¥$unitPrice/$pointLabel', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildLegCard(BuildContext context, Map<String, dynamic> leg, int index) {
    final legId = leg['id'] as int; final airline = leg['airline'] as String;
    final fop = leg['calculatedFOP'] as int?; final miles = leg['calculatedMiles'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final bgColor = airline == 'JAL' ? Colors.red.withOpacity(0.05) : Colors.blue.withOpacity(0.05);
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: airlineColor.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          ElevatedButton.icon(onPressed: _addLeg, icon: const Icon(Icons.add, size: 16), label: const Text('レグ追加', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
          const SizedBox(width: 8),
          TextButton(onPressed: () => _clearLeg(index, legId), child: Text('クリア', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          if (legs.length > 1) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeLeg(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _buildAirlineDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDatePicker('日付', 130, dateControllers[legId]!, context), const SizedBox(width: 8),
          _buildFlightNumberField(legId, index), const SizedBox(width: 8),
          _buildDepartureDropdown(leg, legId, index), const SizedBox(width: 4),
          Icon(Icons.swap_horiz, size: 16, color: Colors.grey[400]), const SizedBox(width: 4),
          _buildDestinationDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildFlightTimeDropdown(leg, legId, index), const SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]), const SizedBox(width: 4),
          _buildArrivalTimeField(legId, index), const SizedBox(width: 8),
          _buildFareTypeDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildSeatClassDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildTextField('運賃(円)', 80, fareAmountControllers[legId]!, '15000', onChanged: (_) => setState(() {})), const SizedBox(width: 12),
          if (fop != null) _buildPointsDisplay(airline, fop, miles, legId),
        ])),
      ]),
    );
  }

  Widget _buildAirlineDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    return SizedBox(width: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('航空会社', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: airline, isExpanded: true, underline: const SizedBox(),
          items: airlines.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) { if (v != null && v != airline) { _clearFlightInfo(index, legId); setState(() { legs[index]['airline'] = v; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); } },
        ),
      ),
    ]));
  }

  Widget _buildDepartureDropdown(Map<String, dynamic> leg, int legId, int index) {
    final departureAirport = leg['departureAirport'] as String; final airline = leg['airline'] as String;
    // 航空会社別の空港リストを使用
    final airportList = airline == 'JAL' 
        ? (jalDepartureAirports.isNotEmpty ? jalDepartureAirports : airports)
        : (anaDepartureAirports.isNotEmpty ? anaDepartureAirports : airports);
    final currentValue = departureAirport.isEmpty || !airportList.contains(departureAirport) ? null : departureAirport;
    final displayItems = ['', ...airportList]; final displayText = departureAirport.isNotEmpty ? departureAirport : '選択';
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('departure_${legId}_$airline'), value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 180,
          hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(displayText, style: const TextStyle(fontSize: 12))),
          selectedItemBuilder: (context) => displayItems.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 12))))).toList(),
          items: displayItems.map((e) => DropdownMenuItem(value: e.isEmpty ? null : e, child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) async { if (v == null || v.isEmpty) { _clearFlightInfo(index, legId); } else { setState(() => legs[index]['departureAirport'] = v); await _fetchAvailableFlights(index); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildDestinationDropdown(Map<String, dynamic> leg, int legId, int index) {
    final arrivalAirport = leg['arrivalAirport'] as String; final destinations = availableDestinations[legId] ?? [];
    final airline = leg['airline'] as String;
    final currentValue = arrivalAirport.isEmpty || !destinations.contains(arrivalAirport) ? null : arrivalAirport;
    final displayItems = ['', ...destinations]; final displayText = arrivalAirport.isNotEmpty ? arrivalAirport : '選択';
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('destination_${legId}_$airline'), value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 180,
          hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(displayText, style: const TextStyle(fontSize: 12))),
          selectedItemBuilder: (context) => displayItems.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 12))))).toList(),
          items: displayItems.map((e) => DropdownMenuItem(value: e.isEmpty ? null : e, child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) async { if (v == null || v.isEmpty) { _clearFlightInfo(index, legId); } else { setState(() => legs[index]['arrivalAirport'] = v); await _fetchAvailableFlights(index); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final flights = availableFlights[legId] ?? []; final airline = leg['airline'] as String;
    final currentTime = departureTimeControllers[legId]?.text ?? '';
    return SizedBox(width: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('flight_time_${legId}_$airline'), value: null, isExpanded: true, underline: const SizedBox(), menuWidth: 150,
          hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(currentTime.isEmpty ? '選択' : currentTime, style: const TextStyle(fontSize: 12))),
          items: [const DropdownMenuItem(value: '__clear__', child: Text('－', style: TextStyle(fontSize: 12))), ...flights.map((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); final arrCode = flight['arrival_code'] ?? ''; return DropdownMenuItem(value: '${flight['id']}', child: Text('${airportNames[arrCode] ?? arrCode} $depTime', style: const TextStyle(fontSize: 12))); })],
          onChanged: (value) { if (value == null) return; if (value == '__clear__') { _clearFlightInfo(index, legId); return; } final flight = flights.firstWhere((f) => f['id'].toString() == value, orElse: () => {}); if (flight.isNotEmpty) { String depTime = flight['departure_time'] ?? ''; String arrTime = flight['arrival_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5); departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime; flightNumberControllers[legId]?.text = flight['flight_number'] ?? ''; setState(() => legs[index]['arrivalAirport'] = flight['arrival_code'] ?? ''); if (index + 1 < legs.length) _fetchAvailableFlights(index + 1); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildArrivalTimeField(int legId, int index) {
    return SizedBox(width: 65, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: arrivalTimeControllers[legId], style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: 'HH:MM', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: (v) { if (v.isEmpty) _clearFlightInfo(index, legId); }),
      ),
    ]));
  }

  Widget _buildFareTypeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String; final fareType = leg['fareType'] as String;
    final fareTypes = fareTypesByAirline[airline] ?? [];
    final currentValue = fareType.isEmpty || !fareTypes.contains(fareType) ? null : fareType;
    return SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('運賃種別', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 250,
          hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 10))),
          selectedItemBuilder: (context) => fareTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(),
          items: fareTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                legs[index]['fareType'] = v;
                // ANA運賃1,2,9なら座席クラスを自動的にプレミアムクラスに
                if (airline == 'ANA' && (v.startsWith('運賃1') || v.startsWith('運賃2') || v.startsWith('運賃9'))) {
                  legs[index]['seatClass'] = 'プレミアムクラス';
                }
              });
              _calculateSingleLeg(index);
            }
          },
        ),
      ),
    ]));
  }

  Widget _buildSeatClassDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String; final seatClass = leg['seatClass'] as String;
    final seatClasses = seatClassesByAirline[airline] ?? [];
    final currentValue = seatClass.isEmpty || !seatClasses.contains(seatClass) ? null : seatClass;
    return SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('座席クラス', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 150,
          hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 10))),
          selectedItemBuilder: (context) => seatClasses.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(),
          items: seatClasses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(),
          onChanged: (v) { if (v != null) { setState(() => legs[index]['seatClass'] = v); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildTextField(String label, double width, TextEditingController controller, String hint, {void Function(String)? onChanged, void Function(String)? onSubmit}) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: controller, style: const TextStyle(fontSize: 12), decoration: InputDecoration(hintText: hint, isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: onChanged, onFieldSubmitted: onSubmit),
      ),
    ]));
  }

  Widget _buildFlightNumberField(int legId, int index) {
    return SizedBox(width: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('便名', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: Focus(
          onFocusChange: (hasFocus) { if (!hasFocus) { final flightNumber = flightNumberControllers[legId]?.text ?? ''; if (flightNumber.isNotEmpty) _autoFillFromFlightNumber(index); } },
          child: TextFormField(controller: flightNumberControllers[legId], style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: '901', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onFieldSubmitted: (_) => _autoFillFromFlightNumber(index)),
        ),
      ),
    ]));
  }

  Widget _buildDatePicker(String label, double width, TextEditingController controller, BuildContext context) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: controller, readOnly: true, style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 14)),
          onTap: () async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: _parseDate(controller.text) ?? now, firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ja')); if (picked != null) { controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}'; setState(() {}); } },
        ),
      ),
    ]));
  }

  DateTime? _parseDate(String text) { if (text.isEmpty) return null; try { final parts = text.split('/'); if (parts.length == 3) return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])); } catch (e) {} return null; }
}
