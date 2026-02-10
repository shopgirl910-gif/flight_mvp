import 'package:supabase_flutter/supabase_flutter.dart';

// === データクラス ===

class OptimizedFlight {
  final String flightNumber;
  final String departureCode;
  final String arrivalCode;
  final String departureTime;
  final String arrivalTime;
  final int distanceMiles;
  final double fareRate;
  final int bonusFop;

  OptimizedFlight({
    required this.flightNumber,
    required this.departureCode,
    required this.arrivalCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.distanceMiles,
    this.fareRate = 0.75,
    this.bonusFop = 400,
  });

  int get depMinutes => _toMinutes(departureTime);
  int get arrMinutes => _toMinutes(arrivalTime);

  int get fop => ((distanceMiles * fareRate) * 2 + bonusFop).toInt();

  static int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + (parts.length > 1 ? int.parse(parts[1]) : 0);
  }
}

class OptimalPlan {
  final List<OptimizedFlight> flights;
  final String label;

  OptimalPlan({required this.flights, required this.label});

  int get totalFop => flights.fold(0, (sum, f) => sum + f.fop);
  int get legCount => flights.length;
  String get route =>
      flights.map((f) => f.departureCode).join('→') +
      '→${flights.last.arrivalCode}';
  String get departureTime => flights.first.departureTime;
  String get arrivalTime => flights.last.arrivalTime;

  String get duration {
    final dep = flights.first.depMinutes;
    final arr = flights.last.arrMinutes;
    final diff = arr - dep;
    return '${diff ~/ 60}時間${diff % 60}分';
  }
}

// === 内部用フライトクラス ===

class _Flight {
  final String flightNumber;
  final String depCode;
  final String arrCode;
  final String depTime;
  final String arrTime;

  _Flight({
    required this.flightNumber,
    required this.depCode,
    required this.arrCode,
    required this.depTime,
    required this.arrTime,
  });

  int get depMinutes => _toMinutes(depTime);
  int get arrMinutes => _toMinutes(arrTime);

  static int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + (parts.length > 1 ? int.parse(parts[1]) : 0);
  }
}

// === メインクラス ===

class PlanOptimizer {
  static const int _minConnection = 30; // 最低乗り継ぎ時間(分)

  // 航空会社グループ定義
  static const Map<String, List<String>> airlineGroups = {
    'JAL': ['JAL', 'JTA', 'RAC'],
    'ANA': ['ANA'],
  };

  final Map<String, int> _distances = {};
  List<_Flight> _flights = [];

