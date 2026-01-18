// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'MRP - Mileage Run Planner';

  @override
  String get tabSimulate => 'シミュレート';

  @override
  String get tabLog => '修行ログ';

  @override
  String get tabQuiz => 'クイズ';

  @override
  String get tabCheckin => 'チェックイン';

  @override
  String get guest => 'guest';

  @override
  String get login => 'ログイン';

  @override
  String get logout => 'ログアウト';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get clear => 'クリア';

  @override
  String get add => '追加';

  @override
  String get csv => 'CSV';

  @override
  String get share => 'シェア';

  @override
  String get addToLog => 'ログに追加';

  @override
  String addedToLog(String title) {
    return '「$title」を修行ログに追加しました';
  }

  @override
  String get loginRequired => 'ログインが必要です';

  @override
  String get loginToSave => '旅程を保存するにはログインしてください。';

  @override
  String get loginToDownload => 'CSVをダウンロードするにはログインしてください。';

  @override
  String get fop => 'FOP';

  @override
  String get pp => 'PP';

  @override
  String get miles => 'マイル';

  @override
  String get lsp => 'LSP';

  @override
  String get legs => 'レグ';

  @override
  String get total => '合計';

  @override
  String get totalFare => '総額';

  @override
  String get unitPrice => '単価';

  @override
  String get costPerPoint => '単価';

  @override
  String get airline => '航空会社';

  @override
  String get flightNumber => '便名';

  @override
  String get departure => '出発';

  @override
  String get arrival => '到着';

  @override
  String get departureAirport => '出発地';

  @override
  String get arrivalAirport => '到着地';

  @override
  String get departureTime => '出発時刻';

  @override
  String get arrivalTime => '到着時刻';

  @override
  String get fareType => '運賃種別';

  @override
  String get seatClass => '座席クラス';

  @override
  String get fareAmount => '運賃';

  @override
  String get fareAmountYen => '運賃(円)';

  @override
  String get date => '日付';

  @override
  String get select => '選択';

  @override
  String get card => 'カード';

  @override
  String get status => 'ステータス';

  @override
  String get shoppingMileP => 'ショッピングマイルP';

  @override
  String get notCalculated => '未計算';

  @override
  String get routeNotSet => '区間未設定';

  @override
  String get noLegsToSave => '保存するレグがありません';

  @override
  String get noLegsToDownload => 'ダウンロードするレグがありません';

  @override
  String savedSuccess(String title) {
    return '「$title」を保存しました';
  }

  @override
  String get csvDownloaded => 'CSVをダウンロードしました';

  @override
  String nLegs(int count) {
    return '$count レグ';
  }

  @override
  String get addLeg => 'レグ追加';

  @override
  String get tourPremium => 'ツアープレミアム';

  @override
  String get shoppingMilePremium => 'ショッピングマイルP';

  @override
  String get cardNotIssued => '💡カード未発行の方';

  @override
  String get cardStatusSettings => '⚙ カード/ステータス設定';

  @override
  String get jalCard => 'JALカード';

  @override
  String get anaCard => 'ANAカード';

  @override
  String get jalStatus => 'JALステータス';

  @override
  String get anaStatus => 'ANAステータス';

  @override
  String get deleteConfirm => '削除確認';

  @override
  String get deleteItineraryConfirm => 'この旅程を削除しますか？';

  @override
  String get deleted => '削除しました';

  @override
  String deleteFailed(String error) {
    return '削除に失敗しました: $error';
  }

  @override
  String dataLoadFailed(String error) {
    return 'データの読み込みに失敗しました: $error';
  }

  @override
  String get reload => '再読み込み';

  @override
  String get noSavedItineraries => '保存された旅程がありません';

  @override
  String get loginRequiredToSaveItineraries => '旅程を保存するにはログインが必要です';

  @override
  String get createItineraryInSimulateTab => 'Simulateタブで旅程を作成し、保存してください';

  @override
  String get loginFromTopRight => '右上のログインボタンからログインしてください';

  @override
  String get untitled => '無題';

  @override
  String get airportStampRally => '空港スタンプラリー';

  @override
  String get conquered => '制覇！';

  @override
  String conqueredPercent(String percent) {
    return '$percent% 制覇';
  }

  @override
  String get checkinAvailable => 'チェックイン可能！';

  @override
  String get loginToCheckin => 'ログインしてチェックイン';

  @override
  String get nearestAirport => '最寄り空港';

  @override
  String get checkin => 'チェックイン';

  @override
  String checkinWithinRadius(String radius) {
    return '${radius}km以内で可能';
  }

  @override
  String distanceFromHere(String distance) {
    return '現在地から $distance km';
  }

  @override
  String get calculatingDistance => '距離計算中...';

  @override
  String get gettingLocation => '位置情報を取得中...';

  @override
  String get retry => '再取得';

  @override
  String get locationPermissionRequired => '位置情報の許可が必要です';

  @override
  String get enableLocationInSettings => '設定から位置情報を許可してください';

  @override
  String get locationError => '位置情報取得エラー';

  @override
  String get dataLoadError => 'データ読み込みエラー';

  @override
  String get checkinError => 'チェックインエラー';

  @override
  String tooFarFromAirport(String distance, String radius) {
    return '空港から${distance}km離れています（${radius}km以内でチェックイン可能）';
  }

  @override
  String checkinSuccess(String airport) {
    return '$airport空港にチェックインしました！';
  }

  @override
  String get loginRequiredForCheckin => 'チェックイン記録を保存するにはログインが必要です。\nログイン画面に移動しますか？';

  @override
  String get goToLogin => 'ログインする';

  @override
  String nAirports(int count) {
    return '$count 空港';
  }

  @override
  String get regionHokkaido => '北海道';

  @override
  String get regionTohoku => '東北';

  @override
  String get regionKanto => '関東';

  @override
  String get regionChubu => '中部';

  @override
  String get regionKansai => '関西';

  @override
  String get regionKinki => '近畿';

  @override
  String get regionChugoku => '中国';

  @override
  String get regionShikoku => '四国';

  @override
  String get regionKyushu => '九州';

  @override
  String get regionOkinawa => '沖縄';
}
