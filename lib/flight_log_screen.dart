import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'pro_service.dart';
import 'pro_purchase_screen.dart';

class FlightLogScreen extends StatefulWidget {
  const FlightLogScreen({super.key});

  @override
  State<FlightLogScreen> createState() => FlightLogScreenState();
}

class FlightLogScreenState extends State<FlightLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> completedItineraries = [];
  List<Map<String, dynamic>> plannedItineraries = [];
  bool isLoading = true;
  String? errorMessage;
  String? _expandedId;

  // 累計統計（修行済みのみ）
  int totalFOP = 0;
  int totalPP = 0;
  int totalMiles = 0;
  int totalLSP = 0;
  int totalLegs = 0;
  int totalFlights = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItineraries();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) _loadItineraries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void refresh() => _loadItineraries();

  Future<void> _loadItineraries() async {
    setState(() => isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        setState(() {
          completedItineraries = [];
          plannedItineraries = [];
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

      final completed = list.where((it) => it['is_completed'] == true).toList();
      final planned = list.where((it) => it['is_completed'] != true).toList();

      _calculateTotals(completed);

      setState(() {
        completedItineraries = completed;
        plannedItineraries = planned;
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
    _jalMiles = 0;
    _jalLegs = 0;
    _anaMiles = 0;
    _anaLegs = 0;
  }

  // JAL/ANA別の統計
  int _jalMiles = 0;
  int _jalLegs = 0;
  int _anaMiles = 0;
  int _anaLegs = 0;

  void _calculateTotals(List<Map<String, dynamic>> list) {
    _resetTotals();
    for (var it in list) {
      totalFOP += (it['total_fop'] as int?) ?? 0;
      totalPP += (it['total_pp'] as int?) ?? 0;
      totalMiles += (it['total_miles'] as int?) ?? 0;
      totalLSP += (it['total_lsp'] as int?) ?? 0;
      final legs = it['legs'] as List<dynamic>? ?? [];
      totalLegs += legs.length;

      // JAL/ANA別にカウント
      for (var leg in legs) {
        final l = leg as Map<String, dynamic>;
        final airline = l['airline'] as String? ?? '';
        final miles = l['miles'] as int? ?? 0;
        if (airline == 'JAL') {
          _jalMiles += miles;
          _jalLegs++;
        } else if (airline == 'ANA') {
          _anaMiles += miles;
          _anaLegs++;
        }
      }
    }
    totalFlights = list.length;
  }

  Future<void> _markAsCompleted(String id) async {
    try {
      await Supabase.instance.client
          .from('saved_itineraries')
          .update({'is_completed': true})
          .eq('id', id);
      _loadItineraries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('修行済みに移動しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移動に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteItinerary(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text(l10n.deleteItineraryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('saved_itineraries')
            .delete()
            .eq('id', id);
        _loadItineraries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleted),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteFailed(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportCsv(Map<String, dynamic> itinerary) async {
    // Pro判定
    final isPro = await ProService().isPro();
    if (!isPro) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pro版限定機能'),
          content: const Text('CSVエクスポートはPro版の機能です。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProPurchaseScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Pro版を見る'),
            ),
          ],
        ),
      );
      return;
    }

    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.writeln(
      '航空会社,日付,便名,出発空港,到着空港,出発時刻,到着時刻,運賃種別,座席クラス,運賃(円),FOP/PP,マイル,LSP',
    );

    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    for (var leg in legs) {
      final l = leg as Map<String, dynamic>;
      final airline = l['airline'] ?? '';
      final date = l['date'] ?? '';
      final flightNum = l['flight_number'] ?? '';
      final dep = l['departure_airport'] ?? '';
      final arr = l['arrival_airport'] ?? '';
      final depTime = l['departure_time'] ?? '';
      final arrTime = l['arrival_time'] ?? '';
      final fareType = (l['fare_type'] as String? ?? '').replaceAll(',', ' ');
      final seatClass = l['seat_class'] ?? '';
      final fare = l['fare'] ?? 0;
      final fop = l['fop'] ?? 0;
      final miles = l['miles'] ?? 0;
      final lsp = l['lsp'] ?? 0;
      buf.writeln(
        '$airline,$date,$flightNum,$dep,$arr,$depTime,$arrTime,$fareType,$seatClass,$fare,$fop,$miles,$lsp',
      );
    }

    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final title = (itinerary['title'] as String? ?? 'flight_log').replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-]'),
      '_',
    );
    final now = DateTime.now();
    final filename =
        'MRP_${title}_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.csv';
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSVをダウンロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _shareToX(Map<String, dynamic> itinerary) {
    showDialog(
      context: context,
      builder: (context) => _ShareDialog(itinerary: itinerary),
    );
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

  DateTime? _getFirstLegDate(Map<String, dynamic> itinerary) {
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    if (legs.isEmpty) return null;
    final firstLeg = legs.first as Map<String, dynamic>;
    final dateStr = firstLeg['date'] as String?;
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  bool _isPastDate(Map<String, dynamic> itinerary) {
    final date = _getFirstLegDate(itinerary);
    if (date == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return date.isBefore(todayOnly);
  }

  bool _hasDate(Map<String, dynamic> itinerary) {
    return _getFirstLegDate(itinerary) != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadItineraries,
              child: Text(l10n.reload),
            ),
          ],
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;

    if (!isLoggedIn) {
      return _buildNotLoggedInView(l10n);
    }

    return Column(
      children: [
        Container(
          color: Colors.purple[50],
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.purple[700],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.purple[700],
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text('修行済み (${completedItineraries.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 6),
                    Text('予定 (${plannedItineraries.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildCompletedTab(l10n), _buildPlannedTab(l10n)],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTab(AppLocalizations l10n) {
    if (completedItineraries.isEmpty) {
      return _buildEmptyTabView('修行済みの旅程はありません', Icons.flight_land);
    }

    return RefreshIndicator(
      onRefresh: _loadItineraries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: _buildSummaryCard(l10n, isMobile),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItineraryCard(
                      completedItineraries[index],
                      isMobile,
                      isCompleted: true,
                    ),
                    childCount: completedItineraries.length,
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

  Widget _buildPlannedTab(AppLocalizations l10n) {
    if (plannedItineraries.isEmpty) {
      return _buildEmptyTabView(
        '予定の旅程はありません\nシミュレーションから追加してください',
        Icons.flight_takeoff,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItineraries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItineraryCard(
                      plannedItineraries[index],
                      isMobile,
                      isCompleted: false,
                    ),
                    childCount: plannedItineraries.length,
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

  Widget _buildEmptyTabView(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedInView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff,
                size: 48,
                color: Colors.purple[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.loginRequiredToSaveItineraries,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loginFromTopRight,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n, bool isMobile) {
    final hasJAL = totalFOP > 0 || _jalLegs > 0;
    final hasANA = totalPP > 0 || _anaLegs > 0;

    // JALのみ
    if (hasJAL && !hasANA) {
      return _buildSingleAirlineSummary(
        l10n,
        isMobile,
        isJAL: true,
        points: totalFOP,
        miles: _jalMiles,
        lsp: totalLSP,
        legs: _jalLegs,
      );
    }

    // ANAのみ
    if (hasANA && !hasJAL) {
      return _buildSingleAirlineSummary(
        l10n,
        isMobile,
        isJAL: false,
        points: totalPP,
        miles: _anaMiles,
        lsp: 0,
        legs: _anaLegs,
      );
    }

    // 混在: 上下分割
    return Column(
      children: [
        // JAL（赤）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[700]!, Colors.red[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.yellow,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'JAL 修行実績',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: isMobile ? 16 : 32,
                runSpacing: 8,
                children: [
                  _buildStatItemInline('FOP', totalFOP),
                  _buildStatItemInline(l10n.miles, _jalMiles),
                  _buildStatItemInline(l10n.legs, _jalLegs),
                  if (totalLSP > 0) _buildStatItemInline('LSP', totalLSP),
                ],
              ),
            ],
          ),
        ),
        // ANA（青）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.yellow,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ANA 修行実績',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: isMobile ? 16 : 32,
                runSpacing: 8,
                children: [
                  _buildStatItemInline('PP', totalPP),
                  _buildStatItemInline(l10n.miles, _anaMiles),
                  _buildStatItemInline(l10n.legs, _anaLegs),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItemInline(String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
        ),
        Text(
          _formatNumber(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleAirlineSummary(
    AppLocalizations l10n,
    bool isMobile, {
    required bool isJAL,
    required int points,
    required int miles,
    required int lsp,
    required int legs,
  }) {
    final colors = isJAL
        ? [Colors.red[700]!, Colors.red[500]!]
        : [Colors.blue[700]!, Colors.blue[500]!];
    final shadowColor = isJAL ? Colors.red : Colors.blue;
    final pointLabel = isJAL ? 'FOP' : 'PP';
    final airlineName = isJAL ? 'JAL' : 'ANA';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.yellow, size: 24),
              const SizedBox(width: 8),
              Text(
                '$airlineName 修行実績',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: isMobile ? 16 : 32,
            runSpacing: 12,
            children: [
              _buildStatItem(pointLabel, points),
              _buildStatItem(l10n.miles, miles),
              _buildStatItem(l10n.legs, legs),
              if (isJAL && lsp > 0) _buildStatItem('LSP', lsp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
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

  Widget _buildItineraryCard(
    Map<String, dynamic> itinerary,
    bool isMobile, {
    required bool isCompleted,
  }) {
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

    final isPast = _isPastDate(itinerary);
    final hasDate = _hasDate(itinerary);

    String unitPrice = '-';
    if (totalFare > 0 && (totalFop > 0 || totalPp > 0)) {
      final points = totalFop > 0 ? totalFop : totalPp;
      unitPrice = '¥${(totalFare / points).toStringAsFixed(1)}';
    }

    String dateDisplay = createdAt;
    Widget? dateBadge;
    if (!isCompleted) {
      if (!hasDate) {
        dateBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '📅 予定',
            style: TextStyle(fontSize: 10, color: Colors.purple[700]),
          ),
        );
      } else if (isPast) {
        dateBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '過去日付',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
        );
      }
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
          InkWell(
            onTap: () => setState(() => _expandedId = isExpanded ? null : id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dateBadge != null) ...[
                        dateBadge,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        dateDisplay,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (totalFop > 0)
                        _buildStatChip(
                          'FOP',
                          _formatNumber(totalFop),
                          Colors.red,
                        ),
                      if (totalPp > 0)
                        _buildStatChip(
                          'PP',
                          _formatNumber(totalPp),
                          Colors.blue,
                        ),
                      _buildStatChip(
                        l10n.miles,
                        _formatNumber(totalMiles),
                        Colors.orange,
                      ),
                      if (totalLsp > 0)
                        _buildStatChip(
                          'LSP',
                          _formatNumber(totalLsp),
                          Colors.purple,
                        ),
                      if (totalFare > 0)
                        _buildStatChip(
                          '',
                          '¥${_formatNumber(totalFare)}',
                          Colors.green,
                        ),
                      if (unitPrice != '-')
                        _buildUnitPriceChip(
                          unitPrice,
                          totalFop > 0 ? 'FOP' : 'PP',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isCompleted && isPast) ...[
            Container(height: 1, color: Colors.grey[200]),
            InkWell(
              onTap: () => _markAsCompleted(id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green[600]!, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '搭乗済み → 修行済みに移動',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (isExpanded) ...[
            Container(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...legs.map(
                    (leg) => _buildLegSummary(leg as Map<String, dynamic>),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportCsv(itinerary),
                        icon: const Icon(Icons.download, size: 16),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('CSV'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple[700],
                          side: BorderSide(color: Colors.purple[200]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _shareToX(itinerary),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(l10n.share),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteItinerary(id),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(l10n.delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red[200]!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.yellow[900],
        ),
      ),
    );
  }

  Widget _buildLegSummary(Map<String, dynamic> leg) {
    final airline = leg['airline'] as String? ?? '';
    final dep = leg['departure_airport'] as String? ?? '';
    final arr = leg['arrival_airport'] as String? ?? '';
    final flightNumber = leg['flight_number'] as String? ?? '';
    final date = leg['date'] as String? ?? '';
    final depTime = leg['departure_time'] as String? ?? '';
    final arrTime = leg['arrival_time'] as String? ?? '';
    final fop = leg['fop'] as int? ?? 0;
    final miles = leg['miles'] as int? ?? 0;
    final lsp = leg['lsp'] as int? ?? 0;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;
    final pointLabel = airline == 'JAL' ? 'FOP' : 'PP';

    // 表示文字列を組み立て
    String statsText =
        '$pointLabel:${_formatNumber(fop)} / ${_formatNumber(miles)}M';
    if (airline == 'JAL' && lsp > 0) {
      statsText += ' / ${lsp}LSP';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 航空会社
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: airlineColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              airline,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 便名
          SizedBox(
            width: 40,
            child: Text(
              flightNumber,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          // 日付（あれば）
          if (date.isNotEmpty) ...[
            Text(date, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(width: 6),
          ],
          // 出発時刻
          if (depTime.isNotEmpty)
            Text(
              '$depTime ',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          // 出発空港
          Text(
            dep,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          // 矢印
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
          ),
          // 到着空港
          Text(
            arr,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          // 到着時刻
          if (arrTime.isNotEmpty)
            Text(
              ' $arrTime',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          const Spacer(),
          // FOP/PP + マイル + LSP（JALのみ）
          Text(
            statsText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: airlineColor,
            ),
          ),
        ],
      ),
    );
  }
}

// シェアダイアログ
class _ShareDialog extends StatefulWidget {
  final Map<String, dynamic> itinerary;

  const _ShareDialog({required this.itinerary});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _themeController = TextEditingController();
  final _commentController = TextEditingController();
  bool _showDetails = false;

  @override
  void dispose() {
    _themeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number == 0) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  List<String> _generateShareTexts() {
    final itinerary = widget.itinerary;
    final theme = _themeController.text.trim();
    final comment = _commentController.text.trim();

    final title = itinerary['title'] as String? ?? '';
    final fop = itinerary['total_fop'] as int? ?? 0;
    final pp = itinerary['total_pp'] as int? ?? 0;
    final miles = itinerary['total_miles'] as int? ?? 0;
    final lsp = itinerary['total_lsp'] as int? ?? 0;
    final fare = itinerary['total_fare'] as int? ?? 0;
    final legs = itinerary['legs'] as List<dynamic>? ?? [];

    // 日付取得
    String dateStr = '';
    if (legs.isNotEmpty) {
      final firstLeg = legs.first as Map<String, dynamic>;
      dateStr = firstLeg['date'] as String? ?? '';
    }

    // 単価計算
    String unitPrice = '';
    final pointLabel = fop > 0 ? 'FOP' : 'PP';
    final points = fop > 0 ? fop : pp;
    if (fare > 0 && points > 0) {
      unitPrice = '¥${(fare / points).toStringAsFixed(1)}/$pointLabel';
    }

    // ヘッダー部分を生成
    final header = StringBuffer();
    if (theme.isNotEmpty) {
      header.writeln('✈️【$theme】');
    } else {
      header.writeln('✈️【修行プラン】');
    }
    header.writeln('');
    if (dateStr.isNotEmpty) {
      header.writeln('🗓 $dateStr');
    }
    header.writeln('🛫 $title');
    header.writeln('');

    // 統計部分
    final stats = StringBuffer();
    if (fop > 0) {
      stats.write(
        '📊 FOP: ${_formatNumber(fop)} / マイル: ${_formatNumber(miles)}',
      );
      if (lsp > 0) stats.write(' / ${lsp}LSP');
      stats.writeln('');
    } else if (pp > 0) {
      stats.writeln(
        '📊 PP: ${_formatNumber(pp)} / マイル: ${_formatNumber(miles)}',
      );
    }
    if (fare > 0) {
      stats.write('💰 ¥${_formatNumber(fare)}');
      if (unitPrice.isNotEmpty) {
        stats.writeln('（$unitPrice）');
      } else {
        stats.writeln('');
      }
    }

    // フッター部分
    final footer = StringBuffer();
    if (comment.isNotEmpty) {
      footer.writeln('');
      footer.writeln('💬 $comment');
    }
    footer.writeln('');
    final airline = fop > 0 ? 'JAL' : 'ANA';
    footer.writeln('#MRP修行プラン #${airline}修行');
    footer.writeln('mileage-run-planner.web.app');

    // 詳細なしの場合
    if (!_showDetails) {
      final text =
          '${header.toString()}${stats.toString()}${footer.toString()}';
      return [text];
    }

    // 詳細ありの場合 - レグ情報を生成
    final legLines = <String>[];
    legLines.add('━━━━━━━━━━━━━━');
    for (var leg in legs) {
      final l = leg as Map<String, dynamic>;
      final legAirline = l['airline'] as String? ?? '';
      final flightNum = l['flight_number'] as String? ?? '';
      final dep = l['departure_airport'] as String? ?? '';
      final arr = l['arrival_airport'] as String? ?? '';
      final depTime = l['departure_time'] as String? ?? '';
      final arrTime = l['arrival_time'] as String? ?? '';
      final legDate = l['date'] as String? ?? '';

      String line = '$legAirline $flightNum';
      if (legDate.isNotEmpty && legs.length > 1) {
        line += ' | $legDate';
      }
      if (depTime.isNotEmpty) {
        line += ' $depTime';
      }
      line += ' $dep → $arr';
      if (arrTime.isNotEmpty) {
        line += ' $arrTime';
      }
      legLines.add(line);
    }
    legLines.add('━━━━━━━━━━━━━━');

    // 280文字で分割
    const maxLength = 270; // URLの余裕を持たせる
    final texts = <String>[];

    // 最初のツイート
    var current = StringBuffer();
    current.write(header.toString());
    current.write(stats.toString());

    int legIndex = 0;
    for (var legLine in legLines) {
      if (current.length + legLine.length + 1 > maxLength &&
          current.length > 0) {
        texts.add(current.toString());
        current = StringBuffer();
      }
      current.writeln(legLine);
      legIndex++;
    }

    // 最後にフッターを追加
    if (current.length + footer.length > maxLength && current.length > 0) {
      texts.add(current.toString());
      current = StringBuffer();
    }
    current.write(footer.toString());
    texts.add(current.toString());

    // 複数に分かれた場合、番号を付ける
    if (texts.length > 1) {
      final total = texts.length;
      for (int i = 0; i < texts.length; i++) {
        texts[i] = '[${i + 1}/$total]\n${texts[i]}';
      }
    }

    return texts;
  }

  void _share() {
    final texts = _generateShareTexts();
    Navigator.pop(context);

    // 最初のツイートを開く
    final text = Uri.encodeComponent(texts[0]);
    final url = 'https://twitter.com/intent/tweet?text=$text';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    // 複数ある場合は通知
    if (texts.length > 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${texts.length}件に分割されました。続きは順番に投稿してください。'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '次へ',
                onPressed: () => _shareNext(texts, 1),
              ),
            ),
          );
        }
      });
    }
  }

  void _shareNext(List<String> texts, int index) {
    if (index >= texts.length) return;

    final text = Uri.encodeComponent(texts[index]);
    final url = 'https://twitter.com/intent/tweet?text=$text';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    if (index + 1 < texts.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('[${index + 2}/${texts.length}] を投稿してください'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '次へ',
                onPressed: () => _shareNext(texts, index + 1),
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final legs = widget.itinerary['legs'] as List<dynamic>? ?? [];
    final shareTexts = _generateShareTexts();
    final hasMultipleTweets = shareTexts.length > 1;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.share, color: Colors.blue),
          SizedBox(width: 8),
          Text('Xでシェア', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // テーマ入力
            TextField(
              controller: _themeController,
              decoration: const InputDecoration(
                labelText: 'テーマ（任意）',
                hintText: '例: W杯追っかけ修行',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // コメント入力
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'コメント（任意）',
                hintText: '例: 初修行完了！',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // 詳細表示チェック
            CheckboxListTile(
              value: _showDetails,
              onChanged: (v) => setState(() => _showDetails = v ?? false),
              title: const Text('フライト詳細を含める', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                '${legs.length}レグの時刻表を表示',
                style: const TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 16),
            // プレビューセクション
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.preview, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'プレビュー${hasMultipleTweets ? "（${shareTexts.length}件に分割）" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...shareTexts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final text = entry.value;
                    return Container(
                      margin: EdgeInsets.only(top: index > 0 ? 8 : 0),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasMultipleTweets)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'ツイート ${index + 1}/${shareTexts.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          Text(
                            text,
                            style: const TextStyle(fontSize: 11, height: 1.4),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${text.length}/280文字',
                              style: TextStyle(
                                fontSize: 10,
                                color: text.length > 280
                                    ? Colors.red
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton.icon(
          onPressed: _share,
          icon: const Icon(Icons.send, size: 18),
          label: Text(
            hasMultipleTweets ? 'シェア (1/${shareTexts.length})' : 'シェア',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
