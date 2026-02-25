import 'package:supabase_flutter/supabase_flutter.dart';

// === データクラス ===

class OptimizedFlight {
  final String flightNumber;
  final String departureCode;
  final String arrivalCode;
  final String departureTime;
  final String arrivalTime;
  final int distanceMiles;
  final int fop;

  OptimizedFlight({
    required this.flightNumber,
    required this.departureCode,
    required this.arrivalCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.distanceMiles,
    required this.fop,
  });

  int get depMinutes => _toMinutes(departureTime);
  int get arrMinutes => _toMinutes(arrivalTime);


  static int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + (parts.length > 1 ? int.parse(parts[1]) : 0);
  }
}

class OptimalPlan {
  final List<OptimizedFlight> flights;
  final String label;
  final List<OptimalPlan>? children;
  final int? _scoredFop;

  OptimalPlan({required this.flights, required this.label, this.children, int? scoredFop}) : _scoredFop = scoredFop;

  int get totalFop => _scoredFop ?? flights.fold(0, (sum, f) => sum + f.fop);
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

  final Map<String, int> _distances = {};
  List<_Flight> _flights = [];

  /// データ読み込み
  Future<void> loadData(String airline, String date, {bool includeCodeshare = false}) async {
    final targetDate = date.replaceAll('/', '-');

    // 路線距離
    final routes = await Supabase.instance.client
        .from('routes')
        .select('departure_code, arrival_code, distance_miles');
    _distances.clear();
    for (var r in routes) {
      _distances['${r['departure_code']}_${r['arrival_code']}'] =
          r['distance_miles'] as int;
    }

    // 時刻表 (ページネーション対応)
    final schedules = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final response = await Supabase.instance.client
          .from('schedules')
          .select()
          .eq('airline_code', airline)
          .eq('is_active', true)
          .order('departure_time')
          .range(from, from + pageSize - 1);
      final page = (response as List).cast<Map<String, dynamic>>();
      schedules.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }

