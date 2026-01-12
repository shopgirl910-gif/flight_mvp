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

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

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

  /// No description provided for @addLeg.
  ///
  /// In en, this message translates to:
  /// **'Add Leg'**
  String get addLeg;

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

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginToSave.
  ///
  /// In en, this message translates to:
  /// **'Please login to save your itinerary.'**
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
  /// **'Miles'**
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

  /// No description provided for @leg.
  ///
  /// In en, this message translates to:
  /// **'Leg'**
  String get leg;

  /// No description provided for @totalFare.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalFare;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost/Point'**
  String get unitPrice;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @airline.
  ///
  /// In en, this message translates to:
  /// **'Airline'**
  String get airline;

  /// No description provided for @flightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get flightNumber;

  /// No description provided for @departure.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get departure;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
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
  /// **'Class'**
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

  /// No description provided for @cardStatusSettings.
  ///
  /// In en, this message translates to:
  /// **'Card & Status Settings'**
  String get cardStatusSettings;

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

  /// No description provided for @cardNotIssued.
  ///
  /// In en, this message translates to:
  /// **'💡No card yet?'**
  String get cardNotIssued;

  /// No description provided for @tourPremium.
  ///
  /// In en, this message translates to:
  /// **'Tour Premium'**
  String get tourPremium;

  /// No description provided for @shoppingMileP.
  ///
  /// In en, this message translates to:
  /// **'Shopping Mile P'**
  String get shoppingMileP;

  /// No description provided for @flightNotFound.
  ///
  /// In en, this message translates to:
  /// **'Flight {flightNumber} not found'**
  String flightNotFound(String flightNumber);

  /// No description provided for @enterFlightNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter flight number'**
  String get enterFlightNumber;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailed;

  /// No description provided for @scheduleWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Schedule changes in some periods'**
  String get scheduleWarning;

  /// No description provided for @nLegs.
  ///
  /// In en, this message translates to:
  /// **'{count} Legs'**
  String nLegs(int count);

  /// No description provided for @costPerPoint.
  ///
  /// In en, this message translates to:
  /// **'¥{price}/P'**
  String costPerPoint(String price);

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
