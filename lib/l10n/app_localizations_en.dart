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
  String get csv => 'CSV';

  @override
  String get share => 'Share';

  @override
  String get addToLog => 'Add to Log';

  @override
  String addedToLog(String title) {
    return 'Added \"$title\" to Flight Log';
  }

  @override
  String get loginRequired => 'Login Required';

  @override
  String get loginToSave => 'Please login to save itineraries.';

  @override
  String get loginToDownload => 'Please login to download CSV.';

  @override
  String get fop => 'FOP';

  @override
  String get pp => 'PP';

  @override
  String get miles => ' miles';

  @override
  String get lsp => 'LSP';

  @override
  String get legs => 'Legs';

  @override
  String get total => 'Total';

  @override
  String get totalFare => 'Total';

  @override
  String get unitPrice => 'Cost';

  @override
  String get costPerPoint => 'Cost/Pt';

  @override
  String get airline => 'Airline';

  @override
  String get flightNumber => 'Flight#';

  @override
  String get departure => 'From';

  @override
  String get arrival => 'To';

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
  String get seatClass => 'Seat Class';

  @override
  String get fareAmount => 'Fare';

  @override
  String get fareAmountYen => 'Fare(¥)';

  @override
  String get date => 'Date';

  @override
  String get select => 'Select';

  @override
  String get card => 'Card';

  @override
  String get status => 'Status';

  @override
  String get shoppingMileP => 'Shopping Mile P';

  @override
  String get notCalculated => 'Not calculated';

  @override
  String get routeNotSet => 'Route not set';

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
  String nLegs(int count) {
    return '$count legs';
  }

  @override
  String get addLeg => 'Add Leg';

  @override
  String get tourPremium => 'Tour Premium';

  @override
  String get shoppingMilePremium => 'Shopping Mile P';

  @override
  String get cardNotIssued => '💡No card yet?';

  @override
  String get cardStatusSettings => '⚙ Card/Status Settings';

  @override
  String get jalCard => 'JAL Card';

  @override
  String get anaCard => 'ANA Card';

  @override
  String get jalStatus => 'JAL Status';

  @override
  String get anaStatus => 'ANA Status';

  @override
  String get deleteConfirm => 'Confirm Delete';

  @override
  String get deleteItineraryConfirm => 'Delete this itinerary?';

  @override
  String get deleted => 'Deleted';

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String dataLoadFailed(String error) {
    return 'Failed to load data: $error';
  }

  @override
  String get reload => 'Reload';

  @override
  String get noSavedItineraries => 'No saved itineraries';

  @override
  String get loginRequiredToSaveItineraries => 'Login required to save itineraries';

  @override
  String get createItineraryInSimulateTab => 'Create an itinerary in Simulate tab and save it';

  @override
  String get loginFromTopRight => 'Login from the button at top right';

  @override
  String get untitled => 'Untitled';

  @override
  String get airportStampRally => 'Airport Stamp Rally';

  @override
  String get conquered => 'Complete!';

  @override
  String conqueredPercent(String percent) {
    return '$percent% Complete';
  }

  @override
  String get checkinAvailable => 'Check-in Available!';

  @override
  String get loginToCheckin => 'Login to Check-in';

  @override
  String get nearestAirport => 'Nearest Airport';

  @override
  String get checkin => 'Check-in';

  @override
  String checkinWithinRadius(String radius) {
    return 'Within ${radius}km';
  }

  @override
  String distanceFromHere(String distance) {
    return '$distance km from here';
  }

  @override
  String get calculatingDistance => 'Calculating distance...';

  @override
  String get gettingLocation => 'Getting location...';

  @override
  String get retry => 'Retry';

  @override
  String get locationPermissionRequired => 'Location permission required';

  @override
  String get enableLocationInSettings => 'Please enable location in settings';

  @override
  String get locationError => 'Location error';

  @override
  String get dataLoadError => 'Data load error';

  @override
  String get checkinError => 'Check-in error';

  @override
  String tooFarFromAirport(String distance, String radius) {
    return 'You are ${distance}km from the airport (must be within ${radius}km)';
  }

  @override
  String checkinSuccess(String airport) {
    return 'Checked in at $airport Airport!';
  }

  @override
  String get loginRequiredForCheckin => 'Login required to save check-in records.\nGo to login screen?';

  @override
  String get goToLogin => 'Login';

  @override
  String nAirports(int count) {
    return '$count airports';
  }

  @override
  String get regionHokkaido => 'Hokkaido';

  @override
  String get regionTohoku => 'Tohoku';

  @override
  String get regionKanto => 'Kanto';

  @override
  String get regionChubu => 'Chubu';

  @override
  String get regionKansai => 'Kansai';

  @override
  String get regionKinki => 'Kinki';

  @override
  String get regionChugoku => 'Chugoku';

  @override
  String get regionShikoku => 'Shikoku';

  @override
  String get regionKyushu => 'Kyushu';

  @override
  String get regionOkinawa => 'Okinawa';
}
