import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MRP - Mileage Run Planner'**
  String get appTitle;

  /// No description provided for @tabSimulate.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get tabSimulate;

  /// No description provided for @tabLog.
  ///
  /// In en, this message translates to:
  /// **'Flight Log'**
  String get tabLog;

  /// No description provided for @tabQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get tabQuiz;

  /// No description provided for @tabCheckin.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get tabCheckin;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'guest'**
  String get guest;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @csv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get csv;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @addToLog.
  ///
  /// In en, this message translates to:
  /// **'Add to Log'**
  String get addToLog;

  /// No description provided for @addedToLog.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to Flight Log'**
  String addedToLog(String title);

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginToSave.
  ///
  /// In en, this message translates to:
  /// **'Please login to save itineraries.'**
  String get loginToSave;

  /// No description provided for @loginToDownload.
  ///
  /// In en, this message translates to:
  /// **'Please login to download CSV.'**
  String get loginToDownload;

  /// No description provided for @fop.
  ///
  /// In en, this message translates to:
  /// **'FOP'**
  String get fop;

  /// No description provided for @pp.
  ///
  /// In en, this message translates to:
  /// **'PP'**
  String get pp;

  /// No description provided for @miles.
  ///
  /// In en, this message translates to:
  /// **' miles'**
  String get miles;

  /// No description provided for @lsp.
  ///
  /// In en, this message translates to:
  /// **'LSP'**
  String get lsp;

  /// No description provided for @legs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get legs;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @totalFare.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalFare;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get unitPrice;

  /// No description provided for @costPerPoint.
  ///
  /// In en, this message translates to:
  /// **'Cost/Pt'**
  String get costPerPoint;

  /// No description provided for @airline.
  ///
  /// In en, this message translates to:
  /// **'Airline'**
  String get airline;

  /// No description provided for @flightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight#'**
  String get flightNumber;

  /// No description provided for @departure.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get departure;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get arrival;

  /// No description provided for @departureAirport.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get departureAirport;

  /// No description provided for @arrivalAirport.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get arrivalAirport;

  /// No description provided for @departureTime.
  ///
  /// In en, this message translates to:
  /// **'Dep Time'**
  String get departureTime;

  /// No description provided for @arrivalTime.
  ///
  /// In en, this message translates to:
  /// **'Arr Time'**
  String get arrivalTime;

  /// No description provided for @fareType.
  ///
  /// In en, this message translates to:
  /// **'Fare Type'**
  String get fareType;

  /// No description provided for @seatClass.
  ///
  /// In en, this message translates to:
  /// **'Seat Class'**
  String get seatClass;

  /// No description provided for @fareAmount.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fareAmount;

  /// No description provided for @fareAmountYen.
  ///
  /// In en, this message translates to:
  /// **'Fare(¥)'**
  String get fareAmountYen;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @shoppingMileP.
  ///
  /// In en, this message translates to:
  /// **'Shopping Mile P'**
  String get shoppingMileP;

  /// No description provided for @notCalculated.
  ///
  /// In en, this message translates to:
  /// **'Not calculated'**
  String get notCalculated;

  /// No description provided for @routeNotSet.
  ///
  /// In en, this message translates to:
  /// **'Route not set'**
  String get routeNotSet;

  /// No description provided for @noLegsToSave.
  ///
  /// In en, this message translates to:
  /// **'No legs to save'**
  String get noLegsToSave;

  /// No description provided for @noLegsToDownload.
  ///
  /// In en, this message translates to:
  /// **'No legs to download'**
  String get noLegsToDownload;

  /// No description provided for @savedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved \"{title}\"'**
  String savedSuccess(String title);

  /// No description provided for @csvDownloaded.
  ///
  /// In en, this message translates to:
  /// **'CSV downloaded'**
  String get csvDownloaded;

  /// No description provided for @nLegs.
  ///
  /// In en, this message translates to:
  /// **'{count} legs'**
  String nLegs(int count);

  /// No description provided for @addLeg.
  ///
  /// In en, this message translates to:
  /// **'Add Leg'**
  String get addLeg;

  /// No description provided for @tourPremium.
  ///
  /// In en, this message translates to:
  /// **'Tour Premium'**
  String get tourPremium;

  /// No description provided for @shoppingMilePremium.
  ///
  /// In en, this message translates to:
  /// **'Shopping Mile P'**
  String get shoppingMilePremium;

  /// No description provided for @cardNotIssued.
  ///
  /// In en, this message translates to:
  /// **'💡No card yet?'**
  String get cardNotIssued;

  /// No description provided for @cardStatusSettings.
  ///
  /// In en, this message translates to:
  /// **'⚙ Card/Status Settings'**
  String get cardStatusSettings;

  /// No description provided for @jalCard.
  ///
  /// In en, this message translates to:
  /// **'JAL Card'**
  String get jalCard;

  /// No description provided for @anaCard.
  ///
  /// In en, this message translates to:
  /// **'ANA Card'**
  String get anaCard;

  /// No description provided for @jalStatus.
  ///
  /// In en, this message translates to:
  /// **'JAL Status'**
  String get jalStatus;

  /// No description provided for @anaStatus.
  ///
  /// In en, this message translates to:
  /// **'ANA Status'**
  String get anaStatus;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get deleteConfirm;

  /// No description provided for @deleteItineraryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this itinerary?'**
  String get deleteItineraryConfirm;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @dataLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data: {error}'**
  String dataLoadFailed(String error);

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @noSavedItineraries.
  ///
  /// In en, this message translates to:
  /// **'No saved itineraries'**
  String get noSavedItineraries;

  /// No description provided for @loginRequiredToSaveItineraries.
  ///
  /// In en, this message translates to:
  /// **'Login required to save itineraries'**
  String get loginRequiredToSaveItineraries;

  /// No description provided for @createItineraryInSimulateTab.
  ///
  /// In en, this message translates to:
  /// **'Create an itinerary in Simulate tab and save it'**
  String get createItineraryInSimulateTab;

  /// No description provided for @loginFromTopRight.
  ///
  /// In en, this message translates to:
  /// **'Login from the button at top right'**
  String get loginFromTopRight;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @airportStampRally.
  ///
  /// In en, this message translates to:
  /// **'Airport Stamp Rally'**
  String get airportStampRally;

  /// No description provided for @conquered.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get conquered;

  /// No description provided for @conqueredPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Complete'**
  String conqueredPercent(String percent);

  /// No description provided for @checkinAvailable.
  ///
  /// In en, this message translates to:
  /// **'Check-in Available!'**
  String get checkinAvailable;

  /// No description provided for @loginToCheckin.
  ///
  /// In en, this message translates to:
  /// **'Login to Check-in'**
  String get loginToCheckin;

  /// No description provided for @nearestAirport.
  ///
  /// In en, this message translates to:
  /// **'Nearest Airport'**
  String get nearestAirport;

  /// No description provided for @checkin.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkin;

  /// No description provided for @checkinWithinRadius.
  ///
  /// In en, this message translates to:
  /// **'Within {radius}km'**
  String checkinWithinRadius(String radius);

  /// No description provided for @distanceFromHere.
  ///
  /// In en, this message translates to:
  /// **'{distance} km from here'**
  String distanceFromHere(String distance);

  /// No description provided for @calculatingDistance.
  ///
  /// In en, this message translates to:
  /// **'Calculating distance...'**
  String get calculatingDistance;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get gettingLocation;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission required'**
  String get locationPermissionRequired;

  /// No description provided for @enableLocationInSettings.
  ///
  /// In en, this message translates to:
  /// **'Please enable location in settings'**
  String get enableLocationInSettings;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Location error'**
  String get locationError;

  /// No description provided for @dataLoadError.
  ///
  /// In en, this message translates to:
  /// **'Data load error'**
  String get dataLoadError;

  /// No description provided for @checkinError.
  ///
  /// In en, this message translates to:
  /// **'Check-in error'**
  String get checkinError;

  /// No description provided for @tooFarFromAirport.
  ///
  /// In en, this message translates to:
  /// **'You are {distance}km from the airport (must be within {radius}km)'**
  String tooFarFromAirport(String distance, String radius);

  /// No description provided for @checkinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {airport} Airport!'**
  String checkinSuccess(String airport);

  /// No description provided for @loginRequiredForCheckin.
  ///
  /// In en, this message translates to:
  /// **'Login required to save check-in records.\nGo to login screen?'**
  String get loginRequiredForCheckin;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get goToLogin;

  /// No description provided for @nAirports.
  ///
  /// In en, this message translates to:
  /// **'{count} airports'**
  String nAirports(int count);

  /// No description provided for @regionHokkaido.
  ///
  /// In en, this message translates to:
  /// **'Hokkaido'**
  String get regionHokkaido;

  /// No description provided for @regionTohoku.
  ///
  /// In en, this message translates to:
  /// **'Tohoku'**
  String get regionTohoku;

  /// No description provided for @regionKanto.
  ///
  /// In en, this message translates to:
  /// **'Kanto'**
  String get regionKanto;

  /// No description provided for @regionChubu.
  ///
  /// In en, this message translates to:
  /// **'Chubu'**
  String get regionChubu;

  /// No description provided for @regionKansai.
  ///
  /// In en, this message translates to:
  /// **'Kansai'**
  String get regionKansai;

  /// No description provided for @regionKinki.
  ///
  /// In en, this message translates to:
  /// **'Kinki'**
  String get regionKinki;

  /// No description provided for @regionChugoku.
  ///
  /// In en, this message translates to:
  /// **'Chugoku'**
  String get regionChugoku;

  /// No description provided for @regionShikoku.
  ///
  /// In en, this message translates to:
  /// **'Shikoku'**
  String get regionShikoku;

  /// No description provided for @regionKyushu.
  ///
  /// In en, this message translates to:
  /// **'Kyushu'**
  String get regionKyushu;

  /// No description provided for @regionOkinawa.
  ///
  /// In en, this message translates to:
  /// **'Okinawa'**
  String get regionOkinawa;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
