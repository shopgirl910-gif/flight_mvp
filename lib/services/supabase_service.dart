import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // フライト検索
  static Future<List<Map<String, dynamic>>> searchFlights({
    required String departureCode,
    required String arrivalCode,
    required String date,
  }) async {
    final response = await Supabase.instance.client
        .from('schedules')
        .select()
        .eq('departure_code', departureCode)
        .eq('arrival_code', arrivalCode)
        .eq('is_active', true)
        .lte('period_start', date)
        .gte('period_end', date);

    return List<Map<String, dynamic>>.from(response);
  }
}