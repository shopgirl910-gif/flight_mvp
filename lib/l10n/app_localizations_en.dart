// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MRP - Mileage Run Planner';

  @override
  String get tabSimulate => 'Simulate';

  @override
  String get tabLog => 'Flight Log';

  @override
  String get tabQuiz => 'Quiz';

  @override
  String get tabCheckin => 'Check-in';

  @override
  String get guest => 'guest';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get clear => 'Clear';

  @override
  String get add => 'Add';

  @override
  String get addLeg => 'Add Leg';

  @override
  String get csv => 'CSV';

  @override
  String get share => 'Share';

  @override
  String get select => 'Select';

  @override
  String get loginRequired => 'Login Required';

  @override
  String get loginToSave => 'Please login to save your itinerary.';

  @override
  String get loginToDownload => 'Please login to download CSV.';

  @override
  String get fop => 'FOP';

  @override
  String get pp => 'PP';

  @override
  String get miles => 'Miles';

  @override
  String get lsp => 'LSP';

  @override
  String get legs => 'Legs';

  @override
  String get leg => 'Leg';

  @override
  String get totalFare => 'Total';

  @override
  String get unitPrice => 'Cost/Point';

  @override
  String get total => 'Total';

  @override
  String get airline => 'Airline';

  @override
  String get flightNumber => 'Flight';

  @override
  String get departure => 'Departure';

  @override
  String get arrival => 'Arrival';

  @override
  String get departureAirport => 'From';

  @override
  String get arrivalAirport => 'To';

  @override
  String get departureTime => 'Dep Time';

  @override
  String get arrivalTime => 'Arr Time';

  @override
  String get fareType => 'Fare Type';

  @override
  String get seatClass => 'Class';

  @override
  String get fareAmount => 'Fare';

  @override
  String get fareAmountYen => 'Fare(¥)';

  @override
  String get date => 'Date';

  @override
  String get noLegsToSave => 'No legs to save';

  @override
  String get noLegsToDownload => 'No legs to download';

  @override
  String savedSuccess(String title) {
    return 'Saved \"$title\"';
  }

  @override
  String get csvDownloaded => 'CSV downloaded';

  @override
  String get cardStatusSettings => 'Card & Status Settings';

  @override
  String get card => 'Card';

  @override
  String get status => 'Status';

  @override
  String get cardNotIssued => '💡No card yet?';

  @override
  String get tourPremium => 'Tour Premium';

  @override
  String get shoppingMileP => 'Shopping Mile P';

  @override
  String flightNotFound(String flightNumber) {
    return 'Flight $flightNumber not found';
  }

  @override
  String get enterFlightNumber => 'Enter flight number';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get scheduleWarning => '⚠️ Schedule changes in some periods';

  @override
  String nLegs(int count) {
    return '$count Legs';
  }

  @override
  String costPerPoint(String price) {
    return '¥$price/P';
  }

  @override
  String get notCalculated => 'Not calculated';

  @override
  String get routeNotSet => 'Route not set';
}
