// lib/screens/email_parse_dialog.dart
// AIメール解析ダイアログ
// - 予約メール貼り付け → Claude Haiku解析 → 結果プレビュー → 保存
// - 過去日付 → 修行済みタブ（確認ダイアログ付き）
// - 未来日付 → 予定タブ
// - Paint it Black連携: 修行済み保存時に空港チェックイン自動登録

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ======================================
// データモデル
// ======================================

class ParsedFlight {
  String airline;        // "JAL" | "ANA"
  String flightNumber;   // "JL901"
  String origin;         // "HND"
  String destination;    // "OKA"
  String flightDate;     // "2026-03-15"
  String departureTime;  // "08:00"
  String arrivalTime;    // "10:30"
  String? fareType;      // "運賃3"
  String? fareTypeName;  // "セイバー"
  String? seatClass;     // "普通席"
  int? fareAmount;       // 運賃金額

  // UI用
  bool isSelected;       // 保存対象として選択中
  bool isPast;           // 過去日付フラグ
  bool saveAsCompleted;  // 修行済みとして保存（過去日付時のトグル）

  ParsedFlight({
    required this.airline,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.flightDate,
    required this.departureTime,
    required this.arrivalTime,
    this.fareType,
    this.fareTypeName,
    this.seatClass,
    this.fareAmount,
    this.isSelected = true,
    this.isPast = false,
    this.saveAsCompleted = true,
  });

  factory ParsedFlight.fromJson(Map<String, dynamic> json) {
    final dateStr = json['flightDate'] ?? '';
    final isPast = _isDatePast(dateStr);

    return ParsedFlight(
      airline: json['airline'] ?? 'JAL',
      flightNumber: json['flightNumber'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      flightDate: dateStr,
      departureTime: json['departureTime'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      fareType: json['fareType'],
      fareTypeName: json['fareTypeName'],
      seatClass: json['seatClass'],
      fareAmount: json['fareAmount'] != null
          ? (json['fareAmount'] as num).toInt()
          : null,
      isPast: isPast,
      saveAsCompleted: isPast, // 過去日付はデフォルトで修行済み
    );
  }

  static bool _isDatePast(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final flightDate = DateTime.parse(dateStr);
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      return flightDate.isBefore(todayOnly);
    } catch (_) {
      return false;
    }
  }

  /// 日付の表示用フォーマット
  String get formattedDate {
    if (flightDate.isEmpty) return '不明';
    try {
      final dt = DateTime.parse(flightDate);
      final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}(${weekdays[dt.weekday - 1]})';
    } catch (_) {
      return flightDate;
    }
  }

  /// ステータスラベル
  String get statusLabel => isPast
      ? (saveAsCompleted ? '✈️ 修行済み' : '📋 予定')
      : '📋 予定';

  Color get statusColor => isPast && saveAsCompleted
      ? const Color(0xFF4CAF50)
      : const Color(0xFF2196F3);
}

// ======================================
// メインダイアログ
// ======================================

class EmailParseDialog extends StatefulWidget {
  /// Paint it Black更新用コールバック
  final VoidCallback? onPaintItBlackUpdate;

  /// 修行ログ更新用コールバック
  final VoidCallback? onFlightLogUpdate;

  /// 保存完了後のタブ切り替えコールバック（0=修行済み, 1=予定）
  final Function(int tabIndex, String? itineraryId)? onNavigateToLog;

  const EmailParseDialog({
    super.key,
    this.onPaintItBlackUpdate,
    this.onFlightLogUpdate,
    this.onNavigateToLog,
  });

  @override
  State<EmailParseDialog> createState() => _EmailParseDialogState();
}

class _EmailParseDialogState extends State<EmailParseDialog> {
  final _emailController = TextEditingController();
  final _supabase = Supabase.instance.client;

  // 画面状態
  _DialogState _state = _DialogState.input;
  List<ParsedFlight> _flights = [];
  String _confidence = '';
  List<String> _warnings = [];
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ======================================
  // AI解析処理
  // ======================================

