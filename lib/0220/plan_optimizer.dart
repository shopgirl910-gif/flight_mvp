import 'package:supabase_flutter/supabase_flutter.dart';

// === ãƒ‡ãƒ¼ã‚¿ã‚¯ãƒ©ã‚¹ ===

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

// === å†…éƒ¨ç”¨ãƒ•ãƒ©ã‚¤ãƒˆã‚¯ãƒ©ã‚¹ ===

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

// === ãƒ¡ã‚¤ãƒ³ã‚¯ãƒ©ã‚¹ ===

class PlanOptimizer {
  static const int _minConnection = 30; // æœ€ä½Žä¹—ã‚Šç¶™ãŽæ™‚é–“(åˆ†)

  final Map<String, int> _distances = {};
  List<_Flight> _flights = [];

  /// ãƒ‡ãƒ¼ã‚¿èª­ã¿è¾¼ã¿
  Future<void> loadData(String airline, String date, {bool includeCodeshare = false}) async {
    final targetDate = date.replaceAll('/', '-');

    // è·¯ç·šè·é›¢
    final routes = await Supabase.instance.client
        .from('routes')
        .select('departure_code, arrival_code, distance_miles');
    _distances.clear();
    for (var r in routes) {
      _distances['${r['departure_code']}_${r['arrival_code']}'] =
          r['distance_miles'] as int;
    }

    // æ™‚åˆ»è¡¨ (ãƒšãƒ¼ã‚¸ãƒãƒ¼ã‚·ãƒ§ãƒ³å¯¾å¿œ)
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

    // é‡è¤‡é™¤åŽ»
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

  /// æœ€é©ãƒ—ãƒ©ãƒ³ã‚’æŽ¢ç´¢

  // ルート重複排除ヘルパー（空港経路が同じなら同一ルートとみなす）
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

  List<OptimalPlan> findOptimalPlans(String homeAirport, {double fareRate = 0.75, int bonusFop = 400}) {
    final allPlans = <List<_Flight>>[];

    // ãƒ‘ã‚¿ãƒ¼ãƒ³A: å˜ç´”å¾€å¾© HOMEâ†’HUBâ†’HOME (Ã—1, Ã—2)
    _findSimpleRoundTrips(homeAirport, allPlans);

    // ãƒ‘ã‚¿ãƒ¼ãƒ³B: ãƒãƒ–+ã‚·ãƒ£ãƒˆãƒ« HOMEâ†’HUBâ†’(SHUTTLEâ‡„HUB)Ã—Nâ†’HOME
    _findHubShuttlePlans(homeAirport, allPlans);

    // ãƒ‘ã‚¿ãƒ¼ãƒ³C: ä¸‰è§’ãƒ«ãƒ¼ãƒˆ HOMEâ†’Aâ†’Bâ†’HOME
    _findTrianglePlans(homeAirport, allPlans);

    if (allPlans.isEmpty) return [];

    // OptimizedFlightã«å¤‰æ›ã—ã¦FOPè¨ˆç®—
    final scored = allPlans.map((plan) {
      final optimized = plan.map((f) => _toOptimized(f, fareRate, bonusFop)).toList();
      final fop = optimized.fold(0, (sum, f) => sum + f.fop);
      return _ScoredPlan(flights: optimized, totalFop: fop);
    }).toList();

    final results = <OptimalPlan>[];

    // FOP最多（重複ルート排除・FOP降順）
    scored.sort((a, b) => b.totalFop.compareTo(a.totalFop));
    final uniqueFopPlans = _dedup(scored)
      ..sort((a, b) => b.totalFop.compareTo(a.totalFop));
    final fopRanking = uniqueFopPlans.take(3).toList().asMap().entries.map((e) {
      final medals = ['🥇', '🥈', '🥉'];
      return OptimalPlan(flights: e.value.flights, label: '${medals[e.key]} ${e.key + 1}位', scoredFop: e.value.totalFop);
    }).toList();

    results.add(OptimalPlan(
      flights: scored.first.flights,
      label: '🏆 FOP最多',
      children: fopRanking,
      scoredFop: scored.first.totalFop,
    ));
    final fopBestRoute = scored.first.flights.map((f) => f.departureCode).join() +
        scored.first.flights.last.arrivalCode;

    // レグ最多（重複ルート排除）
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


    return results;
  }

  // === ãƒ‘ã‚¿ãƒ¼ãƒ³A: å˜ç´”å¾€å¾© ===
  void _findSimpleRoundTrips(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var out1 in outbounds) {
      final returns1 = _getFlightsFrom(
              out1.arrCode, out1.arrMinutes + _minConnection)
          .where((f) => f.arrCode == home)
          .toList();

      for (var ret1 in returns1) {
        results.add([out1, ret1]);

        // ãƒ€ãƒ–ãƒ«å¾€å¾©: HOMEâ†’HUBâ†’HOMEâ†’HUBâ†’HOME
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

  // === ãƒ‘ã‚¿ãƒ¼ãƒ³B: ãƒãƒ–+ã‚·ãƒ£ãƒˆãƒ« ===
  void _findHubShuttlePlans(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var toHub in outbounds) {
      final hub = toHub.arrCode;

      // ãƒãƒ–ã‹ã‚‰ã®ã‚·ãƒ£ãƒˆãƒ«å…ˆï¼ˆå‡ºç™ºç©ºæ¸¯ä»¥å¤–ï¼‰
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
    if (depth >= 3) return; // ã‚·ãƒ£ãƒˆãƒ«æœ€å¤§3å¾€å¾©

    final lastArr = currentShuttles.isEmpty
        ? toHub.arrMinutes
        : currentShuttles.last.arrMinutes;

    // HUBâ†’SHUTTLE
    final toShuttles =
        _getFlightsFrom(hub, lastArr + _minConnection)
            .where((f) => f.arrCode == shuttle)
            .toList();

    for (var toS in toShuttles) {
      // SHUTTLEâ†’HUB
      final backToHubs =
          _getFlightsFrom(shuttle, toS.arrMinutes + _minConnection)
              .where((f) => f.arrCode == hub)
              .toList();

      for (var backH in backToHubs) {
        final newShuttles = [...currentShuttles, toS, backH];

        // HUBâ†’HOME å¸°é‚„ä¾¿
        final returns =
            _getFlightsFrom(hub, backH.arrMinutes + _minConnection)
                .where((f) => f.arrCode == home)
                .toList();

        for (var ret in returns) {
          results.add([toHub, ...newShuttles, ret]);
        }

        // ã•ã‚‰ã«ã‚·ãƒ£ãƒˆãƒ«å¾€å¾©ã‚’è¿½åŠ 
        _buildShuttlePlan(
            home, hub, shuttle, toHub, newShuttles, results, depth + 1);
      }
    }
  }

  // === ãƒ‘ã‚¿ãƒ¼ãƒ³C: ä¸‰è§’ãƒ«ãƒ¼ãƒˆ ===
  void _findTrianglePlans(String home, List<List<_Flight>> results) {
    final outbounds = _getFlightsFrom(home, 0);

    for (var leg1 in outbounds) {
      final mid = leg1.arrCode;
      final leg2s =
          _getFlightsFrom(mid, leg1.arrMinutes + _minConnection)
              .where((f) => f.arrCode != home && f.arrCode != mid)
              .toList();

      for (var leg2 in leg2s) {
        // ç›´æŽ¥å¸°é‚„
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