  /// データ読み込み（JAL選択時はJTA/RACも含む）
  /// 戻り値: null=該当日の時刻表あり, String=フォールバック時の注意文
  Future<String?> loadData(String airline, String date, {bool includeCodeshare = true}) async {
    final targetDate = date.replaceAll('/', '-');
    final codes = includeCodeshare
        ? (airlineGroups[airline] ?? [airline])
        : [airline];

    // 路線距離
    final routes = await Supabase.instance.client
        .from('routes')
        .select('departure_code, arrival_code, distance_miles')
        .limit(5000);
    _distances.clear();
    for (var r in routes) {
      _distances['${r['departure_code']}_${r['arrival_code']}'] =
          r['distance_miles'] as int;
    }

    // 時刻表（JAL系: JAL+JTA+RAC / ANA系: ANA）
    // Supabase max_rows=1000対策: ページネーションで全件取得
    List<dynamic> allSchedules = [];
    String? fallbackNotice;

    Future<List<dynamic>> _fetchAllPages(String code, String date) async {
      List<dynamic> all = [];
      int offset = 0;
      const pageSize = 999;
      while (true) {
        final res = await Supabase.instance.client
            .from('schedules')
            .select()
            .eq('airline_code', code)
            .eq('is_active', true)
            .lte('period_start', date)
            .gte('period_end', date)
            .order('departure_time')
            .range(offset, offset + pageSize);
        final list = res as List;
        all.addAll(list);
        if (list.length <= pageSize) break;
        offset += pageSize + 1;
      }
      return all;
    }

    for (var code in codes) {
      allSchedules.addAll(await _fetchAllPages(code, targetDate));
    }

    // 該当日のデータがない場合、最新の時刻表にフォールバック
    if (allSchedules.isEmpty) {
      final latestRow = await Supabase.instance.client
          .from('schedules')
          .select('period_end')
          .inFilter('airline_code', codes)
          .eq('is_active', true)
          .order('period_end', ascending: false)
          .limit(1);
      if ((latestRow as List).isNotEmpty) {
        final latestEnd = latestRow.first['period_end'] as String;
        for (var code in codes) {
          allSchedules.addAll(await _fetchAllPages(code, latestEnd));
        }
        fallbackNotice = '※ 時刻表が変更されている可能性があります。実際のダイヤは公式サイトでご確認ください。';
      }
    }

    final schedules = allSchedules.cast<Map<String, dynamic>>();

    _flights = schedules
        .map((s) {
          String dep = s['departure_time'] ?? '';
          String arr = s['arrival_time'] ?? '';
          if (dep.length > 5) dep = dep.substring(0, 5);
          if (arr.length > 5) arr = arr.substring(0, 5);
          return _Flight(
            flightNumber: s['flight_number'] ?? '',
            depCode: s['departure_code'] as String,
            arrCode: s['arrival_code'] as String,
            depTime: dep,
            arrTime: arr,
          );
        })
        .toList();

    // 重複除去
    final seen = <String>{};
    _flights = _flights.where((f) {
      final key = '${f.depCode}_${f.arrCode}_${f.depTime}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    // 出発時刻順にソート（Supabaseの文字列ソートに依存しない）
    _flights.sort((a, b) => a.depMinutes.compareTo(b.depMinutes));

    // デバッグ: 読み込みデータ確認
    final hndCts = _flights.where((f) => f.depCode == 'HND' && f.arrCode == 'CTS').length;
    final ctsHnd = _flights.where((f) => f.depCode == 'CTS' && f.arrCode == 'HND').length;
    print('[Optimizer] total flights: ${_flights.length}, schedules raw: ${schedules.length}, CTS→HND: $ctsHnd, HND→CTS: $hndCts');

    return fallbackNotice;
  }

  List<_Flight> _getFlightsFrom(String airport, int afterMinutes) {
    final list = _flights
        .where((f) => f.depCode == airport && f.depMinutes >= afterMinutes)
        .toList();
    list.sort((a, b) => a.depMinutes.compareTo(b.depMinutes));
    return list;
  }

  int _dist(String dep, String arr) =>
      _distances['${dep}_${arr}'] ?? 0;

  double _fareRate = 0.75;
  int _bonusFop = 400;

  OptimizedFlight _toOptimized(_Flight f) {
    return OptimizedFlight(
      flightNumber: f.flightNumber,
      departureCode: f.depCode,
      arrivalCode: f.arrCode,
      departureTime: f.depTime,
      arrivalTime: f.arrTime,
      distanceMiles: _dist(f.depCode, f.arrCode),
      fareRate: _fareRate,
      bonusFop: _bonusFop,
    );
  }

  /// 最適プランを探索
  List<OptimalPlan> findOptimalPlans(String homeAirport, {double fareRate = 0.75, int bonusFop = 400, int depMinStart = 0, int depMinEnd = 1439, int arrMinStart = 0, int arrMinEnd = 1439}) {
    _fareRate = fareRate;
    _bonusFop = bonusFop;
    final allPlans = <List<_Flight>>[];

    // パターンA: 単純往復 HOME→HUB→HOME (×1〜×6)
    _findSimpleRoundTrips(homeAirport, allPlans);

    // パターンB: ハブ+シャトル HOME→HUB→(SHUTTLE⇄HUB)×N→HOME
    _findHubShuttlePlans(homeAirport, allPlans);

    // パターンC: 三角ルート HOME→A→B→HOME
    _findTrianglePlans(homeAirport, allPlans);

    if (allPlans.isEmpty) return [];

    // 時刻フィルター（出発: 最初のレグ、到着: 最後のレグ）
    final filtered = allPlans.where((plan) {
      final firstDep = plan.first.depMinutes;
      final lastArr = plan.last.arrMinutes;
      return firstDep >= depMinStart && firstDep <= depMinEnd &&
             lastArr >= arrMinStart && lastArr <= arrMinEnd;
    }).toList();

    if (filtered.isEmpty) return [];

    // OptimizedFlightに変換してFOP計算
    final scored = filtered.map((plan) {
      final optimized = plan.map(_toOptimized).toList();
      final fop = optimized.fold(0, (sum, f) => sum + f.fop);
      return _ScoredPlan(flights: optimized, totalFop: fop);
    }).toList();

    final results = <OptimalPlan>[];

    // FOP最多
    scored.sort((a, b) => b.totalFop.compareTo(a.totalFop));
    results.add(OptimalPlan(
      flights: scored.first.flights,
      label: '🏆 FOP最多',
    ));
    final fopBestRoute = scored.first.flights.map((f) => f.departureCode).join() +
        scored.first.flights.last.arrivalCode;

    // レグ最多（同数レグの全候補をFOP順で表示、ルート重複除去、最大5件）
    scored.sort((a, b) {
      final legDiff = b.flights.length.compareTo(a.flights.length);
      if (legDiff != 0) return legDiff;
      return b.totalFop.compareTo(a.totalFop);
    });
    final maxLegs = scored.first.flights.length;
    final seenLegRoutes = <String>{};
    int legPlanCount = 0;
    String? legBestRoute;
    for (var plan in scored) {
      if (plan.flights.length < maxLegs) break;
      final route = plan.flights.map((f) => f.departureCode).join('→') + '→' + plan.flights.last.arrivalCode;
      if (seenLegRoutes.contains(route)) continue;
      seenLegRoutes.add(route);
      if (route == fopBestRoute) continue; // FOP最多と同じルートはスキップ
      if (legBestRoute == null) legBestRoute = route;
      legPlanCount++;
      results.add(OptimalPlan(
        flights: plan.flights,
        label: legPlanCount == 1 ? '✈️ レグ最多' : '✈️ レグ最多 #$legPlanCount',
      ));
      if (legPlanCount >= 5) break;
    }

    // 1レグFOP最大（FOP÷レグ数が最大、重複しない場合のみ）
    scored.sort((a, b) {
      final effA = a.totalFop / a.flights.length;
      final effB = b.totalFop / b.flights.length;
      return effB.compareTo(effA);
    });
    final effBestRoute = scored.first.flights.map((f) => f.departureCode).join() +
        scored.first.flights.last.arrivalCode;
    if (effBestRoute != fopBestRoute && !seenLegRoutes.contains(effBestRoute)) {
      results.add(OptimalPlan(
        flights: scored.first.flights,
        label: '💎 1レグFOP最大',
      ));
    }

    return results;
  }

  // === パターンA: 単純往復（貪欲法で最大深度探索） ===
  static const int _maxRoundTrips = 6;

  void _findSimpleRoundTrips(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);
    // 行先ごとにグルーピング
    final destMap = <String, List<_Flight>>{};
    for (var f in outbounds) {
      destMap.putIfAbsent(f.arrCode, () => []).add(f);
    }
    print('[Optimizer] SimpleRT: home=$home, outbound dests=${destMap.keys.toList()}, counts=${destMap.map((k,v) => MapEntry(k, v.length))}');

    for (var dest in destMap.keys) {
      final firstOuts = destMap[dest]!;
      int maxLegs = 0;
      for (var out1 in firstOuts.take(10)) {
        final before = results.length;
        _greedyMaxRoundTrips(home, dest, out1, results);
        for (int i = before; i < results.length; i++) {
          if (results[i].length > maxLegs) maxLegs = results[i].length;
        }
      }
      if (dest == 'HND' || dest == 'MMB' || maxLegs >= 6) {
        print('[Optimizer] SimpleRT $home⇄$dest: maxLegs=$maxLegs');
      }
    }
  }

  /// DFS: 全組み合わせを探索して最大レグ数プランを見つける
  void _greedyMaxRoundTrips(
    String home, String dest, _Flight firstOut, List<List<_Flight>> results,
  ) {
    List<List<_Flight>> allCompletePlans = [];

    void dfs(List<_Flight> plan, _Flight lastFlight, int trips) {
      // 帰り便を探す
      final returns = _getFlightsFrom(
        lastFlight.arrCode, lastFlight.arrMinutes + _minConnection)
          .where((f) => f.arrCode == home)
          .toList();

      if (dest == 'HND' || dest == 'MMB') {
        print('[DFS] depth=$trips, planLegs=${plan.length}, looking return from ${lastFlight.arrCode} after ${lastFlight.arrMinutes + _minConnection}min, found ${returns.length} returns');
      }

      for (var ret in returns.take(3)) {
        final currentPlan = List<_Flight>.from([...plan, ret]);
        allCompletePlans.add(currentPlan);

        if (dest == 'HND' || dest == 'MMB') {
          print('[DFS] depth=$trips, completePlan=${currentPlan.length}legs, lastArr=${ret.arrMinutes}');
        }

        if (trips + 1 >= _maxRoundTrips) continue;

        // 次の出発便を探す
        final nextOuts = _getFlightsFrom(home, ret.arrMinutes + _minConnection)
            .where((f) => f.arrCode == dest)
            .toList();

        if (dest == 'HND' || dest == 'MMB') {
          print('[DFS] depth=$trips, looking next out from $home after ${ret.arrMinutes + _minConnection}min, found ${nextOuts.length} outs');
        }

        for (var nextOut in nextOuts.take(3)) {
          dfs(List<_Flight>.from([...currentPlan, nextOut]), nextOut, trips + 1);
        }
      }
    }

    dfs([firstOut], firstOut, 0);

    // 最大レグのプランを結果に追加
    if (allCompletePlans.isNotEmpty) {
      allCompletePlans.sort((a, b) => b.length.compareTo(a.length));
      results.add(allCompletePlans.first);
      if (dest == 'HND' || dest == 'MMB') {
        print('[DFS] BEST for $home⇄$dest start=${firstOut.flightNumber}: ${allCompletePlans.first.length}legs');
      }
    }
  }

  // === パターンB: ハブ+シャトル（貪欲法） ===
  void _findHubShuttlePlans(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var toHub in outbounds) {
      final hub = toHub.arrCode;

      final shuttleDests = _getFlightsFrom(hub, toHub.arrMinutes + _minConnection)
          .map((f) => f.arrCode)
          .where((code) => code != home)
          .toSet();

      for (var shuttle in shuttleDests) {
        _greedyShuttlePlan(home, hub, shuttle, toHub, results);
      }
    }
  }

