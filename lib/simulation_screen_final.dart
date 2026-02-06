import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';
import 'l10n/app_localizations.dart';

// ========================================
// シミュレーション画面 設計ルール
// ========================================
// 【到着空港選択の重要ルール】
// - 到着空港は出発地から就航している空港のみ表示する
// - _fetchAvailableFlightsでSupabaseから取得したデータを使用
// - フォールバックで全空港を表示してはいけない（過去バグの原因）
// - 関連関数: _buildDesktopDestinationDropdown, _buildMobileDestinationSelector
//
// 【多言語化の重要ルール】
// - 空港名・カード種類・運賃種類は内部キーと表示名を分離
// - _getAirportName(), _getJalCardName()等のメソッドで言語切替
// - 計算ロジックには日本語キー（運賃1等）を使用（互換性維持）
// ========================================

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
  
  Map<int, List<Map<String, dynamic>>> availableFlights = {};
  Map<int, List<String>> availableDestinations = {};
  Map<int, String?> legWarnings = {};
  Map<String, List<String>> airlineAirports = {};
  
  int _legIdCounter = 0;
  bool isLoading = false;
  String? errorMessage;
  bool _isSettingsExpanded = false;

  String? selectedJALCard;
  String? selectedANACard;
  String? selectedJALStatus;
  String? selectedANAStatus;
  bool jalTourPremium = false;
  bool jalShoppingMilePremium = false;

  // カード種類（キー）
  final List<String> jalCardKeys = ['jmb', 'jal_regular', 'jal_club_a', 'jal_club_a_gold', 'jal_platinum', 'jgc_japan', 'jgc_overseas', 'jal_navi', 'jal_est_regular', 'jal_est_club_a', 'jal_est_gold', 'jal_est_platinum'];
  final List<String> anaCardKeys = ['-', 'amc', 'ana_regular', 'ana_student', 'ana_wide', 'ana_gold', 'ana_premium', 'sfc_regular', 'sfc_gold', 'sfc_premium'];
  final List<String> jalStatusKeys = ['-', 'diamond', 'sapphire', 'crystal'];
  final List<String> anaStatusKeys = ['-', 'diamond_1', 'diamond_2', 'platinum_1', 'platinum_2', 'bronze_1', 'bronze_2'];
  
  // カード種類表示名（日本語）
  final Map<String, String> jalCardNamesJa = {'jmb': 'JMB会員', 'jal_regular': 'JALカード普通会員', 'jal_club_a': 'JALカードCLUB-A会員', 'jal_club_a_gold': 'JALカードCLUB-Aゴールド会員', 'jal_platinum': 'JALカードプラチナ会員', 'jgc_japan': 'JALグローバルクラブ会員(日本)', 'jgc_overseas': 'JALグローバルクラブ会員(海外)', 'jal_navi': 'JALカードNAVI会員', 'jal_est_regular': 'JAL CLUB EST 普通会員', 'jal_est_club_a': 'JAL CLUB EST CLUB-A会員', 'jal_est_gold': 'JAL CLUB EST CLUB-A GOLD会員', 'jal_est_platinum': 'JAL CLUB EST プラチナ会員'};
  final Map<String, String> jalCardNamesEn = {'jmb': 'JMB Member', 'jal_regular': 'JAL Card Regular', 'jal_club_a': 'JAL Card CLUB-A', 'jal_club_a_gold': 'JAL Card CLUB-A Gold', 'jal_platinum': 'JAL Card Platinum', 'jgc_japan': 'JGC Member (Japan)', 'jgc_overseas': 'JGC Member (Overseas)', 'jal_navi': 'JAL Card NAVI', 'jal_est_regular': 'JAL CLUB EST Regular', 'jal_est_club_a': 'JAL CLUB EST CLUB-A', 'jal_est_gold': 'JAL CLUB EST CLUB-A Gold', 'jal_est_platinum': 'JAL CLUB EST Platinum'};
  final Map<String, String> anaCardNamesJa = {'-': '-', 'amc': 'AMCカード(提携カード含む)', 'ana_regular': 'ANAカード 一般', 'ana_student': 'ANAカード 学生用', 'ana_wide': 'ANAカード ワイド', 'ana_gold': 'ANAカード ゴールド', 'ana_premium': 'ANAカード プレミアム', 'sfc_regular': 'SFC 一般', 'sfc_gold': 'SFC ゴールド', 'sfc_premium': 'SFC プレミアム'};
  final Map<String, String> anaCardNamesEn = {'-': '-', 'amc': 'AMC Card (incl. Partner)', 'ana_regular': 'ANA Card Regular', 'ana_student': 'ANA Card Student', 'ana_wide': 'ANA Card Wide', 'ana_gold': 'ANA Card Gold', 'ana_premium': 'ANA Card Premium', 'sfc_regular': 'SFC Regular', 'sfc_gold': 'SFC Gold', 'sfc_premium': 'SFC Premium'};
  final Map<String, String> jalStatusNamesJa = {'-': '-', 'diamond': 'JMBダイヤモンド', 'sapphire': 'JMBサファイア', 'crystal': 'JMBクリスタル'};
  final Map<String, String> jalStatusNamesEn = {'-': '-', 'diamond': 'JMB Diamond', 'sapphire': 'JMB Sapphire', 'crystal': 'JMB Crystal'};
  final Map<String, String> anaStatusNamesJa = {'-': '-', 'diamond_1': 'ダイヤモンド(1年目)', 'diamond_2': 'ダイヤモンド(継続2年以上)', 'platinum_1': 'プラチナ(1年目)', 'platinum_2': 'プラチナ(継続2年以上)', 'bronze_1': 'ブロンズ(1年目)', 'bronze_2': 'ブロンズ(継続2年以上)'};
  final Map<String, String> anaStatusNamesEn = {'-': '-', 'diamond_1': 'Diamond (1st Year)', 'diamond_2': 'Diamond (2+ Years)', 'platinum_1': 'Platinum (1st Year)', 'platinum_2': 'Platinum (2+ Years)', 'bronze_1': 'Bronze (1st Year)', 'bronze_2': 'Bronze (2+ Years)'};

  // 空港名（日英）
  final Map<String, String> airportNamesJa = {'HND': '羽田', 'NRT': '成田', 'KIX': '関西', 'ITM': '伊丹', 'NGO': '中部', 'CTS': '新千歳', 'FUK': '福岡', 'OKA': '那覇', 'NGS': '長崎', 'KMJ': '熊本', 'OIT': '大分', 'MYJ': '松山', 'HIJ': '広島', 'TAK': '高松', 'KCZ': '高知', 'TKS': '徳島', 'KOJ': '鹿児島', 'SDJ': '仙台', 'AOJ': '青森', 'AKJ': '旭川', 'AXT': '秋田', 'GAJ': '山形', 'KIJ': '新潟', 'TOY': '富山', 'KMQ': '小松', 'FSZ': '静岡', 'MMB': '女満別', 'OBO': '帯広', 'KUH': '釧路', 'HKD': '函館', 'ISG': '石垣', 'MMY': '宮古', 'UBJ': '山口宇部', 'IWK': '岩国', 'OKJ': '岡山', 'TTJ': '鳥取', 'YGJ': '米子', 'IZO': '出雲', 'NKM': '県営名古屋', 'UKB': '神戸', 'HSG': '佐賀', 'KMI': '宮崎', 'ASJ': '奄美', 'TKN': '徳之島', 'OKI': '隠岐', 'FKS': '福島', 'HNA': '花巻', 'MSJ': '三沢', 'ONJ': '大館能代', 'SHM': '南紀白浜', 'NTQ': '能登', 'KKJ': '北九州', 'TNE': '種子島', 'KUM': '屋久島', 'RNJ': '与論', 'OGN': '与那国', 'HAC': '八丈島', 'MBE': '紋別', 'SHB': '中標津', 'WKJ': '稚内', 'OKD': '丘珠', 'IKI': '壱岐', 'TSJ': '対馬', 'FUJ': '五島福江', 'OIR': '奥尻', 'SYO': '庄内', 'MMJ': '松本', 'AXJ': '天草', 'TJH': '但馬', 'KKX': '喜界', 'UEO': '久米島', 'KTD': '北大東', 'MMD': '南大東', 'AGJ': '粟国', 'KJP': '慶良間', 'TRA': '多良間', 'HTR': '波照間', 'SHI': '下地島', 'IEJ': '伊江島'};
  final Map<String, String> airportNamesEn = {'HND': 'Haneda', 'NRT': 'Narita', 'KIX': 'Kansai', 'ITM': 'Itami', 'NGO': 'Chubu', 'CTS': 'New Chitose', 'FUK': 'Fukuoka', 'OKA': 'Naha', 'NGS': 'Nagasaki', 'KMJ': 'Kumamoto', 'OIT': 'Oita', 'MYJ': 'Matsuyama', 'HIJ': 'Hiroshima', 'TAK': 'Takamatsu', 'KCZ': 'Kochi', 'TKS': 'Tokushima', 'KOJ': 'Kagoshima', 'SDJ': 'Sendai', 'AOJ': 'Aomori', 'AKJ': 'Asahikawa', 'AXT': 'Akita', 'GAJ': 'Yamagata', 'KIJ': 'Niigata', 'TOY': 'Toyama', 'KMQ': 'Komatsu', 'FSZ': 'Shizuoka', 'MMB': 'Memanbetsu', 'OBO': 'Obihiro', 'KUH': 'Kushiro', 'HKD': 'Hakodate', 'ISG': 'Ishigaki', 'MMY': 'Miyako', 'UBJ': 'Yamaguchi Ube', 'IWK': 'Iwakuni', 'OKJ': 'Okayama', 'TTJ': 'Tottori', 'YGJ': 'Yonago', 'IZO': 'Izumo', 'NKM': 'Nagoya Komaki', 'UKB': 'Kobe', 'HSG': 'Saga', 'KMI': 'Miyazaki', 'ASJ': 'Amami', 'TKN': 'Tokunoshima', 'OKI': 'Oki', 'FKS': 'Fukushima', 'HNA': 'Hanamaki', 'MSJ': 'Misawa', 'ONJ': 'Odate Noshiro', 'SHM': 'Nanki Shirahama', 'NTQ': 'Noto', 'KKJ': 'Kitakyushu', 'TNE': 'Tanegashima', 'KUM': 'Yakushima', 'RNJ': 'Yoron', 'OGN': 'Yonaguni', 'HAC': 'Hachijojima', 'MBE': 'Monbetsu', 'SHB': 'Nakashibetsu', 'WKJ': 'Wakkanai', 'OKD': 'Okadama', 'IKI': 'Iki', 'TSJ': 'Tsushima', 'FUJ': 'Goto Fukue', 'OIR': 'Okushiri', 'SYO': 'Shonai', 'MMJ': 'Matsumoto', 'AXJ': 'Amakusa', 'TJH': 'Tajima', 'KKX': 'Kikai', 'UEO': 'Kumejima', 'KTD': 'Kitadaito', 'MMD': 'Minamidaito', 'AGJ': 'Aguni', 'KJP': 'Kerama', 'TRA': 'Tarama', 'HTR': 'Hateruma', 'SHI': 'Shimojishima', 'IEJ': 'Iejima'};
  
  // 運賃種類（キー）
  final Map<String, List<String>> fareTypeKeys = {
    'JAL': ['jal_fare1', 'jal_fare2', 'jal_fare3', 'jal_fare4', 'jal_fare5', 'jal_fare6'],
    'ANA': ['ana_fare1', 'ana_fare2', 'ana_fare3', 'ana_fare4', 'ana_fare5', 'ana_fare6', 'ana_fare7', 'ana_fare8', 'ana_fare9', 'ana_fare10', 'ana_fare11', 'ana_fare12', 'ana_fare13'],
  };
  final Map<String, String> fareTypeNamesJa = {'jal_fare1': '運賃1 (100%) フレックス等', 'jal_fare2': '運賃2 (75%) 株主割引', 'jal_fare3': '運賃3 (75%) セイバー', 'jal_fare4': '運賃4 (75%) スペシャルセイバー', 'jal_fare5': '運賃5 (50%) 包括旅行運賃', 'jal_fare6': '運賃6 (50%) スカイメイト等', 'ana_fare1': '運賃1 (150%) プレミアム運賃', 'ana_fare2': '運賃2 (125%) プレミアム小児', 'ana_fare3': '運賃3 (100%) 片道・往復', 'ana_fare4': '運賃4 (100%) ビジネス', 'ana_fare5': '運賃5 (75%) 特割A', 'ana_fare6': '運賃6 (75%) 特割B', 'ana_fare7': '運賃7 (75%) 特割C', 'ana_fare8': '運賃8 (50%) いっしょにマイル割', 'ana_fare9': '運賃9 (150%) プレミアム株主', 'ana_fare10': '運賃10 (100%) 普通株主', 'ana_fare11': '運賃11 (70%) 特割プラス', 'ana_fare12': '運賃12 (50%) スマートシニア', 'ana_fare13': '運賃13 (30%) 個人包括'};
  final Map<String, String> fareTypeNamesEn = {'jal_fare1': 'Fare1 (100%) Flex', 'jal_fare2': 'Fare2 (75%) Shareholder', 'jal_fare3': 'Fare3 (75%) Saver', 'jal_fare4': 'Fare4 (75%) Special Saver', 'jal_fare5': 'Fare5 (50%) Package Tour', 'jal_fare6': 'Fare6 (50%) Skymate', 'ana_fare1': 'Fare1 (150%) Premium', 'ana_fare2': 'Fare2 (125%) Premium Child', 'ana_fare3': 'Fare3 (100%) One-way/Round', 'ana_fare4': 'Fare4 (100%) Business', 'ana_fare5': 'Fare5 (75%) Value A', 'ana_fare6': 'Fare6 (75%) Value B', 'ana_fare7': 'Fare7 (75%) Value C', 'ana_fare8': 'Fare8 (50%) Together Miles', 'ana_fare9': 'Fare9 (150%) Premium SH', 'ana_fare10': 'Fare10 (100%) Regular SH', 'ana_fare11': 'Fare11 (70%) Value Plus', 'ana_fare12': 'Fare12 (50%) Smart Senior', 'ana_fare13': 'Fare13 (30%) Individual Pkg'};
  
  // 座席クラス（キー）
  final Map<String, List<String>> seatClassKeys = {'JAL': ['economy', 'class_j', 'first'], 'ANA': ['economy', 'premium']};
  final Map<String, String> seatClassNamesJa = {'economy': '普通席', 'class_j': 'クラスJ', 'first': 'ファーストクラス', 'premium': 'プレミアムクラス'};
  final Map<String, String> seatClassNamesEn = {'economy': 'Economy', 'class_j': 'Class J', 'first': 'First Class', 'premium': 'Premium Class'};

  // ANAプレミアム運賃キー（運賃1, 2, 9）
  static const List<String> anaPremiumFareKeys = ['ana_fare1', 'ana_fare2', 'ana_fare9'];
  
  // ANAの運賃選択時に座席を自動設定
  void _onAnaFareTypeChanged(int index, String fareKey) {
    final isPremiumFare = anaPremiumFareKeys.contains(fareKey);
    setState(() {
      legs[index]['fareType'] = fareKey;
      legs[index]['seatClass'] = isPremiumFare ? 'premium' : 'economy';
    });
    _calculateSingleLeg(index);
  }
  
  // ANAの座席選択時に運賃をフィルタリング（必要に応じてリセット）
  void _onAnaSeatClassChanged(int index, String seatKey) {
    final currentFare = legs[index]['fareType'] as String;
    final isPremiumSeat = seatKey == 'premium';
    final isPremiumFare = anaPremiumFareKeys.contains(currentFare);
    
    setState(() {
      legs[index]['seatClass'] = seatKey;
      // 座席と運賃の整合性チェック
      if (isPremiumSeat && !isPremiumFare && currentFare.isNotEmpty) {
        legs[index]['fareType'] = ''; // リセット
      } else if (!isPremiumSeat && isPremiumFare && currentFare.isNotEmpty) {
        legs[index]['fareType'] = ''; // リセット
      }
    });
    _calculateSingleLeg(index);
  }
  
  // ANAの座席に応じた選択可能な運賃リストを取得
  List<String> _getAnaAvailableFareTypes(String seatClass) {
    final allKeys = fareTypeKeys['ANA']!;
    if (seatClass.isEmpty) return allKeys; // 座席未選択時は全て表示
    if (seatClass == 'premium') {
      return allKeys.where((k) => anaPremiumFareKeys.contains(k)).toList();
    } else if (seatClass == 'economy') {
      return allKeys.where((k) => !anaPremiumFareKeys.contains(k)).toList();
    }
    return allKeys;
  }
  
  // ANAの運賃に応じた選択可能な座席クラスリストを取得
  List<String> _getAnaAvailableSeatClasses(String fareType) {
    final allKeys = seatClassKeys['ANA']!;
    if (fareType.isEmpty) return allKeys; // 運賃未選択時は全て表示
    if (anaPremiumFareKeys.contains(fareType)) {
      return ['premium'];
    } else {
      return ['economy'];
    }
  }

  // 言語に応じた表示名取得メソッド
  String _getAirportName(String code) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (airportNamesJa[code] ?? code) : (airportNamesEn[code] ?? code);
  }
  String _getJalCardName(String key) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (jalCardNamesJa[key] ?? key) : (jalCardNamesEn[key] ?? key);
  }
  String _getAnaCardName(String key) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (anaCardNamesJa[key] ?? key) : (anaCardNamesEn[key] ?? key);
  }
  String _getJalStatusName(String key) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (jalStatusNamesJa[key] ?? key) : (jalStatusNamesEn[key] ?? key);
  }
  String _getAnaStatusName(String key) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (anaStatusNamesJa[key] ?? key) : (anaStatusNamesEn[key] ?? key);
  }
  String _getFareTypeName(String key) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (fareTypeNamesJa[key] ?? key) : (fareTypeNamesEn[key] ?? key);
  }
  String _getSeatClassName(String key) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? (seatClassNamesJa[key] ?? key) : (seatClassNamesEn[key] ?? key);
  }

  // 旧リスト（互換性のため残す）
  List<String> get jalCardTypes => jalCardKeys.map((k) => _getJalCardName(k)).toList();
  List<String> get anaCardTypes => anaCardKeys.map((k) => _getAnaCardName(k)).toList();
  List<String> get jalStatusTypes => jalStatusKeys.map((k) => _getJalStatusName(k)).toList();
  List<String> get anaStatusTypes => anaStatusKeys.map((k) => _getAnaStatusName(k)).toList();
  
  final List<String> majorAirports = ['HND', 'NRT', 'ITM', 'KIX', 'NGO', 'CTS', 'FUK', 'OKA'];
  static const String airportDivider = '---';
  final List<String> regionalAirports = ['WKJ', 'MBE', 'MMB', 'SHB', 'AKJ', 'OKD', 'OBO', 'KUH', 'HKD', 'OIR', 'AOJ', 'MSJ', 'HNA', 'AXT', 'ONJ', 'SYO', 'GAJ', 'SDJ', 'FKS', 'HAC', 'NKM', 'FSZ', 'MMJ', 'NTQ', 'TOY', 'KMQ', 'SHM', 'UKB', 'TJH', 'TTJ', 'YGJ', 'OKI', 'IZO', 'OKJ', 'HIJ', 'IWK', 'UBJ', 'TKS', 'TAK', 'KCZ', 'MYJ', 'KKJ', 'HSG', 'NGS', 'KMJ', 'OIT', 'KMI', 'KOJ', 'AXJ', 'IKI', 'TSJ', 'FUJ', 'TNE', 'KUM', 'ASJ', 'KKX', 'TKN', 'RNJ', 'OGN', 'MMY', 'ISG', 'UEO', 'KTD', 'MMD', 'TRA', 'AGJ', 'KJP', 'HTR', 'SHI', 'IEJ'];
  List<String> get airports => [...majorAirports, airportDivider, ...regionalAirports];
  
  // 旧マップ（互換性のため残す - 言語対応版に置き換え）
  Map<String, String> get airportNames {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? airportNamesJa : airportNamesEn;
  }
  final List<String> airlines = ['JAL', 'ANA'];
  Map<String, List<String>> get fareTypesByAirline {
    final keys = fareTypeKeys;
    return {
      'JAL': keys['JAL']!.map((k) => _getFareTypeName(k)).toList(),
      'ANA': keys['ANA']!.map((k) => _getFareTypeName(k)).toList(),
    };
  }
  Map<String, List<String>> get seatClassesByAirline {
    return {
      'JAL': seatClassKeys['JAL']!.map((k) => _getSeatClassName(k)).toList(),
      'ANA': seatClassKeys['ANA']!.map((k) => _getSeatClassName(k)).toList(),
    };
  }
  final Map<String, int> jalBonusFOP = {'運賃1': 400, '運賃2': 400, '運賃3': 200, '運賃4': 200, '運賃5': 0, '運賃6': 0, 'jal_fare1': 400, 'jal_fare2': 400, 'jal_fare3': 200, 'jal_fare4': 200, 'jal_fare5': 0, 'jal_fare6': 0, 'Fare1': 400, 'Fare2': 400, 'Fare3': 200, 'Fare4': 200, 'Fare5': 0, 'Fare6': 0};
  final Map<String, int> anaBonusPoint = {'運賃1': 400, '運賃2': 400, '運賃3': 400, '運賃4': 0, '運賃5': 400, '運賃6': 200, '運賃7': 0, '運賃8': 0, '運賃9': 0, '運賃10': 0, '運賃11': 0, '運賃12': 0, '運賃13': 0, 'ana_fare1': 400, 'ana_fare2': 400, 'ana_fare3': 400, 'ana_fare4': 0, 'ana_fare5': 400, 'ana_fare6': 200, 'ana_fare7': 0, 'ana_fare8': 0, 'ana_fare9': 0, 'ana_fare10': 0, 'ana_fare11': 0, 'ana_fare12': 0, 'ana_fare13': 0, 'Fare1': 400, 'Fare2': 400, 'Fare3': 400, 'Fare4': 0, 'Fare5': 400, 'Fare6': 200, 'Fare7': 0, 'Fare8': 0, 'Fare9': 0, 'Fare10': 0, 'Fare11': 0, 'Fare12': 0, 'Fare13': 0};

  static const String _hapitasUrl = 'https://px.a8.net/svt/ejp?a8mat=45KL8I+5JG97E+1LP8+CALN5';
  Future<void> _openHapitas() async { final uri = Uri.parse(_hapitasUrl); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }

  @override
  void initState() { super.initState(); _initAirlineAirports(); _addLeg(); }

  Future<void> _initAirlineAirports() async { await _fetchAirlineAirports('JAL'); await _fetchAirlineAirports('ANA'); }

  Future<List<String>> _fetchAirlineAirports(String airline) async {
    if (airlineAirports.containsKey(airline)) return airlineAirports[airline]!;
    try {
      final response = await Supabase.instance.client.from('schedules').select('departure_code').eq('airline_code', airline).eq('is_active', true);
      final codes = (response as List).map((r) => r['departure_code'] as String).toSet().toList()..sort();
      setState(() => airlineAirports[airline] = codes);
      return codes;
    } catch (e) { return airports; }
  }

  @override
  void dispose() {
    for (var c in dateControllers.values) c.dispose();
    for (var c in flightNumberControllers.values) c.dispose();
    for (var c in departureTimeControllers.values) c.dispose();
    for (var c in arrivalTimeControllers.values) c.dispose();
    for (var c in fareAmountControllers.values) c.dispose();
    for (var c in departureAirportControllers.values) c.dispose();
    for (var c in arrivalAirportControllers.values) c.dispose();
    for (var f in departureAirportFocusNodes.values) f.dispose();
    for (var f in arrivalAirportFocusNodes.values) f.dispose();
    super.dispose();
  }

  void _addLeg() {
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
    String airline = 'JAL', departureAirport = '', arrivalAirport = '', date = '';
    if (legs.isNotEmpty) {
      final prevLeg = legs.last; final prevLegId = prevLeg['id'] as int;
      airline = prevLeg['airline'] as String;
      departureAirport = prevLeg['arrivalAirport'] as String;
      arrivalAirport = prevLeg['departureAirport'] as String;
      date = dateControllers[prevLegId]?.text ?? '';
    }
    dateControllers[legId]?.text = date;
    departureAirportControllers[legId]?.text = departureAirport;
    arrivalAirportControllers[legId]?.text = arrivalAirport;
    setState(() { legs.add({'id': legId, 'airline': airline, 'departureAirport': departureAirport, 'arrivalAirport': arrivalAirport, 'fareType': '', 'seatClass': '', 'calculatedFOP': null, 'calculatedMiles': null, 'calculatedLSP': null}); expandedLegId = legId; });
    if (departureAirport.isNotEmpty) _fetchAvailableFlights(legs.length - 1);
  }

  void _removeLeg(int index) {
    final legId = legs[index]['id'] as int;
    dateControllers[legId]?.dispose(); flightNumberControllers[legId]?.dispose(); departureTimeControllers[legId]?.dispose(); arrivalTimeControllers[legId]?.dispose(); fareAmountControllers[legId]?.dispose();
    departureAirportControllers[legId]?.dispose(); arrivalAirportControllers[legId]?.dispose(); departureAirportFocusNodes[legId]?.dispose(); arrivalAirportFocusNodes[legId]?.dispose();
    dateControllers.remove(legId); flightNumberControllers.remove(legId); departureTimeControllers.remove(legId); arrivalTimeControllers.remove(legId); fareAmountControllers.remove(legId);
    departureAirportControllers.remove(legId); arrivalAirportControllers.remove(legId); departureAirportFocusNodes.remove(legId); arrivalAirportFocusNodes.remove(legId);
    availableFlights.remove(legId); availableDestinations.remove(legId);
    setState(() { legs.removeAt(index); if (expandedLegId == legId) expandedLegId = legs.isNotEmpty ? legs.last['id'] as int : null; });
  }

  void _clearFlightInfo(int index, int legId) {
    setState(() { legs[index]['departureAirport'] = ''; legs[index]['arrivalAirport'] = ''; legs[index]['calculatedFOP'] = null; legs[index]['calculatedMiles'] = null; legs[index]['calculatedLSP'] = null; availableFlights[legId] = []; availableDestinations[legId] = []; legWarnings[legId] = null; });
    flightNumberControllers[legId]?.text = ''; departureTimeControllers[legId]?.text = ''; arrivalTimeControllers[legId]?.text = '';
    departureAirportControllers[legId]?.text = ''; arrivalAirportControllers[legId]?.text = '';
  }

  void _clearLeg(int index, int legId) { _clearFlightInfo(index, legId); setState(() { legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); dateControllers[legId]?.text = ''; fareAmountControllers[legId]?.text = ''; }

  String _addMinutes(String time, int minutes) {
    if (time.isEmpty || !time.contains(':')) return time;
    final parts = time.split(':'); int hour = int.tryParse(parts[0]) ?? 0, min = int.tryParse(parts[1]) ?? 0;
    min += minutes; while (min >= 60) { min -= 60; hour += 1; } if (hour >= 24) hour -= 24;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  bool _isTimeAfterOrEqual(String time1, String time2) {
    if (time1.isEmpty || time2.isEmpty || !time1.contains(':') || !time2.contains(':')) return true;
    final parts1 = time1.split(':'), parts2 = time2.split(':');
    return (int.tryParse(parts1[0]) ?? 0) * 60 + (int.tryParse(parts1[1]) ?? 0) >= (int.tryParse(parts2[0]) ?? 0) * 60 + (int.tryParse(parts2[1]) ?? 0);
  }

  // ======== 時刻表選択ルール ========
  // 1. 入力日を含む運航期間がある → その期間を使用
  // 2. ない場合 → 入力日以降で最初に始まる期間を探す
  // 3. それもない場合 → 入力日以前で最後に終わる期間を使用
  List<Map<String, dynamic>> _filterFlightsByDateRule(List<Map<String, dynamic>> flights, String targetDate) {
    final flightsByRoute = <String, List<Map<String, dynamic>>>{};
    for (var flight in flights) {
      final key = '${flight['flight_number']}_${flight['arrival_code']}';
      flightsByRoute.putIfAbsent(key, () => []);
      flightsByRoute[key]!.add(flight);
    }
    final result = <Map<String, dynamic>>[];
    for (var entry in flightsByRoute.entries) {
      final routeFlights = entry.value;
      // 1. 入力日を含む期間
      var selected = routeFlights.where((f) => (f['period_start'] as String).compareTo(targetDate) <= 0 && (f['period_end'] as String).compareTo(targetDate) >= 0).toList();
      if (selected.isNotEmpty) { result.add(selected.first); continue; }
      // 2. 入力日以降で最初の期間
      selected = routeFlights.where((f) => (f['period_start'] as String).compareTo(targetDate) > 0).toList();
      if (selected.isNotEmpty) { selected.sort((a, b) => (a['period_start'] as String).compareTo(b['period_start'] as String)); result.add(selected.first); continue; }
      // 3. 入力日以前で最後の期間
      selected = routeFlights.where((f) => (f['period_end'] as String).compareTo(targetDate) < 0).toList();
      if (selected.isNotEmpty) { selected.sort((a, b) => (b['period_end'] as String).compareTo(a['period_end'] as String)); result.add(selected.first); }
    }
    return result;
  }

  Map<String, dynamic>? _selectScheduleByDateRule(List<Map<String, dynamic>> schedules, String targetDate) {
    if (schedules.isEmpty) return null;
    // 1. 入力日を含む期間
    var selected = schedules.where((s) => (s['period_start'] as String).compareTo(targetDate) <= 0 && (s['period_end'] as String).compareTo(targetDate) >= 0).toList();
    if (selected.isNotEmpty) return selected.first;
    // 2. 入力日以降で最初の期間
    selected = schedules.where((s) => (s['period_start'] as String).compareTo(targetDate) > 0).toList();
    if (selected.isNotEmpty) { selected.sort((a, b) => (a['period_start'] as String).compareTo(b['period_start'] as String)); return selected.first; }
    // 3. 入力日以前で最後の期間
    selected = schedules.where((s) => (s['period_end'] as String).compareTo(targetDate) < 0).toList();
    if (selected.isNotEmpty) { selected.sort((a, b) => (b['period_end'] as String).compareTo(a['period_end'] as String)); return selected.first; }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchScheduleByFlightNumber(String airline, String flightNumber, String date) async {
    try {
      final targetDate = date.isEmpty ? DateTime.now().toIso8601String().substring(0, 10) : date.replaceAll('/', '-');
      final response = await Supabase.instance.client.from('schedules').select().eq('airline_code', airline).eq('flight_number', flightNumber).eq('is_active', true);
      return _selectScheduleByDateRule((response as List).cast<Map<String, dynamic>>(), targetDate);
    } catch (e) { return null; }
  }

  Future<void> _autoFillFromFlightNumber(int index) async {
    final legId = legs[index]['id'] as int, airline = legs[index]['airline'] as String;
    final flightNumber = flightNumberControllers[legId]?.text ?? '', date = dateControllers[legId]?.text ?? '';
    if (flightNumber.isEmpty) { setState(() => errorMessage = '便名を入力してください'); return; }
    final schedule = await _fetchScheduleByFlightNumber(airline, flightNumber, date);
    if (schedule != null) {
      String depTime = schedule['departure_time'] ?? '', arrTime = schedule['arrival_time'] ?? '';
      if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5);
      final depCode = schedule['departure_code'] as String, arrCode = schedule['arrival_code'] as String;
      setState(() { legs[index]['departureAirport'] = depCode; legs[index]['arrivalAirport'] = arrCode; errorMessage = null; });
      departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime;
      departureAirportControllers[legId]?.text = depCode; arrivalAirportControllers[legId]?.text = arrCode;
      if ((schedule['remarks'] as String? ?? '').isNotEmpty) setState(() => legWarnings[legId] = '⚠️ 一部期間で時刻変更あり');
      await _fetchAvailableFlights(index);
      if (index + 1 < legs.length) _fetchAvailableFlights(index + 1);
      _calculateSingleLeg(index);
    } else { setState(() => errorMessage = '$flightNumber便が見つかりません'); }
  }

  Future<void> _fetchAvailableFlights(int index) async {
    final leg = legs[index]; final legId = leg['id'] as int, airline = leg['airline'] as String;
    final departure = leg['departureAirport'] as String, arrival = leg['arrivalAirport'] as String;
    final dateText = dateControllers[legId]?.text ?? '';
    if (departure.isEmpty) { setState(() { availableFlights[legId] = []; availableDestinations[legId] = []; }); return; }
    final targetDate = dateText.isEmpty ? DateTime.now().toIso8601String().substring(0, 10) : dateText.replaceAll('/', '-');
    try {
      final allFlightsResponse = await Supabase.instance.client.from('schedules').select().eq('airline_code', airline).eq('departure_code', departure).eq('is_active', true).order('departure_time');
      var allFlights = _filterFlightsByDateRule((allFlightsResponse as List).cast<Map<String, dynamic>>(), targetDate);
      final seenAll = <String>{};
      allFlights = allFlights.where((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); final key = '${depTime}_${flight['arrival_code']}'; if (seenAll.contains(key)) return false; seenAll.add(key); return true; }).toList();
      final destinations = allFlights.map((f) => f['arrival_code'] as String).toSet().toList()..sort();
      var filteredFlights = arrival.isNotEmpty ? allFlights.where((f) => f['arrival_code'] == arrival).toList() : allFlights;
      if (index > 0) {
        final prevLeg = legs[index - 1]; final prevLegId = prevLeg['id'] as int;
        final prevArrival = prevLeg['arrivalAirport'] as String, prevArrivalTime = arrivalTimeControllers[prevLegId]?.text ?? '';
        if (prevArrival == departure && prevArrivalTime.isNotEmpty) {
          final minDepartureTime = _addMinutes(prevArrivalTime, 30);
          filteredFlights = filteredFlights.where((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); return _isTimeAfterOrEqual(depTime, minDepartureTime); }).toList();
        }
      }
      setState(() { availableFlights[legId] = filteredFlights; availableDestinations[legId] = destinations; });
    } catch (e) { setState(() { availableFlights[legId] = []; availableDestinations[legId] = []; }); }
  }

  Future<void> _calculateSingleLeg(int index) async {
    final leg = legs[index]; final dep = leg['departureAirport'] as String, arr = leg['arrivalAirport'] as String;
    final fare = leg['fareType'] as String, seat = leg['seatClass'] as String, airline = leg['airline'] as String;
    if (dep.isEmpty || arr.isEmpty || fare.isEmpty || seat.isEmpty) return;
    try {
      final routeData = await Supabase.instance.client.from('routes').select('distance_miles').eq('departure_code', dep).eq('arrival_code', arr).maybeSingle();
      if (routeData == null) return;
      final distance = routeData['distance_miles'] as int;
      double fareRate = 1.0;
      // 積算率をキーまたは表示名から取得
      final fareRateMap = {
        'jal_fare1': 1.0, 'jal_fare2': 0.75, 'jal_fare3': 0.75, 'jal_fare4': 0.75, 'jal_fare5': 0.50, 'jal_fare6': 0.50,
        'ana_fare1': 1.5, 'ana_fare2': 1.25, 'ana_fare3': 1.0, 'ana_fare4': 1.0, 'ana_fare5': 0.75, 'ana_fare6': 0.75, 'ana_fare7': 0.75, 'ana_fare8': 0.50, 'ana_fare9': 1.5, 'ana_fare10': 1.0, 'ana_fare11': 0.70, 'ana_fare12': 0.50, 'ana_fare13': 0.30,
      };
      if (fareRateMap.containsKey(fare)) {
        fareRate = fareRateMap[fare]!;
      } else {
        final rateMatch = RegExp(r'\((\d+)%\)').firstMatch(fare);
        if (rateMatch != null) fareRate = int.parse(rateMatch.group(1)!) / 100.0;
      }
      final fareNumber = fare.split(' ').first;
      int totalPoints = 0, totalMiles = 0, totalLSP = 0;
      if (airline == 'JAL') {
        final seatBonusRate = {'普通席': 0.0, 'クラスJ': 0.1, 'ファーストクラス': 0.5}[seat] ?? 0.0;
        // JALカードボーナス率（EST系は+5%）
        final cardBonusRate = {'-': 0.0, 'JMB会員': 0.0, 'JALカード普通会員': 0.10, 'JALカードCLUB-A会員': 0.25, 'JALカードCLUB-Aゴールド会員': 0.25, 'JALカードプラチナ会員': 0.25, 'JALグローバルクラブ会員(日本)': 0.35, 'JALグローバルクラブ会員(海外)': 0.0, 'JALカードNAVI会員': 0.10, 'JAL CLUB EST 普通会員': 0.15, 'JAL CLUB EST CLUB-A会員': 0.30, 'JAL CLUB EST CLUB-A GOLD会員': 0.30, 'JAL CLUB EST プラチナ会員': 0.30}[selectedJALCard ?? '-'] ?? 0.0;
        final statusBonusRate = {'-': 0.0, 'JMBダイヤモンド': 1.30, 'JMBサファイア': 1.05, 'JMBクリスタル': 0.55}[selectedJALStatus ?? '-'] ?? 0.0;
        final appliedBonusRate = cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate;
        
        // フライトマイル（元の積算率ベース、FOP計算にも使用）
        final flightMiles = (distance * (fareRate + seatBonusRate)).round();
        
        // ツアープレミアム判定（運賃4,5が対象）
        final isTourPremiumTarget = jalTourPremium && (fareNumber == '運賃4' || fareNumber == '運賃5' || fare == 'jal_fare4' || fare == 'jal_fare5');
        
        if (isTourPremiumTarget) {
          // ツアプレ適用時: フライトマイル + ツアプレボーナス + カードボーナス
          final tourPremiumBonus = (distance * (1.0 - fareRate)).round();
          final cardBonus = (flightMiles * appliedBonusRate + 0.5).toInt();
          totalMiles = flightMiles + tourPremiumBonus + cardBonus;
        } else {
          // 通常計算
          totalMiles = flightMiles + (flightMiles * appliedBonusRate + 0.5).toInt();
        }
        // FOP計算: ツアプレ影響なし、常に元の積算率ベース
        totalPoints = (flightMiles * 2) + (jalBonusFOP[fareNumber] ?? 0);
        totalLSP = (fareRate >= 0.5) ? 5 : 0;
      } else {
        // +5%対象カード判定（ゴールド/プレミアム系）
        final isGoldPremium = {'ANAカード ゴールド', 'ANAカード プレミアム', 'SFC ゴールド', 'SFC プレミアム'}.contains(selectedANACard);
        final cardBonusRate = {'-': 0.0, 'AMCカード(提携カード含む)': 0.0, 'ANAカード 一般': 0.10, 'ANAカード 学生用': 0.10, 'ANAカード ワイド': 0.25, 'ANAカード ゴールド': 0.25, 'ANAカード プレミアム': 0.50, 'SFC 一般': 0.35, 'SFC ゴールド': 0.40, 'SFC プレミアム': 0.50}[selectedANACard ?? '-'] ?? 0.0;
        final statusBonusRate = {'-': 0.0, 'ダイヤモンド(1年目)': 1.15, 'ダイヤモンド(継続2年以上)': 1.25, 'プラチナ(1年目)': 0.90, 'プラチナ(継続2年以上)': 1.00, 'ブロンズ(1年目)': 0.40, 'ブロンズ(継続2年以上)': 0.50}[selectedANAStatus ?? '-'] ?? 0.0;
        // 適用ボーナス率：ゴールド/プレミアム系+ステータス保有時は+5%
        final hasStatus = statusBonusRate > 0.0;
        final appliedBonusRate = (isGoldPremium && hasStatus) ? statusBonusRate + 0.05 : (cardBonusRate > statusBonusRate ? cardBonusRate : statusBonusRate);
        // 段階的計算（公式計算方法に準拠）
        final flightMiles = (distance * fareRate).toInt();
        final bonusMiles = (flightMiles * appliedBonusRate).round();
        totalMiles = flightMiles + bonusMiles;
        totalPoints = (flightMiles * 2 + (anaBonusPoint[fareNumber] ?? anaBonusPoint[fare] ?? 0)).toInt();
      }
      setState(() { legs[index]['calculatedFOP'] = totalPoints; legs[index]['calculatedMiles'] = totalMiles; legs[index]['calculatedLSP'] = totalLSP; });
    } catch (e) {}
  }

  void _recalculateAllLegs() { for (int i = 0; i < legs.length; i++) _calculateSingleLeg(i); }
  void _onJALCardChanged(String? v) { setState(() => selectedJALCard = v); _recalculateAllLegs(); }
  void _onJALStatusChanged(String? v) { setState(() => selectedJALStatus = v); _recalculateAllLegs(); }
  void _onANACardChanged(String? v) { setState(() => selectedANACard = v); _recalculateAllLegs(); }
  void _onANAStatusChanged(String? v) { setState(() => selectedANAStatus = v); _recalculateAllLegs(); }
  void _onJALTourPremiumChanged(bool? v) { setState(() => jalTourPremium = v ?? false); _recalculateAllLegs(); }
  void _onJALShoppingMilePremiumChanged(bool? v) { setState(() => jalShoppingMilePremium = v ?? false); }

  Future<void> _saveItinerary() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ログインが必要です'),
            content: const Text('旅程を保存するにはログインしてください。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen(onAuthSuccess: () { Navigator.pop(context); setState(() {}); }))); }, child: const Text('ログイン')),
            ],
          ),
        );
      }
      return;
    }
    final userId = user.id;
    final validLegs = legs.where((leg) => leg['calculatedFOP'] != null).toList();
    if (validLegs.isEmpty) { setState(() => errorMessage = '保存するレグがありません'); return; }
    setState(() => isLoading = true);
    try {
      final airports = <String>[];
      for (var leg in validLegs) { final dep = leg['departureAirport'] as String, arr = leg['arrivalAirport'] as String; if (airports.isEmpty || airports.last != dep) airports.add(dep); airports.add(arr); }
      final title = '${airports.join("-")} ${validLegs.length}レグ';
      final legsJson = validLegs.map((leg) { final legId = leg['id'] as int; return {'airline': leg['airline'], 'date': dateControllers[legId]?.text ?? '', 'flight_number': flightNumberControllers[legId]?.text ?? '', 'departure_airport': leg['departureAirport'], 'arrival_airport': leg['arrivalAirport'], 'departure_time': departureTimeControllers[legId]?.text ?? '', 'arrival_time': arrivalTimeControllers[legId]?.text ?? '', 'fare_type': leg['fareType'], 'seat_class': leg['seatClass'], 'fare_amount': int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0, 'fop': leg['calculatedFOP'], 'miles': leg['calculatedMiles'], 'lsp': leg['calculatedLSP']}; }).toList();
      await Supabase.instance.client.from('saved_itineraries').insert({'user_id': userId, 'title': title, 'legs': legsJson, 'total_fop': jalFOP, 'total_pp': anaPP, 'total_miles': jalMiles + anaMiles, 'total_lsp': jalTotalLSP, 'total_fare': jalFare + anaFare, 'jal_card': selectedJALCard, 'ana_card': selectedANACard, 'jal_status': selectedJALStatus, 'ana_status': selectedANAStatus, 'jal_tour_premium': jalTourPremium, 'jal_shopping_mile_premium': jalShoppingMilePremium});
      setState(() { isLoading = false; errorMessage = null; });
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addedToLog(title)), backgroundColor: Colors.green));
      }
    } catch (e) { setState(() { isLoading = false; errorMessage = '保存に失敗しました: $e'; }); }
  }

  void _downloadCsv() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ログインが必要です'),
            content: const Text('CSVをダウンロードするにはログインしてください。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen(onAuthSuccess: () { Navigator.pop(context); setState(() {}); }))); }, child: const Text('ログイン')),
            ],
          ),
        );
      }
      return;
    }
    final validLegs = legs.where((leg) => leg['calculatedFOP'] != null).toList();
    if (validLegs.isEmpty) { setState(() => errorMessage = 'ダウンロードするレグがありません'); return; }
    
    final csvRows = <String>[];
    csvRows.add('日付,航空会社,便名,出発地,到着地,出発時刻,到着時刻,運賃種別,座席クラス,運賃,FOP/PP,マイル,LSP');
    for (var leg in validLegs) {
      final legId = leg['id'] as int;
      final airline = leg['airline'] as String;
      csvRows.add([
        dateControllers[legId]?.text ?? '',
        airline,
        flightNumberControllers[legId]?.text ?? '',
        leg['departureAirport'],
        leg['arrivalAirport'],
        departureTimeControllers[legId]?.text ?? '',
        arrivalTimeControllers[legId]?.text ?? '',
        '"${leg['fareType']}"',
        leg['seatClass'],
        fareAmountControllers[legId]?.text ?? '0',
        '${leg['calculatedFOP'] ?? 0}',
        '${leg['calculatedMiles'] ?? 0}',
        airline == 'JAL' ? '${leg['calculatedLSP'] ?? 0}' : '-',
      ].join(','));
    }
    csvRows.add('');
    csvRows.add('合計,,,,,,,,,${ jalFare + anaFare },FOP:$jalFOP / PP:$anaPP,${jalMiles + anaMiles},$jalTotalLSP');
    
    final csvContent = csvRows.join('\n');
    final bom = [0xEF, 0xBB, 0xBF];
    final bytes = Uint8List.fromList([...bom, ...utf8.encode(csvContent)]);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'flight_log_${DateTime.now().toIso8601String().substring(0, 10)}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSVをダウンロードしました'), backgroundColor: Colors.green));
  }

  String _formatNumber(int number) => number == 0 ? '0' : number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  int get jalFOP => legs.where((l) => l['airline'] == 'JAL').fold<int>(0, (s, l) => s + ((l['calculatedFOP'] as int?) ?? 0));
  int get jalMiles => legs.where((l) => l['airline'] == 'JAL').fold<int>(0, (s, l) => s + ((l['calculatedMiles'] as int?) ?? 0));
  int get jalFlightLSP => legs.where((l) => l['airline'] == 'JAL').fold<int>(0, (s, l) => s + ((l['calculatedLSP'] as int?) ?? 0));
  bool get isAutoShoppingMilePremium { final c = selectedJALCard ?? '-'; return c.contains('ゴールド') || c.contains('プラチナ') || c.contains('JAL CLUB EST') || c == 'JALカードNAVI会員'; }
  bool get isShoppingMileEligible { final c = selectedJALCard ?? '-'; return c != '-' && c != 'JMB会員'; }
  bool get isShoppingMilePremiumActive => isAutoShoppingMilePremium || jalShoppingMilePremium;
  int get jalShoppingMiles => !isShoppingMileEligible ? 0 : (isShoppingMilePremiumActive ? jalFare ~/ 100 : jalFare ~/ 200);
  int get jalShoppingLSP => (jalShoppingMiles ~/ 2000) * 5;
  int get jalTotalLSP => jalFlightLSP + jalShoppingLSP;
  int get jalCount => legs.where((l) => l['airline'] == 'JAL' && l['calculatedFOP'] != null).length;
  int get jalFare { int s = 0; for (var l in legs) { if (l['airline'] != 'JAL') continue; s += int.tryParse(fareAmountControllers[l['id'] as int]?.text ?? '') ?? 0; } return s; }
  String get jalUnitPrice => (jalFare > 0 && jalFOP > 0) ? (jalFare / jalFOP).toStringAsFixed(1) : '-';
  int get anaPP => legs.where((l) => l['airline'] == 'ANA').fold<int>(0, (s, l) => s + ((l['calculatedFOP'] as int?) ?? 0));
  int get anaMiles => legs.where((l) => l['airline'] == 'ANA').fold<int>(0, (s, l) => s + ((l['calculatedMiles'] as int?) ?? 0));
  int get anaCount => legs.where((l) => l['airline'] == 'ANA' && l['calculatedFOP'] != null).length;
  int get anaFare { int s = 0; for (var l in legs) { if (l['airline'] != 'ANA') continue; s += int.tryParse(fareAmountControllers[l['id'] as int]?.text ?? '') ?? 0; } return s; }
  String get anaUnitPrice => (anaFare > 0 && anaPP > 0) ? (anaFare / anaPP).toStringAsFixed(1) : '-';
  List<String> _getSortedAirportList(List<String> inputList) { final m = majorAirports.where((a) => inputList.contains(a)).toList(), r = regionalAirports.where((a) => inputList.contains(a)).toList(); if (m.isEmpty) return r; if (r.isEmpty) return m; return [...m, airportDivider, ...r]; }
  DateTime? _parseDate(String text) { if (text.isEmpty) return null; try { final p = text.split('/'); if (p.length == 3) return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); } catch (e) {} return null; }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      return Column(children: [
        Expanded(
          child: SingleChildScrollView(padding: EdgeInsets.all(isMobile ? 8 : 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSummaryBar(isMobile),
            ...legs.asMap().entries.map((e) => _buildLegCard(context, e.value, e.key, isMobile)),
            if (errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14))),
            if (isMobile) const SizedBox(height: 60), // モバイル版のみ下部ボタン分のスペース
          ])),
        ),
        if (isMobile) _buildBottomActionBar(),
      ]);
    });
  }

  Widget _buildBottomActionBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addLeg,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addLeg),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveItinerary,
                icon: const Icon(Icons.add_chart, size: 18),
                label: Text(l10n.addToLog),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _downloadCsv,
                icon: const Icon(Icons.download, size: 18),
                label: Text(l10n.csv),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== UI WIDGETS (Part 2に続く) ==========
  
  Widget _buildSummaryBar(bool isMobile) {
    if (isMobile) {
      return _buildMobileSummarySection();
    }
    return _buildDesktopSummaryBar();
  }

  Widget _buildMobileSummarySection() {
    final l10n = AppLocalizations.of(context)!;
    final hasJAL = legs.any((l) => l['airline'] == 'JAL'), hasANA = legs.any((l) => l['airline'] == 'ANA');
    final totalFop = jalFOP + anaPP;
    final totalLegs = jalCount + anaCount;
    
    return Column(children: [
      // コンパクトサマリー + 設定ボタン
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.purple[700]!, Colors.purple[500]!]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.total, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (hasJAL) ...[
                  Text('${_formatNumber(jalFOP)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(' ${l10n.fop}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
                if (hasJAL && hasANA) const Text('  ', style: TextStyle(fontSize: 12)),
                if (hasANA) ...[
                  Text('${_formatNumber(anaPP)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(' ${l10n.pp}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(l10n.nLegs(totalLegs), style: const TextStyle(fontSize: 14, color: Colors.white)),
              if (jalUnitPrice != '-' || anaUnitPrice != '-')
                Text('${l10n.costPerPoint}: ¥${jalUnitPrice != '-' ? jalUnitPrice : anaUnitPrice}', style: TextStyle(fontSize: 12, color: Colors.yellow[200])),
            ]),
          ]),
          const SizedBox(height: 8),
          // 設定ボタン
          GestureDetector(
            onTap: () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.settings, size: 16, color: Colors.white.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(l10n.cardStatusSettings, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                const SizedBox(width: 4),
                Icon(_isSettingsExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.white.withOpacity(0.9)),
              ]),
            ),
          ),
        ]),
      ),
      // 設定パネル（展開時）
      if (_isSettingsExpanded) _buildMobileSettingsPanel(),
      // 航空会社別サマリー
      if (hasJAL) _buildMobileSummaryCard('JAL', Colors.red),
      if (hasJAL && hasANA) const SizedBox(height: 6),
      if (hasANA) _buildMobileSummaryCard('ANA', Colors.blue),
      const SizedBox(height: 10),
    ]);
  }

  Widget _buildMobileSettingsPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // JAL設定
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
            child: const Text('JAL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          GestureDetector(onTap: _openHapitas, child: Text(l10n.cardNotIssued, style: TextStyle(fontSize: 10, color: Colors.red.withOpacity(0.7), decoration: TextDecoration.underline))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildMobileSettingDropdown(l10n.card, selectedJALCard, jalCardTypes, Colors.red, _onJALCardChanged)),
          const SizedBox(width: 8),
          Expanded(child: _buildMobileSettingDropdown(l10n.status, selectedJALStatus, jalStatusTypes, Colors.red, _onJALStatusChanged)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Row(children: [
            SizedBox(width: 20, height: 20, child: Checkbox(value: jalTourPremium, onChanged: _onJALTourPremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            const SizedBox(width: 4),
            Text(l10n.tourPremium, style: const TextStyle(fontSize: 11)),
          ])),
          Expanded(child: Row(children: [
            SizedBox(width: 20, height: 20, child: Checkbox(value: isAutoShoppingMilePremium || jalShoppingMilePremium, onChanged: isAutoShoppingMilePremium ? null : _onJALShoppingMilePremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            const SizedBox(width: 4),
            Text(l10n.shoppingMileP, style: TextStyle(fontSize: 11, color: isAutoShoppingMilePremium ? Colors.grey : Colors.black)),
          ])),
        ]),
        const SizedBox(height: 12),
        // ANA設定
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
            child: const Text('ANA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          GestureDetector(onTap: _openHapitas, child: Text(l10n.cardNotIssued, style: TextStyle(fontSize: 10, color: Colors.blue.withOpacity(0.7), decoration: TextDecoration.underline))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildMobileSettingDropdown(l10n.card, selectedANACard, anaCardTypes, Colors.blue, _onANACardChanged)),
          const SizedBox(width: 8),
          Expanded(child: _buildMobileSettingDropdown(l10n.status, selectedANAStatus, anaStatusTypes, Colors.blue, _onANAStatusChanged)),
        ]),
      ]),
    );
  }

  Widget _buildMobileSettingDropdown(String label, String? value, List<String> items, Color color, void Function(String?) onChanged) {
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Container(
        height: 36,
        decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
          hint: Padding(padding: const EdgeInsets.only(left: 8), child: Text(l10n.select, style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
          selectedItemBuilder: (c) => items.map((e) => Padding(padding: const EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)))).toList(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  Widget _buildDesktopSummaryBar() {
    final l10n = AppLocalizations.of(context)!;
    final hasJAL = legs.any((l) => l['airline'] == 'JAL'), hasANA = legs.any((l) => l['airline'] == 'ANA');
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: Column(children: [
        // サマリー行（常に表示）
        Container(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            // JALサマリー
            if (hasJAL) ...[
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: const Text('JAL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.fop, _formatNumber(jalFOP), Colors.red),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.miles, _formatNumber(jalMiles), Colors.red),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.lsp, '${_formatNumber(jalFlightLSP + jalShoppingLSP)}', Colors.red),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.legs, '$jalCount', Colors.red),
              if (jalFare > 0) ...[const SizedBox(width: 8), _buildMiniStat(l10n.totalFare, '¥${_formatNumber(jalFare)}', Colors.red)],
              if (jalUnitPrice != '-') ...[const SizedBox(width: 8), _buildMiniStat(l10n.unitPrice, '¥$jalUnitPrice', Colors.red)],
            ],
            if (hasJAL && hasANA) Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 12), color: Colors.grey[300]),
            // ANAサマリー
            if (hasANA) ...[
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                child: const Text('ANA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.pp, _formatNumber(anaPP), Colors.blue),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.miles, _formatNumber(anaMiles), Colors.blue),
              const SizedBox(width: 8),
              _buildMiniStat(l10n.legs, '$anaCount', Colors.blue),
              if (anaFare > 0) ...[const SizedBox(width: 8), _buildMiniStat(l10n.totalFare, '¥${_formatNumber(anaFare)}', Colors.blue)],
              if (anaUnitPrice != '-') ...[const SizedBox(width: 8), _buildMiniStat(l10n.unitPrice, '¥$anaUnitPrice', Colors.blue)],
            ],
            const Spacer(),
            // 設定展開ボタン
            GestureDetector(
              onTap: () => setState(() => _isSettingsExpanded = !_isSettingsExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.purple[200]!)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.settings, size: 14, color: Colors.purple[700]),
                  const SizedBox(width: 4),
                  Text(l10n.cardStatusSettings, style: TextStyle(fontSize: 11, color: Colors.purple[700])),
                  const SizedBox(width: 2),
                  Icon(_isSettingsExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.purple[700]),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // 保存・CSVボタン
            ElevatedButton.icon(onPressed: _saveItinerary, icon: const Icon(Icons.add_chart, size: 14), label: Text(l10n.addToLog), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 11))),
            const SizedBox(width: 6),
            ElevatedButton.icon(onPressed: _downloadCsv, icon: const Icon(Icons.download, size: 14), label: Text(l10n.csv), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 11))),
          ]),
        ),
        // 設定パネル（展開時）
        if (_isSettingsExpanded) ...[
          Container(height: 1, color: Colors.grey[300]),
          Container(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              // JAL設定
              SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text('JAL ${l10n.card}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(width: 4), GestureDetector(onTap: _openHapitas, child: Text(l10n.cardNotIssued, style: TextStyle(fontSize: 9, color: Colors.red.withOpacity(0.7), decoration: TextDecoration.underline)))]),
                const SizedBox(height: 2), Container(height: 26, decoration: BoxDecoration(border: Border.all(color: Colors.red.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
                  child: DropdownButton<String>(value: selectedJALCard, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]), menuWidth: 250, hint: Padding(padding: const EdgeInsets.only(left: 4), child: Text(l10n.select, style: TextStyle(fontSize: 10, color: Colors.grey[600]))), selectedItemBuilder: (c) => jalCardTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 4), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(), items: jalCardTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(), onChanged: _onJALCardChanged)),
              ])),
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 18, height: 18, child: Checkbox(value: jalTourPremium, onChanged: _onJALTourPremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)), const SizedBox(width: 4), Text(l10n.tourPremium, style: const TextStyle(fontSize: 9, color: Colors.red))]),
                Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 18, height: 18, child: Checkbox(value: isAutoShoppingMilePremium || jalShoppingMilePremium, onChanged: isAutoShoppingMilePremium ? null : _onJALShoppingMilePremiumChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)), const SizedBox(width: 4), Text(l10n.shoppingMileP, style: TextStyle(fontSize: 9, color: isAutoShoppingMilePremium ? Colors.grey : Colors.red))]),
              ]),
              _buildCompactDropdown('JAL ${l10n.status}', 120, selectedJALStatus, jalStatusTypes, Colors.red, _onJALStatusChanged),
              Container(width: 1, height: 36, color: Colors.grey[300]),
              // ANA設定
              SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text('ANA ${l10n.card}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)), const SizedBox(width: 4), GestureDetector(onTap: _openHapitas, child: Text(l10n.cardNotIssued, style: TextStyle(fontSize: 9, color: Colors.blue.withOpacity(0.7), decoration: TextDecoration.underline)))]),
                const SizedBox(height: 2), Container(height: 26, decoration: BoxDecoration(border: Border.all(color: Colors.blue.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
                  child: DropdownButton<String>(value: selectedANACard, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]), menuWidth: 250, hint: Padding(padding: const EdgeInsets.only(left: 4), child: Text(l10n.select, style: TextStyle(fontSize: 10, color: Colors.grey[600]))), selectedItemBuilder: (c) => anaCardTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 4), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(), items: anaCardTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(), onChanged: _onANACardChanged)),
              ])),
              _buildCompactDropdown('ANA ${l10n.status}', 140, selectedANAStatus, anaStatusTypes, Colors.blue, _onANAStatusChanged),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildMobileSummaryCard(String airline, Color color) {
    final l10n = AppLocalizations.of(context)!;
    final isJAL = airline == 'JAL';
    final fop = isJAL ? jalFOP : anaPP;
    final miles = isJAL ? jalMiles : anaMiles;
    final count = isJAL ? jalCount : anaCount;
    final unitPrice = isJAL ? jalUnitPrice : anaUnitPrice;
    final fare = isJAL ? jalFare : anaFare;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: Text(airline, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(l10n.nLegs(count), style: TextStyle(fontSize: 12, color: color)),
            const Spacer(),
            Text('${_formatNumber(fop)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(' ${isJAL ? l10n.fop : l10n.pp}', style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text('${_formatNumber(miles)} ${l10n.miles}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (isJAL) ...[
              const SizedBox(width: 12),
              Text('${_formatNumber(jalFlightLSP + jalShoppingLSP)} ${l10n.lsp}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
            const Spacer(),
            if (fare > 0) ...[
              Text('¥${_formatNumber(fare)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(width: 8),
            ],
            if (unitPrice != '-')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(4)),
                child: Text('¥$unitPrice/${isJAL ? l10n.fop : l10n.pp}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown(String label, double width, String? value, List<String> items, Color labelColor, void Function(String?) onChanged) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor)), const SizedBox(height: 2),
      Container(height: 26, decoration: BoxDecoration(border: Border.all(color: labelColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: value, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]), menuWidth: width + 100, hint: Padding(padding: const EdgeInsets.only(left: 4), child: Text('選択', style: TextStyle(fontSize: 10, color: Colors.grey[600]))), selectedItemBuilder: (c) => items.map((e) => Padding(padding: const EdgeInsets.only(left: 4), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(), onChanged: onChanged)),
    ]));
  }

  Widget _buildMiniStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))]);

  Widget _buildLegCard(BuildContext context, Map<String, dynamic> leg, int index, bool isMobile) {
    final legId = leg['id'] as int, airline = leg['airline'] as String, fop = leg['calculatedFOP'] as int?, miles = leg['calculatedMiles'] as int?, lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue, isExpanded = expandedLegId == legId;
    final dep = leg['departureAirport'] as String, arr = leg['arrivalAirport'] as String;
    final flightNum = flightNumberControllers[legId]?.text ?? '';
    final depTime = departureTimeControllers[legId]?.text ?? '';
    final arrTime = arrivalTimeControllers[legId]?.text ?? '';
    final fareType = leg['fareType'] as String? ?? '';
    final seatClass = leg['seatClass'] as String? ?? '';
    final fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop != null && fop > 0) ? (fare / fop).toStringAsFixed(1) : '-';
    
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isExpanded ? airlineColor : airlineColor.withOpacity(0.3), width: isExpanded ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          InkWell(
            onTap: () => setState(() => expandedLegId = isExpanded ? null : legId),
            borderRadius: BorderRadius.circular(isExpanded ? 0 : 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isExpanded ? airlineColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(11),
                  topRight: const Radius.circular(11),
                  bottomLeft: Radius.circular(isExpanded ? 0 : 11),
                  bottomRight: Radius.circular(isExpanded ? 0 : 11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1行目: レグ番号、FOP、出発-到着時刻
                  Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 8),
                    if (fop != null) ...[
                      Text('${_formatNumber(fop)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: airlineColor)),
                      Text(' ${airline == "JAL" ? "FOP" : "PP"}', style: TextStyle(fontSize: 10, color: airlineColor)),
                    ] else
                      Text(AppLocalizations.of(context)!.notCalculated, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    if (depTime.isNotEmpty && arrTime.isNotEmpty)
                      Text('$depTime → $arrTime', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: airlineColor),
                  ]),
                  const SizedBox(height: 6),
                  // 2行目: 出発地-到着地
                  Row(children: [
                    if (dep.isNotEmpty) ...[
                      Text(dep, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (airportNames[dep] != null)
                        Text(' ${airportNames[dep]}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
                    ),
                    if (arr.isNotEmpty) ...[
                      Text(arr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (airportNames[arr] != null)
                        Text(' ${airportNames[arr]}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                    if (dep.isEmpty && arr.isEmpty)
                      Text(AppLocalizations.of(context)!.routeNotSet, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ]),
                  // 3行目: 便名、運賃種別、座席、単価（計算済みの場合）
                  if (fop != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      if (flightNum.isNotEmpty)
                        Text(flightNum, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      if (flightNum.isNotEmpty && fareType.isNotEmpty)
                        const SizedBox(width: 8),
                      if (fareType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                          child: Text(_shortenFareType(fareType), style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                        ),
                      if (seatClass.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(seatClass, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                      const Spacer(),
                      if (unitPrice != '-')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(4)),
                          child: Text('¥$unitPrice/${airline == "JAL" ? "FOP" : "PP"}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: airlineColor)),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded) _buildMobileExpandedContent(leg, legId, index, fop, miles, lsp, airline),
        ]),
      );
    }
    return _buildDesktopLegCard(context, leg, index);
  }

  String _shortenFareType(String fareType) {
    // 運賃種別を短縮表示（例: "運賃3 (75%) セイバー" → "運賃3(75%)"）
    final match = RegExp(r'運賃\d+.*?\(\d+%\)').firstMatch(fareType);
    if (match != null) return match.group(0)!.replaceAll(' ', '');
    if (fareType.length > 12) return '${fareType.substring(0, 10)}...';
    return fareType;
  }

  Widget _buildMobileExpandedContent(Map<String, dynamic> leg, int legId, int index, int? fop, int? miles, int? lsp, String airline) {
    final l10n = AppLocalizations.of(context)!;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue, fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop != null && fop > 0) ? (fare / fop).toStringAsFixed(1) : '-';
    return Container(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: _buildMobileAirlineDropdown(l10n.airline, leg['airline'] as String, (v) { if (v != null && v != leg['airline']) { _clearFlightInfo(index, legId); setState(() { legs[index]['airline'] = v; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); } })), const SizedBox(width: 8), Expanded(flex: 2, child: _buildMobileDatePicker(l10n.date, dateControllers[legId]!, context, index)), const SizedBox(width: 8), SizedBox(width: 60, child: _buildMobileTextField(l10n.flightNumber, flightNumberControllers[legId]!, '', onSubmit: (_) => _autoFillFromFlightNumber(index)))]),
      const SizedBox(height: 6),
      Row(children: [Expanded(child: _buildMobileAirportSelector(l10n.departure, departureAirportControllers[legId]!, departureAirportFocusNodes[legId]!, airlineAirports[airline] ?? airports, (v) { if (v != null) { _clearFlightInfo(index, legId); departureAirportControllers[legId]?.text = v; setState(() => legs[index]['departureAirport'] = v); _fetchAvailableFlights(index); } })), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.grey[400], size: 20)), Expanded(child: _buildMobileDestinationSelector(leg, legId, index))]),
      const SizedBox(height: 6),
      Row(children: [Expanded(child: _buildMobileFlightTimeDropdown(leg, legId, index)), const SizedBox(width: 8), Expanded(child: _buildMobileTextField(l10n.arrivalTime, arrivalTimeControllers[legId]!, 'HH:MM'))]),
      const SizedBox(height: 6),
      // ANAの場合は座席に応じて運賃をフィルタリング
      _buildMobileDropdown(l10n.fareType, leg['fareType'] as String, 
        airline == 'ANA' ? _getAnaAvailableFareTypes(leg['seatClass'] as String).map((k) => _getFareTypeName(k)).toList() : fareTypesByAirline[airline] ?? [], 
        (v) { if (v != null) { 
          if (airline == 'ANA') {
            final key = fareTypeKeys['ANA']!.firstWhere((k) => _getFareTypeName(k) == v, orElse: () => '');
            if (key.isNotEmpty) _onAnaFareTypeChanged(index, key);
          } else {
            setState(() => legs[index]['fareType'] = v); _calculateSingleLeg(index);
          }
        } }),
      const SizedBox(height: 6),
      // ANAの場合は運賃に応じて座席をフィルタリング
      Row(children: [Expanded(child: _buildMobileDropdown(l10n.seatClass, leg['seatClass'] as String, 
        airline == 'ANA' ? _getAnaAvailableSeatClasses(leg['fareType'] as String).map((k) => _getSeatClassName(k)).toList() : seatClassesByAirline[airline] ?? [], 
        (v) { if (v != null) { 
        if (airline == 'ANA') {
          final key = seatClassKeys['ANA']!.firstWhere((k) => _getSeatClassName(k) == v, orElse: () => '');
          if (key.isNotEmpty) _onAnaSeatClassChanged(index, key);
        } else {
          setState(() => legs[index]['seatClass'] = v); _calculateSingleLeg(index);
        }
      } })), const SizedBox(width: 8), Expanded(child: _buildMobileTextField(l10n.fareAmountYen, fareAmountControllers[legId]!, '', onChanged: (_) => setState(() {}), isNumeric: true))]),
      if (fop != null) ...[const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text('${_formatNumber(fop)} ${airline == "JAL" ? "FOP" : "PP"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 10), Text('${_formatNumber(miles ?? 0)}${l10n.miles}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)), if (airline == 'JAL' && lsp != null) ...[const SizedBox(width: 6), Text('${lsp}LSP', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11))]]), if (fare > 0) Text('¥$unitPrice/${airline == "JAL" ? "FOP" : "PP"}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 11))]))],
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: () => _clearLeg(index, legId), child: Text(l10n.clear, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
        if (legs.length > 1) TextButton(onPressed: () => _removeLeg(index), child: Text(l10n.delete, style: TextStyle(color: Colors.red, fontSize: 12))),
      ]),
    ]));
  }

  Widget _buildMobileDropdown(String label, String value, List<String> items, void Function(String?) onChanged, {Color? color}) {
    final currentValue = value.isEmpty || !items.contains(value) ? null : value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), const SizedBox(height: 2),
      Container(height: 36, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]), hint: Padding(padding: const EdgeInsets.only(left: 8), child: Text('選択', style: TextStyle(fontSize: 12, color: Colors.grey[500]))), selectedItemBuilder: (c) => items.map((e) => Padding(padding: const EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: TextStyle(fontSize: 12, color: color ?? Colors.black, fontWeight: color != null ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)))).toList(), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 12, color: color ?? Colors.black)))).toList(), onChanged: onChanged))]);
  }

  // 航空会社用ドロップダウン（JAL=赤、ANA=青）
  Widget _buildMobileAirlineDropdown(String label, String value, void Function(String?) onChanged) {
    final currentValue = value.isEmpty ? null : value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), const SizedBox(height: 2),
      Container(height: 36, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]), hint: Padding(padding: const EdgeInsets.only(left: 8), child: Text('選択', style: TextStyle(fontSize: 12, color: Colors.grey[500]))), 
          selectedItemBuilder: (c) => airlines.map((e) => Padding(padding: const EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)))).toList(), 
          items: airlines.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)))).toList(), 
          onChanged: onChanged))]);
  }

  Widget _buildMobileAirportSelector(String label, TextEditingController controller, FocusNode focusNode, List<String> items, void Function(String?) onChanged) {
    final airportList = items.where((e) => e != airportDivider).toList();
    final effectiveList = airportList.isNotEmpty ? airportList : [...majorAirports, ...regionalAirports];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), const SizedBox(height: 2), _buildMobileAirportAutocomplete(controller: controller, focusNode: focusNode, airportList: effectiveList, onSelected: (code) => onChanged(code))]);
  }

  // ========================================
  // 到着空港選択ウィジェット（モバイル版）
  // 重要: 出発地から就航している空港のみ表示する
  // availableDestinationsは_fetchAvailableFlightsで設定される
  // フォールバックで全空港を表示してはいけない（バグの原因）
  // ========================================
  Widget _buildMobileDestinationSelector(Map<String, dynamic> leg, int legId, int index) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = (availableDestinations[legId] ?? []).where((e) => e != airportDivider).toList();
    final sortedDestinations = _getSortedAirportList(destinations).where((e) => e != airportDivider).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.arrival, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), 
      const SizedBox(height: 2), 
      _buildMobileAirportAutocomplete(
        controller: arrivalAirportControllers[legId]!,
        focusNode: arrivalAirportFocusNodes[legId]!,
        airportList: sortedDestinations, // 就航空港のみ。全空港にしないこと！
        onSelected: (code) {
          arrivalAirportControllers[legId]?.text = code;
          setState(() => legs[index]['arrivalAirport'] = code);
          _fetchAvailableFlights(index);
          _calculateSingleLeg(index);
        },
      ),
    ]);
  }

  Widget _buildMobileAirportAutocomplete({required TextEditingController controller, required FocusNode focusNode, required List<String> airportList, required void Function(String) onSelected}) {
    return RawAutocomplete<String>(textEditingController: controller, focusNode: focusNode,
      optionsBuilder: (textEditingValue) { final input = textEditingValue.text.toUpperCase(); if (input.isEmpty) return _getSortedAirportList(airportList).where((e) => e != airportDivider); return airportList.where((code) { final name = airportNames[code] ?? ''; return code.contains(input) || name.contains(input); }); },
      displayStringForOption: (code) => code,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6), color: Colors.grey[50]),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TextFormField(controller: textController, focusNode: focusNode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero), onFieldSubmitted: (value) { final code = value.toUpperCase(); if (airportList.contains(code)) onSelected(code); }), if (textController.text.isNotEmpty && airportList.contains(textController.text.toUpperCase())) Text(airportNames[textController.text.toUpperCase()] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[600]))])), Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600])])),
      optionsViewBuilder: (context, onAutoSelected, options) { final sortedOptions = _getSortedAirportList(options.toList()); return Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 250, maxWidth: 200), child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: sortedOptions.length, itemBuilder: (context, i) { final code = sortedOptions[i]; if (code == airportDivider) return Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8)); return InkWell(onTap: () => onAutoSelected(code), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [Text(code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Text(airportNames[code] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]))]))); })))); },
      onSelected: onSelected);
  }

  Widget _buildMobileFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final l10n = AppLocalizations.of(context)!;
    final flights = availableFlights[legId] ?? [], currentTime = departureTimeControllers[legId]?.text ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.departureTime, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), const SizedBox(height: 2),
      Container(height: 36, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
        child: DropdownButton<String>(value: null, isExpanded: true, underline: const SizedBox(), icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]), hint: Padding(padding: const EdgeInsets.only(left: 8), child: Text(currentTime.isEmpty ? '選択' : currentTime, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: currentTime.isEmpty ? Colors.grey[500] : Colors.black))),
          items: [const DropdownMenuItem(value: '__clear__', child: Text('-', style: TextStyle(fontSize: 12))), ...flights.map((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); final arrCode = flight['arrival_code'] ?? ''; return DropdownMenuItem(value: '${flight['id']}', child: Text('${airportNames[arrCode] ?? arrCode} $depTime', style: const TextStyle(fontSize: 12))); })],
          onChanged: (value) { if (value == null) return; if (value == '__clear__') { _clearFlightInfo(index, legId); return; } final flight = flights.firstWhere((f) => f['id'].toString() == value, orElse: () => {}); if (flight.isNotEmpty) { String depTime = flight['departure_time'] ?? '', arrTime = flight['arrival_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5); departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime; flightNumberControllers[legId]?.text = flight['flight_number'] ?? ''; setState(() => legs[index]['arrivalAirport'] = flight['arrival_code'] ?? ''); arrivalAirportControllers[legId]?.text = flight['arrival_code'] ?? ''; if (index + 1 < legs.length) _fetchAvailableFlights(index + 1); _calculateSingleLeg(index); } }))]);
  }

  Widget _buildMobileTextField(String label, TextEditingController controller, String hint, {void Function(String)? onChanged, void Function(String)? onSubmit, bool isNumeric = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), const SizedBox(height: 2),
      Container(height: 36, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
        child: Focus(onFocusChange: (hasFocus) { if (!hasFocus && onSubmit != null && controller.text.isNotEmpty) onSubmit(controller.text); }, child: TextFormField(controller: controller, style: const TextStyle(fontSize: 12), keyboardType: isNumeric ? TextInputType.number : TextInputType.text, inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null, decoration: InputDecoration(hintText: hint, isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)), onChanged: onChanged, onFieldSubmitted: onSubmit)))]);
  }

  Widget _buildMobileDatePicker(String label, TextEditingController controller, BuildContext context, int index) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])), const SizedBox(height: 2),
      Container(height: 36, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
        child: TextFormField(controller: controller, readOnly: true, style: const TextStyle(fontSize: 12), decoration: InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), suffixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.grey[600])),
          onTap: () async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: _parseDate(controller.text) ?? now, firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ja')); if (picked != null) { controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}'; setState(() {}); _fetchAvailableFlights(index); } }))]);
  }

  Widget _buildDesktopLegCard(BuildContext context, Map<String, dynamic> leg, int index) {
    final l10n = AppLocalizations.of(context)!;
    final legId = leg['id'] as int, airline = leg['airline'] as String, fop = leg['calculatedFOP'] as int?, miles = leg['calculatedMiles'] as int?, lsp = leg['calculatedLSP'] as int?;
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue, warning = legWarnings[legId];
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: airlineColor.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [if (warning != null) Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)), child: Text(warning, style: TextStyle(fontSize: 11, color: Colors.orange[800])))) else const Spacer(), TextButton.icon(onPressed: _addLeg, icon: const Icon(Icons.add, size: 16), label: Text(l10n.addLeg), style: TextButton.styleFrom(foregroundColor: Colors.grey[600], textStyle: const TextStyle(fontSize: 12))), TextButton(onPressed: () => _clearLeg(index, legId), child: Text(l10n.clear, style: TextStyle(color: Colors.grey[600], fontSize: 12))), if (legs.length > 1) IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[600]), onPressed: () => _removeLeg(index), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: l10n.delete)]),
        const SizedBox(height: 4),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _buildDesktopAirlineDropdown(leg, legId, index), const SizedBox(width: 8), _buildDesktopDatePicker(l10n.date, 130, dateControllers[legId]!, context, index), const SizedBox(width: 8), _buildDesktopFlightNumberField(legId, index), const SizedBox(width: 8),
          _buildDesktopDepartureDropdown(leg, legId, index), const SizedBox(width: 4), Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]), const SizedBox(width: 4), _buildDesktopDestinationDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDesktopFlightTimeDropdown(leg, legId, index), const SizedBox(width: 4), _buildDesktopArrivalTimeField(legId), const SizedBox(width: 8),
          _buildDesktopFareTypeDropdown(leg, legId, index), const SizedBox(width: 8), _buildDesktopSeatClassDropdown(leg, legId, index), const SizedBox(width: 8),
          _buildDesktopTextField(l10n.fareAmount, 70, fareAmountControllers[legId]!, '', onChanged: (_) => setState(() {}), isNumeric: true), const SizedBox(width: 8),
          if (fop != null) _buildDesktopPointsDisplay(airline, fop, miles, lsp, legId),
        ]))]));
  }

  Widget _buildDesktopPointsDisplay(String airline, int fop, int? miles, int? lsp, int legId) {
    final airlineColor = airline == 'JAL' ? Colors.red : Colors.blue, fare = int.tryParse(fareAmountControllers[legId]?.text ?? '') ?? 0;
    final unitPrice = (fare > 0 && fop > 0) ? (fare / fop).toStringAsFixed(1) : '-', pointLabel = airline == 'JAL' ? 'FOP' : 'PP';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: airlineColor, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [if (airline == 'JAL') Text('$pointLabel: $fop  マイル: $miles  LSP: ${lsp ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)) else Text('$pointLabel: $fop  マイル: $miles', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)), if (fare > 0) Text('単価: ¥$unitPrice/$pointLabel', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10))]));
  }

  Widget _buildDesktopAirlineDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String;
    return SizedBox(width: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.airline, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: airline.isEmpty ? null : airline, isExpanded: true, underline: const SizedBox(), hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 12))), selectedItemBuilder: (c) => airlines.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold))))).toList(), items: airlines.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 12, color: e == 'JAL' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)))).toList(), onChanged: (v) { if (v != null && v != airline) { _clearFlightInfo(index, legId); setState(() { legs[index]['airline'] = v; legs[index]['fareType'] = ''; legs[index]['seatClass'] = ''; }); } }))]));
  }

  Widget _buildDesktopDepartureDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String, airportList = (airlineAirports[airline] ?? [...majorAirports, ...regionalAirports]).where((e) => e != airportDivider).toList();
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.departureAirport, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), _buildAirportAutocomplete(controller: departureAirportControllers[legId]!, focusNode: departureAirportFocusNodes[legId]!, airportList: airportList, onSelected: (code) { _clearFlightInfo(index, legId); departureAirportControllers[legId]?.text = code; setState(() => legs[index]['departureAirport'] = code); _fetchAvailableFlights(index); })]));
  }

  // ========================================
  // 到着空港選択ウィジェット
  // 重要: 出発地から就航している空港のみ表示する
  // availableDestinationsは_fetchAvailableFlightsで設定される
  // フォールバックで全空港を表示してはいけない（バグの原因）
  // ========================================
  Widget _buildDesktopDestinationDropdown(Map<String, dynamic> leg, int legId, int index) {
    final destinations = (availableDestinations[legId] ?? []).where((e) => e != airportDivider).toList();
    final sortedDestinations = _getSortedAirportList(destinations).where((e) => e != airportDivider).toList();
    return SizedBox(width: 85, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppLocalizations.of(context)!.arrivalAirport, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 4), 
      _buildAirportAutocomplete(
        controller: arrivalAirportControllers[legId]!,
        focusNode: arrivalAirportFocusNodes[legId]!,
        airportList: sortedDestinations, // 就航空港のみ。全空港にしないこと！
        onSelected: (code) {
          arrivalAirportControllers[legId]?.text = code;
          setState(() => legs[index]['arrivalAirport'] = code);
          _fetchAvailableFlights(index);
          _calculateSingleLeg(index);
        },
      ),
    ]));
  }

  Widget _buildAirportAutocomplete({required TextEditingController controller, required FocusNode focusNode, required List<String> airportList, required void Function(String) onSelected}) {
    return RawAutocomplete<String>(textEditingController: controller, focusNode: focusNode,
      optionsBuilder: (textEditingValue) { final input = textEditingValue.text.toUpperCase(); if (input.isEmpty) return _getSortedAirportList(airportList).where((e) => e != airportDivider); return airportList.where((code) { final name = airportNames[code] ?? ''; return code.contains(input) || name.contains(input); }); },
      displayStringForOption: (code) => code,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) => Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: TextFormField(controller: textController, focusNode: focusNode, style: const TextStyle(fontSize: 12), textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), suffixIcon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600])), onFieldSubmitted: (value) { final code = value.toUpperCase(); if (airportList.contains(code)) onSelected(code); })),
      optionsViewBuilder: (context, onAutoSelected, options) { final sortedOptions = _getSortedAirportList(options.toList()); return Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 250, maxWidth: 160), child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: sortedOptions.length, itemBuilder: (context, i) { final code = sortedOptions[i]; if (code == airportDivider) return Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8)); return InkWell(onTap: () => onAutoSelected(code), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text('$code ${airportNames[code] ?? ''}', style: const TextStyle(fontSize: 12)))); })))); },
      onSelected: onSelected);
  }

  Widget _buildDesktopFlightTimeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final flights = availableFlights[legId] ?? [], airline = leg['airline'] as String, currentTime = departureTimeControllers[legId]?.text ?? '';
    return SizedBox(width: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.departureTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(key: ValueKey('flight_time_${legId}_$airline'), value: null, isExpanded: true, underline: const SizedBox(), menuWidth: 150, hint: Padding(padding: const EdgeInsets.only(left: 6), child: Text(currentTime.isEmpty ? '選択' : currentTime, style: const TextStyle(fontSize: 12))),
          items: [const DropdownMenuItem(value: '__clear__', child: Text('-', style: TextStyle(fontSize: 12))), ...flights.map((flight) { String depTime = flight['departure_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); final arrCode = flight['arrival_code'] ?? ''; return DropdownMenuItem(value: '${flight['id']}', child: Text('${airportNames[arrCode] ?? arrCode} $depTime', style: const TextStyle(fontSize: 12))); })],
          onChanged: (value) { if (value == null) return; if (value == '__clear__') { _clearFlightInfo(index, legId); return; } final flight = flights.firstWhere((f) => f['id'].toString() == value, orElse: () => {}); if (flight.isNotEmpty) { String depTime = flight['departure_time'] ?? '', arrTime = flight['arrival_time'] ?? ''; if (depTime.length > 5) depTime = depTime.substring(0, 5); if (arrTime.length > 5) arrTime = arrTime.substring(0, 5); departureTimeControllers[legId]?.text = depTime; arrivalTimeControllers[legId]?.text = arrTime; flightNumberControllers[legId]?.text = flight['flight_number'] ?? ''; setState(() => legs[index]['arrivalAirport'] = flight['arrival_code'] ?? ''); arrivalAirportControllers[legId]?.text = flight['arrival_code'] ?? ''; if (index + 1 < legs.length) _fetchAvailableFlights(index + 1); _calculateSingleLeg(index); } }))]));
  }

  Widget _buildDesktopArrivalTimeField(int legId) => SizedBox(width: 65, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.arrivalTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: TextFormField(controller: arrivalTimeControllers[legId], style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: 'HH:MM', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8))))]));

  Widget _buildDesktopFareTypeDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String, fareType = leg['fareType'] as String;
    final seatClass = leg['seatClass'] as String;
    // ANAの場合は座席に応じて運賃をフィルタリング
    final fareTypes = airline == 'ANA' 
        ? _getAnaAvailableFareTypes(seatClass).map((k) => _getFareTypeName(k)).toList()
        : fareTypesByAirline[airline] ?? [];
    final displayFareType = fareType.isNotEmpty ? _getFareTypeName(fareType) : '';
    final currentValue = displayFareType.isEmpty || !fareTypes.contains(displayFareType) ? null : displayFareType;
    return SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.fareType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 250, hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 10))), selectedItemBuilder: (c) => fareTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(), items: fareTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(), onChanged: (v) { 
          if (v != null) { 
            if (airline == 'ANA') {
              final key = fareTypeKeys['ANA']!.firstWhere((k) => _getFareTypeName(k) == v, orElse: () => '');
              if (key.isNotEmpty) _onAnaFareTypeChanged(index, key);
            } else {
              setState(() => legs[index]['fareType'] = v); _calculateSingleLeg(index);
            }
          } 
        }))]));
  }

  Widget _buildDesktopSeatClassDropdown(Map<String, dynamic> leg, int legId, int index) {
    final airline = leg['airline'] as String, seatClass = leg['seatClass'] as String;
    final fareType = leg['fareType'] as String;
    // ANAの場合は運賃に応じて座席をフィルタリング
    final seatClasses = airline == 'ANA' 
        ? _getAnaAvailableSeatClasses(fareType).map((k) => _getSeatClassName(k)).toList()
        : seatClassesByAirline[airline] ?? [];
    final displaySeatClass = seatClass.isNotEmpty ? _getSeatClassName(seatClass) : '';
    final currentValue = displaySeatClass.isEmpty || !seatClasses.contains(displaySeatClass) ? null : displaySeatClass;
    return SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.seatClass, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: DropdownButton<String>(value: currentValue, isExpanded: true, underline: const SizedBox(), menuWidth: 150, hint: const Padding(padding: EdgeInsets.only(left: 6), child: Text('選択', style: TextStyle(fontSize: 10))), selectedItemBuilder: (c) => seatClasses.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: Align(alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))).toList(), items: seatClasses.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 10)))).toList(), onChanged: (v) { 
          if (v != null) { 
            if (airline == 'ANA') {
              final key = seatClassKeys['ANA']!.firstWhere((k) => _getSeatClassName(k) == v, orElse: () => '');
              if (key.isNotEmpty) _onAnaSeatClassChanged(index, key);
            } else {
              setState(() => legs[index]['seatClass'] = v); _calculateSingleLeg(index);
            }
          } 
        }))]));
  }

  Widget _buildDesktopTextField(String label, double width, TextEditingController controller, String hint, {void Function(String)? onChanged, bool isNumeric = false}) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: TextFormField(controller: controller, style: const TextStyle(fontSize: 12), keyboardType: isNumeric ? TextInputType.number : TextInputType.text, inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null, decoration: InputDecoration(hintText: hint, isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: onChanged))]));

  Widget _buildDesktopFlightNumberField(int legId, int index) => SizedBox(width: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.flightNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: Focus(onFocusChange: (hasFocus) { if (!hasFocus) { final flightNumber = flightNumberControllers[legId]?.text ?? ''; if (flightNumber.isNotEmpty) _autoFillFromFlightNumber(index); } }, child: TextFormField(controller: flightNumberControllers[legId], style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: '', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onFieldSubmitted: (_) => _autoFillFromFlightNumber(index))))]));

  Widget _buildDesktopDatePicker(String label, double width, TextEditingController controller, BuildContext context, int index) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(height: 32, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: TextFormField(controller: controller, readOnly: true, style: const TextStyle(fontSize: 12), decoration: const InputDecoration(hintText: '選択', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), suffixIcon: Icon(Icons.calendar_today, size: 14)), onTap: () async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: _parseDate(controller.text) ?? now, firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ja')); if (picked != null) { controller.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}'; setState(() {}); _fetchAvailableFlights(index); } }))]));
}
