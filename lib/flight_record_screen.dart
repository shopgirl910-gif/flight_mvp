import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlightRecordScreen extends StatefulWidget {
  const FlightRecordScreen({super.key});

  @override
  State<FlightRecordScreen> createState() => _FlightRecordScreenState();
}

class _FlightRecordScreenState extends State<FlightRecordScreen> with AutomaticKeepAliveClientMixin {
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

  // カード種別
  String? selectedJALCard;
  String? selectedANACard;
  
  // ステータス
  String? selectedJALStatus;
  String? selectedANAStatus;

  final List<String> jalCardTypes = [
    '-',
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

  final List<String> airports = ['HND', 'NRT', 'OKA', 'CTS', 'FUK', 'KIX', 'NGO'];
  
  final Map<String, String> airportNames = {
    'HND': '東京/羽田',
    'NRT': '成田',
    'OKA': '那覇',
    'CTS': '札幌',
    'FUK': '福岡',
    'KIX': '大阪/関西',
    'NGO': '名古屋',
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
      '運賃A (150%) フレックス/F',
      '運賃B (130%) スタンダード/F',
      '運賃C (120%) シンプル/F',
      '運賃D (100%) フレックス/Y',
      '運賃E (100%) 島民割引',
      '運賃G (80%) 株主優待割引',
      '運賃H (80%) スタンダード/Y',
      '運賃I (70%) シンプル/Y',
      '運賃J (50%) ユース・シニア',
      '運賃K (30%) 包括旅行割引',
    ],
  };
  final Map<String, List<String>> seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファーストクラス'],
    'ANA': ['普通席', 'ファーストクラス'],
  };

  @override
  void initState() {
    super.initState();
    _addLeg();
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

    String airline = 'JAL';
    String departureAirport = '';
    String arrivalAirport = '';
    String date = '';

    if (legs.isNotEmpty) {
      final prevLeg = legs.last;
      final prevLegId = prevLeg['id'] as int;
      airline = prevLeg['airline'] as String;
      departureAirport = prevLeg['arrivalAirport'] as String;
      arrivalAirport = prevLeg['departureAirport'] as String;
      date = dateControllers[prevLegId]?.text ?? '';
    }

    dateControllers[legId]?.text = date;
    
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
      });
    });

    if (departureAirport.isNotEmpty) {
      _fetchAvailableFlights(legs.length - 1);
    }
  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    dateControllers[legId]?.dispose();
    flightNumberControllers[legId]?.dispose();
    departureTimeControllers[legId]?.dispose();
    arrivalTimeControllers[legId]?.dispose();
    fareAmountControllers[legId]?.dispose();
    dateControllers.remove(legId);
    flightNumberControllers.remove(legId);
    departureTimeControllers.remove(legId);
    arrivalTimeControllers.remove(legId);
    fareAmountControllers.remove(legId);
    availableFlights.remove(legId);
    availableDestinations.remove(legId);
    setState(() => legs.removeAt(index));
  }

  void _clearFlightInfo(int index, int legId) {
    setState(() {
      legs[index]['departureAirport'] = '';
      legs[index]['arrivalAirport'] = '';
      legs[index]['calculatedFOP'] = null;
      legs[index]['calculatedMiles'] = null;
      availableFlights[legId] = [];
      availableDestinations[legId] = [];
    });
    flightNumberControllers[legId]?.text = '';
    departureTimeControllers[legId]?.text = '';
    arrivalTimeControllers[legId]?.text = '';
  }

  void _clearAll() {
    for (int i = legs.length - 1; i >= 0; i--) {
      if (i > 0) {
        _removeLeg(i);
      } else {
        final legId = legs[0]['id'] as int;
        _clearFlightInfo(0, legId);
        setState(() {
          legs[0]['airline'] = 'JAL';
          legs[0]['fareType'] = '';
          legs[0]['seatClass'] = '';
        });
        dateControllers[legId]?.text = '';
        fareAmountControllers[legId]?.text = '';
      }
    }
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
    int hour = int.tryParse(parts[0]) ?? 0;
    int min = int.tryParse(parts[1]) ?? 0;
    min += minutes;
    while (min >= 60) { min -= 60; hour += 1; }
    if (hour >= 24) hour -= 24;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  bool _isTimeAfterOrEqual(String time1, String time2) {
    if (time1.isEmpty || time2.isEmpty) return true;
    if (!time1.contains(':') || !time2.contains(':')) return true;
    final parts1 = time1.split(':');
    final parts2 = time2.split(':');
    final minutes1 = (int.tryParse(parts1[0]) ?? 0) * 60 + (int.tryParse(parts1[1]) ?? 0);
    final minutes2 = (int.tryParse(parts2[0]) ?? 0) * 60 + (int.tryParse(parts2[1]) ?? 0);
    return minutes1 >= minutes2;
  }

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(String airline, String flightNumber) async {
    try {
      final response = await Supabase.instance.client
          .from('schedules').select()
          .eq('airline_code', airline).eq('flight_number', flightNumber).eq('is_active', true)
          .maybeSingle();
      return response;
    } catch (e) { return null; }
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int;
    final airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) { setState(() => errorMessage = '便名を入力してください'); return; }

    final schedule = await _fetchScheduleByFlightNumber(airline, flightNumber);
    if (schedule != null) {
      String depTime = schedule['departure_time'] ?? '';
      String arrTime = schedule['arrival_time'] ?? '';
      if (depTime.length > 5) depTime = depTime.substring(0, 5);
      if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
      
      final depCode = schedule['departure_code'] as String;
      final arrCode = schedule['arrival_code'] as String;
      
      setState(() {
        legs[index]['departureAirport'] = depCode;
        legs[index]['arrivalAirport'] = '';
        errorMessage = null;
      });
      
      await _fetchAvailableFlights(index);
      
      setState(() {
        legs[index]['arrivalAirport'] = arrCode;
      });
      
      departureTimeControllers[legId]?.text = depTime;
      arrivalTimeControllers[legId]?.text = arrTime;
      if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
      _calculateSingleLeg(index);
    } else {
      setState(() => errorMessage = '$flightNumber便が見つかりません');
    }
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final leg = legs[index];
    final legId = leg['id'] as int;
    final airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String;
    final arrival = leg['arrivalAirport'] as String;

    if (departure.isEmpty) { 
      setState(() {
        availableFlights[legId] = [];
        availableDestinations[legId] = [];
      }); 
      return; 
    }

    try {
      var query = Supabase.instance.client.from('schedules').select()
          .eq('airline_code', airline).eq('departure_code', departure).eq('is_active', true);
      if (arrival.isNotEmpty) query = query.eq('arrival_code', arrival);
      
      final response = await query.order('departure_time');
      List<Map<String, dynamic>> flights = (response as List).cast<Map<String, dynamic>>();

      if (index > 0) {
        final prevLeg = legs[index - 1];
        final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String;
        final prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          flights = flights.where((flight) {
            String depTime = flight['departure_time'] ?? '';
            if (depTime.length > 5) depTime = depTime.substring(0, 5);
            return _isTimeAfterOrEqual(depTime, minDepartureTime);
          }).toList();
        }
      }

      final destinations = flights.map((f) => f['arrival_code'] as String).toSet().toList();
      destinations.sort();

      setState(() {
        availableFlights[legId] = flights;
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
    final dep = leg['departureAirport'] as String;
    final arr = leg['arrivalAirport'] as String;
    final fare = leg['fareType'] as String;
    final seat = leg['seatClass'] as String;
    final airline = leg['airline'] as String;
    if (dep.isEmpty || arr.isEmpty || fare.isEmpty || seat.isEmpty) return;

    final seatBonus = {
      'JAL': {'普通席': 0.0, 'クラスJ': 0.10, 'ファーストクラス': 0.50}, 
      'ANA': {'普通席': 0.0, 'ファーストクラス': 0.50}
    };
    try {
      final routeData = await Supabase.instance.client.from('routes').select('distance_miles')
          .eq('departure_code', dep).eq('arrival_code', arr).maybeSingle();
      if (routeData == null) return;
      final distance = routeData['distance_miles'] as int;

      // 運賃種別名から積算率を抽出（例: "運賃I (70%) シンプル/Y" → 0.70）
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
      if (rateMatch != null) {
        fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      }

      final baseFOP = (distance * fareRate).round();
      final bonus = seatBonus[airline]?[seat] ?? 0.0;
      final totalFOP = baseFOP + 400 + (baseFOP * bonus).round();
      final totalMiles = (distance * fareRate).round() + ((distance * fareRate) * bonus).round();
      setState(() { legs[index]['calculatedFOP'] = totalFOP; legs[index]['calculatedMiles'] = totalMiles; });
    } catch (e) {}
  }

  Future<void> _calculateFOP() async {
    setState(() { isLoading = true; errorMessage = null; });
    for (int i = 0; i < legs.length; i++) await _calculateSingleLeg(i);
    setState(() => isLoading = false);
  }

  Future<void> _saveToHistory() async {
    if (!legs.any((leg) => leg['calculatedFOP'] != null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先に計算を実行してください'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => isLoading = true);
    try {
      for (int i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final legId = leg['id'] as int;
        if (leg['calculatedFOP'] == null) continue;
        final dateText = dateControllers[legId]?.text ?? '';
        final fareAmountText = fareAmountControllers[legId]?.text ?? '';
        final fareAmount = int.tryParse(fareAmountText);
        
        await Supabase.instance.client.from('flight_calculations').insert({
          'airline': leg['airline'], 'departure': leg['departureAirport'], 'arrival': leg['arrivalAirport'],
          'fare_type': leg['fareType'], 'seat_class': leg['seatClass'],
          'flight_date': dateText.isNotEmpty ? dateText.replaceAll('/', '-') : null,
          'auto_points': leg['calculatedFOP'], 'auto_miles': leg['calculatedMiles'],
          'final_points': leg['calculatedFOP'], 'final_miles': leg['calculatedMiles'],
          'points_overridden': false, 'miles_overridden': false, 'calculation_version': 'v1.0',
          'fare_amount': fareAmount,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('履歴に保存しました'), backgroundColor: Colors.green));
        _clearAll();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗: $e'), backgroundColor: Colors.red));
    }
    setState(() => isLoading = false);
  }

  String _calculateUnitPrice(int legId, int? fop) {
    if (fop == null || fop == 0) return 'N/A';
    final fareText = fareAmountControllers[legId]?.text ?? '';
    final fareAmount = int.tryParse(fareText);
    if (fareAmount == null || fareAmount == 0) return 'N/A';
    final unitPrice = fareAmount / fop;
    return '${unitPrice.toStringAsFixed(1)}円';
  }

  // JAL集計
  int get jalFOP => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs.where((leg) => leg['airline'] == 'JAL').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get jalCount => legs.where((leg) => leg['airline'] == 'JAL' && leg['calculatedFOP'] != null).length;
  int get jalFare {
    int sum = 0;
    for (var leg in legs) {
      if (leg['airline'] != 'JAL') continue;
      final legId = leg['id'] as int;
      sum += int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    }
    return sum;
  }
  // 全JALレグの運賃が入力されているか
  bool get jalAllFareEntered {
    final jalLegs = legs.where((leg) => leg['airline'] == 'JAL' && leg['calculatedFOP'] != null).toList();
    if (jalLegs.isEmpty) return false;
    for (var leg in jalLegs) {
      final legId = leg['id'] as int;
      final fareText = fareAmountControllers[legId]?.text ?? '';
      if (fareText.isEmpty || int.tryParse(fareText) == null) return false;
    }
    return true;
  }

  String get jalUnitPrice {
    if (jalFOP == 0 || !jalAllFareEntered) return '';
    return '${(jalFare / jalFOP).toStringAsFixed(1)}円';
  }

  // ANA集計
  int get anaPP => legs.where((leg) => leg['airline'] == 'ANA').fold<int>(0, (sum, leg) => sum + ((leg['calculatedFOP'] as int?) ?? 0));
  int get anaMiles => legs.where((leg) => leg['airline'] == 'ANA').fold<int>(0, (sum, leg) => sum + ((leg['calculatedMiles'] as int?) ?? 0));
  int get anaCount => legs.where((leg) => leg['airline'] == 'ANA' && leg['calculatedFOP'] != null).length;
  int get anaFare {
    int sum = 0;
    for (var leg in legs) {
      if (leg['airline'] != 'ANA') continue;
      final legId = leg['id'] as int;
      sum += int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    }
    return sum;
  }
  // 全ANAレグの運賃が入力されているか
  bool get anaAllFareEntered {
    final anaLegs = legs.where((leg) => leg['airline'] == 'ANA' && leg['calculatedFOP'] != null).toList();
    if (anaLegs.isEmpty) return false;
    for (var leg in anaLegs) {
      final legId = leg['id'] as int;
      final fareText = fareAmountControllers[legId]?.text ?? '';
      if (fareText.isEmpty || int.tryParse(fareText) == null) return false;
    }
    return true;
  }

  String get anaUnitPrice {
    if (anaPP == 0 || !anaAllFareEntered) return '';
    return '${(anaFare / anaPP).toStringAsFixed(1)}円';
  }

  bool get hasJAL => jalCount > 0;
  bool get hasANA => anaCount > 0;
  int get totalFare => jalFare + anaFare;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin required
    return isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // カード種別 + ステータス + サマリー統合
        Container(
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
              // JALカード
              _buildCompactDropdown('JALカード', 150, selectedJALCard, jalCardTypes, Colors.red, (v) => setState(() => selectedJALCard = v)),
              // JALステータス
              _buildCompactDropdown('JALステータス', 120, selectedJALStatus, jalStatusTypes, Colors.red, (v) => setState(() => selectedJALStatus = v)),
              // JAL FOP
              _buildMiniStat('FOP', _formatNumber(jalFOP), Colors.red),
              // JAL マイル
              _buildMiniStat('マイル', _formatNumber(jalMiles), Colors.red),
              // JAL レグ
              _buildMiniStat('レグ', '$jalCount', Colors.red),
              // JAL 総額
              _buildMiniStat('総額', jalFare > 0 ? '¥${_formatNumber(jalFare)}' : '-', Colors.red),
              // 区切り
              Container(width: 1, height: 36, color: Colors.grey[300]),
              // ANAカード
              _buildCompactDropdown('ANAカード', 150, selectedANACard, anaCardTypes, Colors.blue, (v) => setState(() => selectedANACard = v)),
              // ANAステータス
              _buildCompactDropdown('ANAステータス', 140, selectedANAStatus, anaStatusTypes, Colors.blue, (v) => setState(() => selectedANAStatus = v)),
              // ANA PP
              _buildMiniStat('PP', _formatNumber(anaPP), Colors.blue),
              // ANA マイル
              _buildMiniStat('マイル', _formatNumber(anaMiles), Colors.blue),
              // ANA レグ
              _buildMiniStat('レグ', '$anaCount', Colors.blue),
              // ANA 総額
              _buildMiniStat('総額', anaFare > 0 ? '¥${_formatNumber(anaFare)}' : '-', Colors.blue),
            ],
          ),
        ),
        
        ...legs.asMap().entries.map((e) => _buildLegCard(context, e.value, e.key)),
        const SizedBox(height: 8),
        if (errorMessage != null) 
          Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildCompactDropdown(String label, double width, String? value, List<String> items, Color color, void Function(String?) onChanged) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Container(
            height: 26,
            decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, size: 16, color: color),
              menuWidth: width + 80,
              hint: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('-', style: TextStyle(fontSize: 10)),
              ),
              selectedItemBuilder: (context) {
                return items.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                  ),
                )).toList();
              },
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildAirlineSummaryRow(String airline, Color color, String pointLabel, int points, int miles, int count, int fare, String unitPrice) {
    return Row(
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(airline, style: TextStyle(fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildSummaryItem(pointLabel, _formatNumber(points), color),
              _buildSummaryItem('マイル', _formatNumber(miles), color),
              _buildSummaryItem('レグ', '$count', color),
              _buildSummaryItem('総支出', fare > 0 ? '¥${_formatNumber(fare)}' : '', Colors.green[700]!),
              _buildSummaryItem('単価', unitPrice, Colors.orange[700]!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  Widget _buildLegCard(BuildContext context, Map<String, dynamic> leg, int index) {
    final legId = leg['id'] as int;
    final airline = leg['airline'] as String;
    final fareTypes = fareTypesByAirline[airline] ?? [];
    final seatClasses = seatClassesByAirline[airline] ?? [];
    final fop = leg['calculatedFOP'] as int?;
    final unitPrice = _calculateUnitPrice(legId, fop);

    return Card(
      margin: const EdgeInsets.only(bottom: 16), 
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ヘッダー行（保存・クリア・削除ボタン）
          Row(children: [
            const Spacer(),
            SizedBox(
              height: 32,
              child: TextButton.icon(
                onPressed: _saveToHistory,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
            SizedBox(
              height: 32,
              child: TextButton.icon(
                onPressed: () => _clearLeg(index, legId),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('クリア', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
            if (legs.length > 1) 
              SizedBox(
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeLeg(index),
                  padding: EdgeInsets.zero,
                ),
              ),
          ]),
          const SizedBox(height: 12),
          
          // 入力フィールド行
          Wrap(spacing: 8, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
            _buildDropdown('航空会社', 70, airline, airlines, (v) { 
              setState(() { legs[index]['airline'] = v!; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); 
              _clearFlightInfo(index, legId);
            }),
            _buildDatePicker('日付', 115, dateControllers[legId]!, context),
            _buildTextField('便名', 65, flightNumberControllers[legId]!, '', 
              onChanged: (v) async { 
                if (v.isEmpty) { 
                  _clearFlightInfo(index, legId);
                  return; 
                } 
                if (v.length >= 3) await _autoFillFromFlightNumber(index); 
              }, 
              onSubmit: (_) => _autoFillFromFlightNumber(index)
            ),
            _buildDepartureDropdown(leg, legId, index),
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Icon(Icons.flight_takeoff, size: 18)),
            _buildDestinationDropdown(leg, legId, index),
            _buildFlightTimeDropdown(leg, legId, index),
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Icon(Icons.arrow_forward, size: 16)),
            _buildArrivalTimeField(legId, index),
            _buildDropdown('運賃種別', 125, fareTypes.contains(leg['fareType']) ? leg['fareType'] : null, fareTypes, (v) { 
              setState(() => legs[index]['fareType'] = v ?? ''); 
              _calculateSingleLeg(index); 
            }),
            _buildDropdown('座席クラス', 105, seatClasses.contains(leg['seatClass']) ? leg['seatClass'] : null, seatClasses, (v) { 
              setState(() => legs[index]['seatClass'] = v ?? ''); 
              _calculateSingleLeg(index); 
            }),
            _buildFareAmountField(legId),
            // レグ追加ボタン（最後のレグのみ）
            if (index == legs.length - 1)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: _addLeg,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('レグ追加', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ),
                ],
              ),
            // FOP/PP + マイル + 単価 横並びボタン
            if (leg['calculatedFOP'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: airline == 'JAL' ? Colors.red : Colors.blue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${airline == 'JAL' ? 'FOP' : 'PP'}: ${leg['calculatedFOP']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                            ),
                            Text(
                              'マイル: ${leg['calculatedMiles']}',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      if (unitPrice != 'N/A') ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '単価: $unitPrice',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildFareAmountField(int legId) {
    return SizedBox(
      width: 95,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('運賃(円)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
            child: TextFormField(
              controller: fareAmountControllers[legId],
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '15000',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartureDropdown(Map<String, dynamic> leg, int legId, int index) {
    final currentValue = (leg['departureAirport'] as String).isEmpty ? null : leg['departureAirport'] as String;
    final airline = leg['airline'] as String;
    final displayItems = ['', ...airports];
    
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      Container(
        height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(
          key: ValueKey('departure_${legId}_$airline'),
          value: currentValue,
          isExpanded: true,
          underline: const SizedBox(),
          menuWidth: 150,
          hint: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(currentValue ?? '選択', style: const TextStyle(fontSize: 12)),
          ),
          selectedItemBuilder: (context) {
            return displayItems.map((e) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 12))),
            )).toList();
          },
          items: displayItems.map((e) => DropdownMenuItem(
            value: e.isEmpty ? null : e,
            child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: (v) {
            if (v == null || v.isEmpty) {
              _clearFlightInfo(index, legId);
            } else {
              setState(() => legs[index]['departureAirport'] = v);
              _fetchAvailableFlights(index); 
              _calculateSingleLeg(index);
            }
          },
        ),
      ),
    ]));
  }

  Widget _buildDestinationDropdown(Map<String, dynamic> leg, int legId, int index) {
    final arrivalAirport = leg['arrivalAirport'] as String;
    final destinations = availableDestinations[legId] ?? [];
    final airline = leg['airline'] as String;
    final currentValue = arrivalAirport.isEmpty || !destinations.contains(arrivalAirport) ? null : arrivalAirport;
    final displayItems = ['', ...destinations];
    final displayText = arrivalAirport.isNotEmpty ? arrivalAirport : '選択';
    
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      Container(
        height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(
          key: ValueKey('destination_${legId}_$airline'),
          value: currentValue,
          isExpanded: true,
          underline: const SizedBox(),
          menuWidth: 150,
          hint: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(displayText, style: const TextStyle(fontSize: 12)),
          ),
          selectedItemBuilder: (context) {
            return displayItems.map((e) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 12))),
            )).toList();
          },
          items: displayItems.map((e) => DropdownMenuItem(
            value: e.isEmpty ? null : e,
            child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: (v) {
            if (v == null || v.isEmpty) {
              _clearFlightInfo(index, legId);
            } else {
              setState(() => legs[index]['arrivalAirport'] = v);
              _fetchAvailableFlights(index);
              _calculateSingleLeg(index);
            }
          },
        ),
      ),
    ]));
  }

  Widget _buildFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final flights = availableFlights[legId] ?? [];
    final airline = leg['airline'] as String;
    final currentTime = departureTimeControllers[legId]?.text ?? '';

    return SizedBox(width: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
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
            child: Text(currentTime.isEmpty ? '選択' : currentTime, style: const TextStyle(fontSize: 12)),
          ),
          items: [
            const DropdownMenuItem(value: '__clear__', child: Text('－', style: TextStyle(fontSize: 12))),
            ...flights.map((flight) {
              String depTime = flight['departure_time'] ?? '';
              if (depTime.length > 5) depTime = depTime.substring(0, 5);
              final arrCode = flight['arrival_code'] ?? '';
              String displayText = '${airportNames[arrCode] ?? arrCode} $depTime';
              return DropdownMenuItem(value: '${flight['id']}', child: Text(displayText, style: const TextStyle(fontSize: 12)));
            }),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == '__clear__') { _clearFlightInfo(index, legId); return; }
            final flight = flights.firstWhere((f) => f['id'].toString() == value, orElse: () => {});
            if (flight.isNotEmpty) {
              String depTime = flight['departure_time'] ?? '';
              String arrTime = flight['arrival_time'] ?? '';
              if (depTime.length > 5) depTime = depTime.substring(0, 5);
              if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
              departureTimeControllers[legId]?.text = depTime;
              arrivalTimeControllers[legId]?.text = arrTime;
              flightNumberControllers[legId]?.text = flight['flight_number'] ?? '';
              setState(() => legs[index]['arrivalAirport'] = flight['arrival_code'] ?? '');
              if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
              _calculateSingleLeg(index);
            }
          },
        ),
      ),
    ]));
  }

  Widget _buildArrivalTimeField(int legId, int index) {
    return SizedBox(width: 65, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      Container(
        height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(
          controller: arrivalTimeControllers[legId], 
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(hintText: 'HH:MM', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
          onChanged: (v) { if (v.isEmpty) _clearFlightInfo(index, legId); },
        ),
      ),
    ]));
  }

  Widget _buildTextField(String label, double width, TextEditingController controller, String hint, {void Function(String)? onChanged, void Function(String)? onSubmit}) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      Container(
        height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextFormField(controller: controller, style: const TextStyle(fontSize: 12), decoration: InputDecoration(hintText: hint, isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: onChanged, onFieldSubmitted: onSubmit),
      ),
    ]));
  }

  Widget _buildDatePicker(String label, double width, TextEditingController controller, BuildContext context) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      Container(
        height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
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
              controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
              setState(() {});
            }
          },
        ),
      ),
    ]));
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    try {
      final parts = text.split('/');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (e) {}
    return null;
  }

  Widget _buildDropdown(String label, double width, String? value, List<String> items, void Function(String?) onChanged) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      Container(
        height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          menuWidth: width + 100,
          hint: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('選択', style: const TextStyle(fontSize: 10)),
          ),
          selectedItemBuilder: (context) {
            return items.map((e) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
              ),
            )).toList();
          },
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(),
          onChanged: onChanged,
        ),
      ),
    ]));
  }
}