  /// 貪欲法: ハブ→シャトル→ハブ を最早便で最大回数繰り返す
  void _greedyShuttlePlan(
    String home, String hub, String shuttle, _Flight toHub,
    List<List<_Flight>> results,
  ) {
    final shuttleLegs = <_Flight>[];
    var lastArrMinutes = toHub.arrMinutes;

    for (int i = 0; i < 5; i++) {
      // HUB → SHUTTLE
      final toS = _getFlightsFrom(hub, lastArrMinutes + _minConnection)
          .where((f) => f.arrCode == shuttle)
          .toList();
      if (toS.isEmpty) break;

      // SHUTTLE → HUB
      final backH = _getFlightsFrom(shuttle, toS.first.arrMinutes + _minConnection)
          .where((f) => f.arrCode == hub)
          .toList();
      if (backH.isEmpty) break;

      shuttleLegs.addAll([toS.first, backH.first]);
      lastArrMinutes = backH.first.arrMinutes;

      // HUB → HOME 帰還便を探して登録
      final returns = _getFlightsFrom(hub, lastArrMinutes + _minConnection)
          .where((f) => f.arrCode == home)
          .toList();
      if (returns.isNotEmpty) {
        results.add([toHub, ...shuttleLegs, returns.first]);
      }
    }
  }

  // === パターンC: 三角ルート ===
  void _findTrianglePlans(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var leg1 in outbounds) {
      final mid = leg1.arrCode;
      final leg2s =
          _getFlightsFrom(mid, leg1.arrMinutes + _minConnection)
              .where((f) => f.arrCode != home && f.arrCode != mid)
              .toList();

      for (var leg2 in leg2s.take(10)) {
        final returns =
            _getFlightsFrom(leg2.arrCode, leg2.arrMinutes + _minConnection)
                .where((f) => f.arrCode == home)
                .toList();

        if (returns.isNotEmpty) {
          results.add([leg1, leg2, returns.first]);
        }
      }
    }
  }
}

class _ScoredPlan {
  final List<OptimizedFlight> flights;
  final int totalFop;
  _ScoredPlan({required this.flights, required this.totalFop});
}
