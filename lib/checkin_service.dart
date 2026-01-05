import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckinService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 位置情報の権限を確認・リクエスト
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 現在地を取得
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  /// 最寄りの空港を検索
  Future<Map<String, dynamic>?> findNearestAirport(
    double lat,
    double lng,
  ) async {
    final response = await _supabase
        .from('airports')
        .select('code, name_ja, latitude, longitude')
        .not('latitude', 'is', null);

    if (response.isEmpty) return null;

    Map<String, dynamic>? nearest;
    double minDistance = double.infinity;

    for (final airport in response) {
      final distance = _calculateDistance(
        lat,
        lng,
        airport['latitude'],
        airport['longitude'],
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = {...airport, 'distance_m': distance.round()};
      }
    }

    return nearest;
  }

  /// 2点間の距離を計算（メートル）
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // メートル
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  /// チェックインを保存
  Future<bool> saveCheckin({
    required String airportCode,
    required double userLat,
    required double userLng,
    required int distanceM,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      print('userId: $userId'); // デバッグ用
      if (userId == null) {
        print('userID: $userId');
        return false;
      }
      await _supabase.from('checkins').insert({
        'user_id': userId,
        'airport_code': airportCode,
        'latitude': userLat,
        'longitude': userLng,
        'distance_m': distanceM,
      });
      return true;
    } catch (e) {
      print('Checkin error: $e'); // エラー詳細を表示
      return false;
    }
  }
}
