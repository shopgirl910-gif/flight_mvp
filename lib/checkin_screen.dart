import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'auth_screen.dart';

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
  
  // 地方→都道府県のマッピング
  static const Map<String, List<String>> regionPrefectures = {
    '北海道': ['北海道'],
    '東北': ['青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'],
    '関東': ['東京都', '千葉県'],
    '中部': ['新潟県', '長野県', '静岡県', '愛知県', '石川県', '富山県'],
    '関西': ['大阪府', '兵庫県', '和歌山県'],
    '中国': ['鳥取県', '島根県', '岡山県', '広島県', '山口県'],
    '四国': ['香川県', '愛媛県', '高知県', '徳島県'],
    '九州': ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県'],
    '沖縄': ['沖縄県'],
  };

  static const List<String> regionOrder = [
    '北海道', '東北', '関東', '中部', '関西', '中国', '四国', '九州', '沖縄',
  ];
  
  // 展開中の地方
  Set<String> expandedRegions = {};

  // チェックイン可能距離（メートル）
  static const double checkinRadius = 3000;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      setState(() => errorMessage = 'データ読み込みエラー: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAirports() async {
    final response = await Supabase.instance.client
        .from('airports')
        .select('code, name_ja, prefecture, latitude, longitude')
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
    try {
      // 位置情報の許可確認
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => errorMessage = '位置情報の許可が必要です');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => errorMessage = '設定から位置情報を許可してください');
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
      setState(() => errorMessage = '位置情報取得エラー: $e');
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

  Future<void> _checkin() async {
    if (nearestAirport == null || distanceToNearest == null) return;
    if (distanceToNearest! > checkinRadius) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('空港から${(distanceToNearest! / 1000).toStringAsFixed(1)}km離れています（${(checkinRadius / 1000).toStringAsFixed(0)}km以内でチェックイン可能）'),
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
          title: const Text('ログインが必要です'),
          content: const Text('チェックイン記録を保存するにはログインが必要です。\nログイン画面に移動しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
              child: const Text('ログインする'),
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
        const SnackBar(content: Text('ログインが必要です'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    final airportCode = nearestAirport!['code'] as String;
    
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
            content: Text('${nearestAirport!['name_ja']}空港にチェックインしました！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('チェックインエラー: $e'), backgroundColor: Colors.red),
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
              const Text('空港スタンプラリー', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: Text('$checked / $total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellow),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('${percent.toStringAsFixed(1)}% 制覇', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCheckinCard() {
    final canCheckin = nearestAirport != null && 
                       distanceToNearest != null && 
                       distanceToNearest! <= checkinRadius;
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
                  ? (needsLogin ? 'ログインしてチェックイン' : 'チェックイン可能！') 
                  : '最寄り空港',
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
              '${nearestAirport!['name_ja']}空港 (${nearestAirport!['code']})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              distanceToNearest != null
                  ? '現在地から ${(distanceToNearest! / 1000).toStringAsFixed(1)} km'
                  : '距離計算中...',
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
                    ? (needsLogin ? 'ログインが必要です' : 'チェックイン')
                    : '${(checkinRadius / 1000).toStringAsFixed(0)}km以内で可能'
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCheckin ? (needsLogin ? Colors.orange : Colors.green) : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            const Text('位置情報を取得中...'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('再取得'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRegionList() {
    final widgets = <Widget>[];
    
    for (var region in regionOrder) {
      final prefectures = regionPrefectures[region] ?? [];
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
      
      final isRegionExpanded = expandedRegions.contains(region);
      final regionProgress = checkedInRegion / totalInRegion;
      
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
                      expandedRegions.remove(region);
                    } else {
                      expandedRegions.add(region);
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
                              region,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '$checkedInRegion / $totalInRegion 空港',
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
                          child: const Text('制覇！', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                                      '${airport['name_ja']} (${airport['code']})',
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
