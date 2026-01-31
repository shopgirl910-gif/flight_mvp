import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'auth_screen.dart';
import 'l10n/app_localizations.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  bool isLoading = true;
  String? errorMessage;
  Position? currentPosition;
  Map<String, dynamic>? nearestAirport;
  double? distanceToNearest;
  
  // 都道府県別空港データ
  Map<String, List<Map<String, dynamic>>> airportsByPrefecture = {};
  // ユーザーのチェックイン済み空港
  Set<String> checkedAirports = {};
  // 展開中の都道府県
  Set<String> expandedPrefectures = {};
  
  // 地方キー（多言語対応用）
  static const List<String> regionKeys = [
    'hokkaido', 'tohoku', 'kanto', 'chubu', 'kansai', 'chugoku', 'shikoku', 'kyushu', 'okinawa',
  ];
  
  // 地方→都道府県のマッピング
  static const Map<String, List<String>> regionPrefectures = {
    'hokkaido': ['北海道'],
    'tohoku': ['青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'],
    'kanto': ['東京都', '千葉県'],
    'chubu': ['新潟県', '長野県', '静岡県', '愛知県', '石川県', '富山県'],
    'kansai': ['大阪府', '兵庫県', '和歌山県'],
    'chugoku': ['鳥取県', '島根県', '岡山県', '広島県', '山口県'],
    'shikoku': ['香川県', '愛媛県', '高知県', '徳島県'],
    'kyushu': ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県'],
    'okinawa': ['沖縄県'],
  };
  
  // 展開中の地方
  Set<String> expandedRegions = {};

  // バッジ定義（5階級）
  static const List<Map<String, dynamic>> badgeTiers = [
    {'name': 'Bronze', 'nameJa': 'ブロンズ', 'icon': '🥉', 'required': 5, 'color': 0xFFCD7F32},
    {'name': 'Silver', 'nameJa': 'シルバー', 'icon': '🥈', 'required': 15, 'color': 0xFFC0C0C0},
    {'name': 'Gold', 'nameJa': 'ゴールド', 'icon': '🥇', 'required': 30, 'color': 0xFFFFD700},
    {'name': 'Platinum', 'nameJa': 'プラチナ', 'icon': '💎', 'required': 50, 'color': 0xFFE5E4E2},
    {'name': 'Diamond', 'nameJa': 'ダイヤモンド', 'icon': '👑', 'required': 70, 'color': 0xFFB9F2FF},
  ];

  // 現在のバッジを取得
  Map<String, dynamic>? _getCurrentBadge(int checkedCount) {
    Map<String, dynamic>? current;
    for (var badge in badgeTiers) {
      if (checkedCount >= badge['required']) {
        current = badge;
      } else {
        break;
      }
    }
    return current;
  }

  // 次のバッジを取得
  Map<String, dynamic>? _getNextBadge(int checkedCount) {
    for (var badge in badgeTiers) {
      if (checkedCount < badge['required']) {
        return badge;
      }
    }
    return null; // 全バッジ達成
  }

  // 地方名を取得（多言語対応）
  String _getRegionName(String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'hokkaido': return l10n.regionHokkaido;
      case 'tohoku': return l10n.regionTohoku;
      case 'kanto': return l10n.regionKanto;
      case 'chubu': return l10n.regionChubu;
      case 'kansai': return l10n.regionKansai;
      case 'chugoku': return l10n.regionChugoku;
      case 'shikoku': return l10n.regionShikoku;
      case 'kyushu': return l10n.regionKyushu;
      case 'okinawa': return l10n.regionOkinawa;
      default: return key;
    }
  }

  // チェックイン可能距離（メートル）
  double _getCheckinRadius(String airportCode) {
    // 大空港は3km、それ以外は1.5km
    const largeAirports = ['HND', 'KIX'];
    return largeAirports.contains(airportCode) ? 3000 : 1500;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    // ログイン状態の変化を監視
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn && mounted) {
        _loadCheckins().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadAirports(),
        _loadCheckins(),
      ]);
      await _getCurrentLocation();
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => errorMessage = '${l10n.dataLoadError}: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAirports() async {
    final response = await Supabase.instance.client
        .from('airports')
        .select('code, name_ja, name_en, prefecture, latitude, longitude')
        .eq('is_active', true)
        .not('prefecture', 'is', null);
    
    final airports = (response as List).cast<Map<String, dynamic>>();
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (var airport in airports) {
      final pref = airport['prefecture'] as String;
      grouped.putIfAbsent(pref, () => []);
      grouped[pref]!.add(airport);
    }
    
    // 各都道府県内を空港コード順にソート
    for (var pref in grouped.keys) {
      grouped[pref]!.sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
    }
    
    setState(() => airportsByPrefecture = grouped);
  }

  Future<void> _loadCheckins() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    final response = await Supabase.instance.client
        .from('airport_checkins')
        .select('airport_code')
        .eq('user_id', userId);
    
    final checkins = (response as List).cast<Map<String, dynamic>>();
    setState(() {
      checkedAirports = checkins.map((c) => c['airport_code'] as String).toSet();
    });
  }

  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // 位置情報の許可確認
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => errorMessage = l10n.locationPermissionRequired);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => errorMessage = l10n.enableLocationInSettings);
        return;
      }

      // 現在位置取得
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => currentPosition = position);
      
      // 最寄り空港を検索
      _findNearestAirport();
    } catch (e) {
      setState(() => errorMessage = '${l10n.locationError}: $e');
    }
  }

  void _findNearestAirport() {
    if (currentPosition == null) return;
    
    double minDistance = double.infinity;
    Map<String, dynamic>? nearest;
    
    for (var airports in airportsByPrefecture.values) {
      for (var airport in airports) {
        final lat = airport['latitude'] as double?;
        final lng = airport['longitude'] as double?;
        if (lat == null || lng == null) continue;
        
        final distance = _calculateDistance(
          currentPosition!.latitude,
          currentPosition!.longitude,
          lat,
          lng,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearest = airport;
        }
      }
    }
    
    setState(() {
      nearestAirport = nearest;
      distanceToNearest = minDistance;
    });
  }

  // Haversine formula で距離計算（メートル）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // メートル
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  bool get _isAnonymousUser {
    final user = Supabase.instance.client.auth.currentUser;
    return user == null || user.isAnonymous;
  }

  // 空港名を取得（多言語対応）
  String _getAirportName(Map<String, dynamic> airport) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    if (isJa) {
      return airport['name_ja'] as String? ?? airport['code'] as String;
    } else {
      return airport['name_en'] as String? ?? airport['name_ja'] as String? ?? airport['code'] as String;
    }
  }

  Future<void> _checkin() async {
    final l10n = AppLocalizations.of(context)!;
    if (nearestAirport == null || distanceToNearest == null) return;
    final airportCode = nearestAirport!['code'] as String;
    final radius = _getCheckinRadius(airportCode);
    if (distanceToNearest! > radius) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tooFarFromAirport(
            (distanceToNearest! / 1000).toStringAsFixed(1),
            (radius / 1000).toStringAsFixed(1),
          )),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 匿名ユーザーはチェックイン不可 → ログイン画面へ誘導
    if (_isAnonymousUser) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.loginRequired),
          content: Text(l10n.loginRequiredForCheckin),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
              child: Text(l10n.goToLogin),
            ),
          ],
        ),
      );
      
      if (shouldLogin == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              onAuthSuccess: () {
                Navigator.pop(context);
                _loadCheckins();
                setState(() {});
              },
            ),
          ),
        );
      }
      return;
    }
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginRequired), backgroundColor: Colors.orange),
      );
      return;
    }
    
    try {
      await Supabase.instance.client.from('airport_checkins').upsert({
        'user_id': userId,
        'airport_code': airportCode,
        'checkin_date': DateTime.now().toIso8601String().substring(0, 10),
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
      }, onConflict: 'user_id,airport_code,checkin_date');
      
      setState(() => checkedAirports.add(airportCode));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkinSuccess(_getAirportName(nearestAirport!))),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.checkinError}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalAirports = airportsByPrefecture.values.fold<int>(0, (sum, list) => sum + list.length);
    final checkedCount = checkedAirports.length;
    final double progressPercent = totalAirports > 0 ? (checkedCount / totalAirports * 100) : 0.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー：全体進捗
            _buildProgressHeader(checkedCount, totalAirports, progressPercent),
            const SizedBox(height: 16),
            
            // チェックインボタン（最寄り空港）
            _buildCheckinCard(),
            const SizedBox(height: 16),
            
            // 地方別リスト
            ..._buildRegionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(int checked, int total, double percent) {
    final l10n = AppLocalizations.of(context)!;
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    final currentBadge = _getCurrentBadge(checked);
    final nextBadge = _getNextBadge(checked);
    
    // 70空港を100%として計算
    const int maxForGauge = 70;
    final double gaugePercent = (checked / maxForGauge * 100).clamp(0, 100);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.airportStampRally, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: Text(isJa ? '合計 $checked' : 'Total $checked', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: gaugePercent / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellow),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isJa ? '${gaugePercent.toStringAsFixed(1)}% (70空港で達成)' : '${gaugePercent.toStringAsFixed(1)}% (70 airports to complete)',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
          
          // バッジ表示
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 現在のバッジ
                if (currentBadge != null) ...[
                  Row(
                    children: [
                      Text(currentBadge['icon'], style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isJa ? currentBadge['nameJa'] : currentBadge['name'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isJa ? '${currentBadge['required']}空港達成！' : '${currentBadge['required']} airports achieved!',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Text('✈️', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Text(
                        isJa ? 'バッジ未獲得' : 'No badge yet',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
                
                // 次のバッジへの進捗
                if (nextBadge != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        isJa ? '次: ${nextBadge['icon']} ${nextBadge['nameJa']}' : 'Next: ${nextBadge['icon']} ${nextBadge['name']}',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: checked / nextBadge['required'],
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(nextBadge['color'])),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$checked/${nextBadge['required']}',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    isJa ? '🎉 全バッジ達成！' : '🎉 All badges achieved!',
                    style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinCard() {
    final l10n = AppLocalizations.of(context)!;
    final airportCode = nearestAirport?['code'] as String? ?? '';
    final radius = _getCheckinRadius(airportCode);
    final canCheckin = nearestAirport != null && 
                       distanceToNearest != null && 
                       distanceToNearest! <= radius;
    final needsLogin = _isAnonymousUser;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canCheckin ? (needsLogin ? Colors.orange[50] : Colors.green[50]) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canCheckin ? (needsLogin ? Colors.orange : Colors.green) : Colors.grey[300]!,
          width: canCheckin ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canCheckin ? Icons.location_on : Icons.location_off,
                color: canCheckin ? (needsLogin ? Colors.orange : Colors.green) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                canCheckin 
                  ? (needsLogin ? l10n.loginToCheckin : l10n.checkinAvailable) 
                  : l10n.nearestAirport,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: canCheckin ? (needsLogin ? Colors.orange[700] : Colors.green[700]) : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nearestAirport != null) ...[
            Text(
              '${_getAirportName(nearestAirport!)} (${nearestAirport!['code']})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              distanceToNearest != null
                  ? l10n.distanceFromHere((distanceToNearest! / 1000).toStringAsFixed(1))
                  : l10n.calculatingDistance,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canCheckin ? _checkin : null,
                icon: Icon(needsLogin ? Icons.login : Icons.check_circle),
                label: Text(
                  canCheckin 
                    ? (needsLogin ? l10n.loginRequired : l10n.checkin)
                    : l10n.checkinWithinRadius((radius / 1000).toStringAsFixed(1))
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCheckin ? (needsLogin ? Colors.orange : Colors.green) : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            Text(l10n.gettingLocation),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRegionList() {
    final l10n = AppLocalizations.of(context)!;
    final widgets = <Widget>[];
    
    for (var regionKey in regionKeys) {
      final prefectures = regionPrefectures[regionKey] ?? [];
      if (prefectures.isEmpty) continue;
      
      // 地方内の全空港数とチェック済み数を計算
      int totalInRegion = 0;
      int checkedInRegion = 0;
      for (var pref in prefectures) {
        final airports = airportsByPrefecture[pref] ?? [];
        totalInRegion += airports.length;
        checkedInRegion += airports.where((a) => checkedAirports.contains(a['code'])).length;
      }
      
      if (totalInRegion == 0) continue;
      
      final isRegionExpanded = expandedRegions.contains(regionKey);
      final regionProgress = checkedInRegion / totalInRegion;
      final regionName = _getRegionName(regionKey);
      
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // 地方ヘッダー
              InkWell(
                onTap: () {
                  setState(() {
                    if (isRegionExpanded) {
                      expandedRegions.remove(regionKey);
                    } else {
                      expandedRegions.add(regionKey);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 進捗インジケーター（円形）
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Stack(
                          children: [
                            CircularProgressIndicator(
                              value: regionProgress,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getProgressColor(regionProgress),
                              ),
                              strokeWidth: 4,
                            ),
                            Center(
                              child: Text(
                                '$checkedInRegion',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _getProgressColor(regionProgress),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              regionName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              l10n.nAirports(totalInRegion),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (checkedInRegion == totalInRegion)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(l10n.conquered, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        isRegionExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              // 都道府県リスト（展開時）
              if (isRegionExpanded)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: _buildPrefectureGrid(prefectures),
                ),
            ],
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildPrefectureGrid(List<String> prefectures) {
    // 2-3列で表示
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
        
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prefectures.map((prefecture) {
            final airports = airportsByPrefecture[prefecture] ?? [];
            if (airports.isEmpty) return const SizedBox.shrink();
            
            final checkedCount = airports.where((a) => checkedAirports.contains(a['code'])).length;
            final totalCount = airports.length;
            final isExpanded = expandedPrefectures.contains(prefecture);
            final isComplete = checkedCount == totalCount;
            
            final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;
            
            return SizedBox(
              width: itemWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: isComplete ? Colors.amber[50] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isComplete ? Colors.amber : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            expandedPrefectures.remove(prefecture);
                          } else {
                            expandedPrefectures.add(prefecture);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        prefecture.replaceAll('県', '').replaceAll('府', '').replaceAll('都', ''),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isComplete ? Colors.amber[800] : Colors.black,
                                        ),
                                      ),
                                      if (isComplete) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.check_circle, size: 14, color: Colors.amber),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '$checkedCount / $totalCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: airports.map((airport) {
                            final isChecked = checkedAirports.contains(airport['code']);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isChecked ? Icons.check_circle : Icons.circle_outlined,
                                    size: 16,
                                    color: isChecked ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${_getAirportName(airport)} (${airport['code']})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isChecked ? Colors.black : Colors.grey[600],
                                        fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _getProgressColor(double ratio) {
    if (ratio >= 1.0) return Colors.amber[700]!;
    if (ratio >= 0.5) return Colors.orange;
    if (ratio > 0) return Colors.blue;
    return Colors.grey;
  }
}
