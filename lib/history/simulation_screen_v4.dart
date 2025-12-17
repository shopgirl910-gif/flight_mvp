import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
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
    'JAL': ['ウルトラ先得', '先得割引', '特便割引', '普通運賃'],
    'ANA': ['旅割', 'ビジネスきっぷ', 'ANA VALUE', '普通運賃'],
  };
  final Map<String, List<String>> seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファースト'],
    'ANA': ['普通席', 'プレミアムクラス'],
  };

  @override
  void initState() {
    super.initState();
    _addLeg();
  }

  @override
  void dispose() {
    for (var c in dateControllers.values) {
      c.dispose();
    }
    for (var c in flightNumberControllers.values) {
      c.dispose();
    }
    for (var c in departureTimeControllers.values) {
      c.dispose();
    }
    for (var c in arrivalTimeControllers.values) {
      c.dispose();
    }
    for (var c in fareAmountControllers.values) {
      c.dispose();
    }
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

    final seatBonus = {'JAL': {'普通席': 0.0, 'クラスJ': 0.10, 'ファースト': 0.50}, 'ANA': {'普通席': 0.0, 'プレミアムクラス': 0.50}};
    try {
      final routeData = await Supabase.instance.client.from('routes').select('distance_miles')
          .eq('departure_code', dep).eq('arrival_code', arr).maybeSingle();
      if (routeData == null) return;
      final distance = routeData['distance_miles'] as int;

      final fareData = await Supabase.instance.client.from('fare_types').select('rate')
          .eq('airline_code', airline).eq('fare_type_name', fare).maybeSingle();
      if (fareData == null) return;

      final fareRate = (fareData['rate'] as num).toDouble();
      final baseFOP = (distance * fareRate).round();
      final bonus = seatBonus[airline]?[seat] ?? 0.0;
      final totalFOP = baseFOP + 400 + (baseFOP * bonus).round();
      final totalMiles = (distance * fareRate).round() + ((distance * fareRate) * bonus).round();
      setState(() { legs[index]['calculatedFOP'] = totalFOP; legs[index]['calculatedMiles'] = totalMiles; });
    } catch (e) {}
  }

  Future<void> _calculateFOP() async {
    setState(() { isLoading = true; errorMessage = null; });
    for (int i = 0; i < legs.length; i++) {
      await _calculateSingleLeg(i);
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
    return isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // サマリー（履歴ページと同じフォーマット）
        if (hasJAL || hasANA)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (hasJAL)
                  _buildAirlineSummaryRow('JAL', Colors.red, 'FOP', jalFOP, jalMiles, jalCount, jalFare, jalUnitPrice),
                if (hasJAL && hasANA)
                  const Divider(height: 16),
                if (hasANA)
                  _buildAirlineSummaryRow('ANA', Colors.blue, 'PP', anaPP, anaMiles, anaCount, anaFare, anaUnitPrice),
                if ((hasJAL && hasANA) && totalFare > 0)
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSummaryItem('総額', '¥${_formatNumber(totalFare)}', Colors.green[700]!),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        
        ...legs.asMap().entries.map((e) => _buildLegCard(context, e.value, e.key)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (errorMessage != null) 
            Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14))),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all, size: 20),
            label: const Text('クリア'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addLeg, 
            icon: const Icon(Icons.add), 
            label: const Text('レグ追加'), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _calculateFOP, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)), 
            child: const Text('計算', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 16),
      ]),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('レグ ${index + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (legs.length > 1) IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeLeg(index)),
          ]),
          const SizedBox(height: 16),
          
          Wrap(spacing: 12, runSpacing: 12, children: [
            _buildDropdown('航空会社', 100, airline, airlines, (v) { 
              setState(() { legs[index]['airline'] = v!; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); 
              _clearFlightInfo(index, legId);
            }),
            _buildTextField('日付', 100, dateControllers[legId]!, 'MM/DD'),
            _buildTextField('便名', 100, flightNumberControllers[legId]!, '', 
              onChanged: (v) async { 
                if (v.isEmpty) { 
                  _clearFlightInfo(index, legId);
                  return; 
                } 
                if (v.length >= 3) await _autoFillFromFlightNumber(index); 
              }, 
              onSubmit: (_) => _autoFillFromFlightNumber(index)
            ),
          ]),
          const SizedBox(height: 12),
          
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _buildDepartureDropdown(leg, legId, index),
            const Padding(padding: EdgeInsets.only(top: 20), child: Icon(Icons.flight_takeoff)),
            _buildDestinationDropdown(leg, legId, index),
            _buildFlightTimeDropdown(leg, legId, index),
            const Padding(padding: EdgeInsets.only(top: 20), child: Icon(Icons.arrow_forward)),
            _buildArrivalTimeField(legId, index),
            _buildDropdown('運賃種別', 160, fareTypes.contains(leg['fareType']) ? leg['fareType'] : null, fareTypes, (v) { 
              setState(() => legs[index]['fareType'] = v ?? ''); 
              _calculateSingleLeg(index); 
            }),
            _buildDropdown('座席クラス', 160, seatClasses.contains(leg['seatClass']) ? leg['seatClass'] : null, seatClasses, (v) { 
              setState(() => legs[index]['seatClass'] = v ?? ''); 
              _calculateSingleLeg(index); 
            }),
            _buildFareAmountField(legId),
          ]),
          const SizedBox(height: 12),
          
          if (leg['calculatedFOP'] != null) 
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(
                color: airline == 'JAL' ? Colors.red[50] : Colors.blue[50], 
                borderRadius: BorderRadius.circular(8),
              ), 
              child: Row(
                children: [
                  Text(
                    '${airline == 'JAL' ? 'FOP' : 'PP'}: ${leg['calculatedFOP']}', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: airline == 'JAL' ? Colors.red[800] : Colors.blue[800]),
                  ),
                  const SizedBox(width: 16),
                  Text('マイル: ${leg['calculatedMiles']}', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 16),
                  if (unitPrice != 'N/A')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '単価: $unitPrice/${airline == 'JAL' ? 'FOP' : 'PP'}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
                      ),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildFareAmountField(int legId) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('運賃(円)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextFormField(
            controller: fareAmountControllers[legId],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '例: 15000',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartureDropdown(Map<String, dynamic> leg, int legId, int index) {
    final currentValue = (leg['departureAirport'] as String).isEmpty ? null : leg['departureAirport'] as String;
    final airline = leg['airline'] as String;
    final displayItems = ['', ...airports];
    
    return SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        key: ValueKey('departure_${legId}_$airline'),
        initialValue: currentValue,
        items: displayItems.map((e) => DropdownMenuItem(
          value: e.isEmpty ? null : e,
          child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)),
        )).toList(),
        selectedItemBuilder: (context) {
          return displayItems.map((e) => Text(e, style: const TextStyle(fontSize: 12))).toList();
        },
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
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
    ]));
  }

  Widget _buildDestinationDropdown(Map<String, dynamic> leg, int legId, int index) {
    final arrivalAirport = leg['arrivalAirport'] as String;
    final destinations = availableDestinations[legId] ?? [];
    final airline = leg['airline'] as String;
    final currentValue = arrivalAirport.isEmpty || !destinations.contains(arrivalAirport) ? null : arrivalAirport;
    final displayItems = ['', ...destinations];
    
    return SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着地', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        key: ValueKey('destination_${legId}_$airline'),
        initialValue: currentValue,
        items: displayItems.map((e) => DropdownMenuItem(
          value: e.isEmpty ? null : e,
          child: Text(e.isEmpty ? '－' : '$e ${airportNames[e] ?? ''}', style: const TextStyle(fontSize: 12)),
        )).toList(),
        selectedItemBuilder: (context) {
          return displayItems.map((e) => Text(e, style: const TextStyle(fontSize: 12))).toList();
        },
        decoration: InputDecoration(
          isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          hintText: arrivalAirport.isNotEmpty && currentValue == null ? arrivalAirport : null,
        ),
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
    ]));
  }

  Widget _buildFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final flights = availableFlights[legId] ?? [];
    final airline = leg['airline'] as String;

    return SizedBox(width: 160, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('出発時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        key: ValueKey('flight_time_${legId}_$airline'),
        initialValue: null,
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
        selectedItemBuilder: (context) {
          return [
            const Text('', style: TextStyle(fontSize: 12)),
            ...flights.map((flight) {
              String depTime = flight['departure_time'] ?? '';
              if (depTime.length > 5) depTime = depTime.substring(0, 5);
              return Text(depTime, style: const TextStyle(fontSize: 12));
            }),
          ];
        },
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        hint: Text(departureTimeControllers[legId]?.text.isEmpty ?? true ? '選択' : departureTimeControllers[legId]!.text, style: const TextStyle(fontSize: 12)),
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
    ]));
  }

  Widget _buildArrivalTimeField(int legId, int index) {
    return SizedBox(width: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('到着時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      TextFormField(
        controller: arrivalTimeControllers[legId], 
        decoration: const InputDecoration(hintText: 'HH:MM', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        onChanged: (v) { if (v.isEmpty) _clearFlightInfo(index, legId); },
      ),
    ]));
  }

  Widget _buildTextField(String label, double width, TextEditingController controller, String hint, {void Function(String)? onChanged, void Function(String)? onSubmit}) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      TextFormField(controller: controller, decoration: InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)), onChanged: onChanged, onFieldSubmitted: onSubmit),
    ]));
  }

  Widget _buildDropdown(String label, double width, String? value, List<String> items, void Function(String?) onChanged) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        initialValue: value, 
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)), 
        onChanged: onChanged,
      ),
    ]));
  }
}
