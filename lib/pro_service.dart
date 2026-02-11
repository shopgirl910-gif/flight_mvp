import 'package:supabase_flutter/supabase_flutter.dart';

/// Pro版の制限管理サービス
/// 
/// 無料版の制限:
/// - FOP/PP計算: 3レグ/日
/// - おまかせ最適化: 結果1件のみ表示
/// - 修行ログ保存: 5旅程まで
/// - CSVエクスポート: 不可
/// - AIメール解析: 不可
/// 
/// Pro版（100円→480円）:
/// - 全機能 無制限ｃ無制限
class ProService {
  static final ProService _instance = ProService._internal();
  factory ProService() => _instance;
  ProService._internal();

  final _supabase = Supabase.instance.client;

  // キャッシュ（毎回DB問い合わせを避ける）
  bool? _isPro;
  DateTime? _lastChecked;

  // ========== 制限定数 ==========
  static const int freeCalcLimit = 6;       // 無料版: 1日6レグ計算
  static const int freeLogLimit = 5;        // 無料版: 5旅程まで保存
  static const int freeOptimizeResults = 1; // 無料版: 最適化結果1件
  static const int proPrice = 100;          // リリース記念価格（円）
  static const int regularPrice = 480;      // 正規価格（円）
  static const int earlyBirdSlots = 200;    // 先着枠

  // ========== Pro判定 ==========

  /// Pro版かどうか（キャッシュ付き・5分間有効）
  Future<bool> isPro() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    // キャッシュが5分以内なら再利用
    if (_isPro != null && _lastChecked != null) {
      if (DateTime.now().difference(_lastChecked!).inMinutes < 5) {
        return _isPro!;
      }
    }

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('is_pro')
          .eq('user_id', user.id)
          .maybeSingle();

      _isPro = response?['is_pro'] == true;
      _lastChecked = DateTime.now();
      return _isPro!;
    } catch (e) {
      return false;
    }
  }

  /// キャッシュクリア（購入後に呼ぶ）
  void clearCache() {
    _isPro = null;
    _lastChecked = null;
  }

  // ========== 利用回数チェック ==========

  /// 今日の計算回数を取得
  Future<int> getTodayCalcCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return 0;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await _supabase
          .from('flight_calculations')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', '${today}T00:00:00')
          .lte('created_at', '${today}T23:59:59');

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// 計算可能かどうか
  Future<bool> canCalculate() async {
    if (await isPro()) return true;
    final count = await getTodayCalcCount();
    return count < freeCalcLimit;
  }

  /// 残り計算回数
  Future<int> remainingCalcCount() async {
    if (await isPro()) return -1; // -1 = 無制限
    final count = await getTodayCalcCount();
    return (freeCalcLimit - count).clamp(0, freeCalcLimit);
  }

  /// 保存済み旅程数を取得
  Future<int> getSavedLogCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return 0;

    try {
      final response = await _supabase
          .from('saved_itineraries')
          .select('id')
          .eq('user_id', user.id);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// 旅程保存可能かどうか
  Future<bool> canSaveLog() async {
    if (await isPro()) return true;
    final count = await getSavedLogCount();
    return count < freeLogLimit;
  }

  /// おまかせ最適化の表示件数
  Future<int> getOptimizeResultLimit() async {
    if (await isPro()) return 999; // 実質無制限
    return freeOptimizeResults;
  }

  // ========== 先着枠管理 ==========

  /// 残り先着枠数を取得
  Future<int> getRemainingSlots() async {
    try {
      final response = await _supabase
          .from('pro_purchase_stats')
          .select()
          .single();

      return response['remaining_slots'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 現在の価格を取得
  Future<int> getCurrentPrice() async {
    final remaining = await getRemainingSlots();
    return remaining > 0 ? proPrice : regularPrice;
  }

  // ========== 購入処理 ==========

  /// Pro版購入を記録（Stripe決済成功後に呼ぶ）
  Future<bool> activatePro() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    try {
      await _supabase
          .from('user_profiles')
          .update({
            'is_pro': true,
            'pro_purchased_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);

      clearCache();
      return true;
    } catch (e) {
      return false;
    }
  }
}