  Future<void> _parseEmail() async {
    final emailText = _emailController.text.trim();
    if (emailText.length < 20) {
      setState(() {
        _errorMessage = 'メール本文が短すぎます。予約確認メールの全文を貼り付けてください。';
      });
      return;
    }

    setState(() {
      _state = _DialogState.loading;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'parse-email',
        body: {'emailText': emailText},
      );

      if (response.status != 200) {
        final errorData = response.data;
        throw Exception(errorData['error'] ?? 'AI解析に失敗しました');
      }

      final data = response.data;
      final flightsList = (data['flights'] as List)
          .map((f) => ParsedFlight.fromJson(f as Map<String, dynamic>))
          .toList();

      if (flightsList.isEmpty) {
        throw Exception('フライト情報を検出できませんでした。');
      }

      setState(() {
        _flights = flightsList;
        _confidence = data['confidence'] ?? 'medium';
        _warnings = (data['warnings'] as List?)
                ?.map((w) => w.toString())
                .toList() ??
            [];
        _state = _DialogState.preview;
      });
    } catch (e) {
      setState(() {
        _state = _DialogState.input;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ======================================
  // 保存処理
  // ======================================

  Future<void> _saveFlights() async {
    final selectedFlights =
        _flights.where((f) => f.isSelected).toList();
    if (selectedFlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存するレグを選択してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('ログインが必要です');

      // 修行済みと予定を分離
      final completedFlights =
          selectedFlights.where((f) => f.isPast && f.saveAsCompleted).toList();
      final plannedFlights =
          selectedFlights.where((f) => !f.isPast || !f.saveAsCompleted).toList();

      String? savedItineraryId;
      int targetTabIndex = 1; // デフォルト: 予定タブ

      // --- 修行済みレグの保存 ---
      if (completedFlights.isNotEmpty) {
        savedItineraryId = await _saveItinerary(
          userId: userId,
          flights: completedFlights,
          status: '修行済み',
        );
        targetTabIndex = 0;

        // Paint it Black連携: 空港チェックイン自動登録
        await _registerAirportCheckins(userId, completedFlights);
      }

      // --- 予定レグの保存 ---
      if (plannedFlights.isNotEmpty) {
        final plannedId = await _saveItinerary(
          userId: userId,
          flights: plannedFlights,
          status: '予定',
        );
        // 予定のみの場合は予定タブへ
        if (completedFlights.isEmpty) {
          savedItineraryId = plannedId;
          targetTabIndex = 1;
        }
      }

      // コールバック発火
      widget.onFlightLogUpdate?.call();
      if (completedFlights.isNotEmpty) {
        widget.onPaintItBlackUpdate?.call();
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      // 保存結果のフィードバック
      final completedCount = completedFlights.length;
      final plannedCount = plannedFlights.length;
      final messages = <String>[];
      if (completedCount > 0) messages.add('$completedCountレグを修行済みに登録');
      if (plannedCount > 0) messages.add('$plannedCountレグを予定に登録');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${messages.join('、')}しました'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      // 修行ログへ遷移 + 展開表示
      widget.onNavigateToLog?.call(targetTabIndex, savedItineraryId);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存エラー: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 旅程をsaved_itinerariesに保存
  Future<String> _saveItinerary({
    required String userId,
    required List<ParsedFlight> flights,
    required String status,
  }) async {
    // レグJSON構築
    final legs = flights.map((f) {
      return {
        'airline': f.airline,
        'flightNumber': f.flightNumber,
        'origin': f.origin,
        'destination': f.destination,
        'flightDate': f.flightDate,
        'departureTime': f.departureTime,
        'arrivalTime': f.arrivalTime,
        'fareType': f.fareType,
        'fareTypeName': f.fareTypeName,
        'seatClass': f.seatClass ?? '普通席',
        'fareAmount': f.fareAmount,
      };
    }).toList();

    // 旅程名自動生成
    final first = flights.first;
    final last = flights.last;
    final datePart = first.flightDate.replaceAll('-', '/');
    final routePart = flights.length == 1
        ? '${first.origin}→${first.destination}'
        : '${first.origin}→...→${last.destination}';
    final itineraryName = '$datePart $routePart（メール解析）';

    // 合計運賃
    final totalFare = flights
        .where((f) => f.fareAmount != null)
        .fold<int>(0, (sum, f) => sum + f.fareAmount!);

    // FOP/PP計算は既存のcalculateメソッドに委譲
    // ここでは0で保存し、flight_log_screenの再計算ロジックに任せる
    final response = await _supabase.from('saved_itineraries').insert({
      'user_id': userId,
      'itinerary_name': itineraryName,
      'legs': jsonEncode(legs),
      'total_fop': 0,  // 再計算で上書きされる
      'total_pp': 0,   // 再計算で上書きされる
      'total_fare': totalFare,
      'status': status,
    }).select('id').single();

    return response['id'].toString();
  }

  // ======================================
  // Paint it Black連携
  // ======================================

  /// 修行済みフライトの空港をチェックイン済みとして登録
  Future<void> _registerAirportCheckins(
    String userId,
    List<ParsedFlight> completedFlights,
  ) async {
    // 全レグの出発地・到着地を収集（重複排除）
    final airportCodes = <String>{};
    for (final f in completedFlights) {
      if (f.origin.isNotEmpty) airportCodes.add(f.origin);
      if (f.destination.isNotEmpty) airportCodes.add(f.destination);
    }

    // 既にチェックイン済みの空港を取得
    final existing = await _supabase
        .from('airport_checkins')
        .select('airport_code')
        .eq('user_id', userId);

    final existingCodes =
        (existing as List).map((e) => e['airport_code'] as String).toSet();

    // 未チェックインの空港のみ登録
    final newAirports = airportCodes.difference(existingCodes);
    if (newAirports.isEmpty) return;

    // 空港の緯度経度を取得
    final airports = await _supabase
        .from('airports')
        .select('code, latitude, longitude')
        .inFilter('code', newAirports.toList());

    final airportMap = <String, Map<String, dynamic>>{};
    for (final a in (airports as List)) {
      airportMap[a['code'] as String] = a;
    }

    // バッチINSERT
    final checkins = <Map<String, dynamic>>[];
    for (final code in newAirports) {
      final airport = airportMap[code];
      // フライト日付を取得（該当空港を含む最初のフライト）
      final relatedFlight = completedFlights.firstWhere(
        (f) => f.origin == code || f.destination == code,
        orElse: () => completedFlights.first,
      );

      checkins.add({
        'user_id': userId,
        'airport_code': code,
        'checked_in_at': '${relatedFlight.flightDate}T12:00:00+09:00',
        'latitude': airport?['latitude'] ?? 0.0,
        'longitude': airport?['longitude'] ?? 0.0,
      });
    }

    if (checkins.isNotEmpty) {
      await _supabase.from('airport_checkins').insert(checkins);
    }
  }

  // ======================================
  // UI構築
  // ======================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildBody(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = {
      _DialogState.input: '📧 予約メールから入力',
      _DialogState.loading: '🔍 AI解析中...',
      _DialogState.preview: '✅ 解析結果の確認',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titles[_state] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _DialogState.input:
        return _buildInputView();
      case _DialogState.loading:
        return _buildLoadingView();
      case _DialogState.preview:
        return _buildPreviewView();
    }
  }

  // --- 入力画面 ---
  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'JAL/ANAの予約確認メールの本文を貼り付けてください。',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: '予約確認メールの本文をここに貼り付け...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // ヒント
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('💡 ヒント', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• 過去の搭乗分 → 自動で「修行済み」に登録', style: TextStyle(fontSize: 11)),
              Text('• 未来の予約分 → 「予定」に登録', style: TextStyle(fontSize: 11)),
              Text('• 訪問空港はPaint it Blackに自動反映 🗾', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // --- ローディング ---
  Widget _buildLoadingView() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AIがメールを解析中...', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text('通常5秒以内で完了します', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // --- プレビュー画面 ---
  Widget _buildPreviewView() {
    final hasPastFlights = _flights.any((f) => f.isPast);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 信頼度表示
        _buildConfidenceBadge(),
        const SizedBox(height: 8),

        // 警告表示
        if (_warnings.isNotEmpty) ...[
          ..._warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(child: Text(w, style: const TextStyle(fontSize: 11, color: Colors.orange))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],

        // 過去日付の説明
        if (hasPastFlights)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '過去の搭乗日が検出されました。「修行済み」として登録し、Paint it Blackに反映します。',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),

        // フライト一覧
        ...List.generate(_flights.length, (i) => _buildFlightCard(i)),

        const SizedBox(height: 8),
        // 集計
        _buildSummary(),
      ],
    );
  }

  Widget _buildConfidenceBadge() {
    final configs = {
      'high': ('🟢 高精度', Colors.green),
      'medium': ('🟡 中精度（確認推奨）', Colors.orange),
      'low': ('🔴 低精度（要確認）', Colors.red),
    };
    final config = configs[_confidence] ?? configs['medium']!;
    return Row(
      children: [
        Text(
          '解析精度: ${config.$1}',
          style: TextStyle(fontSize: 12, color: config.$2, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFlightCard(int index) {
    final f = _flights[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: f.isSelected ? 2 : 0,
      color: f.isSelected ? null : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // ヘッダー行: チェックボックス + 便名 + ステータス
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: f.isSelected,
                    onChanged: (v) => setState(() => f.isSelected = v ?? true),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                // 航空会社アイコン
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: f.airline == 'JAL'
                        ? const Color(0xFFE60012)
                        : const Color(0xFF00BFFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    f.flightNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // ステータスバッジ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: f.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: f.statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    f.statusLabel,
                    style: TextStyle(fontSize: 11, color: f.statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ルート情報
            Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 区間
                      Row(
                        children: [
                          Text(f.origin,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                          ),
                          Text(f.destination,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 日付・時刻
                      Text(
                        '${f.formattedDate}  ${f.departureTime}→${f.arrivalTime}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      // 運賃情報
                      if (f.fareTypeName != null || f.fareAmount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (f.fareTypeName != null) f.fareTypeName,
                              if (f.seatClass != null) f.seatClass,
                              if (f.fareAmount != null)
                                '¥${NumberFormat('#,###').format(f.fareAmount)}',
                            ].join(' / '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // 過去日付の場合: 修行済みトグル
            if (f.isPast && f.isSelected) ...[
              const Divider(height: 16),
              Row(
                children: [
                  const SizedBox(width: 32),
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('搭乗済みとして登録', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: f.saveAsCompleted,
                      onChanged: (v) => setState(() => f.saveAsCompleted = v),
                      activeColor: Colors.green,
                    ),
                  ),
                ],
              ),
              if (f.saveAsCompleted)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    '🗾 訪問空港がPaint it Blackに反映されます',
                    style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final selected = _flights.where((f) => f.isSelected).toList();
    final completedCount = selected.where((f) => f.isPast && f.saveAsCompleted).length;
    final plannedCount = selected.length - completedCount;
    final totalFare = selected
        .where((f) => f.fareAmount != null)
        .fold<int>(0, (sum, f) => sum + f.fareAmount!);

    // Paint it Blackに追加される空港
    final newAirports = <String>{};
    for (final f in selected.where((f) => f.isPast && f.saveAsCompleted)) {
      newAirports.add(f.origin);
      newAirports.add(f.destination);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 保存内容',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          if (completedCount > 0)
            Text('  ✈️ 修行済み: $completedCountレグ', style: const TextStyle(fontSize: 12)),
          if (plannedCount > 0)
            Text('  📋 予定: $plannedCountレグ', style: const TextStyle(fontSize: 12)),
          if (totalFare > 0)
            Text('  💰 合計運賃: ¥${NumberFormat('#,###').format(totalFare)}',
                style: const TextStyle(fontSize: 12)),
          if (newAirports.isNotEmpty)
            Text(
              '  🗾 Paint it Black: ${newAirports.join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_state == _DialogState.preview) ...[
            TextButton(
              onPressed: () => setState(() {
                _state = _DialogState.input;
                _flights = [];
              }),
              child: const Text('← やり直す'),
            ),
            const SizedBox(width: 8),
          ],
          if (_state == _DialogState.input)
            ElevatedButton.icon(
              onPressed: _parseEmail,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI解析'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          if (_state == _DialogState.preview)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveFlights,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, size: 16),
              label: Text(_isSaving ? '保存中...' : '修行ログに保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

// 画面状態
enum _DialogState { input, loading, preview }

// ======================================
// 呼び出し用ヘルパー
// ======================================

/// シミュレーション画面などから呼び出す
/// ```dart
/// showEmailParseDialog(
///   context,
///   onPaintItBlackUpdate: () => _loadCheckinData(),
///   onFlightLogUpdate: () => _refreshFlightLog(),
///   onNavigateToLog: (tab, id) => _switchToLogTab(tab, expandId: id),
/// );
/// ```
void showEmailParseDialog(
  BuildContext context, {
  VoidCallback? onPaintItBlackUpdate,
  VoidCallback? onFlightLogUpdate,
  Function(int tabIndex, String? itineraryId)? onNavigateToLog,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EmailParseDialog(
      onPaintItBlackUpdate: onPaintItBlackUpdate,
      onFlightLogUpdate: onFlightLogUpdate,
      onNavigateToLog: onNavigateToLog,
    ),
  );
}