    _flights = schedules
        .where((s) {
          final start = s['period_start'] as String? ?? '';
          final end = s['period_end'] as String? ?? '';
          return start.compareTo(targetDate) <= 0 &&
              end.compareTo(targetDate) >= 0;
        })
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
  }

  List<_Flight> _getFlightsFrom(String airport, int afterMinutes) {
    return _flights
        .where((f) => f.depCode == airport && f.depMinutes >= afterMinutes)
        .toList();
  }

  int _dist(String dep, String arr) =>
      _distances['${dep}_${arr}'] ?? 0;

  OptimizedFlight _toOptimized(_Flight f, double fareRate, int bonusFop) {
    final dist = _dist(f.depCode, f.arrCode);
    return OptimizedFlight(
      flightNumber: f.flightNumber,
      departureCode: f.depCode,
      arrivalCode: f.arrCode,
      departureTime: f.depTime,
      arrivalTime: f.arrTime,
      distanceMiles: dist,
      fop: ((dist * fareRate) * 2 + bonusFop).toInt(),
    );
  }

  /// 最適プランを探索

  // ルート重複排除ヘルパー(空港経路が同じなら同一ルートとみなす)
  String _routeKey(List<OptimizedFlight> flights) =>
      flights.map((f) => f.departureCode).join('_') + '_' + flights.last.arrivalCode;

  List<_ScoredPlan> _dedup(List<_ScoredPlan> plans) {
    final seen = <String>{};
    return plans.where((p) {
      final key = _routeKey(p.flights);
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  List<OptimalPlan> findOptimalPlans(String homeAirport, {double fareRate = 0.75, int bonusFop = 400, String airline = 'JAL'}) {
    final allPlans = <List<_Flight>>[];

    final pointLabel = airline == 'JAL' ? 'FOP' : 'PP';

    // パターンA: 単純往復 HOME→HUB→HOME (×1, ×2)
    _findSimpleRoundTrips(homeAirport, allPlans);

    // パターンB: ハブ+シャトル HOME→HUB→(SHUTTLE⇄HUB)×N→HOME
    _findHubShuttlePlans(homeAirport, allPlans);

    // パターンC: 三角ルート HOME→A→B→HOME
    _findTrianglePlans(homeAirport, allPlans);

    // パターンD: 周遊 HOME→A→B→C→...→HOME（同一空港着陸なし、同一路線なし）
    final tourPlans = <List<_Flight>>[];
    _findTourPlans(homeAirport, tourPlans);

    if (allPlans.isEmpty) return [];

    // OptimizedFlightに変換してFOP計算
    final scored = allPlans.map((plan) {
      final optimized = plan.map((f) => _toOptimized(f, fareRate, bonusFop)).toList();
      final fop = optimized.fold(0, (sum, f) => sum + f.fop);
      return _ScoredPlan(flights: optimized, totalFop: fop);
    }).toList();

    final results = <OptimalPlan>[];

    // $pointLabel最多(重複ルート排除・FOP降順)
    scored.sort((a, b) => b.totalFop.compareTo(a.totalFop));
    final uniqueFopPlans = _dedup(scored)
      ..sort((a, b) => b.totalFop.compareTo(a.totalFop));
    final fopRanking = uniqueFopPlans.take(3).toList().asMap().entries.map((e) {
      final medals = ['🥇', '🥈', '🥉'];
      return OptimalPlan(flights: e.value.flights, label: '${medals[e.key]} ${e.key + 1}位', scoredFop: e.value.totalFop);
    }).toList();

    results.add(OptimalPlan(
      flights: scored.first.flights,
      label: '🏆 $pointLabel最多',
      children: fopRanking,
      scoredFop: scored.first.totalFop,
    ));
    final fopBestRoute = scored.first.flights.map((f) => f.departureCode).join() +
        scored.first.flights.last.arrivalCode;

    // レグ最多(重複ルート排除)
    final maxLegs = scored.map((s) => s.flights.length).reduce((a, b) => a > b ? a : b);
    final maxLegPlans = scored.where((s) => s.flights.length == maxLegs).toList();
    final byFop = _dedup(List<_ScoredPlan>.from(maxLegPlans)..sort((a, b) => b.totalFop.compareTo(a.totalFop)));
    final uniqueCount = byFop.length;

    if (byFop.isNotEmpty) {
      final legRanking = byFop.take(3).toList().asMap().entries.map((e) {
        final medals = ['🥇', '🥈', '🥉'];
        return OptimalPlan(flights: e.value.flights, label: '${medals[e.key]} ${e.key + 1}位', scoredFop: e.value.totalFop);
      }).toList();

      results.add(OptimalPlan(
        flights: byFop.first.flights,
        label: '✈️ レグ最多 (${maxLegs}レグ・${uniqueCount}ルート)',
        children: legRanking,
        scoredFop: byFop.first.totalFop,
      ));
    }

    // 🌏 周遊プラン（同一空港着陸なし・同一路線なし）
    if (tourPlans.isNotEmpty) {
      final tourScored = tourPlans.map((plan) {
        final optimized = plan.map((f) => _toOptimized(f, fareRate, bonusFop)).toList();
        final fop = optimized.fold(0, (sum, f) => sum + f.fop);
        return _ScoredPlan(flights: optimized, totalFop: fop);
      }).toList();

      // レグ数降順、同レグ数ならFOP降順
      tourScored.sort((a, b) {
        final legCmp = b.flights.length.compareTo(a.flights.length);
        if (legCmp != 0) return legCmp;
        return b.totalFop.compareTo(a.totalFop);
      });

      final uniqueTour = _dedup(tourScored);
      final maxTourLegs = uniqueTour.first.flights.length;

      final tourRanking = uniqueTour.take(3).toList().asMap().entries.map((e) {
        final medals = ['🥇', '🥈', '🥉'];
        final legs = e.value.flights.length;
        return OptimalPlan(
          flights: e.value.flights,
          label: '${medals[e.key]} ${legs}レグ',
          scoredFop: e.value.totalFop,
        );
      }).toList();

      results.add(OptimalPlan(
        flights: uniqueTour.first.flights,
        label: '🌏 周遊プラン (最大${maxTourLegs}レグ)',
        children: tourRanking,
        scoredFop: uniqueTour.first.totalFop,
      ));
    }


    return results;
  }

  // === パターンA: 単純往復 ===
  void _findSimpleRoundTrips(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var out1 in outbounds) {
      final returns1 = _getFlightsFrom(
              out1.arrCode, out1.arrMinutes + _minConnection)
          .where((f) => f.arrCode == home)
          .toList();

      for (var ret1 in returns1) {
        results.add([out1, ret1]);

        // ダブル往復: HOME→HUB→HOME→HUB→HOME
        final out2s = _getFlightsFrom(home, ret1.arrMinutes + _minConnection)
            .where((f) => f.arrCode == out1.arrCode)
            .toList();

        for (var out2 in out2s) {
          final returns2 = _getFlightsFrom(
                  out2.arrCode, out2.arrMinutes + _minConnection)
              .where((f) => f.arrCode == home)
              .toList();

          for (var ret2 in returns2) {
            results.add([out1, ret1, out2, ret2]);
          }
        }
      }
    }
  }

  // === パターンB: ハブ+シャトル ===
  void _findHubShuttlePlans(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var toHub in outbounds) {
      final hub = toHub.arrCode;

      // ハブからのシャトル先(出発空港以外)
      final shuttleDests = _getFlightsFrom(hub, toHub.arrMinutes + _minConnection)
          .map((f) => f.arrCode)
          .where((code) => code != home)
          .toSet();

      for (var shuttle in shuttleDests) {
        _buildShuttlePlan(home, hub, shuttle, toHub, [], results, 0);
      }
    }
  }

  void _buildShuttlePlan(
    String home,
    String hub,
    String shuttle,
    _Flight toHub,
    List<_Flight> currentShuttles,
    List<List<_Flight>> results,
    int depth,
  ) {
    if (depth >= 3) return; // シャトル最大3往復

    final lastArr = currentShuttles.isEmpty
        ? toHub.arrMinutes
        : currentShuttles.last.arrMinutes;

    // HUB→SHUTTLE
    final toShuttles =
        _getFlightsFrom(hub, lastArr + _minConnection)
            .where((f) => f.arrCode == shuttle)
            .toList();

    for (var toS in toShuttles) {
      // SHUTTLE→HUB
      final backToHubs =
          _getFlightsFrom(shuttle, toS.arrMinutes + _minConnection)
              .where((f) => f.arrCode == hub)
              .toList();

      for (var backH in backToHubs) {
        final newShuttles = [...currentShuttles, toS, backH];

        // HUB→HOME 帰還便
        final returns =
            _getFlightsFrom(hub, backH.arrMinutes + _minConnection)
                .where((f) => f.arrCode == home)
                .toList();

        for (var ret in returns) {
          results.add([toHub, ...newShuttles, ret]);
        }

        // さらにシャトル往復を追加
        _buildShuttlePlan(
            home, hub, shuttle, toHub, newShuttles, results, depth + 1);
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

      for (var leg2 in leg2s) {
        // 直接帰還
        final returns =
            _getFlightsFrom(leg2.arrCode, leg2.arrMinutes + _minConnection)
                .where((f) => f.arrCode == home)
                .toList();

        for (var ret in returns) {
          results.add([leg1, leg2, ret]);
        }
      }
    }
  }
  // === パターンD: 周遊ルート ===
  // HOME→A→B→C→...→HOME
  // ・同じ空港に2回着陸NG（HOMEは出発/帰着のみ例外）
  // ・同一路線（双方向）は1回のみ
  void _findTourPlans(String home, List<List<_Flight>> results) {
    _tourDFS(
      home: home,
      current: home,
      currentTime: 0,
      path: [],
      visitedAirports: {home},
      usedRoutes: {},
      results: results,
    );
  }

  /// 路線キーを正規化（双方向で同一とみなす）
  String _routePairKey(String a, String b) {
    return a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';
  }

  void _tourDFS({
    required String home,
    required String current,
    required int currentTime,
    required List<_Flight> path,
    required Set<String> visitedAirports,
    required Set<String> usedRoutes,
    required List<List<_Flight>> results,
  }) {
    // 深さ制限（パフォーマンス保護）
    if (path.length >= 12) return;

    final available = _getFlightsFrom(current, currentTime + _minConnection);

    for (var f in available) {
      final routeKey = _routePairKey(f.depCode, f.arrCode);

      // 同一路線使用済みならスキップ
      if (usedRoutes.contains(routeKey)) continue;

      if (f.arrCode == home) {
        // 帰着: 3レグ以上で有効（2レグは三角ルートと重複）
        if (path.length >= 3) {
          results.add([...path, f]);
        }
      } else if (!visitedAirports.contains(f.arrCode)) {
        // 未訪問空港へ
        visitedAirports.add(f.arrCode);
        usedRoutes.add(routeKey);
        path.add(f);

        _tourDFS(
          home: home,
          current: f.arrCode,
          currentTime: f.arrMinutes,
          path: path,
          visitedAirports: visitedAirports,
          usedRoutes: usedRoutes,
          results: results,
        );

        path.removeLast();
        usedRoutes.remove(routeKey);
        visitedAirports.remove(f.arrCode);
      }
    }
  }
}

class _ScoredPlan {
  final List<OptimizedFlight> flights;
  final int totalFop;
  _ScoredPlan({required this.flights, required this.totalFop});
}
