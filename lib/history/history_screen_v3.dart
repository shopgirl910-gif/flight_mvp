import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html;
import 'dart:convert';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> filteredHistory = [];
  bool isLoading = true;
  String selectedAirline = '全て';

  // JAL集計
  int jalFOP = 0;
  int jalMiles = 0;
  int jalCount = 0;
  int jalFare = 0;
  int jalFareCount = 0;

  // ANA集計
  int anaPP = 0;
  int anaMiles = 0;
  int anaCount = 0;
  int anaFare = 0;
  int anaFareCount = 0;

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

    // JAL集計
    int jFOP = 0, jMiles = 0, jCount = 0, jFare = 0, jFareNum = 0;
    // ANA集計
    int aPP = 0, aMiles = 0, aCount = 0, aFare = 0, aFareNum = 0;

    for (var record in history) {
      final airline = record['airline'] ?? '';
      final points = (record['final_points'] as int?) ?? 0;
      final miles = (record['final_miles'] as int?) ?? 0;
      final fare = record['fare_amount'] as int?;

      if (airline == 'JAL') {
        jFOP += points;
        jMiles += miles;
        jCount++;
        if (fare != null && fare > 0) {
          jFare += fare;
          jFareNum++;
        }
      } else if (airline == 'ANA') {
        aPP += points;
        aMiles += miles;
        aCount++;
        if (fare != null && fare > 0) {
          aFare += fare;
          aFareNum++;
        }
      }
    }

    setState(() {
      filteredHistory = filtered;
      jalFOP = jFOP;
      jalMiles = jMiles;
      jalCount = jCount;
      jalFare = jFare;
      jalFareCount = jFareNum;
      anaPP = aPP;
      anaMiles = aMiles;
      anaCount = aCount;
      anaFare = aFare;
      anaFareCount = aFareNum;
    });
  }

  String _jalUnitPrice() {
    if (jalFOP == 0 || jalFare == 0) return 'N/A';
    return '${(jalFare / jalFOP).toStringAsFixed(1)}円';
  }

  String _anaUnitPrice() {
    if (anaPP == 0 || anaFare == 0) return 'N/A';
    return '${(anaFare / anaPP).toStringAsFixed(1)}円';
  }

  void _exportCSV() {
    if (filteredHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートするデータがありません'), backgroundColor: Colors.orange),
      );
      return;
    }

    final header = ['日付', '航空会社', '出発地', '到着地', '運賃種別', '座席クラス', 'FOP/PP', 'マイル', '運賃(円)', '単価(円)'];
    final rows = <List<String>>[header];
    
    for (var record in filteredHistory) {
      final fop = record['final_points'] ?? 0;
      final fareAmount = record['fare_amount'] as int?;
      String unitPrice = '';
      if (fareAmount != null && fareAmount > 0 && fop > 0) {
        unitPrice = (fareAmount / fop).toStringAsFixed(1);
      }
      
      String dateStr = '';
      if (record['flight_date'] != null) {
        dateStr = record['flight_date'].toString().substring(0, 10);
      }

      rows.add([
        dateStr,
        record['airline'] ?? '',
        record['departure'] ?? '',
        record['arrival'] ?? '',
        record['fare_type'] ?? '',
        record['seat_class'] ?? '',
        fop.toString(),
        (record['final_miles'] ?? 0).toString(),
        fareAmount?.toString() ?? '',
        unitPrice,
      ]);
    }

    final csvContent = rows.map((row) => row.map((cell) => '"$cell"').join(',')).join('\n');
    final bom = '\uFEFF';
    final csvWithBom = bom + csvContent;

    final bytes = utf8.encode(csvWithBom);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final now = DateTime.now();
    final fileName = '修行履歴_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName をダウンロードしました'), backgroundColor: Colors.green),
    );
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
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 航空会社別サマリー
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    // JAL行
                    if (jalCount > 0)
                      _buildAirlineSummaryRow(
                        'JAL',
                        Colors.red,
                        'FOP',
                        jalFOP,
                        jalMiles,
                        jalCount,
                        jalFare,
                        _jalUnitPrice(),
                        jalFareCount,
                      ),
                    if (jalCount > 0 && anaCount > 0)
                      const Divider(height: 16),
                    // ANA行
                    if (anaCount > 0)
                      _buildAirlineSummaryRow(
                        'ANA',
                        Colors.blue,
                        'PP',
                        anaPP,
                        anaMiles,
                        anaCount,
                        anaFare,
                        _anaUnitPrice(),
                        anaFareCount,
                      ),
                  ],
                ),
              ),

              // フィルタ＆エクスポート
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('表示: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ChoiceChip(
                          label: const Text('全て'),
                          selected: selectedAirline == '全て',
                          onSelected: (_) { setState(() => selectedAirline = '全て'); _applyFilter(); },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('JAL'),
                          selected: selectedAirline == 'JAL',
                          selectedColor: Colors.red[100],
                          onSelected: (_) { setState(() => selectedAirline = 'JAL'); _applyFilter(); },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('ANA'),
                          selected: selectedAirline == 'ANA',
                          selectedColor: Colors.blue[100],
                          onSelected: (_) { setState(() => selectedAirline = 'ANA'); _applyFilter(); },
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'CSVエクスポート',
                      onPressed: _exportCSV,
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
          );
  }

  Widget _buildAirlineSummaryRow(
    String airline,
    Color color,
    String pointLabel,
    int points,
    int miles,
    int count,
    int fare,
    String unitPrice,
    int fareCount,
  ) {
    return Row(
      children: [
        // 航空会社ラベル
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            airline,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        // 統計項目
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildSummaryItem(pointLabel, _formatNumber(points), color),
              _buildSummaryItem('マイル', _formatNumber(miles), color),
              _buildSummaryItem('搭乗', '$count回', color),
              _buildSummaryItem('総支出', fare > 0 ? '¥${_formatNumber(fare)}' : 'N/A', Colors.green[700]!),
              _buildSummaryItem('単価', unitPrice, Colors.orange[700]!),
              _buildSummaryItem('入力率', count > 0 ? '${(fareCount * 100 / count).round()}%' : '0%', Colors.grey[600]!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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

    String unitPrice = 'N/A';
    if (fareAmount != null && fareAmount > 0 && fop > 0) {
      unitPrice = '${(fareAmount / fop).toStringAsFixed(1)}円';
    }

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