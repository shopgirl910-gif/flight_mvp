import 'package:supabase_flutter/supabase_flutter.dart';

// === データクラス ===

class OptimizedFlight {
  final String flightNumber;
  final String departureCode;
  final String arrivalCode;
  final String departureTime;
  final String arrivalTime;
  final int distanceMiles;

  OptimizedFlight({
    required this.flightNumber,
    required this.departureCode,
    required this.arrivalCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.distanceMiles,
  });

  int get depMinutes => _toMinutes(departureTime);
  int get arrMinutes => _toMinutes(arrivalTime);

  // デフォルト: 特割A(75%) 普通席 でFOP計算
  int get fop => ((distanceMiles * 0.75) * 2 + 400).toInt();

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

  final Map<String, int> _distances = {};
  List<_Flight> _flights = [];

  /// データ読み込み
  Future<void> loadData(String airline, String date) async {
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

    // 時刻表
    final response = await Supabase.instance.client
        .from('schedules')
        .select()
        .eq('airline_code', airline)
        .eq('is_active', true)
        .order('departure_time');

    final schedules = (response as List).cast<Map<String, dynamic>>();

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

  OptimizedFlight _toOptimized(_Flight f) {
    return OptimizedFlight(
      flightNumber: f.flightNumber,
      departureCode: f.depCode,
      arrivalCode: f.arrCode,
      departureTime: f.depTime,
      arrivalTime: f.arrTime,
      distanceMiles: _dist(f.depCode, f.arrCode),
    );
  }

  /// 最適プランを探索
  List<OptimalPlan> findOptimalPlans(String homeAirport) {
    final allPlans = <List<_Flight>>[];

    // パターンA: 単純往復 HOME→HUB→HOME (×1, ×2)
    _findSimpleRoundTrips(homeAirport, allPlans);

    // パターンB: ハブ+シャトル HOME→HUB→(SHUTTLE⇄HUB)×N→HOME
    _findHubShuttlePlans(homeAirport, allPlans);

    // パターンC: 三角ルート HOME→A→B→HOME
    _findTrianglePlans(homeAirport, allPlans);

    if (allPlans.isEmpty) return [];

    // OptimizedFlightに変換してFOP計算
    final scored = allPlans.map((plan) {
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

    // レグ最多（FOP最多と異なる場合）
    scored.sort((a, b) {
      final legDiff = b.flights.length.compareTo(a.flights.length);
      if (legDiff != 0) return legDiff;
      return b.totalFop.compareTo(a.totalFop);
    });
    final legBestRoute = scored.first.flights.map((f) => f.departureCode).join() +
        scored.first.flights.last.arrivalCode;
    if (legBestRoute != fopBestRoute) {
      results.add(OptimalPlan(
        flights: scored.first.flights,
        label: '✈️ レグ最多',
      ));
    }

    // FOP効率最良（FOP÷レグ数が最大）
    scored.sort((a, b) {
      final effA = a.totalFop / a.flights.length;
      final effB = b.totalFop / b.flights.length;
      return effB.compareTo(effA);
    });
    final effBestRoute = scored.first.flights.map((f) => f.departureCode).join() +
        scored.first.flights.last.arrivalCode;
    if (effBestRoute != fopBestRoute && effBestRoute != legBestRoute) {
      results.add(OptimalPlan(
        flights: scored.first.flights,
        label: '💎 FOP効率最良',
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

      // ハブからのシャトル先（出発空港以外）
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
}

class _ScoredPlan {
  final List<OptimizedFlight> flights;
  final int totalFop;
  _ScoredPlan({required this.flights, required this.totalFop});
}
