import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> filteredHistory = [];
  bool isLoading = true;
  String selectedAirline = '全て';  // フィルタ用

  // 集計値
  int totalFOP = 0;
  int totalMiles = 0;
  int totalFare = 0;      // 総支出
  int fareCount = 0;      // 運賃入力件数

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('flight_calculations')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      
      setState(() {
        history = list;
        isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      print('履歴取得エラー: $e');
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    List<Map<String, dynamic>> filtered;
    if (selectedAirline == '全て') {
      filtered = history;
    } else {
      filtered = history.where((r) => r['airline'] == selectedAirline).toList();
    }

    // 集計計算
    int fopSum = 0;
    int milesSum = 0;
    int fareSum = 0;
    int fareNum = 0;
    for (var record in filtered) {
      fopSum += (record['final_points'] as int?) ?? 0;
      milesSum += (record['final_miles'] as int?) ?? 0;
      final fare = record['fare_amount'] as int?;
      if (fare != null && fare > 0) {
        fareSum += fare;
        fareNum++;
      }
    }

    setState(() {
      filteredHistory = filtered;
      totalFOP = fopSum;
      totalMiles = milesSum;
      totalFare = fareSum;
      fareCount = fareNum;
    });
  }

  // 平均単価計算
  String get averageUnitPrice {
    if (totalFOP == 0 || totalFare == 0) return 'N/A';
    return '${(totalFare / totalFOP).toStringAsFixed(1)}円';
  }

  Future<void> _deleteRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('flight_calculations')
          .delete()
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました'), backgroundColor: Colors.green),
        );
      }
      _fetchHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搭乗履歴'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // 航空会社フィルタ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: selectedAirline,
              dropdownColor: Colors.indigo[700],
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: ['全て', 'JAL', 'ANA'].map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (v) {
                setState(() => selectedAirline = v!);
                _applyFilter();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _fetchHistory();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 集計サマリー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.indigo[50],
                  child: Column(
                    children: [
                      // 上段: FOP, マイル, 搭乗回数
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            selectedAirline == 'ANA' ? '累計PP' : '累計FOP',
                            '$totalFOP',
                            Colors.indigo,
                          ),
                          _buildSummaryItem('累計マイル', '$totalMiles', Colors.indigo),
                          _buildSummaryItem('搭乗回数', '${filteredHistory.length}', Colors.indigo),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 下段: 総支出, 平均単価
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            '総支出',
                            totalFare > 0 ? '¥${_formatNumber(totalFare)}' : 'N/A',
                            Colors.green[700]!,
                          ),
                          _buildSummaryItem(
                            '平均単価',
                            averageUnitPrice,
                            Colors.orange[700]!,
                          ),
                          _buildSummaryItem(
                            '運賃入力率',
                            '${filteredHistory.isNotEmpty ? (fareCount * 100 / filteredHistory.length).round() : 0}%',
                            Colors.grey[600]!,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 履歴リスト
                Expanded(
                  child: filteredHistory.isEmpty
                      ? const Center(
                          child: Text('履歴がありません', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: filteredHistory.length,
                          itemBuilder: (context, index) {
                            final record = filteredHistory[index];
                            return _buildHistoryCard(record);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final airline = record['airline'] ?? '';
    final departure = record['departure'] ?? '';
    final arrival = record['arrival'] ?? '';
    final fareType = record['fare_type'] ?? '';
    final seatClass = record['seat_class'] ?? '';
    final fop = record['final_points'] ?? 0;
    final miles = record['final_miles'] ?? 0;
    final fareAmount = record['fare_amount'] as int?;
    final flightDate = record['flight_date'];
    final createdAt = record['created_at'];

    // 単価計算
    String unitPrice = 'N/A';
    if (fareAmount != null && fareAmount > 0 && fop > 0) {
      unitPrice = '${(fareAmount / fop).toStringAsFixed(1)}円';
    }

    // 日付フォーマット
    String dateDisplay = '';
    if (flightDate != null) {
      dateDisplay = flightDate.toString().substring(0, 10);
    } else if (createdAt != null) {
      dateDisplay = '(${createdAt.toString().substring(0, 10)})';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: airline == 'JAL' ? Colors.red[100] : Colors.blue[100],
          child: Text(
            airline,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: airline == 'JAL' ? Colors.red : Colors.blue,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              '$departure → $arrival',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              dateDisplay,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text('$fareType / $seatClass'),
            if (fareAmount != null && fareAmount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '¥${_formatNumber(fareAmount)}',
                  style: TextStyle(fontSize: 11, color: Colors.green[700]),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${airline == 'JAL' ? 'FOP' : 'PP'}: $fop',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: airline == 'JAL' ? Colors.red[700] : Colors.blue[700],
              ),
            ),
            Text(
              'マイル: $miles',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (unitPrice != 'N/A')
              Text(
                unitPrice,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
          ],
        ),
        onLongPress: () => _deleteRecord(record['id']),
      ),
    );
  }
}
