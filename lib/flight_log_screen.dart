import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';

class FlightLogScreen extends StatefulWidget {
  const FlightLogScreen({super.key});

  @override
  State<FlightLogScreen> createState() => FlightLogScreenState();
}

class FlightLogScreenState extends State<FlightLogScreen> {
  List<Map<String, dynamic>> itineraries = [];
  bool isLoading = true;
  String? errorMessage;
  String? _expandedId;

  // 累計統計
  int totalFOP = 0;
  int totalPP = 0;
  int totalMiles = 0;
  int totalLSP = 0;
  int totalLegs = 0;
  int totalFlights = 0; // 旅程数

  @override
  void initState() {
    super.initState();
    _loadItineraries();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) _loadItineraries();
    });
  }

  void refresh() => _loadItineraries();

  Future<void> _loadItineraries() async {
    setState(() => isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        setState(() {
          itineraries = [];
          _resetTotals();
          isLoading = false;
          errorMessage = null;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('saved_itineraries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);
      _calculateTotals(list);

      setState(() {
        itineraries = list;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'データの読み込みに失敗しました: $e';
      });
    }
  }

  void _resetTotals() {
    totalFOP = 0;
    totalPP = 0;
    totalMiles = 0;
    totalLSP = 0;
    totalLegs = 0;
    totalFlights = 0;
  }

  void _calculateTotals(List<Map<String, dynamic>> list) {
    _resetTotals();
    for (var it in list) {
      totalFOP += (it['total_fop'] as int?) ?? 0;
      totalPP += (it['total_pp'] as int?) ?? 0;
      totalMiles += (it['total_miles'] as int?) ?? 0;
      totalLSP += (it['total_lsp'] as int?) ?? 0;
      final legs = it['legs'] as List<dynamic>? ?? [];
      totalLegs += legs.length;
    }
    totalFlights = list.length;
  }

  Future<void> _deleteItinerary(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text(l10n.deleteItineraryConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('saved_itineraries').delete().eq('id', id);
        _loadItineraries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleted), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleteFailed(e.toString())), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _shareToX(Map<String, dynamic> itinerary) {
    final title = itinerary['title'] as String? ?? '';
    final fop = itinerary['total_fop'] as int? ?? 0;
    final pp = itinerary['total_pp'] as int? ?? 0;
    final miles = itinerary['total_miles'] as int? ?? 0;
    final fare = itinerary['total_fare'] as int? ?? 0;
    final legs = itinerary['legs'] as List<dynamic>? ?? [];

    // 単価計算
    String unitPrice = '-';
    if (fare > 0) {
      if (fop > 0) {
        unitPrice = '¥${(fare / fop).toStringAsFixed(1)}/FOP';
      } else if (pp > 0) {
        unitPrice = '¥${(fare / pp).toStringAsFixed(1)}/PP';
      }
    }

    // ツイートテキスト生成
    final buffer = StringBuffer();
    buffer.writeln('✈️ 修行プラン作成！');
    buffer.writeln(title);
    buffer.writeln('');
    if (fop > 0) buffer.writeln('FOP: ${_formatNumber(fop)}');
    if (pp > 0) buffer.writeln('PP: ${_formatNumber(pp)}');
    buffer.writeln('マイル: ${_formatNumber(miles)}');
    if (fare > 0) buffer.writeln('総額: ¥${_formatNumber(fare)}');
    if (unitPrice != '-') buffer.writeln('単価: $unitPrice');
    buffer.writeln('');
    buffer.writeln('#MRP修行プラン #マイル修行');
    buffer.writeln('https://mileage-run-planner.web.app');

    final text = Uri.encodeComponent(buffer.toString());
    final url = 'https://twitter.com/intent/tweet?text=$text';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _formatNumber(int number) {
    if (number == 0) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadItineraries, child: Text(l10n.reload)),
        ]),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;

    if (!isLoggedIn) {
      return _buildNotLoggedInView(l10n);
    }

    if (itineraries.isEmpty) {
      return _buildEmptyView(l10n);
    }

    return RefreshIndicator(
      onRefresh: _loadItineraries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return CustomScrollView(
            slivers: [
              // サマリーカード
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: _buildSummaryCard(l10n, isMobile),
                ),
              ),
              // 旅程リスト
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItineraryCard(itineraries[index], isMobile),
                    childCount: itineraries.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotLoggedInView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flight_takeoff, size: 48, color: Colors.purple[400]),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.loginRequiredToSaveItineraries,
            style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.loginFromTopRight,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noSavedItineraries,
            style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.createItineraryInSimulateTab,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[700]!, Colors.purple[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      l10n.total,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$totalFlights ${isMobile ? "" : "trips"} / $totalLegs legs',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // メイン数値
          if (isMobile) ...[
            // モバイル: 2行表示
            Row(
              children: [
                Expanded(child: _buildSummaryStat('FOP', totalFOP, Colors.red[300]!)),
                Expanded(child: _buildSummaryStat('PP', totalPP, Colors.blue[300]!)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSummaryStat(l10n.miles, totalMiles, Colors.orange[300]!)),
                Expanded(child: _buildSummaryStat('LSP', totalLSP, Colors.purple[200]!)),
              ],
            ),
          ] else ...[
            // PC: 1行表示
            Row(
              children: [
                Expanded(child: _buildSummaryStat('FOP', totalFOP, Colors.red[300]!)),
                Expanded(child: _buildSummaryStat('PP', totalPP, Colors.blue[300]!)),
                Expanded(child: _buildSummaryStat(l10n.miles, totalMiles, Colors.orange[300]!)),
                Expanded(child: _buildSummaryStat('LSP', totalLSP, Colors.purple[200]!)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, int value, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          _formatNumber(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItineraryCard(Map<String, dynamic> itinerary, bool isMobile) {
    final l10n = AppLocalizations.of(context)!;
    final id = itinerary['id'] as String;
    final title = itinerary['title'] as String? ?? l10n.untitled;
    final totalFop = itinerary['total_fop'] as int? ?? 0;
    final totalPp = itinerary['total_pp'] as int? ?? 0;
    final totalMiles = itinerary['total_miles'] as int? ?? 0;
    final totalLsp = itinerary['total_lsp'] as int? ?? 0;
    final totalFare = itinerary['total_fare'] as int? ?? 0;
    final createdAt = _formatDate(itinerary['created_at'] as String?);
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    final isExpanded = _expandedId == id;

    // 単価計算
    String unitPrice = '-';
    if (totalFare > 0 && (totalFop > 0 || totalPp > 0)) {
      final points = totalFop > 0 ? totalFop : totalPp;
      unitPrice = '¥${(totalFare / points).toStringAsFixed(1)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ヘッダー（タップで展開）
          InkWell(
            onTap: () => setState(() => _expandedId = isExpanded ? null : id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1行目: タイトルと日付
                  Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        createdAt,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 2行目: 統計チップ
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (totalFop > 0) _buildStatChip('FOP', _formatNumber(totalFop), Colors.red),
                      if (totalPp > 0) _buildStatChip('PP', _formatNumber(totalPp), Colors.blue),
                      _buildStatChip(l10n.miles, _formatNumber(totalMiles), Colors.orange),
                      if (totalLsp > 0) _buildStatChip('LSP', _formatNumber(totalLsp), Colors.purple),
                      if (totalFare > 0) _buildStatChip('', '¥${_formatNumber(totalFare)}', Colors.green),
                      if (unitPrice != '-') _buildUnitPriceChip(unitPrice, totalFop > 0 ? 'FOP' : 'PP'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 展開部分
          if (isExpanded) ...[
            Container(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // レグ一覧
                  ...legs.map((leg) => _buildLegSummary(leg as Map<String, dynamic>)),
                  const SizedBox(height: 12),
                  // アクションボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Xシェアボタン
                      OutlinedButton.icon(
                        onPressed: () => _shareToX(itinerary),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(l10n.share),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 削除ボタン
                      OutlinedButton.icon(
                        onPressed: () => _deleteItinerary(id),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(l10n.delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red[200]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
          ],
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildUnitPriceChip(String value, String pointType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow[600]!, width: 0.5),
      ),
      child: Text(
        '$value/$pointType',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.yellow[900]),
      ),
    );
  }

  Widget _buildLegSummary(Map<String, dynamic> leg) {
    final airline = leg['airline'] as String? ?? '';
    final dep = leg['departure_airport'] as String? ?? '';
    final arr = leg['arrival_airport'] as String? ?? '';
    final flightNumber = leg['flight_number'] as String? ?? '';
    final date = leg['date'] as String? ?? '';
    final fop = leg['fop'] as int? ?? 0;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: airlineColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              airline,
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Text(flightNumber, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$dep → $arr',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${airline == "JAL" ? "FOP" : "PP"}: ${_formatNumber(fop)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: airlineColor),
              ),
              if (date.isNotEmpty)
                Text(date, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}
