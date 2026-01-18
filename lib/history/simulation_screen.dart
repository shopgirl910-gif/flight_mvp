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

  // --- 状態管理用変数 ---
  bool isBlueprintMode = false; 
  List<Map<String, dynamic>> legs = [];
  int? expandedLegId;

  // 既存のコントローラー・データ群
  final Map<int, TextEditingController> dateControllers = {};
  final Map<int, TextEditingController> flightNumberControllers = {};
  final Map<int, TextEditingController> departureTimeControllers = {};
  final Map<int, TextEditingController> arrivalTimeControllers = {};
  final Map<int, TextEditingController> fareAmountControllers = {};
  final Map<int, TextEditingController> departureAirportControllers = {};
  final Map<int, TextEditingController> arrivalAirportControllers = {};
  final Map<int, FocusNode> departureAirportFocusNodes = {};
  final Map<int, FocusNode> arrivalAirportFocusNodes = {};
  final Map<int, List<Map<String, dynamic>>> availableFlights = {};
  final Map<int, List<String>> availableDestinations = {};

  static const String _hapitasUrl = 'https://px.a8.net/svt/ejp?a8mat=45KL8I+5JG97E+1LP8+CALN5';

  @override
  void initState() {
    super.initState();
    _addNewLeg();
  }

  // 数値フォーマットヘルパー
  String _formatNumber(num number) => NumberFormat('#,###').format(number);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
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
              if (!isBlueprintMode) _buildHapitasBanner(),
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

  // --- ヘッダー：直線ゲージ ---
  Widget _buildModernHeader() {
    double currentPP = 32500; // 本来は既存の計算ロジックから引用
    double targetPP = 50000;
    double progress = (currentPP / targetPP).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildModeToggle(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isBlueprintMode ? "BLUEPRINT PLAN" : "FLIGHT LOG", 
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              Text("${_formatNumber(currentPP)} / ${_formatNumber(targetPP)} PP", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          
          Stack(
            children: [
              Container(height: 8, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4))),
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                width: (MediaQuery.of(context).size.width - 48) * progress,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(22)),
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
          decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(22)),
          child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
        ),
      ),
    );
  }

  // --- カード & エディタ ---
  Widget _buildModernLegCard(int index, AppLocalizations l10n) {
    final leg = legs[index];
    final isExpanded = expandedLegId == leg['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isExpanded ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBlueprintMode ? Colors.cyanAccent.withOpacity(0.3) : Colors.white10),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => expandedLegId = isExpanded ? null : leg['id']),
            leading: Icon(isBlueprintMode ? Icons.architecture : Icons.flight_takeoff, color: isBlueprintMode ? Colors.cyanAccent : Colors.orangeAccent),
            title: Text("${leg['departureAirport'] ?? '---'} → ${leg['arrivalAirport'] ?? '---'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white24),
          ),
          if (isExpanded) _buildEditorContent(index),
        ],
      ),
    );
  }

  Widget _buildEditorContent(int index) {
    final legId = legs[index]['id'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField("出発", departureAirportControllers[legId]!)),
              const SizedBox(width: 12),
              Expanded(child: _buildDestinationSelector(index)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField("運賃", fareAmountControllers[legId]!, hint: "任意入力"),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white10),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationSelector(int index) {
    final legId = legs[index]['id'];
    final destinations = availableDestinations[legId] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("到着", style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
        DropdownButton<String>(
          value: destinations.contains(arrivalAirportControllers[legId]!.text) ? arrivalAirportControllers[legId]!.text : null,
          isExpanded: true,
          dropdownColor: const Color(0xFF1B1B2F),
          items: destinations.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
          onChanged: (val) => setState(() => arrivalAirportControllers[legId]!.text = val!),
        ),
      ],
    );
  }

  Widget _buildHapitasBanner() {
    return GestureDetector(
      onTap: _openHapitas,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12), // EdgeInsets.bottomを修正
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))),
        child: const Row(
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 18),
            SizedBox(width: 12),
            Expanded(child: Text("ハピタス経由で予約ポイント三重取り", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black.withOpacity(0.5),
      child: Row(
        children: [
          IconButton(onPressed: _addNewLeg, icon: const Icon(Icons.add_circle, color: Colors.white, size: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {}, 
              style: ElevatedButton.styleFrom(backgroundColor: isBlueprintMode ? Colors.cyanAccent : Colors.indigoAccent),
              child: Text(isBlueprintMode ? "設計図を保存" : "実績ログを保存"),
            ),
          ),
        ],
      ),
    );
  }

  // --- オリジナルのロジックを保持したメソッド群 ---
  void _addNewLeg() {
    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch;
      legs.add({'id': id, 'departureAirport': 'HND', 'arrivalAirport': 'OKA'});
      departureAirportControllers[id] = TextEditingController(text: "HND");
      arrivalAirportControllers[id] = TextEditingController(text: "OKA");
      fareAmountControllers[id] = TextEditingController();
      availableDestinations[id] = ["OKA", "CTS", "FUK"]; // 実際はfetchメソッドで更新
    });
  }

  Future<void> _openHapitas() async {
    final uri = Uri.parse(_hapitasUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}