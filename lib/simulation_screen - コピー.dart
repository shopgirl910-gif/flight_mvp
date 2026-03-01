import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';
import 'plan_optimizer.dart';
import 'pro_service.dart';
import 'pro_purchase_screen.dart';
import 'pro_purchase_dialog.dart';

class SimulationScreen extends StatefulWidget {
  final void Function(String itineraryId)? onNavigateToFlightLog;
  const SimulationScreen({super.key, this.onNavigateToFlightLog});
  @override
  State<SimulationScreen> createState() => SimulationScreenState();
}

class SimulationScreenState extends State<SimulationScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  // おまかせ最適化用
  String _optAirline = 'JAL';
  String _optHomeAirport = 'HND';
  String _optDate = '';
  bool _optIncludeCodeshare = true;
  String _optFareType = '運賃4 (75%) スペシャルセイバー';
  bool _optSearching = false;
  List<OptimalPlan> _optResults = [];
  String? _optError;
  bool _optResultLimited = false;
  bool _optIsPro = false;

  List<Map<String, dynamic>> legs = [];
  int? expandedLegId;

  Map<int, TextEditingController> dateControllers = {};
  Map<int, TextEditingController> flightNumberControllers = {};
  Map<int, TextEditingController> departureTimeControllers = {};
  Map<int, TextEditingController> arrivalTimeControllers = {};
  Map<int, TextEditingController> fareAmountControllers = {};
  Map<int, TextEditingController> departureAirportControllers = {};
  Map<int, TextEditingController> arrivalAirportControllers = {};
  Map<int, FocusNode> departureAirportFocusNodes = {};
  Map<int, FocusNode> arrivalAirportFocusNodes = {};
  final ScrollController _freeDesignScrollController = ScrollController();
  Map<int, List<Map<String, dynamic>>> availableFlights = {};
  Map<int, List<String>> availableDestinations = {};
  Map<int, String?> legWarnings = {};
  Map<String, List<String>> airlineAirports = {};

  int _legIdCounter = 0;
  bool isLoading = false;
  String? errorMessage;

  String? selectedJALCard;
  String? selectedANACard;
  String? selectedJALStatus;
  String? selectedANAStatus;
  bool jalTourPremium = false;
  // ショッピングマイルプレミアム削除済み

  final List<String> jalCardTypes = [
    '-',
    'JMB会員',
    'JALカード普通会員',
    'JALカードCLUB-A会員',
    'JALカードCLUB-Aゴールド会員',
    'JALカードプラチナ会員',
    'JALグローバルクラブ会員(日本)',
    'JALグローバルクラブ会員(海外)',
    'JALカードNAVI会員',
    'JAL CLUB EST 普通会員',
    'JAL CLUB EST CLUB-A会員',
    'JAL CLUB EST CLUB-A GOLD会員',
    'JAL CLUB EST プラチナ会員',
  ];
  final List<String> anaCardTypes = [
    '-',
    'AMCカード(提携カード含む)',
    'ANAカード 一般',
    'ANAカード 学生用',
    'ANAカード ワイド',
    'ANAカード ゴールド',
    'ANAカード プレミアム',
    'SFC 一般',
    'SFC ゴールド',
    'SFC プレミアム',
  ];
  List<String> get jalStatusTypes {
    final isJGC =
        selectedJALCard == 'JALグローバルクラブ会員(日本)' ||
        selectedJALCard == 'JALグローバルクラブ会員(海外)';
    return ['-', 'JMBダイヤモンド', if (isJGC) 'JGCプレミア', 'JMBサファイア', 'JMBクリスタル'];
  }

  final List<String> anaStatusTypes = [
    '-',
    'ダイヤモンド(1年目)',
    'ダイヤモンド(継続2年以上)',
    'プラチナ(1年目)',
    'プラチナ(継続2年以上)',
    'ブロンズ(1年目)',
    'ブロンズ(継続2年以上)',
  ];

  final List<String> majorAirports = [
    'CTS',
    'HND',
    'NRT',
    'NGO',
    'ITM',
    'KIX',
    'FUK',
    'OKA',
  ];
  static const String airportDivider = '---';
  final List<String> regionalAirports = [
    'WKJ',
    'MBE',
    'MMB',
    'SHB',
    'AKJ',
    'OKD',
    'OBO',
    'KUH',
    'HKD',
    'OIR',
    'AOJ',
    'MSJ',
    'ONJ',
    'AXT',
    'SYO',
    'HNA',
    'GAJ',
    'SDJ',
    'FKS',
    'HAC',
    'NKM',
    'MMJ',
    'FSZ',
    'NTQ',
    'TOY',
    'KMQ',
    'SHM',
    'UKB',
    'TJH',
    'TTJ',
    'YGJ',
    'OKI',
    'IZO',
    'OKJ',
    'HIJ',
    'IWK',
    'UBJ',
    'TKS',
    'TAK',
    'MYJ',
    'KCZ',
    'KKJ',
    'HSG',
    'FUJ',
    'IKI',
    'TSJ',
    'NGS',
    'AXJ',
    'KMJ',
    'OIT',
    'KMI',
    'KOJ',
    'TNE',
    'KUM',
    'ASJ',
    'KKX',
    'TKN',
    'RNJ',
    'MMY',
    'ISG',
    'OGN',
  ];
  List<String> get airports => [
    ...majorAirports,
    airportDivider,
    ...regionalAirports,
  ];

  final Map<String, String> airportNames = {
    'HND': '羽田',
    'NRT': '成田',
    'KIX': '関西',
    'ITM': '伊丹',
    'NGO': '中部',
    'CTS': '新千歳',
    'FUK': '福岡',
    'OKA': '那覇',
    'NGS': '長崎',
    'KMJ': '熊本',
    'OIT': '大分',
    'MYJ': '松山',
    'HIJ': '広島',
    'TAK': '高松',
    'KCZ': '高知',
    'TKS': '徳島',
    'KOJ': '鹿児島',
    'SDJ': '仙台',
    'AOJ': '青森',
    'AKJ': '旭川',
    'AXT': '秋田',
    'GAJ': '山形',
    'KIJ': '新潟',
    'TOY': '富山',
    'KMQ': '小松',
    'FSZ': '静岡',
    'MMB': '女満別',
    'OBO': '帯広',
    'KUH': '釧路',
    'HKD': '函館',
    'ISG': '石垣',
    'MMY': '宮古',
    'UBJ': '山口宇部',
    'IWK': '岩国',
    'OKJ': '岡山',
    'TTJ': '鳥取',
    'YGJ': '米子',
    'IZO': '出雲',
    'NKM': '県営名古屋',
    'UKB': '神戸',
    'HSG': '佐賀',
    'KMI': '宮崎',
    'ASJ': '奄美',
    'TKN': '徳之島',
    'OKI': '隠岐',
    'FKS': '福島',
    'HNA': '花巻',
    'MSJ': '三沢',
    'ONJ': '大館能代',
    'SHM': '南紀白浜',
    'NTQ': '能登',
    'KKJ': '北九州',
    'TNE': '種子島',
    'KUM': '屋久島',
    'RNJ': '与論',
    'OGN': '与那国',
    'HAC': '八丈島',
    'MBE': '紋別',
    'SHB': '中標津',
    'WKJ': '稚内',
    'OKD': '丘珠',
    'IKI': '壱岐',
    'TSJ': '対馬',
    'FUJ': '五島福江',
    'OIR': '奥尻',
    'SYO': '庄内',
    'MMJ': '松本',
    'AXJ': '天草',
    'TJH': '但馬',
    'KKX': '喜界',
    'KTD': '北大東',
    'MMD': '南大東',
    'UEO': '久米島',
    'TRA': '多良間',
    'SHI': '下地島',
    'OKE': '沖永良部',
  };
  final List<String> airlines = ['JAL', 'ANA'];

  /// ルートの空港コードを日本語地名に変換（概要表示用）
  String _routeToJapanese(String route) {
    return route.split('→').map((code) => airportNames[code] ?? code).join('→');
  }

  final Map<String, List<String>> fareTypesByAirline = {
    'JAL': [
      '運賃1 (100%) フレックス等',
      '運賃2 (75%) 株主割引',
      '運賃3 (75%) セイバー',
      '運賃4 (75%) スペシャルセイバー',
      '運賃5 (50%) 包括旅行運賃',
      '運賃6 (50%) スカイメイト等',
    ],
    'ANA': [
      '運賃1 (150%) プレミアム運賃',
      '運賃2 (125%) プレミアム株主優待/VALUE PREMIUM',
      '運賃3 (100%) ANA FLEX/ビジネスきっぷ/Biz',
      '運賃4 (100%) 各種アイきっぷ',
      '運賃5 (75%) ANA VALUE/株主優待',
      '運賃6 (75%) ANA VALUE TRANSIT',
      '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割',
      '運賃8 (50%) 個人包括/スマートU25/スマートシニア/SALE',
      '運賃9 (150%) 国際航空券(PC) F/A',
      '運賃10 (100%) 国際航空券(普通) Y/B/M',
      '運賃11 (70%) 国際航空券(普通) U/H/Q',
      '運賃12 (50%) 国際航空券(普通) V/W/S',
      '運賃13 (30%) 国際航空券(普通) L/K',
    ],
  };
  final Map<String, List<String>> seatClassesByAirline = {
    'JAL': ['普通席', 'クラスJ', 'ファーストクラス'],
    'ANA': ['普通席', 'プレミアムクラス'],
  };
  final Map<String, int> jalBonusFOP = {
    '運賃1': 400,
    '運賃2': 400,
    '運賃3': 200,
    '運賃4': 200,
    '運賃5': 0,
    '運賃6': 0,
  };
  final Map<String, int> anaBonusPoint = {
    '運賃1': 400,
    '運賃2': 400,
    '運賃3': 400,
    '運賃4': 0,
    '運賃5': 400,
    '運賃6': 200,
    '運賃7': 0,
    '運賃8': 0,
    '運賃9': 0,
    '運賃10': 0,
    '運賃11': 0,
    '運賃12': 0,
    '運賃13': 0,
  };

  static const String _hapitasUrl =
      'https://px.a8.net/svt/ejp?a8mat=45KL8I+5JG97E+1LP8+CALN5';
  Future<void> _openHapitas() async {
    final uri = Uri.parse(_hapitasUrl);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    final oneMonthLater = DateTime(now.year, now.month + 1, now.day);
    _optDate =
        '${oneMonthLater.year}/${oneMonthLater.month.toString().padLeft(2, '0')}/${oneMonthLater.day.toString().padLeft(2, '0')}';
    _initAirlineAirports();
    _addLeg(); // 初期レグ作成（入力専用カードとして使用）
    _loadUserProfile();

    // 認証状態の変化を監視（ログイン後にプロフィールを再読み込み）
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _loadUserProfile();
      } else if (event.event == AuthChangeEvent.signedOut) {
        // ログアウト時にカード・ステータスをクリア
        setState(() {
          selectedJALCard = null;
          selectedANACard = null;
          selectedJALStatus = null;
          selectedANAStatus = null;
          jalTourPremium = false;
        });
      }
    });
  }

  // プロフィール画面からの更新通知用
  void reloadProfile() {
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    print('DEBUG: _loadUserProfile called');
    final user = Supabase.instance.client.auth.currentUser;
    print('DEBUG: user = $user');
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (res == null) return;
      final home = res['home_airport'] as String?;
      final airline = res['default_airline'] as String?;
      final jalCard = res['jal_card'] as String?;
      final anaCard = res['ana_card'] as String?;
      final jalStatus = res['jal_status'] as String?;
      final anaStatus = res['ana_status'] as String?;
      final tourPremium = res['jal_tour_premium'] as bool? ?? false;
      print(
        'DEBUG: jalCard=$jalCard, anaCard=$anaCard, jalStatus=$jalStatus, anaStatus=$anaStatus',
      );

      // データベース値(キー形式)→ドロップダウン値(表示名)のマッピング
      final jalCardMap = {
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
      final anaCardMap = {
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
      final jalStatusMap = {
        '-': '-',
        'diamond': 'JMBダイヤモンド',
        'jgc_premier': 'JGCプレミア',
        'sapphire': 'JMBサファイア',
        'crystal': 'JMBクリスタル',
      };
      final anaStatusMap = {
        '-': '-',
        'diamond_1': 'ダイヤモンド(1年目)',
        'diamond_2': 'ダイヤモンド(継続2年以上)',
        'platinum_1': 'プラチナ(1年目)',
        'platinum_2': 'プラチナ(継続2年以上)',
        'bronze_1': 'ブロンズ(1年目)',
        'bronze_2': 'ブロンズ(継続2年以上)',
      };

      setState(() {
        if (jalCard != null) {
          selectedJALCard = jalCardMap[jalCard];
          // キー形式で見つからなければ、既にDropdown形式ならそのまま使う
          if (selectedJALCard == null && jalCardTypes.contains(jalCard)) {
            selectedJALCard = jalCard;
          }
        }
        if (anaCard != null) {
          selectedANACard = anaCardMap[anaCard];
          if (selectedANACard == null && anaCardTypes.contains(anaCard)) {
            selectedANACard = anaCard;
          }
        }
        if (jalStatus != null) {
          selectedJALStatus = jalStatusMap[jalStatus];
          if (selectedJALStatus == null && jalStatusTypes.contains(jalStatus)) {
            selectedJALStatus = jalStatus;
          }
        }
        if (anaStatus != null) {
          selectedANAStatus = anaStatusMap[anaStatus];
          if (selectedANAStatus == null && anaStatusTypes.contains(anaStatus)) {
            selectedANAStatus = anaStatus;
          }
        }
        jalTourPremium = tourPremium;
      });

      if (home != null && home.isNotEmpty && legs.isNotEmpty) {
        final legId = legs.first['id'] as int;
        departureAirportControllers[legId]?.text = home;
        setState(() {
          legs.first['departureAirport'] = home;
          if (majorAirports.contains(home)) _optHomeAirport = home;
        });
        _fetchAvailableFlights(0);
      }
      if (airline != null && airline.isNotEmpty && legs.isNotEmpty) {
        setState(() {
          legs.first['airline'] = airline;
          _optAirline = airline;
          _optFareType = airline == 'JAL'
              ? '運賃4 (75%) スペシャルセイバー'
              : '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
        });
      }
    } catch (e) {
      print('DEBUG: error = $e');
    }
  }

  Future<void> _initAirlineAirports() async {
    await _fetchAirlineAirports('JAL');
    await _fetchAirlineAirports('ANA');
  }

  Future<List<String>> _fetchAirlineAirports(String airline) async {
    if (airlineAirports.containsKey(airline)) return airlineAirports[airline]!;
    try {
      final airlineCodes = (airline == 'JAL')
          ? ['JAL', 'JTA', 'RAC', 'JAC']
          : [airline];
      final response = await Supabase.instance.client
          .from('schedules')
          .select('departure_code')
          .inFilter('airline_code', airlineCodes)
          .eq('is_active', true);
      final codes =
          (response as List)
              .map((r) => r['departure_code'] as String)
              .toSet()
              .toList()
            ..sort();
      setState(() => airlineAirports[airline] = codes);
      return codes;
    } catch (e) {
      return airports;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var c in dateControllers.values) c.dispose();
    for (var c in flightNumberControllers.values) c.dispose();
    for (var c in departureTimeControllers.values) c.dispose();
    for (var c in arrivalTimeControllers.values) c.dispose();
    for (var c in fareAmountControllers.values) c.dispose();
    for (var c in departureAirportControllers.values) c.dispose();
    for (var c in arrivalAirportControllers.values) c.dispose();
    for (var f in departureAirportFocusNodes.values) f.dispose();
    for (var f in arrivalAirportFocusNodes.values) f.dispose();
    _freeDesignScrollController.dispose();
    super.dispose();
  }

  void _addLeg() async {
    final proService = ProService();
    final isPro = await proService.isPro();

    if (!isPro && legs.length >= ProService.freeCalcLimit) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('無料版の制限'),
            content: Text(
              '無料版は${ProService.freeCalcLimit}レグまでです。\n'
              'Pro版にアップグレードすると無制限に使えます。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showProPurchaseDialog(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text(
                  'Pro版を見る',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    final legId = _legIdCounter++;
    dateControllers[legId] = TextEditingController();
    flightNumberControllers[legId] = TextEditingController();
    departureTimeControllers[legId] = TextEditingController();
    arrivalTimeControllers[legId] = TextEditingController();
    fareAmountControllers[legId] = TextEditingController();
    departureAirportControllers[legId] = TextEditingController();
    arrivalAirportControllers[legId] = TextEditingController();
    departureAirportFocusNodes[legId] = FocusNode();
    arrivalAirportFocusNodes[legId] = FocusNode();
    String airline = 'JAL',
        departureAirport = '',
        arrivalAirport = '',
        date = '';
    if (legs.isNotEmpty) {
      final prevLeg = legs.last;
      final prevLegId = prevLeg['id'] as int;
      airline = prevLeg['airline'] as String;
      departureAirport = prevLeg['arrivalAirport'] as String;
      arrivalAirport = prevLeg['departureAirport'] as String;
      date = dateControllers[prevLegId]?.text ?? '';
    }
    dateControllers[legId]?.text = date;
    departureAirportControllers[legId]?.text = departureAirport;
    arrivalAirportControllers[legId]?.text = arrivalAirport;

    setState(() {
      // デフォルト運賃種別と座席クラスを設定
      final defaultFareType = airline == 'JAL' 
          ? '運賃4 (75%) スペシャルセイバー' 
          : '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
      const defaultSeatClass = '普通席';
      
      legs.add({
        'id': legId,
        'airline': airline,
        'departureAirport': departureAirport,
        'arrivalAirport': arrivalAirport,
        'fareType': defaultFareType,
        'seatClass': defaultSeatClass,
        'calculatedFOP': null,
        'calculatedMiles': null,
        'calculatedLSP': null,
      });
      expandedLegId = legId;
    });

    if (departureAirport.isNotEmpty) _fetchAvailableFlights(legs.length - 1);
      // Web版: 最下段にスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_freeDesignScrollController.hasClients) {
        _freeDesignScrollController.animateTo(
          _freeDesignScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    dateControllers[legId]?.dispose();
    flightNumberControllers[legId]?.dispose();
    departureTimeControllers[legId]?.dispose();
    arrivalTimeControllers[legId]?.dispose();
    fareAmountControllers[legId]?.dispose();
    departureAirportControllers[legId]?.dispose();
    arrivalAirportControllers[legId]?.dispose();
    departureAirportFocusNodes[legId]?.dispose();
    arrivalAirportFocusNodes[legId]?.dispose();
    dateControllers.remove(legId);
    flightNumberControllers.remove(legId);
    departureTimeControllers.remove(legId);
    arrivalTimeControllers.remove(legId);
    fareAmountControllers.remove(legId);
    departureAirportControllers.remove(legId);
    arrivalAirportControllers.remove(legId);
    departureAirportFocusNodes.remove(legId);
    arrivalAirportFocusNodes.remove(legId);
    availableFlights.remove(legId);
    availableDestinations.remove(legId);
    setState(() {
      legs.removeAt(index);
      if (expandedLegId == legId)
        expandedLegId = legs.isNotEmpty ? legs.last['id'] as int : null;
    });
  }

  // すべてのレグをクリアして新しい入力レグを作成
  void _clearAllLegs() {
    // すべてのコントローラーをdispose
    for (var controller in dateControllers.values) {
      controller.dispose();
    }
    for (var controller in flightNumberControllers.values) {
      controller.dispose();
    }
    for (var controller in departureTimeControllers.values) {
      controller.dispose();
    }
    for (var controller in arrivalTimeControllers.values) {
      controller.dispose();
    }
    for (var controller in fareAmountControllers.values) {
      controller.dispose();
    }
    for (var controller in departureAirportControllers.values) {
      controller.dispose();
    }
    for (var controller in arrivalAirportControllers.values) {
      controller.dispose();
    }
    for (var focusNode in departureAirportFocusNodes.values) {
      focusNode.dispose();
    }
    for (var focusNode in arrivalAirportFocusNodes.values) {
      focusNode.dispose();
    }

    // すべてのマップをクリア
    dateControllers.clear();
    flightNumberControllers.clear();
    departureTimeControllers.clear();
    arrivalTimeControllers.clear();
    fareAmountControllers.clear();
    departureAirportControllers.clear();
    arrivalAirportControllers.clear();
    departureAirportFocusNodes.clear();
    arrivalAirportFocusNodes.clear();
    availableFlights.clear();
    availableDestinations.clear();

    setState(() {
      legs.clear();
      expandedLegId = null;
    });

    // 新しい入力レグを作成
    _addLeg();
  }

  void _clearFlightInfo(int index, int legId) {
    setState(() {
      legs[index]['departureAirport'] = '';
      legs[index]['arrivalAirport'] = '';
      legs[index]['calculatedFOP'] = null;
      legs[index]['calculatedMiles'] = null;
      legs[index]['calculatedLSP'] = null;
      availableFlights[legId] = [];
      availableDestinations[legId] = [];
      legWarnings[legId] = null;
    });
    flightNumberControllers[legId]?.text = '';
    departureTimeControllers[legId]?.text = '';
    arrivalTimeControllers[legId]?.text = '';
    departureAirportControllers[legId]?.text = '';
    arrivalAirportControllers[legId]?.text = '';
  }

  void _clearLeg(int index, int legId) {
    _clearFlightInfo(index, legId);
    setState(() {
      legs[index]['fareType'] = '';
      legs[index]['seatClass'] = '';
    });
    dateControllers[legId]?.text = '';
    fareAmountControllers[legId]?.text = '';
  }

  String _addMinutes(String time, int minutes) {
    if (time.isEmpty || !time.contains(':')) return time;
    final parts = time.split(':');
    int hour = int.tryParse(parts[0]) ?? 0, min = int.tryParse(parts[1]) ?? 0;
    min += minutes;
    while (min >= 60) {
      min -= 60;
      hour += 1;
    }
    if (hour >= 24) hour -= 24;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  bool _isTimeAfterOrEqual(String time1, String time2) {
    if (time1.isEmpty ||
        time2.isEmpty ||
        !time1.contains(':') ||
        !time2.contains(':'))
      return true;
    final parts1 = time1.split(':'), parts2 = time2.split(':');
    return (int.tryParse(parts1[0]) ?? 0) * 60 +
            (int.tryParse(parts1[1]) ?? 0) >=
        (int.tryParse(parts2[0]) ?? 0) * 60 + (int.tryParse(parts2[1]) ?? 0);
  }

  // ======== 時刻表選択ルール ========
  List<Map<String, dynamic>> _filterFlightsByDateRule(
    List<Map<String, dynamic>> flights,
    String targetDate,
  ) {
    final flightsByRoute = <String, List<Map<String, dynamic>>>{};
    for (var flight in flights) {
      final key = '${flight['flight_number']}_${flight['arrival_code']}';
      flightsByRoute.putIfAbsent(key, () => []);
      flightsByRoute[key]!.add(flight);
    }
    final result = <Map<String, dynamic>>[];
    for (var entry in flightsByRoute.entries) {
      final routeFlights = entry.value;
      var selected = routeFlights
          .where(
            (f) =>
                (f['period_start'] as String).compareTo(targetDate) <= 0 &&
                (f['period_end'] as String).compareTo(targetDate) >= 0,
          )
          .toList();
      if (selected.isNotEmpty) {
        result.add(selected.first);
        continue;
      }
      selected = routeFlights
          .where((f) => (f['period_start'] as String).compareTo(targetDate) > 0)
          .toList();
      if (selected.isNotEmpty) {
        selected.sort(
          (a, b) => (a['period_start'] as String).compareTo(
            b['period_start'] as String,
          ),
        );
        result.add(selected.first);
        continue;
      }
      selected = routeFlights
          .where((f) => (f['period_end'] as String).compareTo(targetDate) < 0)
          .toList();
      if (selected.isNotEmpty) {
        selected.sort(
          (a, b) =>
              (b['period_end'] as String).compareTo(a['period_end'] as String),
        );
        result.add(selected.first);
      }
    }
    return result;
  }

  Map<String, dynamic>? _selectScheduleByDateRule(
    List<Map<String, dynamic>> schedules,
    String targetDate,
  ) {
    if (schedules.isEmpty) return null;
    var selected = schedules
        .where(
          (s) =>
              (s['period_start'] as String).compareTo(targetDate) <= 0 &&
              (s['period_end'] as String).compareTo(targetDate) >= 0,
        )
        .toList();
    if (selected.isNotEmpty) return selected.first;
    selected = schedules
        .where((s) => (s['period_start'] as String).compareTo(targetDate) > 0)
        .toList();
    if (selected.isNotEmpty) {
      selected.sort(
        (a, b) => (a['period_start'] as String).compareTo(
          b['period_start'] as String,
        ),
      );
      return selected.first;
    }
    selected = schedules
        .where((s) => (s['period_end'] as String).compareTo(targetDate) < 0)
        .toList();
    if (selected.isNotEmpty) {
      selected.sort(
        (a, b) =>
            (b['period_end'] as String).compareTo(a['period_end'] as String),
      );
      return selected.first;
    }
    return null;
  }

  // JALグループ（JTA/RAC/JAC）も含めて便名検索
  Future<List<Map<String, dynamic>>> _fetchSchedulesByFlightNumber(
    String airline,
    String flightNumber,
    String date,
  ) async {
    try {
      final targetDate = date.isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : date.replaceAll('/', '-');
      final List<String> airlineCodes;
      if (airline == 'JAL') {
        airlineCodes = ['JAL', 'JTA', 'RAC', 'JAC'];
      } else {
        airlineCodes = [airline];
      }
      final response = await Supabase.instance.client
          .from('schedules')
          .select()
          .inFilter('airline_code', airlineCodes)
          .eq('flight_number', flightNumber)
          .eq('is_active', true);
      final allSchedules = (response as List).cast<Map<String, dynamic>>();
      final Map<String, List<Map<String, dynamic>>> byRoute = {};
      for (var s in allSchedules) {
        final key = '${s['departure_code']}-${s['arrival_code']}';
        byRoute.putIfAbsent(key, () => []);
        byRoute[key]!.add(s);
      }
      final results = <Map<String, dynamic>>[];
      for (var routeSchedules in byRoute.values) {
        final best = _selectScheduleByDateRule(routeSchedules, targetDate);
        if (best != null) results.add(best);
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(
    String airline,
    String flightNumber,
    String date,
  ) async {
    final results = await _fetchSchedulesByFlightNumber(
      airline,
      flightNumber,
      date,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int,
        airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '',
        date = dateControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) {
      setState(() => errorMessage = '便名を入力してください');
      return;
    }
    final schedules = await _fetchSchedulesByFlightNumber(
      airline,
      flightNumber,
      date,
    );
    if (schedules.isEmpty) {
      setState(() => errorMessage = '$flightNumber便が見つかりません');
      return;
    }

    Map<String, dynamic> schedule;
    if (schedules.length > 1) {
      final selected = await _showRouteSelectionDialog(flightNumber, schedules);
      if (selected == null) return;
      schedule = selected;
    } else {
      schedule = schedules.first;
    }

    String depTime = schedule['departure_time'] ?? '',
        arrTime = schedule['arrival_time'] ?? '';
    if (depTime.length > 5) depTime = depTime.substring(0, 5);
    if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
    final depCode = schedule['departure_code'] as String,
        arrCode = schedule['arrival_code'] as String;
    setState(() {
      legs[index]['departureAirport'] = depCode;
      legs[index]['arrivalAirport'] = arrCode;
      errorMessage = null;
    });
    departureTimeControllers[legId]?.text = depTime;
    arrivalTimeControllers[legId]?.text = arrTime;
    departureAirportControllers[legId]?.text = depCode;
    arrivalAirportControllers[legId]?.text = arrCode;
    if ((schedule['remarks'] as String? ?? '').isNotEmpty)
      setState(() => legWarnings[legId] = '⚠️ 一部期間で時刻変更あり');
    await _fetchAvailableFlights(index);
    if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
    _calculateSingleLeg(index);
  }

  Future<Map<String, dynamic>?> _showRouteSelectionDialog(
    String flightNumber,
    List<Map<String, dynamic>> schedules,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$flightNumber便 - 路線を選択',
          style: const TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '同じ便名で複数の路線が見つかりました。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...schedules.map((s) {
              String depTime = s['departure_time'] ?? '';
              String arrTime = s['arrival_time'] ?? '';
              if (depTime.length > 5) depTime = depTime.substring(0, 5);
              if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
              final airlineCode = s['airline_code'] as String;
              final label = airlineCode != 'JAL' ? ' ($airlineCode)' : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, s),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s['departure_code']} → ${s['arrival_code']}$label',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '$depTime → $arrTime',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final leg = legs[index];
    final legId = leg['id'] as int, airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String,
        arrival = leg['arrivalAirport'] as String;
    final dateText = dateControllers[legId]?.text ?? '';
    if (departure.isEmpty) {
      setState(() {
        availableFlights[legId] = [];
        availableDestinations[legId] = [];
      });
      return;
    }
    final targetDate = dateText.isEmpty
        ? DateTime.now().toIso8601String().substring(0, 10)
        : dateText.replaceAll('/', '-');
    try {
      final airlineCodes = (airline == 'JAL')
          ? ['JAL', 'JTA', 'RAC', 'JAC']
          : [airline];
      final allFlightsResponse = await Supabase.instance.client
          .from('schedules')
          .select()
          .inFilter('airline_code', airlineCodes)
          .eq('departure_code', departure)
          .eq('is_active', true)
          .order('departure_time', ascending: true);
      var allFlights = _filterFlightsByDateRule(
        (allFlightsResponse as List).cast<Map<String, dynamic>>(),
        targetDate,
      );
      final seenAll = <String>{};
      allFlights = allFlights.where((flight) {
        String depTime = flight['departure_time'] ?? '';
        if (depTime.length > 5) depTime = depTime.substring(0, 5);
        final key = '${depTime}_${flight['arrival_code']}';
        if (seenAll.contains(key)) return false;
        seenAll.add(key);
        return true;
      }).toList();
      final destinations =
          allFlights.map((f) => f['arrival_code'] as String).toSet().toList()
            ..sort();
      var filteredFlights = arrival.isNotEmpty
          ? allFlights.where((f) => f['arrival_code'] == arrival).toList()
          : allFlights;
      if (index > 0) {
        final prevLeg = legs[index - 1];
        final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String,
            prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          filteredFlights = filteredFlights.where((flight) {
            String depTime = flight['departure_time'] ?? '';
            if (depTime.length > 5) depTime = depTime.substring(0, 5);
            return _isTimeAfterOrEqual(depTime, minDepartureTime);
          }).toList();
        }
      }
      setState(() {
        availableFlights[legId] = filteredFlights;
        availableDestinations[legId] = destinations;
      });
    } catch (e) {
      setState(() {
        availableFlights[legId] = [];
        availableDestinations[legId] = [];
      });
    }
  }

  Future<void> _calculateSingleLeg(int index) async {
    final leg = legs[index];
    final dep = leg['departureAirport'] as String,
        arr = leg['arrivalAirport'] as String;
    final fare = leg['fareType'] as String,
        seat = leg['seatClass'] as String,
        airline = leg['airline'] as String;
    if (dep.isEmpty || arr.isEmpty || fare.isEmpty || seat.isEmpty) return;
    try {
      final routeData = await Supabase.instance.client
          .from('routes')
          .select('distance_miles')
          .eq('departure_code', dep)
          .eq('arrival_code', arr)
          .maybeSingle();
      if (routeData == null) return;
      final distance = routeData['distance_miles'] as int;
      double fareRate = 1.0;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      final fareNumber = fare.split(' ').first;
      int totalPoints = 0, totalMiles = 0, totalLSP = 0;
      if (airline == 'JAL') {
        final seatBonusRate =
            {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seat] ?? 0.0;

        // フライトマイル = 区間マイル × (運賃率 + 座席ボーナス率)
        final flightMiles = (distance * (fareRate + seatBonusRate)).round();

        // ツアープレミアムボーナスマイル（対象運賃のみ：区間マイルとフライトマイルの差）
        int tourPremiumBonus = 0;
        if (jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5')) {
          tourPremiumBonus = distance - (distance * fareRate).round();
        }

        // カードボーナス率
        final cardBonusRate =
            {
              '-': 0.0,
              'JMB会員': 0.0,
              'JALカード普通会員': 0.10,
              'JALカードCLUB-A会員': 0.25,
              'JALカードCLUB-Aゴールド会員': 0.25,
              'JALカードプラチナ会員': 0.25,
              'JALグローバルクラブ会員(日本)': 0.35,
              'JALグローバルクラブ会員(海外)': 0.0,
              'JALカードNAVI会員': 0.10,
              'JAL CLUB EST 普通会員': 0.10,
              'JAL CLUB EST CLUB-A会員': 0.25,
              'JAL CLUB EST CLUB-A GOLD会員': 0.25,
              'JAL CLUB EST プラチナ会員': 0.25,
            }[selectedJALCard ?? '-'] ??
            0.0;

        // ステータスボーナス率
        final statusBonusRate =
            {
              '-': 0.0,
              'JMBダイヤモンド': 1.30,
              'JGCプレミア': 1.05,
              'JMBサファイア': 1.05,
              'JMBクリスタル': 0.55,
            }[selectedJALStatus ?? '-'] ??
            0.0;

        // ボーナスマイル = フライトマイル × (カードとステータスの高い方)
        // ※ツアプレボーナスにはボーナス率は適用されない
        final appliedBonusRate = cardBonusRate > statusBonusRate
            ? cardBonusRate
            : statusBonusRate;
        final bonusMiles = (flightMiles * appliedBonusRate).round();

        // 合計マイル = フライトマイル + ツアプレボーナス + ボーナスマイル
        totalMiles = flightMiles + tourPremiumBonus + bonusMiles;

        // FOP = フライトマイル × 2 + 運賃ボーナス（ツアプレは影響しない）
        totalPoints = (flightMiles * 2) + (jalBonusFOP[fareNumber] ?? 0);

        totalLSP = (fareRate >= 0.5) ? 5 : 0;
      } else {
        final cardBonusRate =
            {
              '-': 0.0,
              'AMCカード(提携カード含む)': 0.0,
              'ANAカード 一般': 0.10,
              'ANAカード 学生用': 0.10,
              'ANAカード ワイド': 0.25,
              'ANAカード ゴールド': 0.25,
              'ANAカード プレミアム': 0.50,
              'SFC 一般': 0.35,
              'SFC ゴールド': 0.40,
              'SFC プレミアム': 0.50,
            }[selectedANACard ?? '-'] ??
            0.0;
        final statusBonusRate =
            {
              '-': 0.0,
              'ダイヤモンド(1年目)': 1.15,
              'ダイヤモンド(継続2年以上)': 1.25,
              'プラチナ(1年目)': 0.90,
              'プラチナ(継続2年以上)': 1.00,
              'ブロンズ(1年目)': 0.40,
              'ブロンズ(継続2年以上)': 0.50,
            }[selectedANAStatus ?? '-'] ??
            0.0;
        final cardIdx = anaCardTypes.indexOf(selectedANACard ?? '-');
        final isGoldPremium =
            cardIdx == 5 || cardIdx == 6 || cardIdx == 8 || cardIdx == 9;
        final appliedRate = (isGoldPremium && statusBonusRate > 0)
            ? statusBonusRate + 0.05
            : (cardBonusRate > statusBonusRate
                  ? cardBonusRate
                  : statusBonusRate);
        // ANA公式準拠: マイルは2段階切り捨て、PPは1式切り捨て
        final anaFlightMiles = (distance * fareRate).toInt();
        final anaBonusMiles = (anaFlightMiles * appliedRate).toInt();
        totalMiles = anaFlightMiles + anaBonusMiles;
        totalPoints =
            (distance * fareRate * 2).toInt() + (anaBonusPoint[fareNumber] ?? 0);
      }
      setState(() {
        legs[index]['calculatedFOP'] = totalPoints;
        legs[index]['calculatedMiles'] = totalMiles;
        legs[index]['calculatedLSP'] = totalLSP;
      });
    } catch (e) {}
  }

  void _recalculateAllLegs() {
    for (int i = 0; i < legs.length; i++) _calculateSingleLeg(i);
  }

  void _onJALCardChanged(String? v) {
    setState(() {
      selectedJALCard = v;
      final isJGC = v == 'JALグローバルクラブ会員(日本)' || v == 'JALグローバルクラブ会員(海外)';
      // JGCカード以外に変更した場合、JGCプレミアステータスをリセット
      if (!isJGC && selectedJALStatus == 'JGCプレミア') {
        selectedJALStatus = '-';
      }
      // JGCカード(海外)の場合のみ、ツアープレミアムを無効化
      if (v == 'JALグローバルクラブ会員(海外)') {
        jalTourPremium = false;
      }
    });
    _recalculateAllLegs();
  }

  void _onJALStatusChanged(String? v) {
    setState(() => selectedJALStatus = v);
    _recalculateAllLegs();
  }

  void _onANACardChanged(String? v) {
    setState(() => selectedANACard = v);
    _recalculateAllLegs();
  }

  void _onANAStatusChanged(String? v) {
    setState(() => selectedANAStatus = v);
    _recalculateAllLegs();
  }

  void _onJALTourPremiumChanged(bool? v) {
    setState(() => jalTourPremium = v ?? false);
    _recalculateAllLegs();
  }
  // _onJALShoppingMilePremiumChanged 削除済み

  Future<void> _saveItinerary() async {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn =
        user != null && user.email != null && user.email!.isNotEmpty;
    if (!isLoggedIn) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('旅程を保存するにはログインが必要です'),
            backgroundColor: Colors.orange,
          ),
        );
      return;
    }
    // Pro版制限チェック
    final proService = ProService();
    if (!await proService.canSaveLog()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('無料版の制限'),
            content: const Text(
              '無料版は${ProService.freeLogLimit}旅程まで保存できます。\n'
              'Pro版にアップグレードすると無制限に保存できます。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showProPurchaseDialog(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text(
                  'Pro版を見る',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
      setState(() => isLoading = false);
      return;
    }

    final validLegs = legs
        .where((leg) => leg['calculatedFOP'] != null)
        .toList();
    if (validLegs.isEmpty) {
      setState(() => errorMessage = '保存するレグがありません');
      return;
    }
    setState(() => isLoading = true);
    try {
      final airports = <String>[];
      for (var leg in validLegs) {
        final dep = leg['departureAirport'] as String,
            arr = leg['arrivalAirport'] as String;
        if (airports.isEmpty || airports.last != dep) airports.add(dep);
        airports.add(arr);
      }
      final title = '${airports.join("-")} ${validLegs.length}レグ';
      final legsJson = validLegs.map((leg) {
        final legId = leg['id'] as int;
        return {
          'airline': leg['airline'],
          'date': dateControllers[legId]?.text ?? '',
          'flight_number': flightNumberControllers[legId]?.text ?? '',
          'departure_airport': leg['departureAirport'],
          'arrival_airport': leg['arrivalAirport'],
          'departure_time': departureTimeControllers[legId]?.text ?? '',
          'arrival_time': arrivalTimeControllers[legId]?.text ?? '',
          'fare_type': leg['fareType'],
          'seat_class': leg['seatClass'],
          'fare_amount':
              int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0,
          'fop': leg['calculatedFOP'],
          'miles': leg['calculatedMiles'],
          'lsp': leg['calculatedLSP'],
        };
      }).toList();

      // 最終レグの到着日時を判定してis_completedを設定
      final lastLeg = validLegs.last;
      final lastLegId = lastLeg['id'] as int;
      final lastDate = dateControllers[lastLegId]?.text ?? '';
      final lastArrTime = arrivalTimeControllers[lastLegId]?.text ?? '';
      final isCompleted = _isFlightCompleted(lastDate, lastArrTime);

      await Supabase.instance.client.from('saved_itineraries').insert({
        'user_id': user!.id,
        'title': title,
        'legs': legsJson,
        'total_fop': jalFOP,
        'total_pp': anaPP,
        'total_miles': jalMiles + anaMiles,
        'total_lsp': jalLSP,
        'total_fare': jalFare + anaFare,
        'jal_card': selectedJALCard,
        'ana_card': selectedANACard,
        'jal_status': selectedJALStatus,
        'ana_status': selectedANAStatus,
        'jal_tour_premium': jalTourPremium,
        'is_completed': isCompleted,
      });
      setState(() {
        isLoading = false;
        errorMessage = null;
      });
      final tabName = isCompleted ? '修行済み' : '予定';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$title」を$tabNameに保存しました'),
            backgroundColor: Colors.green,
          ),
        );

        // 保存成功後、すべてのレグをクリア
        _clearAllLegs();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '保存に失敗しました: $e';
      });
    }
  }

  // フライトが完了しているかどうかを判定
  bool _isFlightCompleted(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return false; // 日付なし = 妄想 = 予定扱い
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return false;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      int hour = 23, minute = 59; // 時刻なしの場合は日付の終わり
      if (timeStr.isNotEmpty && timeStr.contains(':')) {
        final timeParts = timeStr.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      final flightDateTime = DateTime(year, month, day, hour, minute);
      return DateTime.now().isAfter(flightDateTime);
    } catch (e) {
      return false;
    }
  }

  String _formatNumber(int number) => number == 0
      ? '0'
      : number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  int get jalFOP => legs
      .where((l) => l['airline'] == 'JAL')
      .fold<int>(0, (s, l) => s + ((l['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs
      .where((l) => l['airline'] == 'JAL')
      .fold<int>(0, (s, l) => s + ((l['calculatedMiles'] as int?) ?? 0));
  int get jalLSP => legs
      .where((l) => l['airline'] == 'JAL')
      .fold<int>(0, (s, l) => s + ((l['calculatedLSP'] as int?) ?? 0));
  // ショッピング関連getter削除済み(isAutoShoppingMilePremium, isShoppingMileEligible, isShoppingMilePremiumActive, jalShoppingMiles, jalShoppingLSP)
  int get jalCount => legs
      .where((l) => l['airline'] == 'JAL' && l['calculatedFOP'] != null)
      .length;
  int get jalFare {
    int s = 0;
    for (var l in legs) {
      if (l['airline'] != 'JAL') continue;
      s += int.tryParse(fareAmountControllers[l['id'] as int]?.text ?? '') ?? 0;
    }
    return s;
  }

  String get jalUnitPrice =>
      (jalFare > 0 && jalFOP > 0) ? (jalFare / jalFOP).toStringAsFixed(1) : '-';
  int get anaPP => legs
      .where((l) => l['airline'] == 'ANA')
      .fold<int>(0, (s, l) => s + ((l['calculatedFOP'] as int?) ?? 0));
  int get anaMiles => legs
      .where((l) => l['airline'] == 'ANA')
      .fold<int>(0, (s, l) => s + ((l['calculatedMiles'] as int?) ?? 0));
  int get anaCount => legs
      .where((l) => l['airline'] == 'ANA' && l['calculatedFOP'] != null)
      .length;
  int get anaFare {
    int s = 0;
    for (var l in legs) {
      if (l['airline'] != 'ANA') continue;
      s += int.tryParse(fareAmountControllers[l['id'] as int]?.text ?? '') ?? 0;
    }
    return s;
  }

  String get anaUnitPrice =>
      (anaFare > 0 && anaPP > 0) ? (anaFare / anaPP).toStringAsFixed(1) : '-';
  List<String> _getSortedAirportList(List<String> inputList) {
    final m = majorAirports.where((a) => inputList.contains(a)).toList(),
        r = regionalAirports.where((a) => inputList.contains(a)).toList();
    if (m.isEmpty) return r;
    if (r.isEmpty) return m;
    return [...m, airportDivider, ...r];
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    try {
      final p = text.split('/');
      if (p.length == 3)
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (e) {}
    return null;
  }

  // 空港名→空港コード変換
  final Map<String, String> airportNameToCode = {
    '羽田': 'HND',
    '東京(羽田)': 'HND',
    '成田': 'NRT',
    '東京(成田)': 'NRT',
    '関西': 'KIX',
    '大阪(関西)': 'KIX',
    '伊丹': 'ITM',
    '大阪(伊丹)': 'ITM',
    '中部': 'NGO',
    '名古屋(中部)': 'NGO',
    '新千歳': 'CTS',
    '札幌(新千歳)': 'CTS',
    '福岡': 'FUK',
    '那覇': 'OKA',
    '沖縄(那覇)': 'OKA',
    '石垣': 'ISG',
    '宮古': 'MMY',
    '長崎': 'NGS',
    '熊本': 'KMJ',
    '大分': 'OIT',
    '松山': 'MYJ',
    '広島': 'HIJ',
    '高松': 'TAK',
    '高知': 'KCZ',
    '徳島': 'TKS',
    '鹿児島': 'KOJ',
    '仙台': 'SDJ',
    '青森': 'AOJ',
    '旭川': 'AKJ',
    '秋田': 'AXT',
    '山形': 'GAJ',
    '新潟': 'KIJ',
    '富山': 'TOY',
    '小松': 'KMQ',
    '静岡': 'FSZ',
    '女満別': 'MMB',
    '帯広': 'OBO',
    '釧路': 'KUH',
    '函館': 'HKD',
    '北九州': 'KKJ',
    '宮崎': 'KMI',
    '奄美': 'ASJ',
    '久米島': 'UEO',
    '北大東': 'KTD',
    '南大東': 'MMD',
    '多良間': 'TRA',
    '下地島': 'SHI',
    '沖永良部': 'OKE',
  };

  // JAL運賃名→運賃種別マッピング
  String _mapJALFareType(String fareName) {
    final lower = fareName.toLowerCase();
    if (lower.contains('フレックス') || lower.contains('flex'))
      return '運賃1 (100%) フレックス等';
    if (lower.contains('株主')) return '運賃2 (75%) 株主割引';
    if (lower.contains('特便') || lower.contains('先得') || lower.contains('セイバー'))
      return '運賃3 (75%) セイバー';
    if (lower.contains('ウルトラ') ||
        lower.contains('スーパー先得') ||
        lower.contains('スペシャル'))
      return '運賃4 (75%) スペシャルセイバー';
    if (lower.contains('包括') || lower.contains('ツアー'))
      return '運賃5 (50%) 包括旅行運賃';
    if (lower.contains('スカイメイト') || lower.contains('当日'))
      return '運賃6 (50%) スカイメイト等';
    return '運賃3 (75%) セイバー';
  }

  // ANA運賃名→運賃種別マッピング
  String _mapANAFareType(String fareName) {
    final lower = fareName.toLowerCase();
    // プレミアムクラス系
    if (lower.contains('プレミアム') && (lower.contains('株主') || lower.contains('優待')))
      return '運賃2 (125%) プレミアム株主優待/VALUE PREMIUM';
    if (lower.contains('プレミアム') || lower.contains('value premium'))
      return '運賃1 (150%) プレミアム運賃';
    // 普通席系
    if (lower.contains('フレックス') || lower.contains('flex') || lower.contains('biz'))
      return '運賃3 (100%) ANA FLEX/ビジネスきっぷ/Biz';
    if (lower.contains('ビジネスきっぷ'))
      return '運賃3 (100%) ANA FLEX/ビジネスきっぷ/Biz';
    if (lower.contains('アイきっぷ'))
      return '運賃4 (100%) 各種アイきっぷ';
    if (lower.contains('トランジット') || lower.contains('transit'))
      return '運賃6 (75%) ANA VALUE TRANSIT';
    if (lower.contains('スーパーバリュー') || lower.contains('super value') || lower.contains('いっしょに'))
      return '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
    if (lower.contains('バリュー') || lower.contains('value') || lower.contains('株主') || lower.contains('優待') || lower.contains('特割'))
      return '運賃5 (75%) ANA VALUE/株主優待';
    if (lower.contains('sale') || lower.contains('セール') || lower.contains('シニア') || lower.contains('u25') || lower.contains('スマート'))
      return '運賃8 (50%) 個人包括/スマートU25/スマートシニア/SALE';
    if (lower.contains('包括') || lower.contains('ツアー'))
      return '運賃8 (50%) 個人包括/スマートU25/スマートシニア/SALE';
    return '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
  }

  // ANA: 運賃種別から座席クラスを自動判定
  String _anaSeatClassForFare(String fareType) {
    final fareNumber = fareType.split(' ').first;
    if (fareNumber == '運賃1' || fareNumber == '運賃2' || fareNumber == '運賃9')
      return 'プレミアムクラス';
    return '普通席';
  }

  // メール解析
  List<Map<String, dynamic>> _parseEmailText(String text) {
    final results = <Map<String, dynamic>>[];

    // JAL形式の解析
    final jalPattern = RegExp(
      r'\((\d+)\)\s*(\d{4})年(\d{1,2})月(\d{1,2})日\s+(JAL|JTA|RAC|JAC)\s*(\d+)便\s+([^\d]+?)\s*(\d{1,2}:\d{2})発\s*→\s*([^\d]+?)\s*(\d{1,2}:\d{2})着\s+(普通席|ファーストクラス|クラスJ)\s+ご利用運賃\s+([^/]+?)(?:/|合計)',
      multiLine: true,
    );

    for (final match in jalPattern.allMatches(text)) {
      final year = match.group(2)!;
      final month = match.group(3)!.padLeft(2, '0');
      final day = match.group(4)!.padLeft(2, '0');
      final flightNum = '${match.group(5)}${match.group(6)}';
      final depName = match.group(7)!.trim();
      final depTime = match.group(8)!;
      final arrName = match.group(9)!.trim();
      final arrTime = match.group(10)!;
      final seatClass = match.group(11)!;
      final fareName = match.group(12)!.trim();

      results.add({
        'airline': 'JAL',
        'date': '$year/$month/$day',
        'flightNumber': flightNum,
        'departure': airportNameToCode[depName] ?? depName,
        'arrival': airportNameToCode[arrName] ?? arrName,
        'departureTime': depTime,
        'arrivalTime': arrTime,
        'seatClass': seatClass,
        'fareType': _mapJALFareType(fareName),
      });
    }

    // ANA形式の解析(シンプル版)
    // 形式: [1] 2026年3月2日(月)  ANA 089    東京(羽田)(08:15) - 石垣(11:30)    普通席    (往復)スーパーバリュー28K
    final anaFlightPattern = RegExp(
      r'\[(\d+)\]\s*(\d{4})年(\d{1,2})月(\d{1,2})日',
    );
    final anaMatches = anaFlightPattern.allMatches(text).toList();

    for (int i = 0; i < anaMatches.length; i++) {
      final match = anaMatches[i];
      final startPos = match.start;
      final endPos = (i + 1 < anaMatches.length)
          ? anaMatches[i + 1].start
          : text.length;
      final segment = text.substring(startPos, endPos);

      // ANAかどうか確認
      if (!segment.contains('ANA')) continue;

      final year = match.group(2)!;
      final month = match.group(3)!.padLeft(2, '0');
      final day = match.group(4)!.padLeft(2, '0');

      // フライト番号: ANA 089 or ANA089
      final flightMatch = RegExp(r'ANA\s*(\d+)').firstMatch(segment);
      if (flightMatch == null) continue;
      final flightNum = 'ANA${flightMatch.group(1)}';

      // 時刻パターン: (08:15) - ... (11:30)
      final timeMatches = RegExp(
        r'\((\d{1,2}:\d{2})\)',
      ).allMatches(segment).toList();
      if (timeMatches.length < 2) continue;
      final depTime = timeMatches[0].group(1)!;
      final arrTime = timeMatches[1].group(1)!;

      // 出発地と到着地: 東京(羽田)(08:15) - 石垣(11:30)
      final routeMatch = RegExp(
        r'ANA\s*\d+\s+(.+?)\(' +
            depTime +
            r'\)\s*-\s*(.+?)\(' +
            arrTime +
            r'\)',
      ).firstMatch(segment);
      if (routeMatch == null) continue;
      var depName = routeMatch.group(1)!.trim();
      var arrName = routeMatch.group(2)!.trim();

      // 括弧を含む空港名から括弧部分を抽出: 東京(羽田) -> 羽田
      final depInner = RegExp(r'\(([^)]+)\)$').firstMatch(depName);
      if (depInner != null) depName = depInner.group(1)!;
      final arrInner = RegExp(r'\(([^)]+)\)$').firstMatch(arrName);
      if (arrInner != null) arrName = arrInner.group(1)!;

      // 座席クラス
      final seatClass = segment.contains('プレミアムクラス') ? 'プレミアムクラス' : '普通席';

      // 運賃タイプ
      final fareMatch = RegExp(
        r'(普通席|プレミアムクラス)\s+[((]?[往復片道]*[))]?([^\s予約]+)',
      ).firstMatch(segment);
      final fareName = fareMatch?.group(2)?.trim() ?? '';

      results.add({
        'airline': 'ANA',
        'date': '$year/$month/$day',
        'flightNumber': flightNum,
        'departure': airportNameToCode[depName] ?? depName,
        'arrival': airportNameToCode[arrName] ?? arrName,
        'departureTime': depTime,
        'arrivalTime': arrTime,
        'seatClass': seatClass,
        'fareType': _mapANAFareType(fareName),
      });
    }

    return results;
  }

  // メールから入力ダイアログ
  Future<void> _showEmailImportDialog() async {
    // ログインチェック(匿名ユーザーも除外)
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn =
        user != null && user.email != null && user.email!.isNotEmpty;

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メールから入力するにはログインが必要です'),
            backgroundColor: Colors.orange,
          ),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              onAuthSuccess: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _showEmailImportDialogInternal();
                });
              },
            ),
          ),
        );
      }
      return;
    }

    _showEmailImportDialogInternal();
  }

  Future<void> _showEmailImportDialogInternal() async {
    final controller = TextEditingController();
    final isPro = await ProService().isPro();

    if (!mounted) return;
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.email, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('メールから入力', style: TextStyle(fontSize: 16)),
                if (isPro) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro
                        ? 'JAL/ANAの予約確認メールを貼り付けてください（AI解析）'
                        : 'JAL/ANAの予約確認メールを貼り付けてください',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'メール本文をここに貼り付け...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  if (!isPro) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.purple[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pro版ならAIがどんなメール形式でも正確に解析します',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                showProPurchaseDialog(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Pro版を見る',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) {
                          setDialogState(() => errorMsg = 'メール本文を貼り付けてください');
                          return;
                        }

                        if (isPro) {
                          // Pro: AI解析（Edge Function）
                          setDialogState(() {
                            isLoading = true;
                            errorMsg = null;
                          });
                          try {
                            final response = await Supabase
                                .instance
                                .client
                                .functions
                                .invoke(
                                  'swift-endpoint',
                                  body: {'emailText': controller.text},
                                );
                            if (response.status != 200) {
                              throw Exception(
                                response.data['error'] ?? '解析に失敗しました',
                              );
                            }
                            final data = response.data as Map<String, dynamic>;
                            final parsedLegs = (data['legs'] as List<dynamic>)
                                .map((e) => Map<String, dynamic>.from(e as Map))
                                .map((l) {
                                  // Edge Functionのキー名をアプリ内のキー名に変換
                                  final airline =
                                      l['airline'] as String? ?? 'JAL';
                                  final rawFareType =
                                      l['fare_type'] as String? ?? '';
                                  final mappedFareType = airline == 'JAL'
                                      ? _mapJALFareType(rawFareType)
                                      : _mapANAFareType(rawFareType);
                                  // 便名にエアライン名を付加（数字のみの場合）
                                  var flightNum = (l['flight_number'] ?? '')
                                      .toString();
                                  if (flightNum.isNotEmpty &&
                                      RegExp(r'^\d+$').hasMatch(flightNum)) {
                                    flightNum = '$airline$flightNum';
                                  }
                                  return {
                                    'airline': airline,
                                    'date': l['date'],
                                    'flightNumber': flightNum,
                                    'departure': l['departure'],
                                    'arrival': l['arrival'],
                                    'departureTime': l['departure_time'] ?? '',
                                    'arrivalTime': l['arrival_time'] ?? '',
                                    'seatClass': (l['seat_class'] == 'ファースト')
                                        ? 'ファーストクラス'
                                        : l['seat_class'],
                                    'fareType': mappedFareType,
                                    'fare': l['fare'],
                                  };
                                })
                                .toList();
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext, parsedLegs);
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorMsg = 'AI解析エラー: $e';
                            });
                          }
                        } else {
                          // 無料版: ローカル正規表現解析
                          final parsed = _parseEmailText(controller.text);
                          Navigator.pop(dialogContext, parsed);
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isPro ? 'AI解析' : '解析',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (result != null && result.isNotEmpty) {
      // 解析結果を既存レグに追加（削除しない）
      for (int i = 0; i < result.length; i++) {
        // 新しいレグを追加
        _addLeg();
        await Future.delayed(const Duration(milliseconds: 50));

        final data = result[i];
        final newIndex = legs.length - 1;
        final legId = legs[newIndex]['id'] as int;

        setState(() {
          legs[newIndex]['airline'] = data['airline'];
          legs[newIndex]['departureAirport'] = data['departure'];
          legs[newIndex]['arrivalAirport'] = data['arrival'];
          legs[newIndex]['fareType'] = data['fareType'];
          legs[newIndex]['seatClass'] = data['seatClass'];
        });

        dateControllers[legId]?.text = data['date'] ?? '';
        flightNumberControllers[legId]?.text = data['flightNumber'] ?? '';
        departureTimeControllers[legId]?.text = data['departureTime'] ?? '';
        arrivalTimeControllers[legId]?.text = data['arrivalTime'] ?? '';
        departureAirportControllers[legId]?.text = data['departure'] ?? '';
        arrivalAirportControllers[legId]?.text = data['arrival'] ?? '';
        if (data['fare'] != null && data['fare'] != 0) {
          fareAmountControllers[legId]?.text = data['fare'].toString();
        }

        await _fetchAvailableFlights(newIndex);
        _calculateSingleLeg(newIndex);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.length}件のフライトを追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (result != null && result.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('フライト情報が見つかりませんでした'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  // ダークネイビー背景色
  static const Color _darkNavy = Color(0xFF1A1A2E);

  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Container(
      color: _darkNavy,
      child: Column(
        children: [
          Container(
            color: _darkNavy,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: '✈ 自由設計'),
                Tab(text: '🎯 おまかせ最適化'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFreeDesignTab(), _buildOptimizerTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDesignTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        // 表示順序を計算
        List<MapEntry<int, Map<String, dynamic>>> displayOrder = [];

        if (legs.isNotEmpty) {
          if (isMobile) {
            // モバイル: 最新レグを最上段、それ以外は時系列順（現状維持）
            final latestIndex = legs.length - 1;
            final latestEntry = MapEntry(latestIndex, legs[latestIndex]);

            final oldLegs = legs
                .asMap()
                .entries
                .where((e) => e.key != latestIndex)
                .toList();
            oldLegs.sort((a, b) {
              final aId = a.value['id'] as int;
              final bId = b.value['id'] as int;
              final aDate = dateControllers[aId]?.text ?? '';
              final bDate = dateControllers[bId]?.text ?? '';
              final aTime = departureTimeControllers[aId]?.text ?? '';
              final bTime = departureTimeControllers[bId]?.text ?? '';

              if (aDate.isNotEmpty && bDate.isNotEmpty) {
                final dateCompare = aDate
                    .replaceAll('/', '')
                    .compareTo(bDate.replaceAll('/', ''));
                if (dateCompare != 0) return dateCompare;
              }
              if (aTime.isNotEmpty && bTime.isNotEmpty) {
                return aTime.compareTo(bTime);
              }
              return aId.compareTo(bId);
            });

            displayOrder = [latestEntry, ...oldLegs];
          } else {
            // Web: 追加順そのまま（上から下に並ぶ）
            displayOrder = legs.asMap().entries.toList();
          }
        }

        return SingleChildScrollView(
          controller: isMobile ? null : _freeDesignScrollController,
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryBar(isMobile),
              // 既存レグを表示
              if (displayOrder.isNotEmpty)
                ...displayOrder.map((e) {
                  final isLatest = legs.isNotEmpty && e.key == legs.length - 1;
                  return _buildLegCard(
                    context,
                    e.value,
                    e.key,
                    isMobile,
                    isLatest: isLatest,
                  );
                }),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ========== おまかせ最適化タブ ==========

  // 運賃種別からfareRate/bonusFopを抽出
  Map<String, dynamic> _extractFareParams(String airline, String fareType) {
    double fareRate = 0.75;
    int bonusFop = airline == 'JAL' ? 400 : 0;
    if (fareType.isNotEmpty) {
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fareType);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      final fareNumber = fareType.split(' ').first;
      if (airline == 'JAL') {
        bonusFop = jalBonusFOP[fareNumber] ?? 400;
      } else {
        bonusFop = anaBonusPoint[fareNumber] ?? 0;
      }
    }
    return {'fareRate': fareRate, 'bonusFop': bonusFop};
  }

  Future<void> _runOptimization() async {
    // ログインチェック
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn =
        user != null && user.email != null && user.email!.isNotEmpty;
    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最適ルート検索にはログインが必要です'),
            backgroundColor: Colors.orange,
          ),
        );
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
      }
      return;
    }
    if (_optDate.isEmpty) {
      setState(() => _optError = '日付を選択してください');
      return;
    }
    if (_optFareType.isEmpty) {
      setState(() => _optError = '運賃種別を選択してください');
      return;
    }
    setState(() {
      _optSearching = true;
      _optError = null;
      _optResults = [];
      _optResultLimited = false;
    });
    try {
      final optimizer = PlanOptimizer();
      await optimizer.loadData(
        _optAirline,
        _optDate,
        includeCodeshare: _optIncludeCodeshare,
      );
      final fareParams = _extractFareParams(_optAirline, _optFareType);
      final results = optimizer.findOptimalPlans(
        _optHomeAirport,
        fareRate: fareParams['fareRate'],
        bonusFop: fareParams['bonusFop'],
        airline: _optAirline,
      );
      final isPro = await ProService().isPro();
      setState(() {
        _optResults = results;
        _optIsPro = isPro;
        _optSearching = false;
        // 2位以降のデータがあるかチェック（Pro版でTOP3表示のため）
        _optResultLimited = !isPro && results.any((plan) =>
          (plan.children != null && plan.children!.length > 1) ||
          (plan.children != null && plan.children!.any((c) => 
            c.children != null && c.children!.length > 1)));
        if (results.isEmpty) _optError = '$_optHomeAirport発の最適ルートが見つかりませんでした';
      });
    } catch (e) {
      setState(() {
        _optSearching = false;
        _optError = 'エラー: $e';
      });
    }
  }

  Widget _buildOptimizerTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final pad = isMobile ? 12.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 入力フォーム
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '条件を設定',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '※ 修行ログに追加後、レグごとの運賃・座席を変更できます',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // 航空会社 + コードシェア
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _optInputSection(
                          '航空会社',
                          120,
                          DropdownButton<String>(
                            value: _optAirline,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: ['JAL', 'ANA']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: e == 'JAL'
                                            ? Colors.red
                                            : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _optAirline = v!;
                              _optFareType = v == 'JAL'
                                  ? '運賃4 (75%) スペシャルセイバー'
                                  : '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
                            }),
                          ),
                        ),
                        _optInputSection(
                          '出発空港',
                          120,
                          DropdownButton<String>(
                            value: _optHomeAirport,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: majorAirports
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      '$e (${airportNames[e] ?? e})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _optHomeAirport = v!),
                          ),
                        ),
                        _optInputSection(
                          '搭乗日',
                          150,
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _parseDate(_optDate) ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    dialogTheme: const DialogThemeData(
                                      insetPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 24,
                                      ),
                                    ),
                                  ),
                                  child: MediaQuery(
                                    data: MediaQuery.of(context).copyWith(
                                      textScaler: const TextScaler.linear(0.9),
                                    ),
                                    child: child!,
                                  ),
                                ),
                              );
                              if (picked != null) {
                                setState(
                                  () => _optDate =
                                      '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}',
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[400]!),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _optDate.isEmpty ? '日付を選択' : _optDate,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _optDate.isEmpty
                                            ? Colors.grey
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _optInputSection(
                          '運賃種別',
                          200,
                          DropdownButton<String>(
                            value:
                                _optFareType.isEmpty ||
                                    !(fareTypesByAirline[_optAirline] ?? [])
                                        .contains(_optFareType)
                                ? null
                                : _optFareType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            hint: const Text(
                              '選択してください',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            items: (fareTypesByAirline[_optAirline] ?? [])
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _optFareType = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // コードシェア便チェックボックス
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _optIncludeCodeshare,
                            onChanged: (v) => setState(
                              () => _optIncludeCodeshare = v ?? true,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(
                            () => _optIncludeCodeshare = !_optIncludeCodeshare,
                          ),
                          child: Text(
                            _optAirline == 'JAL'
                                ? 'JTA・RAC便も含める'
                                : 'コードシェア便も含める',
                            style: TextStyle(
                              fontSize: 13,
                              color: _optAirline == 'JAL'
                                  ? Colors.red[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 検索ボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _optSearching ? null : _runOptimization,
                        icon: _optSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search, size: 18),
                        label: Text(_optSearching ? '検索中...' : '最適ルートを検索'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _optAirline == 'JAL'
                              ? Colors.red
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // エラー表示
              if (_optError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _optError!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // 結果表示
              if (_optResults.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '検索結果',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._optResults.map(
                  (plan) => plan.children != null
                      ? _buildAccordionPlanCard(plan, isMobile)
                      : _buildPlanCard(plan, isMobile),
                ),
                if (_optResultLimited)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await showProPurchaseDialog(context);
                          ProService().clearCache();
                          _runOptimization();
                        },
                        icon: const Icon(Icons.lock, size: 16),
                        label: const Text('Pro版でTOP3を見る'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 免責表示
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '時刻表、マイル、FOP/PPは参考情報です。最新情報は公式サイトでご確認ください。',
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _optInputSection(String label, double width, Widget child) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _buildPlanCard(OptimalPlan plan, bool isMobile) {
    final color = _optAirline == 'JAL' ? Colors.red : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー: ラベル + 合計FOP
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  plan.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatNumber(plan.totalFop)} ${_optAirline == "JAL" ? "FOP" : "PP"}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ルート + 所要時間
          Row(
            children: [
              Icon(Icons.route, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _routeToJapanese(plan.route),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${plan.legCount}レグ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${plan.departureTime} → ${plan.arrivalTime}（${plan.duration}）',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
          // フライト詳細
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: plan.flights.asMap().entries.map((e) {
                final i = e.key;
                final f = e.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i < plan.flights.length - 1 ? 4 : 0,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          f.flightNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${f.departureCode}→${f.arrivalCode}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${f.departureTime}-${f.arrivalTime}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${f.fop}${_optAirline == "JAL" ? "FOP" : "PP"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // 修行ログに保存ボタン
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _saveOptimalPlanToLog(plan),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('修行ログに追加', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionPlanCard(OptimalPlan plan, bool isMobile) {
    final color = _optAirline == 'JAL' ? Colors.red : Colors.blue;
    final children = plan.children ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              plan.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          // 無料版は1位のみ、Pro版はTOP3
          children: (_optIsPro ? children : children.take(1)).map((group) {
            // 子がchildren持ち = サブアコーディオン（💰最多FOP / ⏱️最短時間）
            if (group.children != null && group.children!.isNotEmpty) {
              return _buildSubAccordion(group, color);
            }
            // childrenなし = フラット表示
            return _buildRankedPlanTile(group, color);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubAccordion(OptimalPlan group, Color color) {
    final subChildren = group.children ?? [];
    final isFop = group.label.contains('FOP') || group.label.contains('PP');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Row(
            children: [
              Text(
                group.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              // 1位の代表値を表示
              if (isFop)
                Text(
                  '${_formatNumber(group.totalFop)} ${_optAirline == "JAL" ? "FOP" : "PP"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                )
              else
                Text(
                  group.duration,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
          // 無料版は1位のみ、Pro版はTOP3
          children: (_optIsPro ? subChildren : subChildren.take(1))
              .map((ranked) => _buildRankedPlanTile(ranked, color))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRankedPlanTile(OptimalPlan plan, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1行目: ラベル + ルート（全表示）
              Row(
                children: [
                  Text(
                    plan.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _routeToJapanese(plan.route),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // 2行目: FOP/PP + 所要時間
              Row(
                children: [
                  Text(
                    '${_formatNumber(plan.totalFop)} ${_optAirline == "JAL" ? "FOP" : "PP"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    plan.duration,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          children: [
            // フライト詳細
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  ...plan.flights.asMap().entries.map((e) {
                    final i = e.key;
                    final f = e.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < plan.flights.length - 1 ? 2 : 0,
                      ),
                      child: Row(
                        children: [
                          // 便名
                          SizedBox(
                            width: 45,
                            child: Text(
                              f.flightNumber,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // 出発時間
                          Text(
                            f.departureTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 出発空港
                          Text(
                            f.departureCode,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey[400]),
                          ),
                          // 到着空港
                          Text(
                            f.arrivalCode,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          // 到着時間
                          Text(
                            f.arrivalTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          // FOP/PP
                          Text(
                            '${f.fop}${_optAirline == "JAL" ? "FOP" : "PP"}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _saveOptimalPlanToLog(plan),
                      icon: const Icon(Icons.arrow_forward, size: 12),
                      label: const Text(
                        '修行ログに追加',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOptimalPlanToLog(OptimalPlan plan) async {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn =
        user != null && user.email != null && user.email!.isNotEmpty;
    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('修行ログに保存するにはログインが必要です'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final proService = ProService();
    if (!await proService.canSaveLog()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('無料版の制限'),
            content: const Text(
              '無料版は${ProService.freeLogLimit}旅程まで保存できます。\n'
              'Pro版にアップグレードすると無制限に保存できます。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showProPurchaseDialog(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('Pro版を見る',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final airports = plan.flights.map((f) => f.departureCode).toList();
      airports.add(plan.flights.last.arrivalCode);
      final title = '${airports.join("-")} ${plan.flights.length}レグ';

      // Extract fare params
      double fareRate = 0.75;
      final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(_optFareType);
      if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      final fareNumber = _optFareType.split(' ').first;

      int grandTotalFop = 0, grandTotalMiles = 0, grandTotalLsp = 0;

      final legsJson = plan.flights.map((f) {
        final distance = f.distanceMiles;
        int legFop = 0, legMiles = 0, legLsp = 0;

        if (_optAirline == 'JAL') {
          // Seat bonus (optimizer default: 普通席)
          const seatBonusRate = 0.0;
          final flightMiles = (distance * (fareRate + seatBonusRate)).round();

          // Tour premium bonus
          int tourPremiumBonus = 0;
          final isJGCOverseas =
              selectedJALCard == 'JALグローバルクラブ会員(海外)';
          if (!isJGCOverseas && jalTourPremium &&
              (fareNumber == '運賃4' || fareNumber == '運賃5')) {
            tourPremiumBonus = distance - (distance * fareRate).round();
          }

          // Card bonus rate
          final cardBonusRate = {
            'JMB会員': 0.0,
            'JALカード普通会員': 0.10,
            'JALカードCLUB-A会員': 0.25,
            'JALカードCLUB-Aゴールド会員': 0.25,
            'JALカードプラチナ会員': 0.25,
            'JALグローバルクラブ会員(日本)': 0.35,
            'JALグローバルクラブ会員(海外)': 0.0,
            'JALカードNAVI会員': 0.10,
            'JAL CLUB EST 普通会員': 0.10,
            'JAL CLUB EST CLUB-A会員': 0.25,
            'JAL CLUB EST CLUB-A GOLD会員': 0.25,
            'JAL CLUB EST プラチナ会員': 0.25,
          }[selectedJALCard ?? '-'] ?? 0.0;

          // Status bonus rate
          final statusBonusRate = {
            'JMBダイヤモンド': 1.30,
            'JGCプレミア': 1.05,
            'JMBサファイア': 1.05,
            'JMBクリスタル': 0.55,
          }[selectedJALStatus ?? '-'] ?? 0.0;

          final appliedBonusRate = cardBonusRate > statusBonusRate
              ? cardBonusRate : statusBonusRate;
          final bonusMiles = (flightMiles * appliedBonusRate).round();

          legMiles = flightMiles + tourPremiumBonus + bonusMiles;
          legFop = (flightMiles * 2) + (jalBonusFOP[fareNumber] ?? 0);
          legLsp = (fareRate >= 0.5) ? 5 : 0;
        } else {
          // ANA calculation
          final cardBonusRate = {
            'AMCカード(提携カード含む)': 0.0,
            'ANAカード 一般': 0.10,
            'ANAカード 学生用': 0.10,
            'ANAカード ワイド': 0.25,
            'ANAカード ゴールド': 0.25,
            'ANAカード プレミアム': 0.50,
            'SFC 一般': 0.35,
            'SFC ゴールド': 0.40,
            'SFC プレミアム': 0.50,
          }[selectedANACard ?? '-'] ?? 0.0;

          final statusBonusRate = {
            'ダイヤモンド(1年目)': 1.15,
            'ダイヤモンド(継続2年以上)': 1.25,
            'プラチナ(1年目)': 0.90,
            'プラチナ(継続2年以上)': 1.00,
            'ブロンズ(1年目)': 0.40,
            'ブロンズ(継続2年以上)': 0.50,
          }[selectedANAStatus ?? '-'] ?? 0.0;

          final cardIdx = anaCardTypes.indexOf(selectedANACard ?? '-');
          final isGoldPremium =
              cardIdx == 5 || cardIdx == 6 || cardIdx == 8 || cardIdx == 9;
          final appliedRate = (isGoldPremium && statusBonusRate > 0)
              ? statusBonusRate + 0.05
              : (cardBonusRate > statusBonusRate
                    ? cardBonusRate : statusBonusRate);

          // ANA公式準拠: マイルは2段階切り捨て、PPは1式切り捨て
          final anaFlightMiles = (distance * fareRate).toInt();
          final anaBonusMiles = (anaFlightMiles * appliedRate).toInt();
          legMiles = anaFlightMiles + anaBonusMiles;
          legFop = (distance * fareRate * 2).toInt() +
              (anaBonusPoint[fareNumber] ?? 0);
          legLsp = 0;
        }

        grandTotalFop += legFop;
        grandTotalMiles += legMiles;
        grandTotalLsp += legLsp;

        return {
          'airline': _optAirline,
          'date': _optDate,
          'flight_number': f.flightNumber,
          'departure_airport': f.departureCode,
          'arrival_airport': f.arrivalCode,
          'departure_time': f.departureTime,
          'arrival_time': f.arrivalTime,
          'fare_type': _optFareType,
          'seat_class': '普通席',
          'fare_amount': 0,
          'fop': legFop,
          'miles': legMiles,
          'lsp': legLsp,
        };
      }).toList();

      final isCompleted = _isFlightCompleted(
        _optDate, plan.flights.last.arrivalTime,
      );

      final res = await Supabase.instance.client
          .from('saved_itineraries')
          .insert({
            'user_id': user!.id,
            'title': title,
            'legs': legsJson,
            'total_fop': _optAirline == 'JAL' ? grandTotalFop : 0,
            'total_pp': _optAirline == 'ANA' ? grandTotalFop : 0,
            'total_miles': grandTotalMiles,
            'total_lsp': grandTotalLsp,
            'total_fare': 0,
            'jal_card': selectedJALCard,
            'ana_card': selectedANACard,
            'jal_status': selectedJALStatus,
            'ana_status': selectedANAStatus,
            'jal_tour_premium': jalTourPremium,
            'is_completed': isCompleted,
          })
          .select('id')
          .single();

      final savedId = res['id'] as String;

      if (mounted) {
        final tabName = isCompleted ? '修行済み' : '予定';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$title」を$tabNameに保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onNavigateToFlightLog?.call(savedId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== UI WIDGETS ==========

  Widget _buildSummaryBar(bool isMobile) {
    if (isMobile) {
      final hasJAL = legs.any((l) => l['airline'] == 'JAL'),
          hasANA = legs.any((l) => l['airline'] == 'ANA');
      return Column(
        children: [
          // 免責表示
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '時刻表、マイル、FOP/PPは参考情報です。最新情報は公式サイトでご確認ください。',
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
          ),
          if (hasJAL) _buildMobileSummaryCard('JAL', Colors.red),
          if (hasJAL && hasANA) const SizedBox(height: 6),
          if (hasANA) _buildMobileSummaryCard('ANA', Colors.blue),
          const SizedBox(height: 10),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Tooltip(
            message: '初期値はプロフィール設定から引き継ぎます。\nカードやステータスを変更すると、マイル・FOP/PPが即時再計算されます。',
            child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
          ),
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'JALカード',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _openHapitas,
                      child: Text(
                        '💡カード未発行の方',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.red.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedJALCard,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    menuWidth: 250,
                    hint: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '選択',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    selectedItemBuilder: (c) => jalCardTypes
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: jalCardTypes
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onJALCardChanged,
                  ),
                ),
              ],
            ),
          ),
          // ツアープレミアムのみ(ショッピングマイルP削除)
          // JGCカード(海外)の場合のみ無効化
          Builder(
            builder: (context) {
              final isJGCOverseas =
                  selectedJALCard == 'JALグローバルクラブ会員(海外)';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: jalTourPremium,
                      onChanged: isJGCOverseas ? null : _onJALTourPremiumChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ツアープレミアム',
                    style: TextStyle(
                      fontSize: 9,
                      color: isJGCOverseas ? Colors.grey : Colors.red,
                    ),
                  ),
                ],
              );
            },
          ),
          _buildCompactDropdown(
            'JALステータス',
            120,
            selectedJALStatus,
            jalStatusTypes,
            Colors.red,
            _onJALStatusChanged,
          ),
          _buildMiniStat('FOP', _formatNumber(jalFOP), Colors.red),
          _buildMiniStat('マイル', _formatNumber(jalMiles), Colors.red),
          _buildMiniStat('LSP', _formatNumber(jalLSP), Colors.red),
          _buildMiniStat('レグ', '$jalCount', Colors.red),
          _buildMiniStat(
            '総額',
            jalFare > 0 ? '¥${_formatNumber(jalFare)}' : '-',
            Colors.red,
          ),
          _buildMiniStat(
            '単価',
            jalUnitPrice != '-' ? '¥$jalUnitPrice' : '-',
            Colors.red,
          ),
          Container(width: 1, height: 36, color: Colors.grey[300]),
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ANAカード',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _openHapitas,
                      child: Text(
                        '💡カード未発行の方',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedANACard,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    menuWidth: 250,
                    hint: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '選択',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    selectedItemBuilder: (c) => anaCardTypes
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: anaCardTypes
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onANACardChanged,
                  ),
                ),
              ],
            ),
          ),
          _buildCompactDropdown(
            'ANAステータス',
            140,
            selectedANAStatus,
            anaStatusTypes,
            Colors.blue,
            _onANAStatusChanged,
          ),
          _buildMiniStat('PP', _formatNumber(anaPP), Colors.blue),
          _buildMiniStat('マイル', _formatNumber(anaMiles), Colors.blue),
          _buildMiniStat('レグ', '$anaCount', Colors.blue),
          _buildMiniStat(
            '総額',
            anaFare > 0 ? '¥${_formatNumber(anaFare)}' : '-',
            Colors.blue,
          ),
          _buildMiniStat(
            '単価',
            anaUnitPrice != '-' ? '¥$anaUnitPrice' : '-',
            Colors.blue,
          ),
          Container(width: 1, height: 36, color: Colors.grey[300]),
          // 免責表示
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '時刻表、マイル、FOP/PPは参考情報です。最新情報は公式サイトでご確認ください。',
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummaryCard(String airline, Color color) {
    final isJAL = airline == 'JAL',
        fop = isJAL ? jalFOP : anaPP,
        count = isJAL ? jalCount : anaCount,
        unitPrice = isJAL ? jalUnitPrice : anaUnitPrice;
    final miles = isJAL ? jalMiles : anaMiles;
    final cardName = isJAL
        ? (selectedJALCard ?? '-')
        : (selectedANACard ?? '-');
    final statusName = isJAL
        ? (selectedJALStatus ?? '-')
        : (selectedANAStatus ?? '-');
    final hasSettings = cardName != '-' || statusName != '-';

    return GestureDetector(
      onTap: () => _showMobileSettingsDialog(airline),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  airline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${isJAL ? "FOP" : "PP"}: ${_formatNumber(fop)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  '${count}レグ',
                  style: TextStyle(fontSize: 11, color: color),
                ),
                if (unitPrice != '-') ...[
                  const SizedBox(width: 8),
                  Text(
                    'Â¥$unitPrice',
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(Icons.settings, size: 16, color: color.withOpacity(0.8)),
              ],
            ),
            if (hasSettings) ...[
              const SizedBox(height: 4),
              Text(
                '${cardName != '-' ? cardName : ''}${cardName != '-' && statusName != '-' ? ' / ' : ''}${statusName != '-' ? statusName : ''}',
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isJAL && jalTourPremium) ...[
              const SizedBox(height: 2),
              Text(
                'ツアープレミアム適用中',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // モバイル用設定ダイアログ(JAL/ANA両方表示)
  Future<void> _showMobileSettingsDialog(String airline) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.purple),
              SizedBox(width: 8),
              Text('カード・ステータス設定', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final expanded = ValueNotifier<bool>(false);
                    return ValueListenableBuilder<bool>(
                      valueListenable: expanded,
                      builder: (context, isExpanded, _) => GestureDetector(
                        onTap: () => expanded.value = !expanded.value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isExpanded
                              ? const Text(
                                  '💡 初期値はプロフィール設定から引き継ぎます。カードやステータスを変更すると、マイル・FOP/PPが即時再計算されます。',
                                  style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.4),
                                )
                              : const Row(
                                  children: [
                                    Text('💡', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 6),
                                    Text('この設定について', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
                // === JAL設定 ===
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JAL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // JALカード
                      const Text(
                        'カード種別',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: selectedJALCard,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('選択', style: TextStyle(fontSize: 11)),
                          ),
                          items: jalCardTypes
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            _onJALCardChanged(v);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // JALステータス
                      const Text(
                        'ステータス',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: jalStatusTypes.contains(selectedJALStatus)
                              ? selectedJALStatus
                              : null,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('選択', style: TextStyle(fontSize: 11)),
                          ),
                          items: jalStatusTypes
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            _onJALStatusChanged(v);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ツアープレミアム（JGC海外カードの場合のみ無効）
                      Builder(
                        builder: (context) {
                          final isJGCOverseas =
                              selectedJALCard == 'JALグローバルクラブ会員(海外)';
                          return Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: jalTourPremium,
                                  onChanged: isJGCOverseas
                                      ? null
                                      : (v) {
                                          _onJALTourPremiumChanged(v);
                                          setDialogState(() {});
                                        },
                                  activeColor: Colors.red,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ツアープレミアム',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isJGCOverseas ? Colors.grey : Colors.red,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // === ANA設定 ===
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ANA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ANAカード
                      const Text(
                        'カード種別',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: selectedANACard,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('選択', style: TextStyle(fontSize: 11)),
                          ),
                          items: anaCardTypes
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            _onANACardChanged(v);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ANAステータス
                      const Text(
                        'ステータス',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: selectedANAStatus,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('選択', style: TextStyle(fontSize: 11)),
                          ),
                          items: anaStatusTypes
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            _onANAStatusChanged(v);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // カード未発行の案内
                GestureDetector(
                  onTap: _openHapitas,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text('💡', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'カード未発行の方はこちら',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropdown(
    String label,
    double width,
    String? value,
    List<String> items,
    Color labelColor,
    void Function(String?) onChanged,
  ) {
    // valueがitemsに含まれていない場合はnullを使用
    final validValue = (value != null && items.contains(value)) ? value : null;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 26,
            decoration: BoxDecoration(
              border: Border.all(color: labelColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: validValue,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Colors.grey[600],
              ),
              menuWidth: width + 100,
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '選択',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
              selectedItemBuilder: (c) => items
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 10)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );

  Widget _buildLegCard(
    BuildContext context,
    Map<String, dynamic> leg,
    int index,
    bool isMobile, {
    bool isLatest = false,
  }) {
    final legId = leg['id'] as int,
        airline = leg['airline'] as String,
        fop = leg['calculatedFOP'] as int?,
        miles = leg['calculatedMiles'] as int?,
        lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        isExpanded = expandedLegId == legId;
    final dep = leg['departureAirport'] as String,
        arr = leg['arrivalAirport'] as String,
        flightNum = flightNumberControllers[legId]?.text ?? '',
        depTime = departureTimeControllers[legId]?.text ?? '',
        arrTime = arrivalTimeControllers[legId]?.text ?? '';
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isLatest ? Colors.yellow[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? airlineColor : airlineColor.withOpacity(0.3),
            width: isExpanded ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () =>
                  setState(() => expandedLegId = isExpanded ? null : legId),
              borderRadius: BorderRadius.circular(isExpanded ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? airlineColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(15),
                    topRight: const Radius.circular(15),
                    bottomLeft: Radius.circular(isExpanded ? 0 : 15),
                    bottomRight: Radius.circular(isExpanded ? 0 : 15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: airlineColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        airline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (dep.isNotEmpty && arr.isNotEmpty) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$dep → $arr',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (flightNum.isNotEmpty)
                                Text(
                                  ' ($flightNum)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                          if (depTime.isNotEmpty || arrTime.isNotEmpty)
                            Text(
                              depTime.isNotEmpty && arrTime.isNotEmpty
                                  ? '$depTime - $arrTime'
                                  : depTime.isNotEmpty
                                  ? '$depTime発'
                                  : '$arrTime着',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ] else
                      Text(
                        'レグ ${index + 1}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    const Spacer(),
                    if (fop != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_formatNumber(fop)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: airlineColor,
                                ),
                              ),
                              Text(
                                airline == 'JAL' ? ' FOP' : ' PP',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: airlineColor,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_formatNumber(miles ?? 0)}マイル',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (airline == 'JAL' && lsp != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${lsp}LSP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: airlineColor,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              _buildMobileExpandedContent(
                leg,
                legId,
                index,
                fop,
                miles,
                lsp,
                airline,
              ),
          ],
        ),
      );
    }
    return _buildDesktopLegCard(context, leg, index);
  }

  Widget _buildMobileExpandedContent(
    Map<String, dynamic> leg,
    int legId,
    int index,
    int? fop,
    int? miles,
    int? lsp,
    String airline,
  ) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop != null && fop > 0)
        ? (fare / fop).toStringAsFixed(1)
        : '-';
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                child: _buildMobileDropdown(
                  '航空会社',
                  leg['airline'] as String,
                  airlines,
                  (v) {
                    if (v != null && v != leg['airline']) {
                      _clearFlightInfo(index, legId);
                      // デフォルト運賃種別を設定
                      final defaultFareType = v == 'JAL' 
                          ? '運賃4 (75%) スペシャルセイバー' 
                          : '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
                      setState(() {
                        legs[index]['airline'] = v;
                        legs[index]['fareType'] = defaultFareType;
                        legs[index]['seatClass'] = '普通席';
                      });
                    }
                  },
                  color: airlineColor,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: _buildMobileDatePicker(
                  '日付（任意）',
                  dateControllers[legId]!,
                  context,
                  index,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: _buildMobileTextField(
                  '便名（任意）',
                  flightNumberControllers[legId]!,
                  '',
                  onSubmit: (_) => _autoFillFromFlightNumber(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileAirportSelector(
                  '出発',
                  departureAirportControllers[legId]!,
                  departureAirportFocusNodes[legId]!,
                  airlineAirports[airline] ?? airports,
                  (v) {
                    if (v != null) {
                      _clearFlightInfo(index, legId);
                      departureAirportControllers[legId]?.text = v;
                      setState(() => legs[index]['departureAirport'] = v);
                      _fetchAvailableFlights(index);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
              Expanded(
                child: _buildMobileDestinationDropdown(leg, legId, index),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileFlightTimeDropdown(leg, legId, index),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileTextField(
                  '到着時刻',
                  arrivalTimeControllers[legId]!,
                  'HH:MM',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildMobileDropdown(
            '運賃種別（変更可）',
            leg['fareType'] as String,
            fareTypesByAirline[airline] ?? [],
            (v) {
              if (v != null) {
                setState(() {
                  legs[index]['fareType'] = v;
                  if (airline == 'ANA')
                    legs[index]['seatClass'] = _anaSeatClassForFare(v);
                });
                _calculateSingleLeg(index);
              }
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileDropdown(
                  '座席クラス（変更可）',
                  leg['seatClass'] as String,
                  seatClassesByAirline[airline] ?? [],
                  (v) {
                    if (v != null) {
                      setState(() => legs[index]['seatClass'] = v);
                      _calculateSingleLeg(index);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileTextField(
                  '運賃（任意）',
                  fareAmountControllers[legId]!,
                  '',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // クリアボタン（グレー背景）
                  ElevatedButton(
                    onPressed: () => _clearLeg(index, legId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('クリア', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  // 削除ボタン（ゴミ箱アイコン）
                  if (legs.length > 1)
                    IconButton(
                      onPressed: () => _removeLeg(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '削除',
                    ),
                ],
              ),
              Row(
                children: [
                  // 追加ボタン（緑背景）
                  ElevatedButton(
                    onPressed: _addLeg,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('+ 追加', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  // 修行ログに保存ボタン（紫背景）
                  ElevatedButton(
                    onPressed: _saveItinerary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('修行ログに保存', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged, {
    Color? color,
  }) {
    final currentValue = value.isEmpty || !items.contains(value) ? null : value;
    final isAirlineDropdown = label == '航空会社';

    Color getItemColor(String item) {
      if (isAirlineDropdown) {
        return item == 'JAL' ? Colors.red : Colors.blue;
      }
      return color ?? Colors.black;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: currentValue,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '選択',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            selectedItemBuilder: (c) => items
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 12,
                          color: getItemColor(e),
                          fontWeight: isAirlineDropdown || color != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(
                        fontSize: 12,
                        color: getItemColor(e),
                        fontWeight: isAirlineDropdown
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
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

  Widget _buildMobileAirportSelector(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    final airportList = items.where((e) => e != airportDivider).toList();
    final effectiveList = airportList.isNotEmpty
        ? airportList
        : [...majorAirports, ...regionalAirports];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        _buildMobileAirportAutocomplete(
          controller: controller,
          focusNode: focusNode,
          airportList: effectiveList,
          onSelected: (code) => onChanged(code),
        ),
      ],
    );
  }

  Widget _buildMobileDestinationDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final rawDestinations = (availableDestinations[legId] ?? [])
        .where((e) => e != airportDivider)
        .toList();
    final destinations = _getSortedAirportList(
      rawDestinations,
    ).where((e) => e != airportDivider).toList();
    final currentValue = leg['arrivalAirport'] as String,
        displayValue =
            currentValue.isEmpty || !destinations.contains(currentValue)
            ? null
            : currentValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '到着',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: displayValue,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
            menuMaxHeight: 250,
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '選択',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            selectedItemBuilder: (c) => destinations
                .map(
                  (code) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$code ${airportNames[code] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                )
                .toList(),
            items: destinations
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(
                      '$code ${airportNames[code] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                arrivalAirportControllers[legId]?.text = v;
                setState(() => legs[index]['arrivalAirport'] = v);
                _fetchAvailableFlights(index);
                _calculateSingleLeg(index);
              }
            },
          ),
        ),
      ],
    );
  }

 // ============================================================
// simulation_screen.dart の _buildMobileAirportAutocomplete メソッドを
// 以下の2つのメソッドに差し替え
// 差し替え範囲: 行 4718〜4848
// ============================================================

  Widget _buildMobileAirportAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> airportList,
    required void Function(String) onSelected,
  }) {
    final currentCode = controller.text.toUpperCase();
    final jaName = airportNames[currentCode];
    return GestureDetector(
      onTap: () => _showAirportBottomSheet(
        airportList: airportList,
        onSelected: (code) {
          controller.text = code;
          onSelected(code);
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentCode.isNotEmpty ? currentCode : '選択',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: currentCode.isNotEmpty ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (jaName != null)
                    Text(
                      jaName,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showAirportBottomSheet({
    required List<String> airportList,
    required void Function(String) onSelected,
  }) {
    final searchController = TextEditingController();
    final effectiveList = airportList.where((e) => e != airportDivider).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchController.text.toUpperCase();
            final filtered = query.isEmpty
                ? _getSortedAirportList(effectiveList).where((e) => e != airportDivider).toList()
                : effectiveList.where((code) {
                    final name = airportNames[code] ?? '';
                    return code.contains(query) || name.contains(query);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // ドラッグハンドル
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 検索バー
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: '空港コードまたは名前で検索',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    // 空港リスト
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final code = filtered[i];
                          if (code == airportDivider) {
                            return Container(
                              height: 1,
                              color: Colors.grey[300],
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 16,
                              ),
                            );
                          }
                          return ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
                            title: Row(
                              children: [
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  airportNames[code] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              onSelected(code);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
  Widget _buildMobileFlightTimeDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final flights = availableFlights[legId] ?? [],
        currentTime = departureTimeControllers[legId]?.text ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '出発時刻',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: null,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.grey[600],
            ),
            hint: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                currentTime.isEmpty ? '選択' : currentTime,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: currentTime.isEmpty ? Colors.grey[500] : Colors.black,
                ),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: '__clear__',
                child: Text('-', style: TextStyle(fontSize: 12)),
              ),
              ...flights.map((flight) {
                String depTime = flight['departure_time'] ?? '';
                if (depTime.length > 5) depTime = depTime.substring(0, 5);
                final arrCode = flight['arrival_code'] ?? '';
                return DropdownMenuItem(
                  value: '${flight['id']}',
                  child: Text(
                    '${airportNames[arrCode] ?? arrCode} $depTime',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == '__clear__') {
                _clearFlightInfo(index, legId);
                return;
              }
              final flight = flights.firstWhere(
                (f) => f['id'].toString() == value,
                orElse: () => {},
              );
              if (flight.isNotEmpty) {
                String depTime = flight['departure_time'] ?? '',
                    arrTime = flight['arrival_time'] ?? '';
                if (depTime.length > 5) depTime = depTime.substring(0, 5);
                if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
                departureTimeControllers[legId]?.text = depTime;
                arrivalTimeControllers[legId]?.text = arrTime;
                flightNumberControllers[legId]?.text =
                    flight['flight_number'] ?? '';
                setState(
                  () => legs[index]['arrivalAirport'] =
                      flight['arrival_code'] ?? '',
                );
                arrivalAirportControllers[legId]?.text =
                    flight['arrival_code'] ?? '';
                if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
                _calculateSingleLeg(index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTextField(
    String label,
    TextEditingController controller,
    String hint, {
    void Function(String)? onChanged,
    void Function(String)? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus && onSubmit != null && controller.text.isNotEmpty)
                onSubmit(controller.text);
            },
            child: TextFormField(
              controller: controller,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              onChanged: onChanged,
              onFieldSubmitted: onSubmit,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDatePicker(
    String label,
    TextEditingController controller,
    BuildContext context,
    int index,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '選択',
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              suffixIcon: Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _parseDate(controller.text) ?? now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('ja'),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    dialogTheme: const DialogThemeData(
                      insetPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                    ),
                  ),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(0.9)),
                    child: child!,
                  ),
                ),
              );
              if (picked != null) {
                controller.text =
                    '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
                setState(() {});
                _fetchAvailableFlights(index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLegCard(
    BuildContext context,
    Map<String, dynamic> leg,
    int index,
  ) {
    final legId = leg['id'] as int,
        airline = leg['airline'] as String,
        fop = leg['calculatedFOP'] as int?,
        miles = leg['calculatedMiles'] as int?,
        lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        warning = legWarnings[legId];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: airlineColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (warning != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      warning,
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                onPressed: _addLeg,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('レグ追加'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _clearLeg(index, legId),
                child: Text(
                  'クリア',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              if (legs.length > 1)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  onPressed: () => _removeLeg(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '削除',
                ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDesktopAirlineDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopDatePicker(
                  '日付',
                  130,
                  dateControllers[legId]!,
                  context,
                  index,
                ),
                const SizedBox(width: 8),
                _buildDesktopFlightNumberField(legId, index),
                const SizedBox(width: 8),
                _buildDesktopDepartureDropdown(leg, legId, index),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                _buildDesktopDestinationDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopFlightTimeDropdown(leg, legId, index),
                const SizedBox(width: 4),
                _buildDesktopArrivalTimeField(legId),
                const SizedBox(width: 8),
                _buildDesktopFareTypeDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopSeatClassDropdown(leg, legId, index),
                const SizedBox(width: 8),
                _buildDesktopTextField(
                  '運賃',
                  70,
                  fareAmountControllers[legId]!,
                  '15000',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(width: 8),
                if (fop != null)
                  _buildDesktopPointsDisplay(airline, fop, miles, lsp, legId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPointsDisplay(
    String airline,
    int fop,
    int? miles,
    int? lsp,
    int legId,
  ) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue,
        fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop > 0)
            ? (fare / fop).toStringAsFixed(1)
            : '-',
        pointLabel = airline == 'JAL' ? 'FOP' : 'PP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: airlineColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (airline == 'JAL')
            Text(
              '$pointLabel: $fop  マイル: $miles  LSP: ${lsp ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            )
          else
            Text(
              '$pointLabel: $fop  マイル: $miles',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          if (fare > 0)
            Text(
              '単価: ¥$unitPrice/$pointLabel',
              style: const TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopAirlineDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String;
    return SizedBox(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '航空会社',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: airline.isEmpty ? null : airline,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('選択', style: TextStyle(fontSize: 12)),
              ),
              selectedItemBuilder: (c) => airlines
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 12,
                            color: e == 'JAL' ? Colors.red : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: airlines
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 12,
                          color: e == 'JAL' ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null && v != airline) {
                  _clearFlightInfo(index, legId);
                  // デフォルト運賃種別を設定
                  final defaultFareType = v == 'JAL' 
                      ? '運賃4 (75%) スペシャルセイバー' 
                      : '運賃7 (75%) ANA SUPER VALUE/いっしょにマイル割';
                  setState(() {
                    legs[index]['airline'] = v;
                    legs[index]['fareType'] = defaultFareType;
                    legs[index]['seatClass'] = '普通席';
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDepartureDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String,
        airportList =
            (airlineAirports[airline] ??
                    [...majorAirports, ...regionalAirports])
                .where((e) => e != airportDivider)
                .toList();
    return SizedBox(
      width: 85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出発地',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _buildAirportAutocomplete(
            controller: departureAirportControllers[legId]!,
            focusNode: departureAirportFocusNodes[legId]!,
            airportList: airportList,
            onSelected: (code) {
              _clearFlightInfo(index, legId);
              departureAirportControllers[legId]?.text = code;
              setState(() => legs[index]['departureAirport'] = code);
              _fetchAvailableFlights(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDestinationDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final rawDestinations = (availableDestinations[legId] ?? [])
        .where((e) => e != airportDivider)
        .toList();
    final destinations = _getSortedAirportList(
      rawDestinations,
    ).where((e) => e != airportDivider).toList();
    final currentValue = leg['arrivalAirport'] as String,
        displayValue =
            currentValue.isEmpty || !destinations.contains(currentValue)
            ? null
            : currentValue;
    return SizedBox(
      width: 85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '到着地',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: displayValue,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Colors.grey[600],
              ),
              menuMaxHeight: 300,
              hint: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '選択',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              selectedItemBuilder: (c) => destinations
                  .map(
                    (code) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(code, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  )
                  .toList(),
              items: destinations
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(
                        '$code ${airportNames[code] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  arrivalAirportControllers[legId]?.text = v;
                  setState(() => legs[index]['arrivalAirport'] = v);
                  _fetchAvailableFlights(index);
                  _calculateSingleLeg(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirportAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required List<String> airportList,
    required void Function(String) onSelected,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        final input = textEditingValue.text.toUpperCase();
        if (input.isEmpty)
          return _getSortedAirportList(
            airportList,
          ).where((e) => e != airportDivider);
        return airportList.where((code) {
          final name = airportNames[code] ?? '';
          return code.contains(input) || name.contains(input);
        });
      },
      displayStringForOption: (code) => code,
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) => Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextFormField(
              controller: textController,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 12),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: '選択',
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
              onFieldSubmitted: (value) {
                final code = value.toUpperCase();
                if (airportNames.containsKey(code)) onSelected(code);
              },
            ),
          ),
      optionsViewBuilder: (context, onAutoSelected, options) {
        final sortedOptions = _getSortedAirportList(options.toList());
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 160),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: sortedOptions.length,
                itemBuilder: (context, i) {
                  final code = sortedOptions[i];
                  if (code == airportDivider)
                    return Container(
                      height: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                    );
                  return InkWell(
                    onTap: () => onAutoSelected(code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        '$code ${airportNames[code] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: onSelected,
    );
  }

  Widget _buildDesktopFlightTimeDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final flights = availableFlights[legId] ?? [],
        airline = leg['airline'] as String,
        currentTime = departureTimeControllers[legId]?.text ?? '';
    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出発時刻',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              key: ValueKey('flight_time_${legId}_$airline'),
              value: null,
              isExpanded: true,
              underline: const SizedBox(),
              menuWidth: 150,
              hint: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  currentTime.isEmpty ? '選択' : currentTime,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: '__clear__',
                  child: Text('-', style: TextStyle(fontSize: 12)),
                ),
                ...flights.map((flight) {
                  String depTime = flight['departure_time'] ?? '';
                  if (depTime.length > 5) depTime = depTime.substring(0, 5);
                  final arrCode = flight['arrival_code'] ?? '';
                  return DropdownMenuItem(
                    value: '${flight['id']}',
                    child: Text(
                      '${airportNames[arrCode] ?? arrCode} $depTime',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == '__clear__') {
                  _clearFlightInfo(index, legId);
                  return;
                }
                final flight = flights.firstWhere(
                  (f) => f['id'].toString() == value,
                  orElse: () => {},
                );
                if (flight.isNotEmpty) {
                  String depTime = flight['departure_time'] ?? '',
                      arrTime = flight['arrival_time'] ?? '';
                  if (depTime.length > 5) depTime = depTime.substring(0, 5);
                  if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
                  departureTimeControllers[legId]?.text = depTime;
                  arrivalTimeControllers[legId]?.text = arrTime;
                  flightNumberControllers[legId]?.text =
                      flight['flight_number'] ?? '';
                  setState(
                    () => legs[index]['arrivalAirport'] =
                        flight['arrival_code'] ?? '',
                  );
                  arrivalAirportControllers[legId]?.text =
                      flight['arrival_code'] ?? '';
                  if (index + 1 < legs.length)
                    _fetchAvailableFlights(index + 1);
                  _calculateSingleLeg(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopArrivalTimeField(int legId) => SizedBox(
    width: 65,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '到着時刻',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: arrivalTimeControllers[legId],
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'HH:MM',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopFareTypeDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String,
        fareType = leg['fareType'] as String,
        fareTypes = fareTypesByAirline[airline] ?? [];
    final currentValue = fareType.isEmpty || !fareTypes.contains(fareType)
        ? null
        : fareType;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '運賃種別',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              underline: const SizedBox(),
              menuWidth: 250,
              hint: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('選択', style: TextStyle(fontSize: 10)),
              ),
              selectedItemBuilder: (c) => fareTypes
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: fareTypes
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 10)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    legs[index]['fareType'] = v;
                    if (airline == 'ANA')
                      legs[index]['seatClass'] = _anaSeatClassForFare(v);
                  });
                  _calculateSingleLeg(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSeatClassDropdown(
    Map<String, dynamic> leg,
    int legId,
    int index,
  ) {
    final airline = leg['airline'] as String,
        seatClass = leg['seatClass'] as String,
        seatClasses = seatClassesByAirline[airline] ?? [];
    final currentValue = seatClass.isEmpty || !seatClasses.contains(seatClass)
        ? null
        : seatClass;
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '座席クラス',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              underline: const SizedBox(),
              menuWidth: 150,
              hint: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('選択', style: TextStyle(fontSize: 10)),
              ),
              selectedItemBuilder: (c) => seatClasses
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: seatClasses
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 10)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => legs[index]['seatClass'] = v);
                  _calculateSingleLeg(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTextField(
    String label,
    double width,
    TextEditingController controller,
    String hint, {
    void Function(String)? onChanged,
  }) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopFlightNumberField(int legId, int index) => SizedBox(
    width: 60,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '便名',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                final flightNumber = flightNumberControllers[legId]?.text ?? '';
                if (flightNumber.isNotEmpty) _autoFillFromFlightNumber(index);
              }
            },
            child: TextFormField(
              controller: flightNumberControllers[legId],
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
              onFieldSubmitted: (_) => _autoFillFromFlightNumber(index),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDesktopDatePicker(
    String label,
    double width,
    TextEditingController controller,
    BuildContext context,
    int index,
  ) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: '選択',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              suffixIcon: Icon(Icons.calendar_today, size: 14),
            ),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _parseDate(controller.text) ?? now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('ja'),
              );
              if (picked != null) {
                controller.text =
                    '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
                setState(() {});
                _fetchAvailableFlights(index);
              }
            },
          ),
        ),
      ],
    ),
  );
}
