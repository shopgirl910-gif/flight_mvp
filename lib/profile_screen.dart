import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'auth_screen.dart';

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

  // ANA設定
  String? anaCard;
  String? anaStatus;

  // 共通設定
  String? homeAirport;
  String defaultAirline = 'JAL';

  // テキストコントローラー - JAL
  final _currentLspController = TextEditingController();
  final _targetLspController = TextEditingController();
  final _currentFopController = TextEditingController();
  final _targetFopController = TextEditingController();
  final _currentJalMilesController = TextEditingController();
  final _targetJalMilesController = TextEditingController();

  // テキストコントローラー - ANA
  final _currentPpController = TextEditingController();
  final _targetPpController = TextEditingController();
  final _currentAnaMilesController = TextEditingController();
  final _targetAnaMilesController = TextEditingController();

  // JALカード種別
  final List<String> jalCardKeys = [
    '-',
    'jmb',
    'jal_regular',
    'jal_club_a',
    'jal_club_a_gold',
    'jal_platinum',
    'jgc_japan',
    'jgc_overseas',
    'jal_navi',
    'jal_est_regular',
    'jal_est_club_a',
    'jal_est_gold',
    'jal_est_platinum',
  ];
  final Map<String, String> jalCardNamesJa = {
    '-': '-',
    'jmb': 'JMB会員',
    'jal_regular': 'JALカード普通会員',
    'jal_club_a': 'JALカードCLUB-A会員',
    'jal_club_a_gold': 'JALカードCLUB-Aゴールド会員',
    'jal_platinum': 'JALカードプラチナ会員',
    'jgc_japan': 'JALグローバルクラブ会員(日本)',
    'jgc_overseas': 'JALグローバルクラブ会員(海外)',
    'jal_navi': 'JALカードNAVI会員',
    'jal_est_regular': 'JAL CLUB EST 普通会員',
    'jal_est_club_a': 'JAL CLUB EST CLUB-A会員',
    'jal_est_gold': 'JAL CLUB EST CLUB-A GOLD会員',
    'jal_est_platinum': 'JAL CLUB EST プラチナ会員',
  };
  final Map<String, String> jalCardNamesEn = {
    '-': '-',
    'jmb': 'JMB Member',
    'jal_regular': 'JAL Card Regular',
    'jal_club_a': 'JAL Card CLUB-A',
    'jal_club_a_gold': 'JAL Card CLUB-A Gold',
    'jal_platinum': 'JAL Card Platinum',
    'jgc_japan': 'JGC Member (Japan)',
    'jgc_overseas': 'JGC Member (Overseas)',
    'jal_navi': 'JAL Card NAVI',
    'jal_est_regular': 'JAL CLUB EST Regular',
    'jal_est_club_a': 'JAL CLUB EST CLUB-A',
    'jal_est_gold': 'JAL CLUB EST CLUB-A Gold',
    'jal_est_platinum': 'JAL CLUB EST Platinum',
  };

  // JALステータス
  List<String> get jalStatusKeys {
    final isJGC = jalCard == 'jgc_japan' || jalCard == 'jgc_overseas';
    return [
      '-',
      'diamond',
      if (isJGC) 'jgc_premier',
      'sapphire',
      'crystal',
    ];
  }
  final Map<String, String> jalStatusNamesJa = {
    '-': '-',
    'diamond': 'JMBダイヤモンド',
    'jgc_premier': 'JGCプレミア',
    'sapphire': 'JMBサファイア',
    'crystal': 'JMBクリスタル',
  };
  final Map<String, String> jalStatusNamesEn = {
    '-': '-',
    'diamond': 'JMB Diamond',
    'jgc_premier': 'JGC Premier',
    'sapphire': 'JMB Sapphire',
    'crystal': 'JMB Crystal',
  };

  // ANAカード種別
  final List<String> anaCardKeys = [
    '-',
    'amc',
    'ana_regular',
    'ana_student',
    'ana_wide',
    'ana_gold',
    'ana_premium',
    'sfc_regular',
    'sfc_gold',
    'sfc_premium',
  ];
  final Map<String, String> anaCardNamesJa = {
    '-': '-',
    'amc': 'AMCカード(提携カード含む)',
    'ana_regular': 'ANAカード 一般',
    'ana_student': 'ANAカード 学生用',
    'ana_wide': 'ANAカード ワイド',
    'ana_gold': 'ANAカード ゴールド',
    'ana_premium': 'ANAカード プレミアム',
    'sfc_regular': 'SFC 一般',
    'sfc_gold': 'SFC ゴールド',
    'sfc_premium': 'SFC プレミアム',
  };
  final Map<String, String> anaCardNamesEn = {
    '-': '-',
    'amc': 'AMC Card',
    'ana_regular': 'ANA Card Regular',
    'ana_student': 'ANA Card Student',
    'ana_wide': 'ANA Card Wide',
    'ana_gold': 'ANA Card Gold',
    'ana_premium': 'ANA Card Premium',
    'sfc_regular': 'SFC Regular',
    'sfc_gold': 'SFC Gold',
    'sfc_premium': 'SFC Premium',
  };

  // ANAステータス
  final List<String> anaStatusKeys = [
    '-',
    'diamond_1',
    'diamond_2',
    'platinum_1',
    'platinum_2',
    'bronze_1',
    'bronze_2',
  ];
  final Map<String, String> anaStatusNamesJa = {
    '-': '-',
    'diamond_1': 'ダイヤモンド(1年目)',
    'diamond_2': 'ダイヤモンド(継続2年以上)',
    'platinum_1': 'プラチナ(1年目)',
    'platinum_2': 'プラチナ(継続2年以上)',
    'bronze_1': 'ブロンズ(1年目)',
    'bronze_2': 'ブロンズ(継続2年以上)',
  };
  final Map<String, String> anaStatusNamesEn = {
    '-': '-',
    'diamond_1': 'Diamond (1st year)',
    'diamond_2': 'Diamond (2+ years)',
    'platinum_1': 'Platinum (1st year)',
    'platinum_2': 'Platinum (2+ years)',
    'bronze_1': 'Bronze (1st year)',
    'bronze_2': 'Bronze (2+ years)',
  };

  // 主要空港
  final List<String> majorAirports = [
    'HND',
    'NRT',
    'ITM',
    'KIX',
    'NGO',
    'CTS',
    'FUK',
    'OKA',
  ];
  final Map<String, String> airportNamesJa = {
    'HND': '羽田',
    'NRT': '成田',
    'ITM': '伊丹',
    'KIX': '関西',
    'NGO': '中部',
    'CTS': '新千歳',
    'FUK': '福岡',
    'OKA': '那覇',
  };
  final Map<String, String> airportNamesEn = {
    'HND': 'Haneda',
    'NRT': 'Narita',
    'ITM': 'Itami',
    'KIX': 'Kansai',
    'NGO': 'Chubu',
    'CTS': 'New Chitose',
    'FUK': 'Fukuoka',
    'OKA': 'Naha',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _currentLspController.dispose();
    _targetLspController.dispose();
    _currentFopController.dispose();
    _targetFopController.dispose();
    _currentJalMilesController.dispose();
    _targetJalMilesController.dispose();
    _currentPpController.dispose();
    _targetPpController.dispose();
    _currentAnaMilesController.dispose();
    _targetAnaMilesController.dispose();
    super.dispose();
  }

  bool get _isJapanese => Localizations.localeOf(context).languageCode == 'ja';

  String _getJalCardName(String key) =>
      _isJapanese ? (jalCardNamesJa[key] ?? key) : (jalCardNamesEn[key] ?? key);
  String _getJalStatusName(String key) => _isJapanese
      ? (jalStatusNamesJa[key] ?? key)
      : (jalStatusNamesEn[key] ?? key);
  String _getAnaCardName(String key) =>
      _isJapanese ? (anaCardNamesJa[key] ?? key) : (anaCardNamesEn[key] ?? key);
  String _getAnaStatusName(String key) => _isJapanese
      ? (anaStatusNamesJa[key] ?? key)
      : (anaStatusNamesEn[key] ?? key);
  String _getAirportName(String code) => _isJapanese
      ? (airportNamesJa[code] ?? code)
      : (airportNamesEn[code] ?? code);

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
          anaCard = response['ana_card'] as String?;
          anaStatus = response['ana_status'] as String?;
          homeAirport = response['home_airport'] as String?;
          defaultAirline = response['default_airline'] as String? ?? 'JAL';
        });

        // テキストコントローラーに値を設定
        _currentLspController.text =
            (response['current_lsp'] as int?)?.toString() ?? '';
        _targetLspController.text =
            (response['target_lsp'] as int?)?.toString() ?? '';
        _currentFopController.text =
            (response['current_fop'] as int?)?.toString() ?? '';
        _targetFopController.text =
            (response['target_fop'] as int?)?.toString() ?? '';
        _currentJalMilesController.text =
            (response['current_jal_miles'] as int?)?.toString() ?? '';
        _targetJalMilesController.text =
            (response['target_jal_miles'] as int?)?.toString() ?? '';
        _currentPpController.text =
            (response['current_pp'] as int?)?.toString() ?? '';
        _targetPpController.text =
            (response['target_pp'] as int?)?.toString() ?? '';
        _currentAnaMilesController.text =
            (response['current_ana_miles'] as int?)?.toString() ?? '';
        _targetAnaMilesController.text =
            (response['target_ana_miles'] as int?)?.toString() ?? '';
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
      // '-'や無効な値はnullに変換
      String? cleanValue(String? v) => (v == null || v == '-' || v == 'なし') ? null : v;
      
      await Supabase.instance.client.from('user_profiles').upsert({
        'id': userId,
        'jal_card': cleanValue(jalCard),
        'jal_status': cleanValue(jalStatus),
        'jal_tour_premium': jalTourPremium,
        'current_lsp': int.tryParse(_currentLspController.text),
        'target_lsp': int.tryParse(_targetLspController.text),
        'current_fop': int.tryParse(_currentFopController.text),
        'target_fop': int.tryParse(_targetFopController.text),
        'current_jal_miles': int.tryParse(_currentJalMilesController.text),
        'target_jal_miles': int.tryParse(_targetJalMilesController.text),
        'ana_card': cleanValue(anaCard),
        'ana_status': cleanValue(anaStatus),
        'current_pp': int.tryParse(_currentPpController.text),
        'target_pp': int.tryParse(_targetPpController.text),
        'current_ana_miles': int.tryParse(_currentAnaMilesController.text),
        'target_ana_miles': int.tryParse(_targetAnaMilesController.text),
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
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isJapanese ? '保存に失敗しました: $e' : 'Failed to save: $e'),
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
    final user = Supabase.instance.client.auth.currentUser;
    final isAnonymous = user == null || user.isAnonymous;

    // 未ログインの場合はログイン促進画面を表示
    if (isAnonymous) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isJapanese ? 'プロフィール設定' : 'Profile Settings'),
          backgroundColor: Colors.purple[700],
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_circle, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 24),
                Text(
                  _isJapanese ? 'ログインが必要です' : 'Login Required',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isJapanese
                      ? 'プロフィール設定を保存するには\nログインしてください'
                      : 'Please log in to save\nyour profile settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // プロフィール画面を閉じる
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthScreen(
                          onAuthSuccess: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: Text(_isJapanese ? 'ログイン画面へ' : 'Go to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://mrunplanner.com/tokushoho.html',
                    ),
                  ),
                  child: Text(
                    _isJapanese
                        ? '特定商取引法に基づく表記'
                        : 'Specified Commercial Transactions Act',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[400],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://mrunplanner.com/privacy.html',
                    ),
                  ),
                  child: Text(
                    _isJapanese ? 'プライバシーポリシー' : 'Privacy Policy',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[400],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://mrunplanner.com/terms.html',
                    ),
                  ),
                  child: Text(
                    _isJapanese ? '利用規約' : 'Terms of Service',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[400],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                      'mailto:mileagerunplanner@gmail.com?subject=MRPお問い合わせ',
                    ),
                  ),
                  child: Text(
                    _isJapanese ? 'お問い合わせ' : 'Contact Us',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[400],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                        _isJapanese ? '📊 データ提供元' : '📊 Data Source',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isJapanese
                            ? '本アプリケーションで利用する公共交通データは、公共交通オープンデータセンターにおいて提供されるものです。公共交通事業者により提供されたデータを元にしていますが、必ずしも正確・完全なものとは限りません。\n\n本アプリケーションの表示内容について、公共交通事業者への直接の問合せは行わないでください。\n\nお問い合わせ:mileagerunplanner@gmail.com'
                            : 'Public transportation data used in this application is provided by the Public Transportation Open Data Center. The data is based on information provided by transportation operators, but may not always be accurate or complete.\n\nPlease do not contact transportation operators directly.\n\nContact: mileagerunplanner@gmail.com',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヒントテキスト
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _isJapanese ? '空白可。いつでも設定できます。' : 'All fields are optional.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // JAL設定セクション
            _buildSectionHeader('JAL', Colors.red),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'カード種別' : 'Card Type',
              value: jalCard,
              items: jalCardKeys,
              displayText: _getJalCardName,
              onChanged: (v) {
                setState(() {
                  jalCard = v;
                  final isJGC = v == 'jgc_japan' || v == 'jgc_overseas';
                  // JGCカード以外に変更した場合、JGCプレミアステータスをリセット
                  if (!isJGC && jalStatus == 'jgc_premier') {
                    jalStatus = '-';
                  }
                  // JGCカード(海外)の場合のみ、ツアープレミアムを無効化
                  if (v == 'jgc_overseas') {
                    jalTourPremium = false;
                  }
                });
              },
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
            // ツアープレミアム（JGC海外カードの場合のみ無効）
            Builder(builder: (context) {
              final isJGCOverseas = jalCard == 'jgc_overseas';
              return Row(
                children: [
                  Checkbox(
                    value: jalTourPremium,
                    onChanged: isJGCOverseas ? null : (v) => setState(() => jalTourPremium = v ?? false),
                    activeColor: Colors.red,
                  ),
                  Text(
                    _isJapanese ? 'ツアープレミアム' : 'Tour Premium',
                    style: TextStyle(
                      fontSize: 14,
                      color: isJGCOverseas ? Colors.grey : Colors.grey[800],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // JAL目標設定
            _buildJalGoalsSection(),
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
            const SizedBox(height: 16),

            // ANA目標設定
            _buildAnaGoalsSection(),
            const SizedBox(height: 24),

            // 共通設定セクション
            _buildSectionHeader(
              _isJapanese ? '共通設定' : 'General',
              Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: _isJapanese ? 'ホーム空港' : 'Home Airport',
              value: homeAirport,
              items: ['-', ...majorAirports],
              displayText: (code) =>
                  code == '-' ? '-' : '$code ${_getAirportName(code)}',
              onChanged: (v) =>
                  setState(() => homeAirport = v == '-' ? null : v),
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.save,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            // フッターリンク
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://mileage-run-planner.web.app/tokushoho.html',
                    ),
                  ),
                  child: Text(
                    _isJapanese
                        ? '特定商取引法に基づく表記'
                        : 'Specified Commercial Transactions Act',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[400],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://mrunplanner.com/tokushoho.html'),
              ),
              child: Text(
                _isJapanese ? '特定商取引法に基づく表記' : 'Specified Commercial Transactions Act',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[400],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://mrunplanner.com/privacy.html'),
              ),
              child: Text(
                _isJapanese ? 'プライバシーポリシー' : 'Privacy Policy',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[400],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://mrunplanner.com/terms.html'),
              ),
              child: Text(
                _isJapanese ? '利用規約' : 'Terms of Service',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[400],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('mailto:mileagerunplanner@gmail.com?subject=MRPお問い合わせ'),
              ),
              child: Text(
                _isJapanese ? 'お問い合わせ' : 'Contact Us',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[400],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 24),
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
    final currentValue = value == null || !items.contains(value)
        ? items.first
        : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
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
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      displayText(item),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
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
        Checkbox(value: value, onChanged: onChanged, activeColor: color),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildGoalInput({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow({
    required String currentLabel,
    required String targetLabel,
    required TextEditingController currentController,
    required TextEditingController targetController,
    required String currentHint,
    required String targetHint,
  }) {
    return Row(
      children: [
        _buildGoalInput(
          label: currentLabel,
          controller: currentController,
          hint: currentHint,
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        _buildGoalInput(
          label: targetLabel,
          controller: targetController,
          hint: targetHint,
        ),
      ],
    );
  }

  Widget _buildJalGoalsSection() {
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
            _isJapanese ? '🎯 JAL目標設定' : '🎯 JAL Goals',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          Text(
            _isJapanese
                ? '空欄のまま保存可能です'
                : 'Optional - leave blank if not needed',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),

          // LSP行
          _buildGoalRow(
            currentLabel: _isJapanese ? '現在LSP' : 'Current LSP',
            targetLabel: _isJapanese ? '目標LSP' : 'Target LSP',
            currentController: _currentLspController,
            targetController: _targetLspController,
            currentHint: '0',
            targetHint: '1500',
          ),
          const SizedBox(height: 12),

          // FOP行
          _buildGoalRow(
            currentLabel: _isJapanese ? '現在FOP' : 'Current FOP',
            targetLabel: _isJapanese ? '目標FOP' : 'Target FOP',
            currentController: _currentFopController,
            targetController: _targetFopController,
            currentHint: '0',
            targetHint: '50000',
          ),
          const SizedBox(height: 12),

          // マイル行
          _buildGoalRow(
            currentLabel: _isJapanese ? '現在マイル' : 'Current Miles',
            targetLabel: _isJapanese ? '目標マイル' : 'Target Miles',
            currentController: _currentJalMilesController,
            targetController: _targetJalMilesController,
            currentHint: '0',
            targetHint: '50000',
          ),
          const SizedBox(height: 16),

          // ステータス目安
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
                  _isJapanese ? '📊 ステータス目安' : '📊 Status Reference',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isJapanese
                      ? '• 1,500 LSP → JGC入会可能 ✨\n• 50,000 FOP → ラウンジアクセス'
                      : '• 1,500 LSP → JGC eligible ✨\n• 50,000 FOP → Lounge Access',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 特典航空券マイル目安
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
                  _isJapanese
                      ? '✈️ 特典航空券マイル目安(往復・Y・L)'
                      : '✈️ Award Miles (Round-trip/Y/L)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                _buildMileTable([
                  [_isJapanese ? '国内線' : 'Domestic', '12,000〜'],
                  [_isJapanese ? '韓国' : 'Korea', '15,000〜'],
                  [_isJapanese ? '東南アジア' : 'SE Asia', '35,000〜'],
                  [_isJapanese ? 'ハワイ' : 'Hawaii', '40,000〜'],
                  [_isJapanese ? '北米' : 'N. America', '50,000〜'],
                  [_isJapanese ? '欧州' : 'Europe', '54,000〜'],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMileTable(List<List<String>> rows) {
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      row[0],
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                  Text(
                    row[1],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAnaGoalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isJapanese ? '🎯 ANA目標設定' : '🎯 ANA Goals',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          Text(
            _isJapanese
                ? '空欄のまま保存可能です'
                : 'Optional - leave blank if not needed',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),

          // PP行
          _buildGoalRow(
            currentLabel: _isJapanese ? '現在PP' : 'Current PP',
            targetLabel: _isJapanese ? '目標PP' : 'Target PP',
            currentController: _currentPpController,
            targetController: _targetPpController,
            currentHint: '0',
            targetHint: '50000',
          ),
          const SizedBox(height: 12),

          // マイル行
          _buildGoalRow(
            currentLabel: _isJapanese ? '現在マイル' : 'Current Miles',
            targetLabel: _isJapanese ? '目標マイル' : 'Target Miles',
            currentController: _currentAnaMilesController,
            targetController: _targetAnaMilesController,
            currentHint: '0',
            targetHint: '50000',
          ),
          const SizedBox(height: 16),

          // 目安ガイド
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
                  _isJapanese ? '📊 ステータス目安' : '📊 Status Reference',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isJapanese
                      ? '• 50,000 PP → ラウンジアクセス ✨'
                      : '• 50,000 PP → Lounge Access ✨',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 特典航空券マイル目安
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
                  _isJapanese
                      ? '✈️ 特典航空券マイル目安(往復・Y・L)'
                      : '✈️ Award Miles (Round-trip/Y/L)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                _buildMileTable([
                  [_isJapanese ? '国内線' : 'Domestic', '10,000〜'],
                  [_isJapanese ? '韓国' : 'Korea', '15,000〜'],
                  [_isJapanese ? '東南アジア' : 'SE Asia', '35,000〜'],
                  [_isJapanese ? 'ハワイ' : 'Hawaii', '35,000〜'],
                  [_isJapanese ? '北米' : 'N. America', '50,000〜'],
                  [_isJapanese ? '欧州' : 'Europe', '65,000〜'],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
