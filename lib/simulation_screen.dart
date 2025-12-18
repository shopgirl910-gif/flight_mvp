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
  
  Map<int, TextEditingController> dateControllers = {};
  Map<int, TextEditingController> flightNumberControllers = {};
  Map<int, TextEditingController> departureTimeControllers = {};
  Map<int, TextEditingController> arrivalTimeControllers = {};
  Map<int, TextEditingController> fareAmountControllers = {};
  
  Map<int, List<Map<String, dynamic>>> availableFlights = {};
  Map<int, List<String>> availableDestinations = {};
  
  // è¿½åŠ : èˆªç©ºä¼šç¤¾åˆ¥å°±èˆªç©ºæ¸¯ã‚­ãƒ£ãƒƒã‚·ãƒ¥
  Map<String, List<String>> airlineAirports = {};
  
  int _legIdCounter = 0;
  bool isLoading = false;
  String? errorMessage;

  String? selectedJALCard;
  String? selectedANACard;
  String? selectedJALStatus;
  String? selectedANAStatus;
  bool jalTourPremium = false; // JALã‚«ãƒ¼ãƒ‰ãƒ„ã‚¢ãƒ¼ãƒ—ãƒ¬ãƒŸã‚¢ãƒ 
  bool jalShoppingMilePremium = false; // JALã‚«ãƒ¼ãƒ‰ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«ãƒ»ãƒ—ãƒ¬ãƒŸã‚¢ãƒ 

  final List<String> jalCardTypes = ['-', 'JMBä¼šå“¡', 'JALã‚«ãƒ¼ãƒ‰æ™®é€šä¼šå“¡', 'JALã‚«ãƒ¼ãƒ‰CLUB-Aä¼šå“¡', 'JALã‚«ãƒ¼ãƒ‰CLUB-Aã‚´ãƒ¼ãƒ«ãƒ‰ä¼šå“¡', 'JALã‚«ãƒ¼ãƒ‰ãƒ—ãƒ©ãƒãƒŠä¼šå“¡', 'JALã‚°ãƒ­ãƒ¼ãƒãƒ«ã‚¯ãƒ©ãƒ–ä¼šå“¡(æ—¥æœ¬)', 'JALã‚°ãƒ­ãƒ¼ãƒãƒ«ã‚¯ãƒ©ãƒ–ä¼šå“¡(æµ·å¤–)', 'JALã‚«ãƒ¼ãƒ‰NAVIä¼šå“¡', 'JAL CLUB EST æ™®é€šä¼šå“¡', 'JAL CLUB EST CLUB-Aä¼šå“¡', 'JAL CLUB EST CLUB-A GOLDä¼šå“¡', 'JAL CLUB EST ãƒ—ãƒ©ãƒãƒŠä¼šå“¡'];
  final List<String> anaCardTypes = ['-', 'AMCã‚«ãƒ¼ãƒ‰(ææºã‚«ãƒ¼ãƒ‰å«ã‚€)', 'ANAã‚«ãƒ¼ãƒ‰ ä¸€èˆ¬', 'ANAã‚«ãƒ¼ãƒ‰ å­¦ç”Ÿç”¨', 'ANAã‚«ãƒ¼ãƒ‰ ãƒ¯ã‚¤ãƒ‰', 'ANAã‚«ãƒ¼ãƒ‰ ã‚´ãƒ¼ãƒ«ãƒ‰', 'ANAã‚«ãƒ¼ãƒ‰ ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ', 'SFC ä¸€èˆ¬', 'SFC ã‚´ãƒ¼ãƒ«ãƒ‰', 'SFC ãƒ—ãƒ¬ãƒŸã‚¢ãƒ '];
  final List<String> jalStatusTypes = ['-', 'JMBãƒ€ã‚¤ãƒ¤ãƒ¢ãƒ³ãƒ‰', 'JMBã‚µãƒ•ã‚¡ã‚¤ã‚¢', 'JMBã‚¯ãƒªã‚¹ã‚¿ãƒ«'];
  final List<String> anaStatusTypes = ['-', 'ãƒ€ã‚¤ãƒ¤ãƒ¢ãƒ³ãƒ‰(1å¹´ç›®)', 'ãƒ€ã‚¤ãƒ¤ãƒ¢ãƒ³ãƒ‰(ç¶™ç¶š2å¹´ä»¥ä¸Š)', 'ãƒ—ãƒ©ãƒãƒŠ(1å¹´ç›®)', 'ãƒ—ãƒ©ãƒãƒŠ(ç¶™ç¶š2å¹´ä»¥ä¸Š)', 'ãƒ–ãƒ­ãƒ³ã‚º(1å¹´ç›®)', 'ãƒ–ãƒ­ãƒ³ã‚º(ç¶™ç¶š2å¹´ä»¥ä¸Š)'];
  final List<String> airports = [
    // 主要空港
    'HND', 'NRT', 'ITM', 'KIX', 'UKB', 'CTS', 'NGO', 'FUK', 'OKA',
    // 区切り線
    '---',
    // 北海道（北から）
    'WKJ', 'MBE', 'MMB', 'SHB', 'KUH', 'OBO', 'AKJ', 'CTS', 'OKD', 'HKD', 'OIR',
    // 東北（北から）
    'AOJ', 'MSJ', 'HNA', 'AXT', 'ONJ', 'GAJ', 'SDJ', 'FKS',
    // 関東・中部
    'HND', 'NRT', 'HAC', 'FSZ', 'MMJ', 'NTQ', 'TOY', 'KMQ', 'NGO', 'NKM', 'SHM',
    // 関西
    'ITM', 'KIX', 'UKB', 'TJH',
    // 中国・四国
    'TTJ', 'YGJ', 'IZO', 'OKI', 'OKJ', 'HIJ', 'IWK', 'UBJ', 'TKS', 'TAK', 'KCZ', 'MYJ',
    // 九州（北から）
    'KKJ', 'FUK', 'HSG', 'NGS', 'KMJ', 'OIT', 'KMI', 'KOJ', 'AXJ',
    // 離島
    'IKI', 'TSJ', 'FUJ', 'TNE', 'KUM', 'ASJ', 'KKX', 'TKN', 'OKA', 'OGN', 'MMY', 'ISG', 'RNJ',
  ];
  final Map<String, String> airportNames = {
    'HND': 'ç¾½ç”°', 'NRT': 'æˆç”°', 'KIX': 'é–¢è¥¿', 'ITM': 'ä¼Šä¸¹', 'NGO': 'ä¸­éƒ¨', 'CTS': 'æ–°åƒæ­³', 'FUK': 'ç¦å²¡', 'OKA': 'é‚£è¦‡',
    'NGS': 'é•·å´Ž', 'KMJ': 'ç†Šæœ¬', 'OIT': 'å¤§åˆ†', 'MYJ': 'æ¾å±±', 'HIJ': 'åºƒå³¶', 'TAK': 'é«˜æ¾', 'KCZ': 'é«˜çŸ¥', 'TKS': 'å¾³å³¶', 'KOJ': 'é¹¿å…å³¶',
    'SDJ': 'ä»™å°', 'AOJ': 'é’æ£®', 'AKJ': 'æ—­å·', 'AXT': 'ç§‹ç”°', 'GAJ': 'å±±å½¢', 'KIJ': 'æ–°æ½Ÿ', 'TOY': 'å¯Œå±±', 'KMQ': 'å°æ¾', 'FSZ': 'é™å²¡',
    'MMB': 'å¥³æº€åˆ¥', 'OBO': 'å¸¯åºƒ', 'KUH': 'é‡§è·¯', 'HKD': 'å‡½é¤¨', 'ISG': 'çŸ³åž£', 'MMY': 'å®®å¤', 'UBJ': 'å±±å£å®‡éƒ¨', 'IWK': 'å²©å›½',
    'OKJ': 'å²¡å±±', 'TTJ': 'é³¥å–', 'YGJ': 'ç±³å­', 'IZO': 'å‡ºé›²', 'NKM': 'çœŒå–¶åå¤å±‹', 'UKB': 'ç¥žæˆ¸', 'HSG': 'ä½è³€', 'KMI': 'å®®å´Ž',
    'ASJ': 'å¥„ç¾Ž', 'TKN': 'å¾³ä¹‹å³¶', 'OKI': 'éš å²', 'FKS': 'ç¦å³¶', 'HNA': 'èŠ±å·»', 'MSJ': 'ä¸‰æ²¢', 'ONJ': 'å¤§é¤¨èƒ½ä»£', 'SHM': 'å—ç´€ç™½æµœ',
    'NTQ': 'èƒ½ç™»', 'KKJ': 'åŒ—ä¹å·ž', 'TNE': 'ç¨®å­å³¶', 'KUM': 'å±‹ä¹…å³¶', 'RNJ': 'ä¸Žè«–', 'OGN': 'ä¸Žé‚£å›½', 'HAC': 'å…«ä¸ˆå³¶',
    'MBE': 'ç´‹åˆ¥', 'SHB': 'ä¸­æ¨™æ´¥', 'WKJ': 'ç¨šå†…', 'OKD': 'ä¸˜ç ', 'IKI': 'å£±å²', 'TSJ': 'å¯¾é¦¬', 'FUJ': 'äº”å³¶ç¦æ±Ÿ', 'OIR': 'å¥¥å°»',
    'SYO': 'åº„å†…', 'MMJ': 'æ¾æœ¬', 'AXJ': 'å¤©è‰', 'TJH': 'ä½†é¦¬', 'KKX': 'å–œç•Œ',
    '---': '──────',
  };
  final List<String> airlines = ['JAL', 'ANA'];
  final Map<String, List<String>> fareTypesByAirline = {
    'JAL': ['é‹è³ƒ1 (100%) ãƒ•ãƒ¬ãƒƒã‚¯ã‚¹ç­‰', 'é‹è³ƒ2 (75%) æ ªä¸»å‰²å¼•', 'é‹è³ƒ3 (75%) ã‚»ã‚¤ãƒãƒ¼', 'é‹è³ƒ4 (75%) ã‚¹ãƒšã‚·ãƒ£ãƒ«ã‚»ã‚¤ãƒãƒ¼', 'é‹è³ƒ5 (50%) åŒ…æ‹¬æ—…è¡Œé‹è³ƒ', 'é‹è³ƒ6 (50%) ã‚¹ã‚«ã‚¤ãƒ¡ã‚¤ãƒˆç­‰'],
    'ANA': ['é‹è³ƒ1 (150%) ãƒ—ãƒ¬ãƒŸã‚¢ãƒ é‹è³ƒ', 'é‹è³ƒ2 (125%) ãƒ—ãƒ¬ãƒŸã‚¢ãƒ å°å…', 'é‹è³ƒ3 (100%) ç‰‡é“ãƒ»å¾€å¾©', 'é‹è³ƒ4 (100%) ãƒ“ã‚¸ãƒã‚¹', 'é‹è³ƒ5 (75%) ç‰¹å‰²A', 'é‹è³ƒ6 (75%) ç‰¹å‰²B', 'é‹è³ƒ7 (75%) ç‰¹å‰²C', 'é‹è³ƒ8 (50%) ã„ã£ã—ã‚‡ã«ãƒžã‚¤ãƒ«å‰²', 'é‹è³ƒ9 (150%) ãƒ—ãƒ¬ãƒŸã‚¢ãƒ æ ªä¸»', 'é‹è³ƒ10 (100%) æ™®é€šæ ªä¸»', 'é‹è³ƒ11 (70%) ç‰¹å‰²ãƒ—ãƒ©ã‚¹', 'é‹è³ƒ12 (50%) ã‚¹ãƒžãƒ¼ãƒˆã‚·ãƒ‹ã‚¢', 'é‹è³ƒ13 (30%) å€‹äººåŒ…æ‹¬'],
  };
  final Map<String, List<String>> seatClassesByAirline = {'JAL': ['æ™®é€šå¸­', 'ã‚¯ãƒ©ã‚¹J', 'ãƒ•ã‚¡ãƒ¼ã‚¹ãƒˆã‚¯ãƒ©ã‚¹'], 'ANA': ['æ™®é€šå¸­', 'ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ã‚¯ãƒ©ã‚¹']};

  // JALæ­ä¹—ãƒœãƒ¼ãƒŠã‚¹FOPï¼ˆé‹è³ƒç¨®åˆ¥ã§æ±ºå®šï¼‰
  final Map<String, int> jalBonusFOP = {'é‹è³ƒ1': 400, 'é‹è³ƒ2': 400, 'é‹è³ƒ3': 200, 'é‹è³ƒ4': 200, 'é‹è³ƒ5': 0, 'é‹è³ƒ6': 0};
  
  // ANAæ­ä¹—ãƒã‚¤ãƒ³ãƒˆï¼ˆé‹è³ƒç¨®åˆ¥ã§æ±ºå®šï¼‰
  final Map<String, int> anaBonusPoint = {'é‹è³ƒ1': 400, 'é‹è³ƒ2': 400, 'é‹è³ƒ3': 400, 'é‹è³ƒ4': 0, 'é‹è³ƒ5': 400, 'é‹è³ƒ6': 200, 'é‹è³ƒ7': 0, 'é‹è³ƒ8': 0, 'é‹è³ƒ9': 0, 'é‹è³ƒ10': 0, 'é‹è³ƒ11': 0, 'é‹è³ƒ12': 0, 'é‹è³ƒ13': 0};

  @override
  void initState() {
    super.initState();
    _initAirlineAirports(); // å°±èˆªç©ºæ¸¯ã‚’åˆæœŸåŒ–
    _addLeg();
  }

  // è¿½åŠ : ä¸¡èˆªç©ºä¼šç¤¾ã®å°±èˆªç©ºæ¸¯ã‚’åˆæœŸåŒ–
  Future<void> _initAirlineAirports() async {
    await _fetchAirlineAirports('JAL');
    await _fetchAirlineAirports('ANA');
  }

  // è¿½åŠ : èˆªç©ºä¼šç¤¾åˆ¥ã®å°±èˆªç©ºæ¸¯ã‚’å–å¾—
  Future<List<String>> _fetchAirlineAirports(String airline) async {
    if (airlineAirports.containsKey(airline)) {
      return airlineAirports[airline]!;
    }
    try {
      final response = await Supabase.instance.client
          .from('schedules')
          .select('departure_code')
          .eq('airline_code', airline)
          .eq('is_active', true);
      
      final codes = (response as List)
          .map((r) => r['departure_code'] as String)
          .toSet()
          .toList();
      codes.sort();
      setState(() => airlineAirports[airline] = codes);
      return codes;
    } catch (e) {
      return airports; // ãƒ•ã‚©ãƒ¼ãƒ«ãƒãƒƒã‚¯
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
    // LSPè¿½åŠ : 'calculatedLSP': null
    setState(() { legs.add({'id': legId, 'airline': airline, 'departureAirport': departureAirport, 'arrivalAirport': arrivalAirport, 'fareType': '', 'seatClass': '', 'calculatedFOP': null, 'calculatedMiles': null, 'calculatedLSP': null}); });
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
    // LSPè¿½åŠ : 'calculatedLSP': null
    setState(() { legs[index]['departureAirport'] = ''; legs[index]['arrivalAirport'] = ''; legs[index]['calculatedFOP'] = null; legs[index]['calculatedMiles'] = null; legs[index]['calculatedLSP'] = null; availableFlights[legId] = []; availableDestinations[legId] = []; });
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

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(String airline, String flightNumber, String date) async {
    try {
      // æ—¥ä»˜æœªå…¥åŠ›ãªã‚‰ä»Šæ—¥ã®æ—¥ä»˜ã‚’ä½¿ç”¨
      final targetDate = date.isEmpty 
          ? DateTime.now().toIso8601String().substring(0, 10)
          : date.replaceAll('/', '-');
      return await Supabase.instance.client
          .from('schedules')
          .select()
          .eq('airline_code', airline)
          .eq('flight_number', flightNumber)
          .lte('period_start', targetDate)
          .gte('period_end', targetDate)
          .eq('is_active', true)
          .maybeSingle();
    } catch (e) { return null; }
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int;
    final airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '';
    final date = dateControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) { setState(() => errorMessage = 'ä¾¿åã‚’å…¥åŠ›ã—ã¦ãã ã•ã„'); return; }
    final schedule = await _fetchScheduleByFlightNumber(airline, flightNumber, date);
    if (schedule != null) {
      String depTime = schedule['departure_time'] ?? ''; String arrTime = schedule['arrival_time'] ?? '';
      if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
      final depCode = schedule['departure_code'] as String; final arrCode = schedule['arrival_code'] as String;
      final remarks = schedule['remarks'] as String? ?? '';
      setState(() { legs[index]['departureAirport'] = depCode; legs[index]['arrivalAirport'] = arrCode; errorMessage = null; });
      departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime;
      // remarksè­¦å‘Šè¡¨ç¤º
      if (remarks.isNotEmpty) {
        setState(() => errorMessage = 'âš ï¸ ä¸€éƒ¨æœŸé–“ã§æ™‚åˆ»å¤‰æ›´ã‚ã‚Šã€‚å…¬å¼ã‚µã‚¤ãƒˆã§ç¢ºèªã—ã¦ãã ã•ã„ã€‚');
      }
      await _fetchAvailableFlights(index);
      if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
      _calculateSingleLeg(index);
    } else { setState(() => errorMessage = '$flightNumberä¾¿ãŒè¦‹ã¤ã‹ã‚Šã¾ã›ã‚“'); }
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final legId = legs[index]['id'] as int; 
    final airline = legs[index]['airline'] as String;
    final departure = legs[index]['departureAirport'] as String; 
    final arrival = legs[index]['arrivalAirport'] as String;
    if (departure.isEmpty) { setState(() { availableFlights[legId] = []; availableDestinations[legId] = []; }); return; }
    try {
      // 日付フィルタ用：日付未入力なら今日を使用
      final dateText = dateControllers[legId]?.text ?? '';
      final targetDate = dateText.isEmpty 
          ? DateTime.now().toIso8601String().substring(0, 10)
          : dateText.replaceAll('/', '-');
      
      var query = Supabase.instance.client.from('schedules').select()
          .eq('airline_code', airline)
          .eq('departure_code', departure)
          .eq('is_active', true)
          .lte('period_start', targetDate)
          .gte('period_end', targetDate);
      if (arrival.isNotEmpty) query = query.eq('arrival_code', arrival);
      final response = await query.order('departure_time');
      List<Map<String, dynamic>> flights = (response as List).cast<Map<String, dynamic>>();
      
      // 重複除去（便名+出発時刻+到着地でユニーク化）
      final seen = <String>{};
      flights = flights.where((flight) {
        String depTime = flight['departure_time'] ?? '';
        if (depTime.length > 5) depTime = depTime.substring(0, 5);
        final key = '${flight['flight_number']}_${depTime}_${flight['arrival_code']}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();
      
      if (index > 0) {
        final prevLeg = legs[index - 1]; final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String; final prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          flights = flights.where((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); return _isTimeAfterOrEqual(depTime, minDepartureTime); }).toList();
        }
      }
      // 到着地が確定済みの場合はdestinationsを更新しない
      if (arrival.isEmpty) {
        final destinations = flights.map((f) => f['arrival_code'] as String).toSet().toList(); destinations.sort();
        setState(() { availableFlights[legId] = flights; availableDestinations[legId] = destinations; });
      } else {
        setState(() { availableFlights[legId] = flights; });
      }
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

      // é‹è³ƒç¨®åˆ¥åã‹ã‚‰ç©ç®—çŽ‡ã‚’æŠ½å‡º
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;

      // é‹è³ƒç•ªå·ã‚’æŠ½å‡ºï¼ˆä¾‹: "é‹è³ƒ1 (100%)" â†’ "é‹è³ƒ1"ï¼‰
      final fareNumber = fare.split(' ').first;

      int totalPoints = 0;
      int totalMiles = 0;
      int totalLSP = 0; // LSPè¿½åŠ 

      if (airline == 'JAL') {
        // === JALè¨ˆç®— ===
        // åº§å¸­ãƒœãƒ¼ãƒŠã‚¹çŽ‡
        final seatBonusRate = {'æ™®é€šå¸­': 0.0, 'ã‚¯ãƒ©ã‚¹J': 0.1, 'ãƒ•ã‚¡ãƒ¼ã‚¹ãƒˆã‚¯ãƒ©ã‚¹': 0.5}[seat] ?? 0.0;
        
        // JALã‚«ãƒ¼ãƒ‰ãƒ„ã‚¢ãƒ¼ãƒ—ãƒ¬ãƒŸã‚¢ãƒ é©ç”¨æ™‚ã€é‹è³ƒ4,5ã¯ç©ç®—çŽ‡100%
        double effectiveFareRate = fareRate;
        if (jalTourPremium && (fareNumber == 'é‹è³ƒ4' || fareNumber == 'é‹è³ƒ5')) {
          effectiveFareRate = 1.0;
        }

        // ãƒ•ãƒ©ã‚¤ãƒˆãƒžã‚¤ãƒ« = round(åŒºé–“ãƒžã‚¤ãƒ« Ã— (ç©ç®—çŽ‡ + åº§å¸­ãƒœãƒ¼ãƒŠã‚¹çŽ‡))
        final flightMiles = (distance * (effectiveFareRate + seatBonusRate)).round();

        // ã‚¹ãƒ†ãƒ¼ã‚¿ã‚¹ãƒœãƒ¼ãƒŠã‚¹çŽ‡
        final statusBonusRate = {'-': 0.0, 'JMBãƒ€ã‚¤ãƒ¤ãƒ¢ãƒ³ãƒ‰': 1.30, 'JMBã‚µãƒ•ã‚¡ã‚¤ã‚¢': 1.05, 'JMBã‚¯ãƒªã‚¹ã‚¿ãƒ«': 0.55}[selectedJALStatus ?? '-'] ?? 0.0;

        // ãƒžã‚¤ãƒ«UPãƒœãƒ¼ãƒŠã‚¹ = round(ãƒ•ãƒ©ã‚¤ãƒˆãƒžã‚¤ãƒ« Ã— ã‚¹ãƒ†ãƒ¼ã‚¿ã‚¹ãƒœãƒ¼ãƒŠã‚¹çŽ‡)
        final mileUpBonus = (flightMiles * statusBonusRate).round();

        // åˆè¨ˆãƒžã‚¤ãƒ«
        totalMiles = flightMiles + mileUpBonus;

        // æ­ä¹—ãƒœãƒ¼ãƒŠã‚¹FOPï¼ˆé‹è³ƒç¨®åˆ¥ã§æ±ºå®šï¼‰
        final bonusFOP = jalBonusFOP[fareNumber] ?? 0;

        // FOP = (ãƒ•ãƒ©ã‚¤ãƒˆãƒžã‚¤ãƒ« Ã— 2) + æ­ä¹—ãƒœãƒ¼ãƒŠã‚¹
        totalPoints = (flightMiles * 2) + bonusFOP;

        // LSPè¨ˆç®—: å›½å†…ç·šã§ç©ç®—çŽ‡50%ä»¥ä¸Šãªã‚‰5LSPã€ãã‚Œä»¥å¤–ã¯0
        // å°†æ¥ã®å›½éš›ç·šå¯¾å¿œ: isDomestic ? 5 : (miles ~/ 1000) * 5
        totalLSP = (fareRate >= 0.5) ? 5 : 0;

      } else {
        // === ANAè¨ˆç®— ===
        // ãƒ•ãƒ©ã‚¤ãƒˆãƒžã‚¤ãƒ« = int(åŒºé–“ãƒžã‚¤ãƒ« Ã— ç©ç®—çŽ‡)
        final flightMiles = (distance * fareRate).toInt();

        // ã‚«ãƒ¼ãƒ‰ãƒœãƒ¼ãƒŠã‚¹çŽ‡
        final cardBonusRate = {'-': 0.0, 'AMCã‚«ãƒ¼ãƒ‰(ææºã‚«ãƒ¼ãƒ‰å«ã‚€)': 0.0, 'ANAã‚«ãƒ¼ãƒ‰ ä¸€èˆ¬': 0.10, 'ANAã‚«ãƒ¼ãƒ‰ å­¦ç”Ÿç”¨': 0.10, 'ANAã‚«ãƒ¼ãƒ‰ ãƒ¯ã‚¤ãƒ‰': 0.25, 'ANAã‚«ãƒ¼ãƒ‰ ã‚´ãƒ¼ãƒ«ãƒ‰': 0.25, 'ANAã‚«ãƒ¼ãƒ‰ ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ': 0.50, 'SFC ä¸€èˆ¬': 0.35, 'SFC ã‚´ãƒ¼ãƒ«ãƒ‰': 0.40, 'SFC ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ': 0.50}[selectedANACard ?? '-'] ?? 0.0;

        // ã‚¹ãƒ†ãƒ¼ã‚¿ã‚¹ãƒœãƒ¼ãƒŠã‚¹çŽ‡
        final statusBonusRate = {'-': 0.0, 'ãƒ€ã‚¤ãƒ¤ãƒ¢ãƒ³ãƒ‰(1å¹´ç›®)': 1.15, 'ãƒ€ã‚¤ãƒ¤ãƒ¢ãƒ³ãƒ‰(ç¶™ç¶š2å¹´ä»¥ä¸Š)': 1.25, 'ãƒ—ãƒ©ãƒãƒŠ(1å¹´ç›®)': 0.90, 'ãƒ—ãƒ©ãƒãƒŠ(ç¶™ç¶š2å¹´ä»¥ä¸Š)': 1.00, 'ãƒ–ãƒ­ãƒ³ã‚º(1å¹´ç›®)': 0.40, 'ãƒ–ãƒ­ãƒ³ã‚º(ç¶™ç¶š2å¹´ä»¥ä¸Š)': 0.50}[selectedANAStatus ?? '-'] ?? 0.0;

        // é©ç”¨ãƒœãƒ¼ãƒŠã‚¹çŽ‡ = max(ã‚«ãƒ¼ãƒ‰ãƒœãƒ¼ãƒŠã‚¹çŽ‡, ã‚¹ãƒ†ãƒ¼ã‚¿ã‚¹ãƒœãƒ¼ãƒŠã‚¹çŽ‡)
        final effectiveBonusRate = cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate;

        // ãƒžã‚¤ãƒ«UPãƒœãƒ¼ãƒŠã‚¹ = int(ãƒ•ãƒ©ã‚¤ãƒˆãƒžã‚¤ãƒ« Ã— é©ç”¨ãƒœãƒ¼ãƒŠã‚¹çŽ‡)
        final mileUpBonus = (flightMiles * effectiveBonusRate).toInt();

        // åˆè¨ˆãƒžã‚¤ãƒ«
        totalMiles = flightMiles + mileUpBonus;

        // æ­ä¹—ãƒã‚¤ãƒ³ãƒˆï¼ˆé‹è³ƒç¨®åˆ¥ã§æ±ºå®šï¼‰
        final bonusPoint = anaBonusPoint[fareNumber] ?? 0;

        // PP = int((åŒºé–“ãƒžã‚¤ãƒ« Ã— ç©ç®—çŽ‡ Ã— 2) + æ­ä¹—ãƒã‚¤ãƒ³ãƒˆ)
        totalPoints = ((distance * fareRate * 2) + bonusPoint).toInt();
        
        // ANAã¯LSPå¯¾è±¡å¤–
        totalLSP = 0;
      }

      // LSPè¿½åŠ : calculatedLSPã‚’stateã«æ ¼ç´
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

  String _formatNumber(int number) { if (number == 0) return '0'; return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'); }

  int get jalFOP => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get jalFlightLSP => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedLSP'] as int?) ?? 0)); // ãƒ•ãƒ©ã‚¤ãƒˆLSP
  
  // ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«ãƒ—ãƒ¬ãƒŸã‚¢ãƒ è‡ªå‹•å…¥ä¼šã‚«ãƒ¼ãƒ‰åˆ¤å®šï¼ˆãƒã‚§ãƒƒã‚¯å¼·åˆ¶ï¼†ã‚°ãƒ¬ãƒ¼ã‚¢ã‚¦ãƒˆï¼‰
  bool get isAutoShoppingMilePremium {
    final card = selectedJALCard ?? '-';
    return card.contains('ã‚´ãƒ¼ãƒ«ãƒ‰') || card.contains('ãƒ—ãƒ©ãƒãƒŠ') || card.contains('JAL CLUB EST') || card == 'JALã‚«ãƒ¼ãƒ‰NAVIä¼šå“¡';
  }
  
  // ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«å¯¾è±¡ã‚«ãƒ¼ãƒ‰åˆ¤å®šï¼ˆJMBä¼šå“¡ä»¥å¤–ã®JALã‚«ãƒ¼ãƒ‰ï¼‰
  bool get isShoppingMileEligible {
    final card = selectedJALCard ?? '-';
    return card != '-' && card != 'JMBä¼šå“¡';
  }
  
  // ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«ãƒ—ãƒ¬ãƒŸã‚¢ãƒ æœ‰åŠ¹åˆ¤å®šï¼ˆè‡ªå‹•å…¥ä¼š or ãƒ¦ãƒ¼ã‚¶ãƒ¼ãƒã‚§ãƒƒã‚¯ï¼‰
  bool get isShoppingMilePremiumActive {
    return isAutoShoppingMilePremium || jalShoppingMilePremium;
  }
  
  // ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«è¨ˆç®—ï¼ˆç·é¡ã‹ã‚‰ï¼‰
  int get jalShoppingMiles {
    if (!isShoppingMileEligible) return 0;
    if (isShoppingMilePremiumActive) {
      return jalFare ~/ 100; // 100å††=1ãƒžã‚¤ãƒ«
    } else {
      return jalFare ~/ 200; // 200å††=1ãƒžã‚¤ãƒ«
    }
  }
  
  // ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°LSPï¼ˆ2,000ãƒžã‚¤ãƒ«ã”ã¨ã«5 LSPï¼‰
  int get jalShoppingLSP => (jalShoppingMiles ~/ 2000) * 5;
  
  // åˆè¨ˆLSPï¼ˆãƒ•ãƒ©ã‚¤ãƒˆ + ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ï¼‰
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
    return isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _buildCompactDropdown('JALã‚«ãƒ¼ãƒ‰', 150, selectedJALCard, jalCardTypes, Colors.red, _onJALCardChanged),
            // JALã‚«ãƒ¼ãƒ‰ãƒ„ã‚¢ãƒ¼ãƒ—ãƒ¬ãƒŸã‚¢ãƒ  & ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«ãƒ—ãƒ¬ãƒŸã‚¢ãƒ  ãƒã‚§ãƒƒã‚¯ãƒœãƒƒã‚¯ã‚¹ï¼ˆç¸¦ä¸¦ã³ï¼‰
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 18, height: 18, child: Checkbox(value: jalTourPremium, onChanged: _onJALTourPremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                const SizedBox(width: 4),
                const Text('ãƒ„ã‚¢ãƒ¼ãƒ—ãƒ¬ãƒŸã‚¢ãƒ ', style: TextStyle(fontSize: 9, color: Colors.red)),
              ]),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 18, height: 18, child: Checkbox(
                  value: isAutoShoppingMilePremium || jalShoppingMilePremium,
                  onChanged: isAutoShoppingMilePremium ? null : _onJALShoppingMilePremiumChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
                const SizedBox(width: 4),
                Text('ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°ãƒžã‚¤ãƒ«P', style: TextStyle(fontSize: 9, color: isAutoShoppingMilePremium ? Colors.grey : Colors.red)),
              ]),
            ]),
            _buildCompactDropdown('JALã‚¹ãƒ†ãƒ¼ã‚¿ã‚¹', 120, selectedJALStatus, jalStatusTypes, Colors.red, _onJALStatusChanged),
            _buildMiniStat('FOP', _formatNumber(jalFOP), Colors.red),
            _buildMiniStat('ãƒžã‚¤ãƒ«', _formatNumber(jalMiles), Colors.red),
            _buildMiniStat('LSP', '${_formatNumber(jalFlightLSP)}+${_formatNumber(jalShoppingLSP)}', Colors.red), // ãƒ•ãƒ©ã‚¤ãƒˆ+ã‚·ãƒ§ãƒƒãƒ”ãƒ³ã‚°
            _buildMiniStat('ãƒ¬ã‚°', '$jalCount', Colors.red),
            _buildMiniStat('ç·é¡', jalFare > 0 ? 'Â¥${_formatNumber(jalFare)}' : '-', Colors.red),
            _buildMiniStat('å˜ä¾¡', jalUnitPrice != '-' ? 'Â¥$jalUnitPrice' : '-', Colors.red),
            Container(width: 1, height: 36, color: Colors.grey[300]),
            _buildCompactDropdown('ANAã‚«ãƒ¼ãƒ‰', 150, selectedANACard, anaCardTypes, Colors.blue, _onANACardChanged),
            _buildCompactDropdown('ANAã‚¹ãƒ†ãƒ¼ã‚¿ã‚¹', 140, selectedANAStatus, anaStatusTypes, Colors.blue, _onANAStatusChanged),
            _buildMiniStat('PP', _formatNumber(anaPP), Colors.blue),
            _buildMiniStat('ãƒžã‚¤ãƒ«', _formatNumber(anaMiles), Colors.blue),
            _buildMiniStat('ãƒ¬ã‚°', '$anaCount', Colors.blue),
            _buildMiniStat('ç·é¡', anaFare > 0 ? 'Â¥${_formatNumber(anaFare)}' : '-', Colors.blue),
            _buildMiniStat('å˜ä¾¡', anaUnitPrice != '-' ? 'Â¥$anaUnitPrice' : '-', Colors.blue),
          ]),
        ),
        ...legs.asMap().entries.map((e) => _buildLegCard(context, e.value, e.key)),
        if (errorMessage != null) Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
      ]),
    );
  }

  Widget _buildCompactDropdown(String label, double width, String? value, List<String> items, Color labelColor, void Function(String?) onChanged) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor)),
      const SizedBox(height: 2),
      Container(height: 26, decoration: BoxDecoration(border: Border.all(color: labelColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: value, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]), menuWidth: width + 100,
          hint: Padding(padding: const EdgeInsets.only(left: 4), child: Text('é¸æŠž', style: TextStyle(fontSize: 10, color: Colors.grey[600]))),
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

  Widget _buildPointsDisplay(String airline, int fop, int? miles, int? lsp, int legId) {
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
          // JALã®å ´åˆã¯LSPã‚‚è¡¨ç¤º
          if (airline == 'JAL')
            Text('$pointLabel: $fop  ãƒžã‚¤ãƒ«: $miles  LSP: ${lsp ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
          else
            Text('$pointLabel: $fop  ãƒžã‚¤ãƒ«: $miles', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          if (fare > 0) Text('å˜ä¾¡: Â¥$unitPrice/$pointLabel', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildLegCard(BuildContext context, Map<String, dynamic> leg, int index) {
    final legId = leg['id'] as int; final airline = leg['airline'] as String;
    final fop = leg['calculatedFOP'] as int?; final miles = leg['calculatedMiles'] as int?;
    final lsp = leg['calculatedLSP'] as int?; // LSPè¿½åŠ 
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: airlineColor.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: _addLeg, child: Text('+ レグ追加', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          TextButton(onPressed: () => _clearLeg(index, legId), child: Text('クリア', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          if (legs.length > 1) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeLeg(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _buildAirlineDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDatePicker('æ—¥ä»˜', 130, dateControllers[legId]!, context), const SizedBox(width: 8),
          _buildFlightNumberField(legId, index), const SizedBox(width: 8),
          _buildDepartureDropdown(leg, legId, index), const SizedBox(width: 4),
          Icon(Icons.swap_horiz, size: 16, color: Colors.grey[400]), const SizedBox(width: 4),
          _buildDestinationDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildFlightTimeDropdown(leg, legId, index), const SizedBox(width: 4),
          _buildArrivalTimeField(legId, index), const SizedBox(width: 8),
          _buildFareTypeDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildSeatClassDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildTextField('é‹è³ƒ', 70, fareAmountControllers[legId]!, '15000', onChanged: (_) => setState(() {})), const SizedBox(width: 8),
          // LSPè¿½åŠ : lspãƒ‘ãƒ©ãƒ¡ãƒ¼ã‚¿ã‚’è¿½åŠ 
          if (fop != null) _buildPointsDisplay(airline, fop, miles, lsp, legId),
        ])),
      ]),
    );
  }

  Widget _buildAirlineDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    return SizedBox(width: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('èˆªç©ºä¼šç¤¾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: airline.isEmpty ? null : airline, isExpanded: true, underline: const SizedBox(),
          hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('é¸æŠž', style: TextStyle(fontSize: 12))),
          selectedItemBuilder: (context) => airlines.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold))))).toList(),
          items: airlines.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)))).toList(),
          onChanged: (v) { if (v != null && v != airline) { _clearFlightInfo(index, legId); setState(() { legs[index]['airline'] = v; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); } },
        ),
      ),
    ]));
  }

  // ä¿®æ­£2: èˆªç©ºä¼šç¤¾åˆ¥å°±èˆªç©ºæ¸¯ã®ã¿è¡¨ç¤º
  Widget _buildDepartureDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String;
    // 就航空港リストを取得（キャッシュがあればそれを使用）
    var airportList = List<String>.from(airlineAirports[airline] ?? airports);
    // 便名検索で設定された空港がリストにない場合は追加
    if (departure.isNotEmpty && !airportList.contains(departure)) {
      airportList = [departure, ...airportList];
    }
    final currentValue = departure.isEmpty ? null : departure;
    final displayText = currentValue ?? '選択';
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('departure_${legId}_${airline}_$departure'), value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 180, itemHeight: 36,
          hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(displayText, style: const TextStyle(fontSize: 12))),
          selectedItemBuilder: (context) => airportList.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e == '---' ? '' : e, style: const TextStyle(fontSize: 12))))).toList(),
          items: airportList.map((e) {
            if (e == '---') {
              return DropdownMenuItem<String>(enabled: false, child: Divider(height: 1, color: Colors.grey[400]));
            }
            return DropdownMenuItem(value: e, child: Text('$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)));
          }).toList(),
          onChanged: (v) { if (v != null && v != '---') { _clearFlightInfo(index, legId); setState(() => legs[index]['departureAirport'] = v); _fetchAvailableFlights(index); } },
        ),
      ),
    ]));
  }

  Widget _buildDestinationDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    final arrival = leg['arrivalAirport'] as String;
    final destinations = availableDestinations[legId] ?? [];
    // 便名検索で設定された空港がリストにない場合は追加
    var displayItems = ['', ...destinations];
    if (arrival.isNotEmpty && !displayItems.contains(arrival)) {
      displayItems = ['', arrival, ...destinations];
    }
    final currentValue = arrival.isEmpty ? null : arrival;
    final displayText = currentValue ?? '選択';
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('destination_${legId}_${airline}_$arrival'), value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 150,
          hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(displayText, style: const TextStyle(fontSize: 12))),
          selectedItemBuilder: (context) => displayItems.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 12))))).toList(),
          items: displayItems.map((e) => DropdownMenuItem(value: e.isEmpty ? null : e, child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) { if (v == null || v.isEmpty) { _clearFlightInfo(index, legId); } else { setState(() => legs[index]['arrivalAirport'] = v); _fetchAvailableFlights(index); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final flights = availableFlights[legId] ?? []; final airline = leg['airline'] as String;
    final currentTime = departureTimeControllers[legId]?.text ?? '';
    return SizedBox(width: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('å‡ºç™ºæ™‚åˆ»', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('flight_time_${legId}_$airline'), value: null, isExpanded: true, underline: const SizedBox(), menuWidth: 150,
          hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(currentTime.isEmpty ? 'é¸æŠž' : currentTime, style: const TextStyle(fontSize: 12))),
          items: [const DropdownMenuItem(value: '__clear__', child: Text('ï¼', style: TextStyle(fontSize: 12))), ...flights.map((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); final arrCode = flight['arrival_code'] ?? ''; return DropdownMenuItem(value: '${flight['id']}', child: Text('${airportNames[arrCode] ?? arrCode} $depTime', style: const TextStyle(fontSize: 12))); })],
          onChanged: (value) { if (value == null) return; if (value == '__clear__') { _clearFlightInfo(index, legId); return; } final flight = flights.firstWhere((f) => f['id'].toString() == value, orElse: () => {}); if (flight.isNotEmpty) { String depTime = flight['departure_time'] ?? ''; String arrTime = flight['arrival_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5); departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime; flightNumberControllers[legId]?.text = flight['flight_number'] ?? ''; setState(() => legs[index]['arrivalAirport'] = flight['arrival_code'] ?? ''); if (index + 1 < legs.length) _fetchAvailableFlights(index + 1); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildArrivalTimeField(int legId, int index) {
    return SizedBox(width: 65, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('åˆ°ç€æ™‚åˆ»', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
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
      const Text('é‹è³ƒç¨®åˆ¥', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 250,
          hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('é¸æŠž', style: TextStyle(fontSize: 10))),
          selectedItemBuilder: (context) => fareTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(),
          items: fareTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(),
          onChanged: (v) { if (v != null) { setState(() => legs[index]['fareType'] = v); _calculateSingleLeg(index); } },
        ),
      ),
    ]));
  }

  Widget _buildSeatClassDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String; final seatClass = leg['seatClass'] as String;
    final seatClasses = seatClassesByAirline[airline] ?? [];
    final currentValue = seatClass.isEmpty || !seatClasses.contains(seatClass) ? null : seatClass;
    return SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('åº§å¸­ã‚¯ãƒ©ã‚¹', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 150,
          hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('é¸æŠž', style: TextStyle(fontSize: 10))),
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
      const Text('ä¾¿å', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
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
          decoration: const InputDecoration(hintText: 'é¸æŠž', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 14)),
          onTap: () async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: _parseDate(controller.text) ?? now, firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ja')); if (picked != null) { controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}'; setState(() {}); } },
        ),
      ),
    ]));
  }

  DateTime? _parseDate(String text) { if (text.isEmpty) return null; try { final parts = text.split('/'); if (parts.length == 3) return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])); } catch (e) {} return null; }
}
