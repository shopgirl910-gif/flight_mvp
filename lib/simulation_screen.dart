import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> legs = [];
  int? expandedLegId; // アコーディオン用: 展開中のレグID
  
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
  Map<int, String?> legWarnings = {}; // レグごとの警告メッセージ
  
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

  final List<String> jalCardTypes = ['-', 'JMB会員', 'JALカード普通会員', 'JALカードCLUB-A会員', 'JALカードCLUB-Aゴールド会員', 'JALカードプラチナ会員', 'JALグローバルクラブ会員(日本)', 'JALグローバルクラブ会員(海外)', 'JALカードNAVI会員', 'JAL CLUB EST 普通会員', 'JAL CLUB EST CLUB-A会員', 'JAL CLUB EST CLUB-A GOLD会員', 'JAL CLUB EST プラチナ会員'];
  final List<String> anaCardTypes = ['-', 'AMCカード(提携カード含む)', 'ANAカード 一般', 'ANAカード 学生用', 'ANAカード ワイド', 'ANAカード ゴールド', 'ANAカード プレミアム', 'SFC 一般', 'SFC ゴールド', 'SFC プレミアム'];
  final List<String> jalStatusTypes = ['-', 'JMBダイヤモンド', 'JMBサファイア', 'JMBクリスタル'];
  final List<String> anaStatusTypes = ['-', 'ダイヤモンド(1年目)', 'ダイヤモンド(継続2年以上)', 'プラチナ(1年目)', 'プラチナ(継続2年以上)', 'ブロンズ(1年目)', 'ブロンズ(継続2年以上)'];
  
  // 主要空港
  final List<String> majorAirports = ['HND', 'NRT', 'ITM', 'KIX', 'NGO', 'CTS', 'FUK', 'OKA'];
  // 区切り用
  static const String airportDivider = '---';
  // 北から順（北海道→東北→関東・中部→近畿→中国・四国→九州→沖縄離島）
  final List<String> regionalAirports = [
    // 北海道
    'WKJ', 'MBE', 'MMB', 'SHB', 'AKJ', 'OKD', 'OBO', 'KUH', 'HKD', 'OIR',
    // 東北
    'AOJ', 'MSJ', 'HNA', 'AXT', 'ONJ', 'SYO', 'GAJ', 'SDJ', 'FKS',
    // 関東・中部
    'HAC', 'NKM', 'FSZ', 'MMJ', 'NTQ', 'TOY', 'KMQ', 'SHM',
    // 近畿
    'UKB', 'TJH',
    // 中国・四国
    'TTJ', 'YGJ', 'OKI', 'IZO', 'OKJ', 'HIJ', 'IWK', 'UBJ', 'TKS', 'TAK', 'KCZ', 'MYJ',
    // 九州
    'KKJ', 'HSG', 'NGS', 'KMJ', 'OIT', 'KMI', 'KOJ', 'AXJ',
    // 九州離島
    'IKI', 'TSJ', 'FUJ', 'TNE', 'KUM',
    // 沖縄・奄美
    'ASJ', 'KKX', 'TKN', 'RNJ', 'OGN', 'MMY', 'ISG',
  ];
  // 全空港リスト（表示順）
  List<String> get airports => [...majorAirports, airportDivider, ...regionalAirports];
  
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
  final Map<String, int> jalBonusFOP = {'運賃1': 400, '運賃2': 400, '運賃3': 200, '運賃4': 200, '運賃5': 0, '運賃6': 0};
  final Map<String, int> anaBonusPoint = {'運賃1': 400, '運賃2': 400, '運賃3': 400, '運賃4': 0, '運賃5': 400, '運賃6': 200, '運賃7': 0, '運賃8': 0, '運賃9': 0, '運賃10': 0, '運賃11': 0, '運賃12': 0, '運賃13': 0};

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
      final response = await Supabase.instance.client.from('schedules').select('departure_code').eq('airline_code', airline).eq('is_active', true);
      final codes = (response as List).map((r) => r['departure_code'] as String).toSet().toList();
      codes.sort();
      setState(() => airlineAirports[airline] = codes);
      return codes;
    } catch (e) { return airports; }
  }

  @override
  void dispose() {
    dateControllers.values.forEach((c) => c.dispose());
    flightNumberControllers.values.forEach((c) => c.dispose());
    departureTimeControllers.values.forEach((c) => c.dispose());
    arrivalTimeControllers.values.forEach((c) => c.dispose());
    fareAmountControllers.values.forEach((c) => c.dispose());
    departureAirportControllers.values.forEach((c) => c.dispose());
    arrivalAirportControllers.values.forEach((c) => c.dispose());
    departureAirportFocusNodes.values.forEach((f) => f.dispose());
    arrivalAirportFocusNodes.values.forEach((f) => f.dispose());
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
    String airline = 'JAL'; String departureAirport = ''; String arrivalAirport = ''; String date = '';
    if (legs.isNotEmpty) {
      final prevLeg = legs.last; final prevLegId = prevLeg['id'] as int;
      airline = prevLeg['airline'] as String;
      departureAirport = prevLeg['arrivalAirport'] as String;
      arrivalAirport = prevLeg['departureAirport'] as String;
      date = dateControllers[prevLegId]?.text ?? '';
    }
    dateControllers[legId]?.text = date;
    departureAirportControllers[legId]?.text = departureAirport;
    arrivalAirportControllers[legId]?.text = arrivalAirport;
    setState(() {
      legs.add({'id': legId, 'airline': airline, 'departureAirport': departureAirport, 'arrivalAirport': arrivalAirport, 'fareType': '', 'seatClass': '', 'calculatedFOP': null, 'calculatedMiles': null, 'calculatedLSP': null});
      expandedLegId = legId; // 新規レグは自動展開
    });
    if (departureAirport.isNotEmpty) _fetchAvailableFlights(legs.length - 1);
  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    dateControllers[legId]?.dispose(); flightNumberControllers[legId]?.dispose(); departureTimeControllers[legId]?.dispose(); arrivalTimeControllers[legId]?.dispose(); fareAmountControllers[legId]?.dispose();
    departureAirportControllers[legId]?.dispose(); arrivalAirportControllers[legId]?.dispose();
    departureAirportFocusNodes[legId]?.dispose(); arrivalAirportFocusNodes[legId]?.dispose();
    dateControllers.remove(legId); flightNumberControllers.remove(legId); departureTimeControllers.remove(legId); arrivalTimeControllers.remove(legId); fareAmountControllers.remove(legId);
    departureAirportControllers.remove(legId); arrivalAirportControllers.remove(legId);
    departureAirportFocusNodes.remove(legId); arrivalAirportFocusNodes.remove(legId);
    availableFlights.remove(legId); availableDestinations.remove(legId);
    setState(() {
      legs.removeAt(index);
      if (expandedLegId == legId) expandedLegId = legs.isNotEmpty ? legs.last['id'] as int : null;
    });
  }

  void _clearFlightInfo(int index, int legId) {
    setState(() { legs[index]['departureAirport'] = ''; legs[index]['arrivalAirport'] = ''; legs[index]['calculatedFOP'] = null; legs[index]['calculatedMiles'] = null; legs[index]['calculatedLSP'] = null; availableFlights[legId] = []; availableDestinations[legId] = []; legWarnings[legId] = null; });
    flightNumberControllers[legId]?.text = ''; departureTimeControllers[legId]?.text = ''; arrivalTimeControllers[legId]?.text = '';
    departureAirportControllers[legId]?.text = ''; arrivalAirportControllers[legId]?.text = '';
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

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(String airline, String flightNumber, String date) async {
    try {
      final targetDate = date.isEmpty ? DateTime.now().toIso8601String().substring(0, 10) : date.replaceAll('/', '-');
      return await Supabase.instance.client.from('schedules').select().eq('airline_code', airline).eq('flight_number', flightNumber).lte('period_start', targetDate).gte('period_end', targetDate).eq('is_active', true).maybeSingle();
    } catch (e) { return null; }
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int;
    final airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '';
    final date = dateControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) { setState(() => errorMessage = '便名を入力してください'); return; }
    final schedule = await _fetchScheduleByFlightNumber(airline, flightNumber, date);
    if (schedule != null) {
      String depTime = schedule['departure_time'] ?? ''; String arrTime = schedule['arrival_time'] ?? '';
      if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
      final depCode = schedule['departure_code'] as String; final arrCode = schedule['arrival_code'] as String;
      final remarks = schedule['remarks'] as String? ?? '';
      setState(() { legs[index]['departureAirport'] = depCode; legs[index]['arrivalAirport'] = arrCode; errorMessage = null; });
      departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime;
      departureAirportControllers[legId]?.text = depCode; arrivalAirportControllers[legId]?.text = arrCode;
      if (remarks.isNotEmpty) setState(() => legWarnings[legId] = '⚠️ 一部期間で時刻変更あり');
      await _fetchAvailableFlights(index);
      if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
      _calculateSingleLeg(index);
    } else { setState(() => errorMessage = '$flightNumber便が見つかりません'); }
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final leg = legs[index]; final legId = leg['id'] as int; final airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String; final arrival = leg['arrivalAirport'] as String;
    final dateText = dateControllers[legId]?.text ?? '';
    if (departure.isEmpty) { setState(() { availableFlights[legId] = []; availableDestinations[legId] = []; }); return; }
    
    // 対象日付を決定（未入力なら今日）
    final targetDate = dateText.isEmpty 
        ? DateTime.now().toIso8601String().substring(0, 10)
        : dateText.replaceAll('/', '-');
    
    try {
      // 1. 出発地からの全フライトを取得（運航期間でフィルタリング）
      final allFlightsResponse = await Supabase.instance.client
          .from('schedules')
          .select()
          .eq('airline_code', airline)
          .eq('departure_code', departure)
          .eq('is_active', true)
          .lte('period_start', targetDate)
          .gte('period_end', targetDate)
          .order('departure_time');
      List<Map<String, dynamic>> allFlights = (allFlightsResponse as List).cast<Map<String, dynamic>>();
      
      // 重複除去（出発時刻+到着地でユニーク化）
      final seenAll = <String>{};
      allFlights = allFlights.where((flight) {
        String depTime = flight['departure_time'] ?? '';
        if (depTime.length > 5) depTime = depTime.substring(0, 5);
        final key = '${depTime}_${flight['arrival_code']}';
        if (seenAll.contains(key)) return false;
        seenAll.add(key);
        return true;
      }).toList();
      
      // 全就航先リストを作成
      final destinations = allFlights.map((f) => f['arrival_code'] as String).toSet().toList();
      destinations.sort();
      
      // 2. 時刻ドロップダウン用のフライトリスト（到着地でフィルタリング）
      List<Map<String, dynamic>> filteredFlights = allFlights;
      if (arrival.isNotEmpty) {
        filteredFlights = allFlights.where((f) => f['arrival_code'] == arrival).toList();
      }
      
      // 前レグの到着時刻から30分以上後のフライトのみ
      if (index > 0) {
        final prevLeg = legs[index - 1]; final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String; final prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          filteredFlights = filteredFlights.where((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); return _isTimeAfterOrEqual(depTime, minDepartureTime); }).toList();
        }
      }
      
      setState(() { availableFlights[legId] = filteredFlights; availableDestinations[legId] = destinations; });
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
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      final fareNumber = fare.split(' ').first;
      int totalPoints = 0; int totalMiles = 0; int totalLSP = 0;

      if (airline == 'JAL') {
        final seatBonusRate = {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seat] ?? 0.0;
        double effectiveFareRate = fareRate;
        if (jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5')) effectiveFareRate = 1.0;
        final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();
        final statusBonusRate = {'-': 0.0, 'JMBダイヤモンド': 1.30, 'JMBサファイア': 1.05, 'JMBクリスタル': 0.55}[selectedJALStatus ?? '-'] ?? 0.0;
        final mileUpBonus = (flightMiles * statusBonusRate).round();
        totalMiles = flightMiles + mileUpBonus;
        final bonusFOP = jalBonusFOP[fareNumber] ?? 0;
        totalPoints = (flightMiles * 2) + bonusFOP;
        totalLSP = (fareRate >= 0.5) ? 5 : 0;
      } else {
        final flightMiles = (distance * fareRate).toInt();
        final cardBonusRate = {'-': 0.0, 'AMCカード(提携カード含む)': 0.0, 'ANAカード 一般': 0.10, 'ANAカード 学生用': 0.10, 'ANAカード ワイド': 0.25, 'ANAカード ゴールド': 0.25, 'ANAカード プレミアム': 0.50, 'SFC 一般': 0.35, 'SFC ゴールド': 0.40, 'SFC プレミアム': 0.50}[selectedANACard ?? '-'] ?? 0.0;
        final statusBonusRate = {'-': 0.0, 'ダイヤモンド(1年目)': 1.15, 'ダイヤモンド(継続2年以上)': 1.25, 'プラチナ(1年目)': 0.90, 'プラチナ(継続2年以上)': 1.00, 'ブロンズ(1年目)': 0.40, 'ブロンズ(継続2年以上)': 0.50}[selectedANAStatus ?? '-'] ?? 0.0;
        final effectiveBonusRate = cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate;
        final mileUpBonus = (flightMiles * effectiveBonusRate).toInt();
        totalMiles = flightMiles + mileUpBonus;
        final bonusPoint = anaBonusPoint[fareNumber] ?? 0;
        totalPoints = ((distance * fareRate * 2) + bonusPoint).toInt();
        totalLSP = 0;
      }
      setState(() { legs[index]['calculatedFOP'] = totalPoints; legs[index]['calculatedMiles'] = totalMiles; legs[index]['calculatedLSP'] = totalLSP; });
    } catch (e) {}
  }

  void _recalculateAllLegs() { for (int i = 0; i < legs.length; i++) _calculateSingleLeg(i); }
  void _onJALCardChanged(String? v) { setState(() => selectedJALCard = v); _recalculateAllLegs(); }
  void _onJALStatusChanged(String? v) { setState(() => selectedJALStatus = v); _recalculateAllLegs(); }
  void _onANACardChanged(String? v) { setState(() => selectedANACard = v); _recalculateAllLegs(); }
  void _onANAStatusChanged(String? v) { setState(() => selectedANAStatus = v); _recalculateAllLegs(); }
  void _onJALTourPremiumChanged(bool? v) { setState(() => jalTourPremium = v ?? false); _recalculateAllLegs(); }
  void _onJALShoppingMilePremiumChanged(bool? v) { setState(() => jalShoppingMilePremium = v ?? false); }

  // ======== 旅程保存機能 ========
  Future<void> _saveItinerary() async {
    // ログインチェック
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('旅程を保存するにはログインが必要です'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'ログイン',
              textColor: Colors.white,
              onPressed: () {
                // TODO: ログイン画面へ遷移
              },
            ),
          ),
        );
      }
      return;
    }

    // 計算済みレグがあるか確認
    final validLegs = legs.where((leg) => leg['calculatedFOP'] != null).toList();
    if (validLegs.isEmpty) {
      setState(() => errorMessage = '保存するレグがありません。運賃種別と座席クラスを選択してください。');
      return;
    }

    setState(() => isLoading = true);

    try {
      // 旅程タイトルを自動生成（例: "HND-OKA-HND 3レグ"）
      final airports = <String>[];
      for (var leg in validLegs) {
        final dep = leg['departureAirport'] as String;
        final arr = leg['arrivalAirport'] as String;
        if (airports.isEmpty || airports.last != dep) airports.add(dep);
        airports.add(arr);
      }
      final title = '${airports.join("-")} ${validLegs.length}レグ';

      // レグデータをJSON用に整形
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
          'fare_amount': int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0,
          'fop': leg['calculatedFOP'],
          'miles': leg['calculatedMiles'],
          'lsp': leg['calculatedLSP'],
        };
      }).toList();

      // Supabaseに保存
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

      // 成功メッセージ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$title」を保存しました'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '保存に失敗しました: $e';
      });
    }
  }

  String _formatNumber(int number) { if (number == 0) return '0'; return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'); }

  int get jalFOP => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get jalFlightLSP => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedLSP'] as int?) ?? 0));
  bool get isAutoShoppingMilePremium { final card = selectedJALCard ?? '-'; return card.contains('ゴールド') || card.contains('プラチナ') || card.contains('JAL CLUB EST') || card == 'JALカードNAVI会員'; }
  bool get isShoppingMileEligible { final card = selectedJALCard ?? '-'; return card != '-' && card != 'JMB会員'; }
  bool get isShoppingMilePremiumActive => isAutoShoppingMilePremium || jalShoppingMilePremium;
  int get jalShoppingMiles { if (!isShoppingMileEligible) return 0; return isShoppingMilePremiumActive ? jalFare ~/ 100 : jalFare ~/ 200; }
  int get jalShoppingLSP => (jalShoppingMiles ~/ 2000) * 5;
  int get jalTotalLSP => jalFlightLSP + jalShoppingLSP;
  int get jalCount => legs.where((leg) => leg['airline'] == 'JAL' && leg['calculatedFOP'] != null).length;
  int get jalFare { int sum = 0; for (var leg in legs) { if (leg['airline'] != 'JAL') continue; final legId = leg['id'] as int; sum += int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0; } return sum; }
  String get jalUnitPrice => (jalFare > 0 && jalFOP > 0) ? (jalFare / jalFOP).toStringAsFixed(1) : '-';
  int get anaPP => legs.where((leg) => leg['airline'] == 'ANA').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get anaMiles => legs.where((leg) => leg['airline'] == 'ANA').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get anaCount => legs.where((leg) => leg['airline'] == 'ANA' && leg['calculatedFOP'] != null).length;
  int get anaFare { int sum = 0; for (var leg in legs) { if (leg['airline'] != 'ANA') continue; final legId = leg['id'] as int; sum += int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0; } return sum; }
  String get anaUnitPrice => (anaFare > 0 && anaPP > 0) ? (anaFare / anaPP).toStringAsFixed(1) : '-';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSummaryBar(isMobile),
            ...legs.asMap().entries.map((e) => _buildLegCard(context, e.value, e.key, isMobile)),
            if (errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14))),
            // モバイル版のみ下部にボタン表示
            if (isMobile) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addLeg,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('レグ追加'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveItinerary,
                    icon: const Icon(Icons.save, size: 20),
                    label: const Text('保存'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }

  Widget _buildSummaryBar(bool isMobile) {
    if (isMobile) {
      return Column(children: [
        _buildMobileSummaryCard('JAL', Colors.red),
        const SizedBox(height: 6),
        _buildMobileSummaryCard('ANA', Colors.blue),
        const SizedBox(height: 10),
      ]);
    } else {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _buildCompactDropdown('JALカード', 150, selectedJALCard, jalCardTypes, Colors.red, _onJALCardChanged),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 18, height: 18, child: Checkbox(value: jalTourPremium, onChanged: _onJALTourPremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
              const SizedBox(width: 4), const Text('ツアープレミアム', style: TextStyle(fontSize: 9, color: Colors.red)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 18, height: 18, child: Checkbox(value: isAutoShoppingMilePremium || jalShoppingMilePremium, onChanged: isAutoShoppingMilePremium ? null : _onJALShoppingMilePremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
              const SizedBox(width: 4), Text('ショッピングマイルP', style: TextStyle(fontSize: 9, color: isAutoShoppingMilePremium ? Colors.grey : Colors.red)),
            ]),
          ]),
          _buildCompactDropdown('JALステータス', 120, selectedJALStatus, jalStatusTypes, Colors.red, _onJALStatusChanged),
          _buildMiniStat('FOP', _formatNumber(jalFOP), Colors.red),
          _buildMiniStat('マイル', _formatNumber(jalMiles), Colors.red),
          _buildMiniStat('LSP', '${_formatNumber(jalFlightLSP)}+${_formatNumber(jalShoppingLSP)}', Colors.red),
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
          Container(width: 1, height: 36, color: Colors.grey[300]),
          // 保存ボタン
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
        ]),
      );
    }
  }

  Widget _buildMobileSummaryCard(String airline, Color color) {
    final isJAL = airline == 'JAL';
    final fop = isJAL ? jalFOP : anaPP;
    final miles = isJAL ? jalMiles : anaMiles;
    final count = isJAL ? jalCount : anaCount;
    final unitPrice = isJAL ? jalUnitPrice : anaUnitPrice;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Text(airline, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 12),
        Text('${isJAL ? "FOP" : "PP"}: ${_formatNumber(fop)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const Spacer(),
        Text('$countレグ', style: TextStyle(fontSize: 11, color: color)),
        if (unitPrice != '-') ...[const SizedBox(width: 8), Text('¥$unitPrice', style: TextStyle(fontSize: 11, color: color))],
        const SizedBox(width: 8),
        Icon(Icons.settings, size: 16, color: color.withOpacity(0.6)),
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

  // ======== レグカード（アコーディオン式） ========
  Widget _buildLegCard(BuildContext context, Map<String, dynamic> leg, int index, bool isMobile) {
    final legId = leg['id'] as int;
    final airline = leg['airline'] as String;
    final fop = leg['calculatedFOP'] as int?;
    final miles = leg['calculatedMiles'] as int?;
    final lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final isExpanded = expandedLegId == legId;
    final dep = leg['departureAirport'] as String;
    final arr = leg['arrivalAirport'] as String;
    final depTime = departureTimeControllers[legId]?.text ?? '';
    final arrTime = arrivalTimeControllers[legId]?.text ?? '';
    final flightNum = flightNumberControllers[legId]?.text ?? '';

    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isExpanded ? airlineColor : airlineColor.withOpacity(0.3), width: isExpanded ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // ヘッダー（タップで展開/折りたたみ）
          InkWell(
            onTap: () => setState(() => expandedLegId = isExpanded ? null : legId),
            borderRadius: BorderRadius.circular(isExpanded ? 0 : 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isExpanded ? airlineColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(11),
                  topRight: const Radius.circular(11),
                  bottomLeft: Radius.circular(isExpanded ? 0 : 11),
                  bottomRight: Radius.circular(isExpanded ? 0 : 11),
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(airline, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                if (dep.isNotEmpty && arr.isNotEmpty) ...[
                  Text('$dep → $arr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (flightNum.isNotEmpty) Text(' ($flightNum)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ] else
                  Text('レグ ${index + 1}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const Spacer(),
                if (fop != null) ...[
                  Text('${_formatNumber(fop)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: airlineColor)),
                  Text(airline == 'JAL' ? ' FOP' : ' PP', style: TextStyle(fontSize: 10, color: airlineColor)),
                ],
                const SizedBox(width: 8),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: airlineColor),
              ]),
            ),
          ),
          // 展開時のコンテンツ
          if (isExpanded) _buildMobileExpandedContent(leg, legId, index, fop, miles, lsp, airline),
        ]),
      );
    } else {
      return _buildDesktopLegCard(context, leg, index);
    }
  }

  Widget _buildMobileExpandedContent(Map<String, dynamic> leg, int legId, int index, int? fop, int? miles, int? lsp, String airline) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final fareText = fareAmountControllers[legId]?.text ?? '';
    final fare = int.tryParse(fareText) ?? 0;
    final unitPrice = (fare > 0 && fop != null && fop > 0) ? (fare / fop).toStringAsFixed(1) : '-';

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 航空会社 & 日付 & 便名
        Row(children: [
          Expanded(child: _buildMobileDropdown('航空会社', leg['airline'] as String, airlines, (v) {
            if (v != null && v != leg['airline']) { _clearFlightInfo(index, legId); setState(() { legs[index]['airline'] = v; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); }
          }, color: airlineColor)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _buildMobileDatePicker('日付', dateControllers[legId]!, context, index)),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: _buildMobileTextField('便名', flightNumberControllers[legId]!, '901', onSubmit: (_) => _autoFillFromFlightNumber(index))),
        ]),
        const SizedBox(height: 10),
        // 出発 → 到着
        Row(children: [
          Expanded(child: _buildMobileAirportSelector('出発', departureAirportControllers[legId]!, departureAirportFocusNodes[legId]!, airlineAirports[airline] ?? airports, (v) {
            if (v != null) { _clearFlightInfo(index, legId); departureAirportControllers[legId]?.text = v; setState(() => legs[index]['departureAirport'] = v); _fetchAvailableFlights(index); }
          })),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.grey[400], size: 20)),
          Expanded(child: _buildMobileAirportSelector('到着', arrivalAirportControllers[legId]!, arrivalAirportFocusNodes[legId]!, availableDestinations[legId] ?? [], (v) {
            if (v != null) { arrivalAirportControllers[legId]?.text = v; setState(() => legs[index]['arrivalAirport'] = v); _fetchAvailableFlights(index); _calculateSingleLeg(index); }
          }, isDestination: true)),
        ]),
        const SizedBox(height: 10),
        // 時刻
        Row(children: [
          Expanded(child: _buildMobileFlightTimeDropdown(leg, legId, index)),
          const SizedBox(width: 8),
          Expanded(child: _buildMobileTextField('到着時刻', arrivalTimeControllers[legId]!, 'HH:MM')),
        ]),
        const SizedBox(height: 10),
        // 運賃種別
        _buildMobileDropdown('運賃種別', leg['fareType'] as String, fareTypesByAirline[airline] ?? [], (v) {
          if (v != null) { setState(() => legs[index]['fareType'] = v); _calculateSingleLeg(index); }
        }),
        const SizedBox(height: 10),
        // 座席 & 運賃
        Row(children: [
          Expanded(child: _buildMobileDropdown('座席クラス', leg['seatClass'] as String, seatClassesByAirline[airline] ?? [], (v) {
            if (v != null) { setState(() => legs[index]['seatClass'] = v); _calculateSingleLeg(index); }
          })),
          const SizedBox(width: 8),
          Expanded(child: _buildMobileTextField('運賃(円)', fareAmountControllers[legId]!, '15000', onChanged: (_) => setState(() {}))),
        ]),
        // 計算結果
        if (fop != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Text('${_formatNumber(fop)} ${airline == "JAL" ? "FOP" : "PP"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 12),
                Text('${_formatNumber(miles ?? 0)}マイル', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                if (airline == 'JAL' && lsp != null) ...[const SizedBox(width: 8), Text('${lsp}LSP', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12))],
              ]),
              if (fare > 0) Text('¥$unitPrice/${airline == "JAL" ? "FOP" : "PP"}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ),
        ],
        // アクションボタン
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => _clearLeg(index, legId), child: Text('クリア', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          if (legs.length > 1) TextButton(onPressed: () => _removeLeg(index), child: const Text('削除', style: TextStyle(color: Colors.red, fontSize: 12))),
        ]),
      ]),
    );
  }

  // ======== モバイル用入力ウィジェット ========
  Widget _buildMobileDropdown(String label, String value, List<String> items, void Function(String?) onChanged, {Color? color}) {
    final currentValue = value.isEmpty || !items.contains(value) ? null : value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 4),
      Container(
        height: 44,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          hint: Padding(padding: const EdgeInsets.only(left: 12), child: Text('選択', style: TextStyle(fontSize: 13, color: Colors.grey[500]))),
          selectedItemBuilder: (context) => items.map((e) => Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Align(alignment: Alignment.centerLeft, child: Text(e, style: TextStyle(fontSize: 13, color: color ?? Colors.black, fontWeight: color != null ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
          )).toList(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13, color: color ?? Colors.black)))).toList(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  Widget _buildMobileAirportSelector(String label, TextEditingController controller, FocusNode focusNode, List<String> items, void Function(String?) onChanged, {bool isDestination = false}) {
    final airportList = items.where((e) => e != airportDivider).toList();
    // 到着地の場合は就航先のみ、出発地の場合はフォールバックあり
    final effectiveList = isDestination ? airportList : (airportList.isNotEmpty ? airportList : [...majorAirports, ...regionalAirports]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 4),
      _buildMobileAirportAutocomplete(
        controller: controller,
        focusNode: focusNode,
        airportList: effectiveList,
        onSelected: (code) => onChanged(code),
      ),
    ]);
  }
  
  // モバイル用オートコンプリート付き空港入力
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
        if (input.isEmpty) {
          return _getSortedAirportList(airportList).where((e) => e != airportDivider);
        }
        return airportList.where((code) {
          final name = airportNames[code] ?? '';
          return code.contains(input) || name.contains(input);
        });
      },
      displayStringForOption: (code) => code,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), color: Colors.grey[50]),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: '選択',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onFieldSubmitted: (value) {
                    final code = value.toUpperCase();
                    if (airportNames.containsKey(code)) {
                      onSelected(code);
                    }
                  },
                ),
                if (textController.text.isNotEmpty && airportNames[textController.text.toUpperCase()] != null)
                  Text(airportNames[textController.text.toUpperCase()]!, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ]),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
          ]),
        );
      },
      optionsViewBuilder: (context, onAutoSelected, options) {
        final sortedOptions = _getSortedAirportList(options.toList());
        final renderBox = context.findRenderObject() as RenderBox?;
        final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
        final screenHeight = MediaQuery.of(context).size.height;
        final spaceBelow = screenHeight - offset.dy - 60;
        final showAbove = spaceBelow < 200;
        
        final itemHeight = 38.0;
        final dividerCount = sortedOptions.where((e) => e == airportDivider).length;
        final actualItemCount = sortedOptions.length - dividerCount;
        final calculatedHeight = (actualItemCount * itemHeight) + (dividerCount * 13);
        final menuHeight = calculatedHeight.clamp(0.0, 250.0);
        
        if (showAbove) {
          return Transform.translate(
            offset: Offset(0, -menuHeight - 50),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: menuHeight, maxWidth: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: sortedOptions.length,
                    itemBuilder: (context, i) {
                      final code = sortedOptions[i];
                      if (code == airportDivider) {
                        return Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8));
                      }
                      return InkWell(
                        onTap: () => onAutoSelected(code),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Text(code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text(airportNames[code] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
        
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
                  if (code == airportDivider) {
                    return Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8));
                  }
                  return InkWell(
                    onTap: () => onAutoSelected(code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Text(code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(airportNames[code] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ]),
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

  Widget _buildMobileFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final flights = availableFlights[legId] ?? [];
    final currentTime = departureTimeControllers[legId]?.text ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('出発時刻', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 4),
      Container(
        height: 44,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: DropdownButton<String>(
          value: null,
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          hint: Padding(padding: const EdgeInsets.only(left: 12), child: Text(currentTime.isEmpty ? '選択' : currentTime, style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: currentTime.isEmpty ? Colors.grey[500] : Colors.black))),
          items: [
            const DropdownMenuItem(value: '__clear__', child: Text('－', style: TextStyle(fontSize: 14))),
            ...flights.map((flight) {
              String depTime = flight['departure_time'] ?? '';
              if (depTime.length > 5) depTime = depTime.substring(0, 5);
              final arrCode = flight['arrival_code'] ?? '';
              return DropdownMenuItem(value: '${flight['id']}', child: Text('${airportNames[arrCode] ?? arrCode} $depTime', style: const TextStyle(fontSize: 13)));
            }),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == '__clear__') { _clearFlightInfo(index, legId); return; }
            final flight = flights.firstWhere((f) => f['id'].toString() == value, orElse: () => {});
            if (flight.isNotEmpty) {
              String depTime = flight['departure_time'] ?? ''; String arrTime = flight['arrival_time'] ?? '';
              if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
              departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime;
              flightNumberControllers[legId]?.text = flight['flight_number'] ?? '';
              setState(() => legs[index]['arrivalAirport'] = flight['arrival_code'] ?? '');
              if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
              _calculateSingleLeg(index);
            }
          },
        ),
      ),
    ]);
  }

  Widget _buildMobileTextField(String label, TextEditingController controller, String hint, {void Function(String)? onChanged, void Function(String)? onSubmit}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 4),
      Container(
        height: 44,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus && onSubmit != null && controller.text.isNotEmpty) {
              onSubmit(controller.text);
            }
          },
          child: TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(hintText: hint, isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            onChanged: onChanged,
            onFieldSubmitted: onSubmit,
          ),
        ),
      ),
    ]);
  }

  Widget _buildMobileDatePicker(String label, TextEditingController controller, BuildContext context, int index) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 4),
      Container(
        height: 44,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), suffixIcon: Icon(Icons.calendar_today, size: 18, color: Colors.grey[600])),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(context: context, initialDate: _parseDate(controller.text) ?? now, firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ja'));
            if (picked != null) { controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}'; setState(() {}); _fetchAvailableFlights(index); }
          },
        ),
      ),
    ]);
  }

  DateTime? _parseDate(String text) { if (text.isEmpty) return null; try { final parts = text.split('/'); if (parts.length == 3) return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])); } catch (e) {} return null; }

  // ======== デスクトップ用レグカード（従来版） ========
  Widget _buildDesktopLegCard(BuildContext context, Map<String, dynamic> leg, int index) {
    final legId = leg['id'] as int; final airline = leg['airline'] as String;
    final fop = leg['calculatedFOP'] as int?; final miles = leg['calculatedMiles'] as int?;
    final lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final warning = legWarnings[legId];
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: airlineColor.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 上部: 警告帯（左）とボタン群（右）
        Row(children: [
          // 左側: 警告帯
          if (warning != null) Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)),
              child: Text(warning, style: TextStyle(fontSize: 11, color: Colors.orange[800])),
            ),
          ) else const Spacer(),
          // 右側: ボタン群
          TextButton.icon(onPressed: _addLeg, icon: const Icon(Icons.add, size: 16), label: const Text('レグ追加'), style: TextButton.styleFrom(foregroundColor: Colors.grey[600], textStyle: const TextStyle(fontSize: 12))),
          TextButton(onPressed: () => _clearLeg(index, legId), child: Text('クリア', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          if (legs.length > 1) IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[600]), onPressed: () => _removeLeg(index), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: '削除'),
        ]),
        const SizedBox(height: 4),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _buildDesktopAirlineDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDesktopDatePicker('日付', 130, dateControllers[legId]!, context, index), const SizedBox(width: 8),
          _buildDesktopFlightNumberField(legId, index), const SizedBox(width: 8),
          _buildDesktopDepartureDropdown(leg, legId, index), const SizedBox(width: 4),
          Icon(Icons.swap_horiz, size: 16, color: Colors.grey[400]), const SizedBox(width: 4),
          _buildDesktopDestinationDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDesktopFlightTimeDropdown(leg, legId, index), const SizedBox(width: 4),
          _buildDesktopArrivalTimeField(legId, index), const SizedBox(width: 8),
          _buildDesktopFareTypeDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDesktopSeatClassDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDesktopTextField('運賃', 70, fareAmountControllers[legId]!, '15000', onChanged: (_) => setState(() {})), const SizedBox(width: 8),
          if (fop != null) _buildDesktopPointsDisplay(airline, fop, miles, lsp, legId),
        ])),
      ]),
    );
  }

  Widget _buildDesktopPointsDisplay(String airline, int fop, int? miles, int? lsp, int legId) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final fareText = fareAmountControllers[legId]?.text ?? '';
    final fare = int.tryParse(fareText) ?? 0;
    final unitPrice = (fare > 0 && fop > 0) ? (fare / fop).toStringAsFixed(1) : '-';
    final pointLabel = airline == 'JAL' ? 'FOP' : 'PP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (airline == 'JAL') Text('$pointLabel: $fop  マイル: $miles  LSP: ${lsp ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
        else Text('$pointLabel: $fop  マイル: $miles', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        if (fare > 0) Text('単価: ¥$unitPrice/$pointLabel', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10)),
      ]),
    );
  }

  Widget _buildDesktopAirlineDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    return SizedBox(width: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('航空会社', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: airline.isEmpty ? null : airline, isExpanded: true, underline: const SizedBox(),
          hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 12))),
          selectedItemBuilder: (context) => airlines.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold))))).toList(),
          items: airlines.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)))).toList(),
          onChanged: (v) { if (v != null && v != airline) { _clearFlightInfo(index, legId); setState(() { legs[index]['airline'] = v; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); } },
        ),
      ),
    ]));
  }

  Widget _buildDesktopDepartureDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    final airportList = (airlineAirports[airline] ?? [...majorAirports, ...regionalAirports]).where((e) => e != airportDivider).toList();
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
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
    ]));
  }

  Widget _buildDesktopDestinationDropdown(Map<String, dynamic> leg, int legId, int index) {
    final destinations = (availableDestinations[legId] ?? []).where((e) => e != airportDivider).toList();
    // 就航先のみを表示（出発地未選択時は空リスト）
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      _buildAirportAutocomplete(
        controller: arrivalAirportControllers[legId]!,
        focusNode: arrivalAirportFocusNodes[legId]!,
        airportList: destinations,
        onSelected: (code) {
          arrivalAirportControllers[legId]?.text = code;
          setState(() => legs[index]['arrivalAirport'] = code);
          _fetchAvailableFlights(index);
          _calculateSingleLeg(index);
        },
      ),
    ]));
  }
  
  // オートコンプリート付き空港入力ウィジェット
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
        if (input.isEmpty) {
          return _getSortedAirportList(airportList).where((e) => e != airportDivider);
        }
        return airportList.where((code) {
          final name = airportNames[code] ?? '';
          return code.contains(input) || name.contains(input);
        });
      },
      displayStringForOption: (code) => code,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return Container(
          height: 32,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          child: TextFormField(
            controller: textController,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 12),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: '選択',
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              suffixIcon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
            ),
            onFieldSubmitted: (value) {
              final code = value.toUpperCase();
              if (airportNames.containsKey(code)) {
                onSelected(code);
              }
            },
          ),
        );
      },
      optionsViewBuilder: (context, onAutoSelected, options) {
        final sortedOptions = _getSortedAirportList(options.toList());
        final renderBox = context.findRenderObject() as RenderBox?;
        final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
        final screenHeight = MediaQuery.of(context).size.height;
        final spaceBelow = screenHeight - offset.dy - 40;
        final showAbove = spaceBelow < 200;
        
        // 候補数に応じた高さを計算（1項目約28px）
        final itemHeight = 28.0;
        final dividerCount = sortedOptions.where((e) => e == airportDivider).length;
        final actualItemCount = sortedOptions.length - dividerCount;
        final calculatedHeight = (actualItemCount * itemHeight) + (dividerCount * 9);
        final menuHeight = calculatedHeight.clamp(0.0, 250.0);
        
        if (showAbove) {
          return Transform.translate(
            offset: Offset(0, -menuHeight - 36),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: menuHeight, maxWidth: 160),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: sortedOptions.length,
                    itemBuilder: (context, i) {
                      final code = sortedOptions[i];
                      if (code == airportDivider) {
                        return Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8));
                      }
                      return InkWell(
                        onTap: () => onAutoSelected(code),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text('$code ${airportNames[code] ?? ''}', style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
        
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
                  if (code == airportDivider) {
                    return Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8));
                  }
                  return InkWell(
                    onTap: () => onAutoSelected(code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text('$code ${airportNames[code] ?? ''}', style: const TextStyle(fontSize: 12)),
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
  
  // 空港リストを主要空港→区切り→北から順にソート
  List<String> _getSortedAirportList(List<String> inputList) {
    final majorInList = majorAirports.where((a) => inputList.contains(a)).toList();
    final regionalInList = regionalAirports.where((a) => inputList.contains(a)).toList();
    if (majorInList.isEmpty) return regionalInList;
    if (regionalInList.isEmpty) return majorInList;
    return [...majorInList, airportDivider, ...regionalInList];
  }

  Widget _buildDesktopFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
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

  Widget _buildDesktopArrivalTimeField(int legId, int index) {
    return SizedBox(width: 65, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: arrivalTimeControllers[legId], style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: 'HH:MM', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: (v) { if (v.isEmpty) _clearFlightInfo(index, legId); }),
      ),
    ]));
  }

  Widget _buildDesktopFareTypeDropdown(Map<String, dynamic> leg, int legId, int index) {
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
          onChanged: (v) { if (v != null) { setState(() => legs[index]['fareType'] = v); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildDesktopSeatClassDropdown(Map<String, dynamic> leg, int legId, int index) {
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

  Widget _buildDesktopTextField(String label, double width, TextEditingController controller, String hint, {void Function(String)? onChanged}) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: controller, style: const TextStyle(fontSize: 12), decoration: InputDecoration(hintText: hint, isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: onChanged),
      ),
    ]));
  }

  Widget _buildDesktopFlightNumberField(int legId, int index) {
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

  Widget _buildDesktopDatePicker(String label, double width, TextEditingController controller, BuildContext context, int index) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: controller, readOnly: true, style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 14)),
          onTap: () async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: _parseDate(controller.text) ?? now, firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ja')); if (picked != null) { controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}'; setState(() {}); _fetchAvailableFlights(index); } },
        ),
      ),
    ]));
  }
}
