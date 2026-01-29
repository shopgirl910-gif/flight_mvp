import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  bool isSaving = false;
  
  // JAL設定
  String? jalCard;
  String? jalStatus;
  bool jalTourPremium = false;
  int currentLsp = 0;
  int targetLsp = 1500;
  
  // ANA設定
  String? anaCard;
  String? anaStatus;
  
  // 共通設定
  String? homeAirport;
  String defaultAirline = 'JAL';

  // JALカード種別
  final List<String> jalCardKeys = ['-', 'jmb', 'jal_regular', 'jal_club_a', 'jal_club_a_gold', 'jal_platinum', 'jgc_japan', 'jgc_overseas', 'jal_navi', 'jal_est_regular', 'jal_est_club_a', 'jal_est_gold', 'jal_est_platinum'];
  final Map<String, String> jalCardNamesJa = {'-': '-', 'jmb': 'JMB会員', 'jal_regular': 'JALカード普通会員', 'jal_club_a': 'JALカードCLUB-A会員', 'jal_club_a_gold': 'JALカードCLUB-Aゴールド会員', 'jal_platinum': 'JALカードプラチナ会員', 'jgc_japan': 'JALグローバルクラブ会員(日本)', 'jgc_overseas': 'JALグローバルクラブ会員(海外)', 'jal_navi': 'JALカードNAVI会員', 'jal_est_regular': 'JAL CLUB EST 普通会員', 'jal_est_club_a': 'JAL CLUB EST CLUB-A会員', 'jal_est_gold': 'JAL CLUB EST CLUB-A GOLD会員', 'jal_est_platinum': 'JAL CLUB EST プラチナ会員'};
  final Map<String, String> jalCardNamesEn = {'-': '-', 'jmb': 'JMB Member', 'jal_regular': 'JAL Card Regular', 'jal_club_a': 'JAL Card CLUB-A', 'jal_club_a_gold': 'JAL Card CLUB-A Gold', 'jal_platinum': 'JAL Card Platinum', 'jgc_japan': 'JGC Member (Japan)', 'jgc_overseas': 'JGC Member (Overseas)', 'jal_navi': 'JAL Card NAVI', 'jal_est_regular': 'JAL CLUB EST Regular', 'jal_est_club_a': 'JAL CLUB EST CLUB-A', 'jal_est_gold': 'JAL CLUB EST CLUB-A Gold', 'jal_est_platinum': 'JAL CLUB EST Platinum'};

  // JALステータス
  final List<String> jalStatusKeys = ['-', 'diamond', 'sapphire', 'crystal'];
  final Map<String, String> jalStatusNamesJa = {'-': '-', 'diamond': 'JMBダイヤモンド', 'sapphire': 'JMBサファイア', 'crystal': 'JMBクリスタル'};
  final Map<String, String> jalStatusNamesEn = {'-': '-', 'diamond': 'JMB Diamond', 'sapphire': 'JMB Sapphire', 'crystal': 'JMB Crystal'};

  // ANAカード種別
  final List<String> anaCardKeys = ['-', 'amc', 'ana_regular', 'ana_student', 'ana_wide', 'ana_gold', 'ana_premium', 'sfc_regular', 'sfc_gold', 'sfc_premium'];
  final Map<String, String> anaCardNamesJa = {'-': '-', 'amc': 'AMCカード(提携カード含む)', 'ana_regular': 'ANAカード 一般', 'ana_student': 'ANAカード 学生用', 'ana_wide': 'ANAカード ワイド', 'ana_gold': 'ANAカード ゴールド', 'ana_premium': 'ANAカード プレミアム', 'sfc_regular': 'SFC 一般', 'sfc_gold': 'SFC ゴールド', 'sfc_premium': 'SFC プレミアム'};
  final Map<String, String> anaCardNamesEn = {'-': '-', 'amc': 'AMC Card', 'ana_regular': 'ANA Card Regular', 'ana_student': 'ANA Card Student', 'ana_wide': 'ANA Card Wide', 'ana_gold': 'ANA Card Gold', 'ana_premium': 'ANA Card Premium', 'sfc_regular': 'SFC Regular', 'sfc_gold': 'SFC Gold', 'sfc_premium': 'SFC Premium'};

  // ANAステータス
  final List<String> anaStatusKeys = ['-', 'diamond_1', 'diamond_2', 'platinum_1', 'platinum_2', 'bronze_1', 'bronze_2'];
  final Map<String, String> anaStatusNamesJa = {'-': '-', 'diamond_1': 'ダイヤモンド(1年目)', 'diamond_2': 'ダイヤモンド(継続2年以上)', 'platinum_1': 'プラチナ(1年目)', 'platinum_2': 'プラチナ(継続2年以上)', 'bronze_1': 'ブロンズ(1年目)', 'bronze_2': 'ブロンズ(継続2年以上)'};
  final Map<String, String> anaStatusNamesEn = {'-': '-', 'diamond_1': 'Diamond (1st year)', 'diamond_2': 'Diamond (2+ years)', 'platinum_1': 'Platinum (1st year)', 'platinum_2': 'Platinum (2+ years)', 'bronze_1': 'Bronze (1st year)', 'bronze_2': 'Bronze (2+ years)'};

  // 主要空港
  final List<String> majorAirports = ['HND', 'NRT', 'ITM', 'KIX', 'NGO', 'CTS', 'FUK', 'OKA'];
  final Map<String, String> airportNamesJa = {'HND': '羽田', 'NRT': '成田', 'ITM': '伊丹', 'KIX': '関西', 'NGO': '中部', 'CTS': '新千歳', 'FUK': '福岡', 'OKA': '那覇'};
  final Map<String, String> airportNamesEn = {'HND': 'Haneda', 'NRT': 'Narita', 'ITM': 'Itami', 'KIX': 'Kansai', 'NGO': 'Chubu', 'CTS': 'New Chitose', 'FUK': 'Fukuoka', 'OKA': 'Naha'};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  bool get _isJapanese => Localizations.localeOf(context).languageCode == 'ja';

  String _getJalCardName(String key) => _isJapanese ? (jalCardNamesJa[key] ?? key) : (jalCardNamesEn[key] ?? key);
  String _getJalStatusName(String key) => _isJapanese ? (jalStatusNamesJa[key] ?? key) : (jalStatusNamesEn[key] ?? key);
  String _getAnaCardName(String key) => _isJapanese ? (anaCardNamesJa[key] ?? key) : (anaCardNamesEn[key] ?? key);
  String _getAnaStatusName(String key) => _isJapanese ? (anaStatusNamesJa[key] ?? key) : (anaStatusNamesEn[key] ?? key);
  String _getAirportName(String code) => _isJapanese ? (airportNamesJa[code] ?? code) : (airportNamesEn[code] ?? code);

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          jalCard = response['jal_card'] as String?;
          jalStatus = response['jal_status'] as String?;
          jalTourPremium = response['jal_tour_premium'] as bool? ?? false;
          currentLsp = response['current_lsp'] as int? ?? 0;
          targetLsp = response['target_lsp'] as int? ?? 1500;
          anaCard = response['ana_card'] as String?;
          anaStatus = response['ana_status'] as String?;
          homeAirport = response['home_airport'] as String?;
          defaultAirline = response['default_airline'] as String? ?? 'JAL';
        });
      }
    } catch (e) {
      // エラー時はデフォルト値のまま
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _saveProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isSaving = true);

    try {
      await Supabase.instance.client.from('user_profiles').upsert({
        'id': userId,
        'jal_card': jalCard,
        'jal_status': jalStatus,
        'jal_tour_premium': jalTourPremium,
        'current_lsp': currentLsp,
        'target_lsp': targetLsp,
        'ana_card': anaCard,
        'ana_status': anaStatus,
        'home_airport': homeAirport,
        'default_airline': defaultAirline,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isJapanese ? '設定を保存しました' : 'Settings saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // 保存成功を返す
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isJapanese ? '保存に失敗しました' : 'Failed to save'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isJapanese ? 'プロフィール設定' : 'Profile Settings'),
          backgroundColor: Colors.purple[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isJapanese ? 'プロフィール設定' : 'Profile Settings'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: isSaving ? null : _saveProfile,
            child: Text(
              l10n.save,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // JAL設定セクション
            _buildSectionHeader('JAL', Colors.red),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'カード種別' : 'Card Type',
              value: jalCard,
              items: jalCardKeys,
              displayText: _getJalCardName,
              onChanged: (v) => setState(() => jalCard = v),
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'ステータス' : 'Status',
              value: jalStatus,
              items: jalStatusKeys,
              displayText: _getJalStatusName,
              onChanged: (v) => setState(() => jalStatus = v),
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            _buildCheckbox(
              label: _isJapanese ? 'ツアープレミアム' : 'Tour Premium',
              value: jalTourPremium,
              onChanged: (v) => setState(() => jalTourPremium = v ?? false),
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            
            // LSP設定
            _buildLspSection(),
            const SizedBox(height: 24),

            // ANA設定セクション
            _buildSectionHeader('ANA', Colors.blue),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'カード種別' : 'Card Type',
              value: anaCard,
              items: anaCardKeys,
              displayText: _getAnaCardName,
              onChanged: (v) => setState(() => anaCard = v),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'ステータス' : 'Status',
              value: anaStatus,
              items: anaStatusKeys,
              displayText: _getAnaStatusName,
              onChanged: (v) => setState(() => anaStatus = v),
              color: Colors.blue,
            ),
            const SizedBox(height: 24),

            // 共通設定セクション
            _buildSectionHeader(_isJapanese ? '共通設定' : 'General', Colors.purple),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'ホーム空港' : 'Home Airport',
              value: homeAirport,
              items: ['-', ...majorAirports],
              displayText: (code) => code == '-' ? '-' : '$code ${_getAirportName(code)}',
              onChanged: (v) => setState(() => homeAirport = v == '-' ? null : v),
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'デフォルト航空会社' : 'Default Airline',
              value: defaultAirline,
              items: ['JAL', 'ANA'],
              displayText: (v) => v,
              onChanged: (v) => setState(() => defaultAirline = v ?? 'JAL'),
              color: Colors.purple,
            ),
            const SizedBox(height: 32),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(l10n.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String Function(String) displayText,
    required void Function(String?) onChanged,
    required Color color,
  }) {
    final currentValue = value == null || !items.contains(value) ? items.first : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: currentValue,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(displayText(item), style: const TextStyle(fontSize: 14)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
    required Color color,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildLspSection() {
    final remainingLsp = targetLsp - currentLsp;
    final remainingLegs = remainingLsp > 0 ? (remainingLsp / 5).ceil() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Life Status Points (LSP)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red[700]),
          ),
          const SizedBox(height: 12),
          
          // 現在のLSP
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isJapanese ? '現在のLSP' : 'Current LSP',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        initialValue: currentLsp.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (v) => setState(() => currentLsp = int.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isJapanese ? '目標LSP' : 'Target LSP',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        initialValue: targetLsp.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (v) => setState(() => targetLsp = int.tryParse(v) ?? 1500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 目標までの残り
          if (remainingLsp > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isJapanese 
                        ? '🎯 目標まで あと $remainingLsp LSP'
                        : '🎯 $remainingLsp LSP to goal',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isJapanese 
                        ? '（国内線 約 $remainingLegs レグ）'
                        : '(Approx. $remainingLegs domestic legs)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isJapanese ? '🎉 目標達成！' : '🎉 Goal achieved!',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // LSP目安ガイド
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isJapanese ? '📊 LSP目安' : '📊 LSP Guide',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  _isJapanese 
                      ? '1,500 LSP → JGC入会可能 ✨'
                      : '1,500 LSP → JGC eligible ✨',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
