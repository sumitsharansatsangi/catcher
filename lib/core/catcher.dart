import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:catcher/core/application_profile_manager.dart';
import 'package:catcher/core/catcher_screenshot_manager.dart';
import 'package:catcher/core/offline_report_queue.dart';
import 'package:catcher/mode/report_mode_action_confirmed.dart';
import 'package:catcher/model/application_profile.dart';
import 'package:catcher/model/breadcrumb.dart';
import 'package:catcher/model/catcher_options.dart';
import 'package:catcher/model/localization_options.dart';
import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:catcher/model/report_mode.dart';
import 'package:catcher/model/report_severity.dart';
import 'package:catcher/utils/catcher_error_widget.dart';
import 'package:catcher/utils/catcher_logger.dart';
import 'package:catcher/utils/report_redactor.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Catcher implements ReportModeAction {
  static late Catcher _instance;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Root widget which will be ran
  final Widget? rootWidget;

  ///Run app function which will be ran
  final void Function()? runAppFunction;

  /// Instance of catcher config used in release mode
  CatcherOptions? releaseConfig;

  /// Instance of catcher config used in debug mode
  CatcherOptions? debugConfig;

  /// Instance of catcher config used in profile mode
  CatcherOptions? profileConfig;

  /// Should catcher logs be enabled
  final bool enableLogger;

  /// Should catcher run WidgetsFlutterBinding.ensureInitialized() during
  /// initialization.
  final bool ensureInitialized;

  late CatcherOptions _currentConfig;
  late CatcherLogger _logger;
  late CatcherScreenshotManager screenshotManager;
  late OfflineReportQueue _offlineReportQueue;
  final Map<String, dynamic> _deviceParameters = <String, dynamic>{};
  final Map<String, dynamic> _applicationParameters = <String, dynamic>{};
  final Map<String, dynamic> _tags = <String, dynamic>{};
  final Map<String, dynamic> _extras = <String, dynamic>{};
  final Map<String, dynamic> _user = <String, dynamic>{};
  final List<Breadcrumb> _breadcrumbs = <Breadcrumb>[];
  final List<Report> _cachedReports = [];
  final Map<DateTime, String> _reportsOccurrenceMap = {};
  LocalizationOptions? _localizationOptions;

  /// Instance of navigator key
  static GlobalKey<NavigatorState>? get navigatorKey {
    return _navigatorKey;
  }

  /// Builds catcher instance
  Catcher({
    this.rootWidget,
    this.runAppFunction,
    this.releaseConfig,
    this.debugConfig,
    this.profileConfig,
    this.enableLogger = true,
    this.ensureInitialized = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : assert(
         rootWidget != null || runAppFunction != null,
         'You need to provide rootWidget or runAppFunction',
       ) {
    _configure(navigatorKey);
  }

  void _configure(GlobalKey<NavigatorState>? navigatorKey) {
    _instance = this;
    _configureNavigatorKey(navigatorKey);
    _setupCurrentConfig();
    _configureLogger();
    _setupOfflineQueue();
    unawaited(_setupErrorHooks());
    _setupScreenshotManager();
    _setupReportModeActionInReportMode();

    _loadDeviceInfo();
    _loadApplicationInfo();

    if (_currentConfig.handlers.isEmpty) {
      _logger.warning(
        'Handlers list is empty. Configure at least one handler to '
        'process error reports.',
      );
    } else {
      _logger.fine('Catcher configured successfully.');
    }
  }

  void _configureNavigatorKey(GlobalKey<NavigatorState>? navigatorKey) {
    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    } else {
      _navigatorKey = GlobalKey<NavigatorState>();
    }
  }

  void _setupCurrentConfig() {
    switch (ApplicationProfileManager.getApplicationProfile()) {
      case ApplicationProfile.release:
        {
          if (releaseConfig != null) {
            _currentConfig = releaseConfig!;
          } else {
            _currentConfig = CatcherOptions.getDefaultReleaseOptions();
          }
          break;
        }
      case ApplicationProfile.debug:
        {
          if (debugConfig != null) {
            _currentConfig = debugConfig!;
          } else {
            _currentConfig = CatcherOptions.getDefaultDebugOptions();
          }
          break;
        }
      case ApplicationProfile.profile:
        {
          if (profileConfig != null) {
            _currentConfig = profileConfig!;
          } else {
            _currentConfig = CatcherOptions.getDefaultProfileOptions();
          }
          break;
        }
    }
  }

  ///Update config after initialization
  void updateConfig({
    CatcherOptions? debugConfig,
    CatcherOptions? profileConfig,
    CatcherOptions? releaseConfig,
  }) {
    if (debugConfig != null) {
      this.debugConfig = debugConfig;
    }
    if (profileConfig != null) {
      this.profileConfig = profileConfig;
    }
    if (releaseConfig != null) {
      this.releaseConfig = releaseConfig;
    }
    _setupCurrentConfig();
    _setupScreenshotManager();
    _setupReportModeActionInReportMode();
    _configureLogger();
    _setupOfflineQueue();
    _localizationOptions = null;
  }

  void _setupOfflineQueue() {
    _offlineReportQueue = OfflineReportQueue(
      _currentConfig.offlineReportQueueOptions,
      _logger,
    );
    unawaited(
      _offlineReportQueue.flush(_currentConfig.handlers, _getContext()),
    );
  }

  void _setupReportModeActionInReportMode() {
    _currentConfig.reportMode.setReportModeAction(this);
    _currentConfig.explicitExceptionReportModesMap.forEach(
      (error, reportMode) {
        reportMode.setReportModeAction(this);
      },
    );
  }

  void _setupLocalizationsOptionsInReportMode() {
    _currentConfig.reportMode.setLocalizationOptions(_localizationOptions);
    _currentConfig.explicitExceptionReportModesMap.forEach(
      (error, reportMode) {
        reportMode.setLocalizationOptions(_localizationOptions);
      },
    );
  }

  void _setupLocalizationsOptionsInReportsHandler() {
    _currentConfig.handlers.forEach((handler) {
      handler.setLocalizationOptions(_localizationOptions);
    });
  }

  Future<void> _setupErrorHooks() async {
    FlutterError.onError = (details) async {
      await _reportError(
        details.exception,
        details.stack,
        errorDetails: details,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(_reportError(error, stack));
      return true;
    };

    ///Web doesn't have Isolate error listener support
    if (!ApplicationProfileManager.isWeb()) {
      Isolate.current.addErrorListener(
        RawReceivePort((dynamic pair) async {
          final isolateError = pair as List<dynamic>;
          await _reportError(
            isolateError.first.toString(),
            isolateError.last.toString(),
          );
        }).sendPort,
      );
    }

    if (rootWidget != null) {
      // _runZonedGuarded(() {
      //   runApp(rootWidget!);
      // });
      _initWidgetsBinding();
      runApp(rootWidget!);
    } else if (runAppFunction != null) {
      // _runZonedGuarded(() {
      //   runAppFunction!();
      // });
      _initWidgetsBinding();
      runAppFunction!();
    } else {
      throw ArgumentError('Provide rootWidget or runAppFunction to Catcher.');
    }
  }

  void _initWidgetsBinding() {
    if (ensureInitialized) {
      WidgetsFlutterBinding.ensureInitialized();
    }
  }

  void _configureLogger() {
    if (_currentConfig.logger != null) {
      _logger = _currentConfig.logger!;
    } else {
      _logger = CatcherLogger();
    }
    if (enableLogger) {
      _logger.setup();
    }

    _currentConfig.handlers.forEach((handler) {
      handler.logger = _logger;
    });
  }

  void _loadDeviceInfo() {
    final deviceInfo = DeviceInfoPlugin();
    if (ApplicationProfileManager.isWeb()) {
      unawaited(
        deviceInfo.webBrowserInfo.then((webBrowserInfo) {
          _loadWebParameters(webBrowserInfo);
          _removeExcludedParameters();
        }),
      );
    } else if (ApplicationProfileManager.isLinux()) {
      unawaited(
        deviceInfo.linuxInfo.then((linuxDeviceInfo) {
          _loadLinuxParameters(linuxDeviceInfo);
          _removeExcludedParameters();
        }),
      );
    } else if (ApplicationProfileManager.isWindows()) {
      unawaited(
        deviceInfo.windowsInfo.then((windowsInfo) {
          _loadWindowsParameters(windowsInfo);
          _removeExcludedParameters();
        }),
      );
    } else if (ApplicationProfileManager.isMacOS()) {
      unawaited(
        deviceInfo.macOsInfo.then((macOsDeviceInfo) {
          _loadMacOSParameters(macOsDeviceInfo);
          _removeExcludedParameters();
        }),
      );
    } else if (ApplicationProfileManager.isAndroid()) {
      unawaited(
        deviceInfo.androidInfo.then((androidInfo) {
          _loadAndroidParameters(androidInfo);
          _removeExcludedParameters();
        }),
      );
    } else if (ApplicationProfileManager.isIos()) {
      unawaited(
        deviceInfo.iosInfo.then((iosInfo) {
          _loadIosParameters(iosInfo);
          _removeExcludedParameters();
        }),
      );
    } else {
      _logger.info("Couldn't load device info for unsupported device type.");
    }
  }

  ///Remove excluded parameters from device parameters.
  void _removeExcludedParameters() {
    _currentConfig.excludedParameters.forEach(_deviceParameters.remove);
  }

  void _loadLinuxParameters(LinuxDeviceInfo linuxDeviceInfo) {
    try {
      _deviceParameters['name'] = linuxDeviceInfo.name;
      _deviceParameters['version'] = linuxDeviceInfo.version;
      _deviceParameters['id'] = linuxDeviceInfo.id;
      _deviceParameters['idLike'] = linuxDeviceInfo.idLike;
      _deviceParameters['versionCodename'] = linuxDeviceInfo.versionCodename;
      _deviceParameters['versionId'] = linuxDeviceInfo.versionId;
      _deviceParameters['prettyName'] = linuxDeviceInfo.prettyName;
      _deviceParameters['buildId'] = linuxDeviceInfo.buildId;
      _deviceParameters['variant'] = linuxDeviceInfo.variant;
      _deviceParameters['variantId'] = linuxDeviceInfo.variantId;
      _deviceParameters['machineId'] = linuxDeviceInfo.machineId;
    } on Object catch (exception) {
      _logger.warning('Load Linux parameters failed: $exception');
    }
  }

  void _loadMacOSParameters(MacOsDeviceInfo macOsDeviceInfo) {
    try {
      _deviceParameters['computerName'] = macOsDeviceInfo.computerName;
      _deviceParameters['hostName'] = macOsDeviceInfo.hostName;
      _deviceParameters['arch'] = macOsDeviceInfo.arch;
      _deviceParameters['model'] = macOsDeviceInfo.model;
      _deviceParameters['kernelVersion'] = macOsDeviceInfo.kernelVersion;
      _deviceParameters['majorVersion'] = macOsDeviceInfo.majorVersion;
      _deviceParameters['minorVersion'] = macOsDeviceInfo.minorVersion;
      _deviceParameters['patchVersion'] = macOsDeviceInfo.patchVersion;
      _deviceParameters['osRelease'] = macOsDeviceInfo.osRelease;
      _deviceParameters['activeCPUs'] = macOsDeviceInfo.activeCPUs;
      _deviceParameters['memorySize'] = macOsDeviceInfo.memorySize;
      _deviceParameters['cpuFrequency'] = macOsDeviceInfo.cpuFrequency;
      _deviceParameters['systemGUID'] = macOsDeviceInfo.systemGUID;
    } on Object catch (exception) {
      _logger.warning('Load MacOS parameters failed: $exception');
    }
  }

  void _loadWindowsParameters(WindowsDeviceInfo windowsDeviceInfo) {
    try {
      _deviceParameters['computerName'] = windowsDeviceInfo.computerName;
      _deviceParameters['numberOfCores'] = windowsDeviceInfo.numberOfCores;
      _deviceParameters['systemMemoryInMegabytes'] =
          windowsDeviceInfo.systemMemoryInMegabytes;
      _deviceParameters['majorVersion'] = windowsDeviceInfo.majorVersion;
      _deviceParameters['minorVersion'] = windowsDeviceInfo.minorVersion;
      _deviceParameters['buildNumber'] = windowsDeviceInfo.buildNumber;
      _deviceParameters['platformId'] = windowsDeviceInfo.platformId;
      _deviceParameters['csdVersion'] = windowsDeviceInfo.csdVersion;
      _deviceParameters['servicePackMajor'] =
          windowsDeviceInfo.servicePackMajor;
      _deviceParameters['servicePackMinor'] =
          windowsDeviceInfo.servicePackMinor;
      _deviceParameters['suitMask'] = windowsDeviceInfo.suitMask;
      _deviceParameters['productType'] = windowsDeviceInfo.productType;
      _deviceParameters['reserved'] = windowsDeviceInfo.reserved;
      _deviceParameters['buildLab'] = windowsDeviceInfo.buildLab;
      _deviceParameters['buildLabEx'] = windowsDeviceInfo.buildLabEx;
      _deviceParameters['digitalProductId'] =
          windowsDeviceInfo.digitalProductId;
      _deviceParameters['displayVersion'] = windowsDeviceInfo.displayVersion;
      _deviceParameters['editionId'] = windowsDeviceInfo.editionId;
      _deviceParameters['installDate'] = windowsDeviceInfo.installDate;
      _deviceParameters['productId'] = windowsDeviceInfo.productId;
      _deviceParameters['productName'] = windowsDeviceInfo.productName;
      _deviceParameters['registeredOwner'] = windowsDeviceInfo.registeredOwner;
      _deviceParameters['releaseId'] = windowsDeviceInfo.releaseId;
      _deviceParameters['deviceId'] = windowsDeviceInfo.deviceId;
    } on Object catch (exception) {
      _logger.warning('Load Windows parameters failed: $exception');
    }
  }

  void _loadWebParameters(WebBrowserInfo webBrowserInfo) {
    try {
      _deviceParameters['language'] = webBrowserInfo.language;
      _deviceParameters['appCodeName'] = webBrowserInfo.appCodeName;
      _deviceParameters['appName'] = webBrowserInfo.appName;
      _deviceParameters['appVersion'] = webBrowserInfo.appVersion;
      _deviceParameters['browserName'] = webBrowserInfo.browserName.toString();
      _deviceParameters['deviceMemory'] = webBrowserInfo.deviceMemory;
      _deviceParameters['hardwareConcurrency'] =
          webBrowserInfo.hardwareConcurrency;
      _deviceParameters['languages'] = webBrowserInfo.languages;
      _deviceParameters['maxTouchPoints'] = webBrowserInfo.maxTouchPoints;
      _deviceParameters['platform'] = webBrowserInfo.platform;
      _deviceParameters['product'] = webBrowserInfo.product;
      _deviceParameters['productSub'] = webBrowserInfo.productSub;
      _deviceParameters['userAgent'] = webBrowserInfo.userAgent;
      _deviceParameters['vendor'] = webBrowserInfo.vendor;
      _deviceParameters['vendorSub'] = webBrowserInfo.vendorSub;
    } on Object catch (exception) {
      _logger.warning('Load Web parameters failed: $exception');
    }
  }

  void _loadAndroidParameters(AndroidDeviceInfo androidDeviceInfo) {
    try {
      _deviceParameters['id'] = androidDeviceInfo.id;
      _deviceParameters['board'] = androidDeviceInfo.board;
      _deviceParameters['bootloader'] = androidDeviceInfo.bootloader;
      _deviceParameters['brand'] = androidDeviceInfo.brand;
      _deviceParameters['device'] = androidDeviceInfo.device;
      _deviceParameters['display'] = androidDeviceInfo.display;
      _deviceParameters['fingerprint'] = androidDeviceInfo.fingerprint;
      _deviceParameters['hardware'] = androidDeviceInfo.hardware;
      _deviceParameters['host'] = androidDeviceInfo.host;
      _deviceParameters['isPhysicalDevice'] =
          androidDeviceInfo.isPhysicalDevice;
      _deviceParameters['manufacturer'] = androidDeviceInfo.manufacturer;
      _deviceParameters['model'] = androidDeviceInfo.model;
      _deviceParameters['product'] = androidDeviceInfo.product;
      _deviceParameters['tags'] = androidDeviceInfo.tags;
      _deviceParameters['type'] = androidDeviceInfo.type;
      _deviceParameters['versionBaseOs'] = androidDeviceInfo.version.baseOS;
      _deviceParameters['versionCodename'] = androidDeviceInfo.version.codename;
      _deviceParameters['versionIncremental'] =
          androidDeviceInfo.version.incremental;
      _deviceParameters['versionPreviewSdk'] =
          androidDeviceInfo.version.previewSdkInt;
      _deviceParameters['versionRelease'] = androidDeviceInfo.version.release;
      _deviceParameters['versionSdk'] = androidDeviceInfo.version.sdkInt;
      _deviceParameters['versionSecurityPatch'] =
          androidDeviceInfo.version.securityPatch;
      _deviceParameters['systemFeatures'] = androidDeviceInfo.systemFeatures;
    } on Object catch (exception) {
      _logger.warning('Load Android parameters failed: $exception');
    }
  }

  void _loadIosParameters(IosDeviceInfo iosInfo) {
    try {
      _deviceParameters['model'] = iosInfo.model;
      _deviceParameters['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
      _deviceParameters['name'] = iosInfo.name;
      _deviceParameters['identifierForVendor'] = iosInfo.identifierForVendor;
      _deviceParameters['localizedModel'] = iosInfo.localizedModel;
      _deviceParameters['systemName'] = iosInfo.systemName;
      _deviceParameters['utsnameVersion'] = iosInfo.utsname.version;
      _deviceParameters['utsnameRelease'] = iosInfo.utsname.release;
      _deviceParameters['utsnameMachine'] = iosInfo.utsname.machine;
      _deviceParameters['utsnameNodename'] = iosInfo.utsname.nodename;
      _deviceParameters['utsnameSysname'] = iosInfo.utsname.sysname;
    } on Object catch (exception) {
      _logger.warning('Load iOS parameters failed: $exception');
    }
  }

  void _loadApplicationInfo() {
    _applicationParameters['environment'] =
        ApplicationProfileManager.getApplicationProfile().name;

    unawaited(
      PackageInfo.fromPlatform().then((packageInfo) {
        _applicationParameters['version'] = packageInfo.version;
        _applicationParameters['appName'] = packageInfo.appName;
        _applicationParameters['buildNumber'] = packageInfo.buildNumber;
        _applicationParameters['packageName'] = packageInfo.packageName;
      }),
    );
  }

  ///We need to setup localizations lazily because context needed to setup these
  ///localizations can be used after app was build for the first time.
  void _setupLocalization() {
    var locale = const Locale('en', 'US');
    if (_isContextValid()) {
      final context = _getContext();
      if (context != null) {
        locale = Localizations.localeOf(context);
      }
      if (_currentConfig.localizationOptions.isNotEmpty) {
        for (final options in _currentConfig.localizationOptions) {
          if (options.languageCode.toLowerCase() ==
              locale.languageCode.toLowerCase()) {
            _localizationOptions = options;
          }
        }
      }
    }

    _localizationOptions ??= _getDefaultLocalizationOptionsForLanguage(
      locale.languageCode,
    );
    _setupLocalizationsOptionsInReportMode();
    _setupLocalizationsOptionsInReportsHandler();
  }

  LocalizationOptions _getDefaultLocalizationOptionsForLanguage(
    String language,
  ) {
    switch (language.toLowerCase()) {
      case 'en':
        return LocalizationOptions.buildDefaultEnglishOptions();
      case 'zh':
        return LocalizationOptions.buildDefaultChineseOptions();
      case 'hi':
        return LocalizationOptions.buildDefaultHindiOptions();
      case 'es':
        return LocalizationOptions.buildDefaultSpanishOptions();
      case 'ms':
        return LocalizationOptions.buildDefaultMalayOptions();
      case 'ru':
        return LocalizationOptions.buildDefaultRussianOptions();
      case 'pt':
        return LocalizationOptions.buildDefaultPortugueseOptions();
      case 'fr':
        return LocalizationOptions.buildDefaultFrenchOptions();
      case 'pl':
        return LocalizationOptions.buildDefaultPolishOptions();
      case 'it':
        return LocalizationOptions.buildDefaultItalianOptions();
      case 'ko':
        return LocalizationOptions.buildDefaultKoreanOptions();
      case 'nl':
        return LocalizationOptions.buildDefaultDutchOptions();
      case 'de':
        return LocalizationOptions.buildDefaultGermanOptions();
      default:
        return LocalizationOptions.buildDefaultEnglishOptions();
    }
  }

  ///Setup screenshot manager's screenshots path.
  void _setupScreenshotManager() {
    screenshotManager = CatcherScreenshotManager(_logger);
    final screenshotsPath = _currentConfig.screenshotsPath;
    if (!ApplicationProfileManager.isWeb() && screenshotsPath.isEmpty) {
      _logger.warning("Screenshots path is empty. Screenshots won't work.");
    }
    screenshotManager.path = screenshotsPath;
  }

  /// Report checked error (error caught in try-catch block). Catcher will treat
  /// this as normal exception and pass it to handlers.
  static void reportCheckedError(
    dynamic error,
    dynamic stackTrace, {
    ReportSeverity severity = ReportSeverity.error,
  }) {
    dynamic errorValue = error;
    dynamic stackTraceValue = stackTrace;
    errorValue ??= 'undefined error';
    stackTraceValue ??= StackTrace.current;
    unawaited(_instance._reportError(error, stackTrace, severity: severity));
  }

  static void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    _instance._breadcrumbs.add(
      Breadcrumb(message, category: category, data: data),
    );
    if (_instance._breadcrumbs.length > 100) {
      _instance._breadcrumbs.removeAt(0);
    }
  }

  static void clearBreadcrumbs() {
    _instance._breadcrumbs.clear();
  }

  static void setTag(String key, dynamic value) {
    _instance._tags[key] = value;
  }

  static void removeTag(String key) {
    _instance._tags.remove(key);
  }

  static void setExtra(String key, dynamic value) {
    _instance._extras[key] = value;
  }

  static void removeExtra(String key) {
    _instance._extras.remove(key);
  }

  static void setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    _instance._user
      ..clear()
      ..addAll(data);
    if (id != null) {
      _instance._user['id'] = id;
    }
    if (email != null) {
      _instance._user['email'] = email;
    }
    if (username != null) {
      _instance._user['username'] = username;
    }
  }

  static void clearUser() {
    _instance._user.clear();
  }

  Future<void> _reportError(
    dynamic error,
    dynamic stackTrace, {
    FlutterErrorDetails? errorDetails,
    ReportSeverity? severity,
  }) async {
    if (errorDetails?.silent ?? false) {
      _logger.info(
        'Report error skipped for error: $error. HandleSilentError is false.',
      );
      return;
    }

    if (_localizationOptions == null) {
      _logger.info('Setup localization lazily!');
      _setupLocalization();
    }

    _cleanPastReportsOccurrences();

    File? screenshot;
    final screenshotOptions = _currentConfig.screenshotOptions;
    if (!ApplicationProfileManager.isWeb() && screenshotOptions.enabled) {
      screenshot = await screenshotManager.captureAndSave(
        pixelRatio: screenshotOptions.pixelRatio,
        delay: screenshotOptions.delay,
        maxBytes: screenshotOptions.maxBytes,
        redactedAreas: screenshotOptions.redactedAreas,
      );
    }

    final redactor = ReportRedactor(_currentConfig.redactionOptions);
    final redactedError = redactor.redact(error).toString();
    final redactedStackTrace = redactor.redact(stackTrace).toString();

    final report = Report(
      redactedError,
      redactedStackTrace,
      DateTime.now(),
      redactor.redactMap(_deviceParameters),
      redactor.redactMap(_applicationParameters),
      redactor.redactMap(_currentConfig.customParameters),
      errorDetails,
      _getPlatformType(),
      screenshot,
      severity: severity ?? _currentConfig.defaultSeverity,
      breadcrumbs: _breadcrumbs
          .map(
            (breadcrumb) => Breadcrumb(
              redactor.redact(breadcrumb.message).toString(),
              timestamp: breadcrumb.timestamp,
              category: breadcrumb.category,
              data: redactor.redactMap(breadcrumb.data),
            ),
          )
          .toList(),
      tags: redactor.redactMap(_tags),
      extras: redactor.redactMap(_extras),
      user: redactor.redactMap(_user),
    );

    if (_isReportInReportsOccurrencesMap(report)) {
      _logger.fine(
        "Error: '$error' has been skipped to due to duplication occurrence "
        'within ${_currentConfig.reportOccurrenceTimeout} ms.',
      );
      return;
    }

    if (_currentConfig.filterFunction != null &&
        !_currentConfig.filterFunction!(report)) {
      _logger.fine(
        "Error: '$error' has been filtered from Catcher logs. Report will be "
        'skipped.',
      );
      return;
    }
    _cachedReports.add(report);
    var reportMode = _getReportModeFromExplicitExceptionReportModeMap(error);
    if (reportMode != null) {
      _logger.info('Using explicit report mode for error');
    } else {
      reportMode = _currentConfig.reportMode;
    }
    if (!isReportModeSupportedInPlatform(report, reportMode)) {
      _logger.warning(
        '$reportMode in not supported for ${report.platformType.name}'
        'platform',
      );
      return;
    }

    _addReportInReportsOccurencesMap(report);

    if (reportMode.isContextRequired()) {
      if (_isContextValid()) {
        reportMode.requestAction(report, _getContext());
      } else {
        _logger.warning(
          "Couldn't use report mode because you didn't provide navigator key."
          ' Add navigator key to use this report mode.',
        );
      }
    } else {
      reportMode.requestAction(report, null);
    }
  }

  /// Check if given report mode is enabled in current platform. Only supported
  /// handlers in given report mode can be used.
  bool isReportModeSupportedInPlatform(Report report, ReportMode reportMode) {
    if (reportMode.getSupportedPlatforms().isEmpty) {
      return false;
    }
    return reportMode.getSupportedPlatforms().contains(report.platformType);
  }

  ReportMode? _getReportModeFromExplicitExceptionReportModeMap(dynamic error) {
    final errorName = error != null ? error.toString().toLowerCase() : '';
    ReportMode? reportMode;
    _currentConfig.explicitExceptionReportModesMap.forEach((key, value) {
      if (errorName.contains(key.toLowerCase())) {
        reportMode = value;
        return;
      }
    });
    return reportMode;
  }

  ReportHandler? _getReportHandlerFromExplicitExceptionHandlerMap(
    dynamic error,
  ) {
    final errorName = error != null ? error.toString().toLowerCase() : '';
    ReportHandler? reportHandler;
    _currentConfig.explicitExceptionHandlersMap.forEach((key, value) {
      if (errorName.contains(key.toLowerCase())) {
        reportHandler = value;
        return;
      }
    });
    return reportHandler;
  }

  @override
  void onActionConfirmed(Report report) {
    final reportHandler = _getReportHandlerFromExplicitExceptionHandlerMap(
      report.error,
    );
    if (reportHandler != null) {
      _logger.info('Using explicit report handler');
      _handleReport(report, reportHandler);
      return;
    }

    for (final handler in _currentConfig.handlers) {
      _handleReport(report, handler);
    }
  }

  void _handleReport(Report report, ReportHandler reportHandler) {
    if (!isReportHandlerSupportedInPlatform(report, reportHandler)) {
      _logger.warning(
        '$reportHandler in not supported for '
        '${report.platformType.name} platform',
      );
      return;
    }

    if (reportHandler.isContextRequired() && !_isContextValid()) {
      _logger.warning(
        "Couldn't use report handler because you didn't provide navigator key."
        ' Add navigator key to use this report mode',
      );
      return;
    }

    unawaited(
      reportHandler
          .handle(report, _getContext())
          .catchError((dynamic handlerError) {
            _logger.warning(
              'Error occurred in $reportHandler: $handlerError',
            );
            return true;
          })
          .then((result) {
            _logger.info('${report.runtimeType} result: $result');
            if (!result) {
              _logger.warning('$reportHandler failed to report error');
              unawaited(_offlineReportQueue.enqueue(report, reportHandler));
            } else {
              _cachedReports.remove(report);
              unawaited(
                _offlineReportQueue.flush(
                  _currentConfig.handlers,
                  _getContext(),
                ),
              );
            }
          })
          .timeout(
            Duration(milliseconds: _currentConfig.handlerTimeout),
            onTimeout: () {
              _logger.warning(
                '$reportHandler failed to report error because of timeout',
              );
            },
          ),
    );
  }

  /// Checks is report handler is supported in given platform. Only supported
  /// report handlers in given platform can be used.
  bool isReportHandlerSupportedInPlatform(
    Report report,
    ReportHandler reportHandler,
  ) {
    if (reportHandler.getSupportedPlatforms().isEmpty) {
      return false;
    }
    return reportHandler.getSupportedPlatforms().contains(report.platformType);
  }

  @override
  void onActionRejected(Report report) {
    _currentConfig.handlers
        .where((handler) => handler.shouldHandleWhenRejected())
        .forEach((handler) {
          _handleReport(report, handler);
        });

    _cachedReports.remove(report);
  }

  BuildContext? _getContext() {
    return navigatorKey?.currentState?.overlay?.context;
  }

  bool _isContextValid() {
    return navigatorKey?.currentState?.overlay != null;
  }

  /// Get currently used config.
  CatcherOptions? getCurrentConfig() {
    return _currentConfig;
  }

  /// Send text exception. Used to test Catcher configuration.
  static void sendTestException() {
    throw const FormatException('Test exception generated by Catcher');
  }

  /// Add default error widget which replaces red screen of death (RSOD).
  static void addDefaultErrorWidget({
    bool showStacktrace = true,
    String title = 'An application error has occurred',
    String description =
        'There was unexpected situation in application. Application has been '
        'able to recover from error state.',
    double maxWidthForSmallMode = 150,
  }) {
    ErrorWidget.builder = (details) {
      return CatcherErrorWidget(
        details: details,
        showStacktrace: showStacktrace,
        title: title,
        description: description,
        maxWidthForSmallMode: maxWidthForSmallMode,
      );
    };
  }

  ///Get platform type based on device.
  PlatformType _getPlatformType() {
    if (ApplicationProfileManager.isWeb()) {
      return PlatformType.web;
    }
    if (ApplicationProfileManager.isAndroid()) {
      return PlatformType.android;
    }
    if (ApplicationProfileManager.isIos()) {
      return PlatformType.iOS;
    }
    if (ApplicationProfileManager.isLinux()) {
      return PlatformType.linux;
    }
    if (ApplicationProfileManager.isWindows()) {
      return PlatformType.windows;
    }
    if (ApplicationProfileManager.isMacOS()) {
      return PlatformType.macOS;
    }

    return PlatformType.unknown;
  }

  ///Clean report occurrencess from the past.
  void _cleanPastReportsOccurrences() {
    final occurrenceTimeout = _currentConfig.reportOccurrenceTimeout;
    final nowDateTime = DateTime.now();
    _reportsOccurrenceMap.removeWhere((key, value) {
      final occurrenceWithTimeout = key.add(
        Duration(milliseconds: occurrenceTimeout),
      );
      return nowDateTime.isAfter(occurrenceWithTimeout);
    });
  }

  ///Check whether reports occurence map contains given report.
  bool _isReportInReportsOccurrencesMap(Report report) {
    return _reportsOccurrenceMap.containsValue(report.fingerprint);
  }

  ///Add report in reports occurences map. Report will be added only when
  ///error is not null and report occurence timeout is greater than 0.
  void _addReportInReportsOccurencesMap(Report report) {
    if (_currentConfig.reportOccurrenceTimeout > 0) {
      _reportsOccurrenceMap[DateTime.now()] = report.fingerprint;
    }
  }

  ///Get current Catcher instance.
  static Catcher getInstance() {
    return _instance;
  }
}
