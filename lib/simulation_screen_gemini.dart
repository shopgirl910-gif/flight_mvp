import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';
import 'l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool isBlueprintMode = false;
  List<Map<String, dynamic>> legs = [];
  int? expandedLegId;

  // オリジナルコードの全コントローラー・データを維持
  final Map<int, TextEditingController> dateControllers = {};
  final Map<int, TextEditingController> flightNumberControllers = {};
  final Map<int, TextEditingController> departureTimeControllers = {};
  final Map<int, TextEditingController> arrivalTimeControllers = {};
  final Map<int, TextEditingController> fareAmountControllers = {};
  final Map<int, TextEditingController> departureAirportControllers = {};
  final Map<int, TextEditingController> arrivalAirportControllers = {};
  final Map<int, String> selectedAirlines = {}; // 'ANA' or 'JAL'

  final Map<int, List<Map<String, dynamic>>> availableFlights = {};
  final Map<int, List<String>> availableDestinations = {};

  final List<String> allAirports = ["HND", "NRT", "ITM", "KIX", "NGO", "FUK", "CTS", "OKA", "ISG", "MMY"];

  @override
  void initState() {
    super.initState();
    _addNewLeg();
  }

  // --- オリジナルから継承したデータフェッチロジック ---
  Future<void> _onDepartureChanged(int index, String deptCode) async {
    final legId = legs[index]['id'];
    final airline = selectedAirlines[legId] ?? 'ANA';
    
    // ここで本来の _fetchAvailableFlights(index, deptCode, airline) を呼び出し
    // 今回は挙動確認のためシミュレーション値をセット
    setState(() {
      departureAirportControllers[legId]!.text = deptCode;
      arrivalAirportControllers[legId]!.clear();
      departureTimeControllers[legId]!.clear();
      
      // 仮の就航路線データ（JALとANAで変える例）
      if (airline == "ANA") {
        availableDestinations[legId] = ["OKA", "CTS", "FUK"];
      } else {
        availableDestinations[legId] = ["HND", "ITM", "ISG"];
      }
    });
  }

  Future<void> _onDestinationChanged(int index, String destCode) async {
    final legId = legs[index]['id'];
    setState(() {
      arrivalAirportControllers[legId]!.text = destCode;
      // 仮の運行ダイヤデータ
      final prefix = selectedAirlines[legId] == "ANA" ? "NH" : "JL";
      availableFlights[legId] = [
        {"time": "08:00", "no": "${prefix}101"},
        {"time": "13:30", "no": "${prefix}105"},
        {"time": "18:20", "no": "${prefix}110"},
      ];
    });
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isBlueprintMode 
              ? [const Color(0xFF001F3F), const Color(0xFF003366)] 
              : [const Color(0xFF0F0F1A), const Color(0xFF1B1B2F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: legs.length,
                  itemBuilder: (context, index) => _buildModernLegCard(index, l10n),
                ),
              ),
              _buildBottomActionDock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildModeToggle(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isBlueprintMode ? "BLUEPRINT" : "LOGBOOK", style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const Text("32,500 / 50,000 PP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: 0.65, backgroundColor: Colors.white10, color: Colors.cyanAccent, minHeight: 4),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          _buildModeTab("実績 Log", !isBlueprintMode, () => setState(() => isBlueprintMode = false)),
          _buildModeTab("妄想 Blueprint", isBlueprintMode, () => setState(() => isBlueprintMode = true)),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: active ? Colors.white10 : Colors.transparent, borderRadius: BorderRadius.circular(22)),
          child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 12))),
        ),
      ),
    );
  }

  Widget _buildModernLegCard(int index, AppLocalizations l10n) {
    final legId = legs[index]['id'];
    final isExpanded = expandedLegId == legId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isExpanded ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? Colors.cyanAccent.withOpacity(0.4) : Colors.white10),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => expandedLegId = isExpanded ? null : legId),
            leading: CircleAvatar(
              backgroundColor: selectedAirlines[legId] == "ANA" ? Colors.blue.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              child: Text(selectedAirlines[legId] == "ANA" ? "NH" : "JL", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            title: Text(
              "${departureAirportControllers[legId]!.text.isEmpty ? '???' : departureAirportControllers[legId]!.text} → ${arrivalAirportControllers[legId]!.text.isEmpty ? '???' : arrivalAirportControllers[legId]!.text}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${departureTimeControllers[legId]!.text} 出発 | ${flightNumberControllers[legId]!.text}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white24),
          ),
          if (isExpanded) 
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildEditorContent(index, l10n),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorContent(int index, AppLocalizations l10n) {
    final legId = legs[index]['id'];
    
    return Column(
      children: [
        const Divider(color: Colors.white10, height: 24),
        // 1. 航空会社選択 (セグメントコントロール)
        _buildAirlineSelector(legId, index),
        const SizedBox(height: 16),
        Row(
          children: [
            // 2. 出発空港 (全空港から選択)
            Expanded(
              child: _buildStyledDropdown(
                label: "出発空港",
                value: departureAirportControllers[legId]!.text.isEmpty ? null : departureAirportControllers[legId]!.text,
                items: allAirports,
                onChanged: (val) => _onDepartureChanged(index, val!),
              ),
            ),
            const SizedBox(width: 12),
            // 3. 到着空港 (就航路線のみ)
            Expanded(
              child: _buildStyledDropdown(
                label: "到着空港",
                value: availableDestinations[legId]?.contains(arrivalAirportControllers[legId]!.text) == true 
                       ? arrivalAirportControllers[legId]!.text : null,
                items: availableDestinations[legId] ?? [],
                onChanged: (val) => _onDestinationChanged(index, val!),
                hint: "出発地を選択",
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // 4. 出発時間 (運行ダイヤから選択)
            Expanded(
              child: _buildStyledDropdown(
                label: "出発時間",
                value: departureTimeControllers[legId]!.text.isEmpty ? null : departureTimeControllers[legId]!.text,
                items: (availableFlights[legId] ?? []).map((f) => f['time'] as String).toList(),
                onChanged: (val) {
                  setState(() {
                    departureTimeControllers[legId]!.text = val!;
                    final flight = availableFlights[legId]!.firstWhere((f) => f['time'] == val);
                    flightNumberControllers[legId]!.text = flight['no'];
                  });
                },
                hint: "路線を選択",
              ),
            ),
            const SizedBox(width: 12),
            // 5. 便名 (自動表示)
            Expanded(child: _buildTextField("便名", flightNumberControllers[legId]!)),
          ],
        ),
      ],
    );
  }

  Widget _buildAirlineSelector(int legId, int index) {
    return Row(
      children: ["ANA", "JAL"].map((airline) {
        bool isSelected = selectedAirlines[legId] == airline;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => selectedAirlines[legId] = airline);
              if (departureAirportControllers[legId]!.text.isNotEmpty) {
                _onDepartureChanged(index, departureAirportControllers[legId]!.text);
              }
            },
            child: Container(
              margin: EdgeInsets.only(right: airline == "ANA" ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected 
                  ? (airline == "ANA" ? Colors.blue.withOpacity(0.6) : Colors.red.withOpacity(0.6)) 
                  : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.white30 : Colors.transparent),
              ),
              child: Center(child: Text(airline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStyledDropdown({required String label, required String? value, required List<String> items, required ValueChanged<String?> onChanged, String hint = "選択"}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF1B1B2F),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)), hintText: hint, hintStyle: const TextStyle(color: Colors.white12, fontSize: 12)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        TextField(readOnly: true, controller: controller, style: const TextStyle(color: Colors.white38, fontSize: 14), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)))),
      ],
    );
  }

  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: const Border(top: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          IconButton(onPressed: _addNewLeg, icon: const Icon(Icons.add_circle, color: Colors.white, size: 32)),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: isBlueprintMode ? Colors.cyanAccent : Colors.indigoAccent, foregroundColor: isBlueprintMode ? Colors.black : Colors.white), child: Text(isBlueprintMode ? "SAVE BLUEPRINT" : "SAVE LOG"))),
        ],
      ),
    );
  }

  void _addNewLeg() {
    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch;
      legs.add({'id': id});
      departureAirportControllers[id] = TextEditingController();
      arrivalAirportControllers[id] = TextEditingController();
      departureTimeControllers[id] = TextEditingController();
      flightNumberControllers[id] = TextEditingController();
      selectedAirlines[id] = "ANA";
    });
  }
}