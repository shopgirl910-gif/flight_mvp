import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> itineraries = [];
  bool isLoading = true;
  String? errorMessage;
  String? _expandedId; // 展開中の旅程ID

  @override
  void initState() {
    super.initState();
    _loadItineraries();
    // ログイン状態の変化を監視
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _loadItineraries();
      }
    });
  }

  // 外部から呼び出し可能なリフレッシュメソッド
  void refresh() {
    _loadItineraries();
  }

  Future<void> _loadItineraries() async {
    setState(() => isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // ログインしていない or 匿名ユーザーの場合は空リスト
      if (user == null || user.isAnonymous) {
        setState(() {
          itineraries = [];
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
      
      setState(() {
        itineraries = List<Map<String, dynamic>>.from(response);
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

  Future<void> _deleteItinerary(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この旅程を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('saved_itineraries').delete().eq('id', id);
        _loadItineraries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除しました'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadItineraries, child: const Text('再読み込み')),
        ]),
      );
    }

    if (itineraries.isEmpty) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null && !user.isAnonymous;
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isLoggedIn ? Icons.history : Icons.login, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isLoggedIn ? '保存された旅程がありません' : '旅程を保存するにはログインが必要です',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isLoggedIn ? 'Simulateタブで旅程を作成し、保存してください' : '右上のログインボタンからログインしてください',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItineraries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return ListView.builder(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            itemCount: itineraries.length,
            itemBuilder: (context, index) => _buildItineraryCard(itineraries[index], isMobile),
          );
        },
      ),
    );
  }

  Widget _buildItineraryCard(Map<String, dynamic> itinerary, bool isMobile) {
    final id = itinerary['id'] as String;
    final title = itinerary['title'] as String? ?? '無題';
    final totalFop = itinerary['total_fop'] as int? ?? 0;
    final totalPp = itinerary['total_pp'] as int? ?? 0;
    final totalMiles = itinerary['total_miles'] as int? ?? 0;
    final totalLsp = itinerary['total_lsp'] as int? ?? 0;
    final totalFare = itinerary['total_fare'] as int? ?? 0;
    final createdAt = _formatDate(itinerary['created_at'] as String?);
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    final isExpanded = _expandedId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        // ヘッダー行（常に表示）
        InkWell(
          onTap: () => setState(() => _expandedId = isExpanded ? null : id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              // 展開ボタン
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              // タイトル＆日時
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(createdAt, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ]),
              ),
              // サマリー統計
              if (totalFop > 0) _buildMiniChip('FOP', _formatNumber(totalFop), Colors.red),
              if (totalPp > 0) _buildMiniChip('PP', _formatNumber(totalPp), Colors.blue),
              const SizedBox(width: 8),
              // 削除ボタン
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.grey[400],
                onPressed: () => _deleteItinerary(id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '削除',
              ),
            ]),
          ),
        ),
        // 展開時の詳細
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 統計チップ
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (totalFop > 0) _buildStatChip('FOP', _formatNumber(totalFop), Colors.red),
                if (totalPp > 0) _buildStatChip('PP', _formatNumber(totalPp), Colors.blue),
                if (totalMiles > 0) _buildStatChip('マイル', _formatNumber(totalMiles), Colors.orange),
                if (totalLsp > 0) _buildStatChip('LSP', _formatNumber(totalLsp), Colors.purple),
                if (totalFare > 0) _buildStatChip('総額', '¥${_formatNumber(totalFare)}', Colors.green),
              ]),
              const SizedBox(height: 12),
              // レグ一覧
              ...legs.map((leg) => _buildLegSummary(leg as Map<String, dynamic>)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildMiniChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text('$value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildLegSummary(Map<String, dynamic> leg) {
    final airline = leg['airline'] as String? ?? '';
    final dep = leg['departure_airport'] as String? ?? '';
    final arr = leg['arrival_airport'] as String? ?? '';
    final flightNumber = leg['flight_number'] as String? ?? '';
    final fop = leg['fop'] as int? ?? 0;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(4)),
          child: Text(airline, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Text('$flightNumber', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Text('$dep → $arr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('${airline == "JAL" ? "FOP" : "PP"}: $fop', style: TextStyle(fontSize: 11, color: airlineColor)),
      ]),
    );
  }

  void _showItineraryDetail(Map<String, dynamic> itinerary) {
    final title = itinerary['title'] as String? ?? '無題';
    final legs = itinerary['legs'] as List<dynamic>? ?? [];
    final jalCard = itinerary['jal_card'] as String?;
    final anaCard = itinerary['ana_card'] as String?;
    final jalStatus = itinerary['jal_status'] as String?;
    final anaStatus = itinerary['ana_status'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ハンドル
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // タイトル
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // カード・ステータス情報
            if (jalCard != null && jalCard != '-') Text('JALカード: $jalCard', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (jalStatus != null && jalStatus != '-') Text('JALステータス: $jalStatus', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (anaCard != null && anaCard != '-') Text('ANAカード: $anaCard', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (anaStatus != null && anaStatus != '-') Text('ANAステータス: $anaStatus', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 16),
            const Divider(),
            // レグ一覧
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: legs.length,
                itemBuilder: (context, index) => _buildDetailLegCard(legs[index] as Map<String, dynamic>, index),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailLegCard(Map<String, dynamic> leg, int index) {
    final airline = leg['airline'] as String? ?? '';
    final date = leg['date'] as String? ?? '';
    final flightNumber = leg['flight_number'] as String? ?? '';
    final dep = leg['departure_airport'] as String? ?? '';
    final arr = leg['arrival_airport'] as String? ?? '';
    final depTime = leg['departure_time'] as String? ?? '';
    final arrTime = leg['arrival_time'] as String? ?? '';
    final fareType = leg['fare_type'] as String? ?? '';
    final seatClass = leg['seat_class'] as String? ?? '';
    final fareAmount = leg['fare_amount'] as int? ?? 0;
    final fop = leg['fop'] as int? ?? 0;
    final miles = leg['miles'] as int? ?? 0;
    final lsp = leg['lsp'] as int? ?? 0;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ヘッダー
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(4)),
              child: Text(airline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text('$flightNumber', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
          const SizedBox(height: 8),
          // 区間
          Row(children: [
            Text(dep, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(arr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$depTime - $arrTime', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
          const SizedBox(height: 8),
          // 詳細
          Wrap(spacing: 8, runSpacing: 4, children: [
            Text(fareType, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(seatClass, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (fareAmount > 0) Text('¥${_formatNumber(fareAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ]),
          const SizedBox(height: 8),
          // ポイント
          Row(children: [
            _buildStatChip(airline == 'JAL' ? 'FOP' : 'PP', _formatNumber(fop), airlineColor),
            const SizedBox(width: 8),
            _buildStatChip('マイル', _formatNumber(miles), Colors.orange),
            if (airline == 'JAL' && lsp > 0) ...[
              const SizedBox(width: 8),
              _buildStatChip('LSP', _formatNumber(lsp), Colors.purple),
            ],
          ]),
        ]),
      ),
    );
  }
}
