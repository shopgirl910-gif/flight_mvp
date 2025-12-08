import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;

  // 集計値
  int totalFOP = 0;
  int totalMiles = 0;

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
      
      // 集計計算
      int fopSum = 0;
      int milesSum = 0;
      for (var record in list) {
        fopSum += (record['final_points'] as int?) ?? 0;
        milesSum += (record['final_miles'] as int?) ?? 0;
      }

      setState(() {
        history = list;
        totalFOP = fopSum;
        totalMiles = milesSum;
        isLoading = false;
      });
    } catch (e) {
      print('履歴取得エラー: $e');
      setState(() => isLoading = false);
    }
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('累計FOP', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '$totalFOP',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('累計マイル', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '$totalMiles',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('搭乗回数', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${history.length}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 履歴リスト
                Expanded(
                  child: history.isEmpty
                      ? const Center(
                          child: Text('履歴がありません', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final record = history[index];
                            return _buildHistoryCard(record);
                          },
                        ),
                ),
              ],
            ),
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
    final flightDate = record['flight_date'];
    final createdAt = record['created_at'];

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
        subtitle: Text('$fareType / $seatClass'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'FOP: $fop',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            Text(
              'マイル: $miles',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onLongPress: () => _deleteRecord(record['id']),
      ),
    );
  }
}