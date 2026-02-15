import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  String? _departureCode;
  String? _arrivalCode;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // 主要空港リスト（後でDBから取得に変更）
  final List<Map<String, String>> _airports = [
    {'code': 'HND', 'name': '羽田'},
    {'code': 'NRT', 'name': '成田'},
    {'code': 'KIX', 'name': '関西'},
    {'code': 'ITM', 'name': '伊丹'},
    {'code': 'CTS', 'name': '新千歳'},
    {'code': 'FUK', 'name': '福岡'},
    {'code': 'OKA', 'name': '那覇'},
    {'code': 'NGO', 'name': '中部'},
  ];

  Future<void> _searchFlights() async {
    if (_departureCode == null || _arrivalCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出発地と到着地を選択してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await SupabaseService.searchFlights(
        departureCode: _departureCode!,
        arrivalCode: _arrivalCode!,
        date: _selectedDate.toIso8601String().split('T')[0],
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'フライト検索',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // 出発地選択
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '出発地',
              border: OutlineInputBorder(),
            ),
            value: _departureCode,
            items: _airports.map((airport) {
              return DropdownMenuItem(
                value: airport['code'],
                child: Text('${airport['name']} (${airport['code']})'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _departureCode = value),
          ),
          const SizedBox(height: 12),
          
          // 到着地選択
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '到着地',
              border: OutlineInputBorder(),
            ),
            value: _arrivalCode,
            items: _airports.map((airport) {
              return DropdownMenuItem(
                value: airport['code'],
                child: Text('${airport['name']} (${airport['code']})'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _arrivalCode = value),
          ),
          const SizedBox(height: 12),
          
          // 日付選択
          ListTile(
            title: const Text('搭乗日'),
            subtitle: Text('${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
          ),
          const SizedBox(height: 16),
          
          // 検索ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _searchFlights,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('検索', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
          
          // 検索結果
          const Text(
            '検索結果',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(child: Text('検索結果がありません'))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final flight = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            '${flight['airline_code']} ${flight['flight_number']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${flight['departure_time']} → ${flight['arrival_time']}',
                          ),
                          trailing: Text(
                            '${flight['departure_code']} → ${flight['arrival_code']}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}