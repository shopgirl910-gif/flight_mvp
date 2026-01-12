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
  String get logoutConfirm => 'ログアウトしますか？';

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
  String get addLeg => 'レグ追加';

  @override
  String get csv => 'CSV';

  @override
  String get share => 'シェア';

  @override
  String get select => '選択';

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
  String get leg => 'レグ';

  @override
  String get totalFare => '総額';

  @override
  String get unitPrice => '単価';

  @override
  String get total => '合計';

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
  String get cardStatusSettings => 'カード・ステータス設定';

  @override
  String get card => 'カード';

  @override
  String get status => 'ステータス';

  @override
  String get cardNotIssued => '💡カード未発行の方';

  @override
  String get tourPremium => 'ツアープレミアム';

  @override
  String get shoppingMileP => 'ショッピングマイルP';

  @override
  String flightNotFound(String flightNumber) {
    return '$flightNumber便が見つかりません';
  }

  @override
  String get enterFlightNumber => '便名を入力してください';

  @override
  String get saveFailed => '保存に失敗しました';

  @override
  String get scheduleWarning => '⚠️ 一部期間で時刻変更あり';

  @override
  String nLegs(int count) {
    return '$count レグ';
  }

  @override
  String costPerPoint(String price) {
    return '¥$price/P';
  }

  @override
  String get notCalculated => '未計算';

  @override
  String get routeNotSet => '区間未設定';
}
