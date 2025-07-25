import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

class SentryHandler extends ReportHandler {
  ///Sentry Client instance
  final SentryClient sentryClient;

  ///User data
  SentryUser? userContext;

  ///Enable device parameters to be generated by Catcher
  final bool enableDeviceParameters;

  ///Enable application parameters to be generated by Catcher
  final bool enableApplicationParameters;

  ///Enable custom parameters to be generated by Catcher
  final bool enableCustomParameters;

  ///Custom environment, if null, Catcher will generate it
  final String? customEnvironment;

  ///Custom release, if null, Catcher will generate it
  final String? customRelease;

  ///Enable additional logs printing
  final bool printLogs;

  SentryHandler(
    this.sentryClient, {
    this.userContext,
    this.enableDeviceParameters = true,
    this.enableApplicationParameters = true,
    this.enableCustomParameters = true,
    this.printLogs = true,
    this.customEnvironment,
    this.customRelease,
  });

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    try {
      _printLog('Logging to sentry...');

      final tags = <String, dynamic>{};
      if (enableApplicationParameters) {
        tags.addAll(report.applicationParameters);
      }
      if (enableDeviceParameters) {
        tags.addAll(report.deviceParameters);
      }
      if (enableCustomParameters) {
        tags.addAll(report.customParameters);
      }

      final event = buildEvent(report, tags);
      await sentryClient.captureEvent(event, stackTrace: report.stackTrace);

      _printLog('Logged to sentry!');
      return true;
    } catch (exception, stackTrace) {
      _printLog('Failed to send sentry event: $exception $stackTrace');
      return false;
    }
  }

  String _getApplicationVersion(Report report) {
    var applicationVersion = '';
    final applicationParameters = report.applicationParameters;
    if (applicationParameters.containsKey('appName')) {
      applicationVersion += (applicationParameters['appName'] as String?)!;
    }
    if (applicationParameters.containsKey('version')) {
      applicationVersion += ' ${applicationParameters['version']}';
    }
    if (applicationVersion.isEmpty) {
      applicationVersion = '?';
    }
    return applicationVersion;
  }

  SentryEvent buildEvent(Report report, Map<String, dynamic> tags) {
    return SentryEvent(
      logger: 'Catcher',
      serverName: 'Catcher',
      release: customRelease ?? _getApplicationVersion(report),
      environment:
          customEnvironment ??
          (report.applicationParameters['environment'] as String?),
      message: const SentryMessage('Error handled by Catcher'),
      throwable: report.error,
      level: SentryLevel.error,
      culprit: '',
      tags: changeToSentryMap(tags),
      user: userContext,
    );
  }

  Map<String, String> changeToSentryMap(Map<String, dynamic> map) {
    final sentryMap = <String, String>{};
    map.forEach((key, dynamic value) {
      if (value.toString().isEmpty) {
        sentryMap[key] = 'none';
      } else {
        sentryMap[key] = value.toString();
      }
    });
    return sentryMap;
  }

  void _printLog(String message) {
    if (printLogs) {
      logger.info(message);
    }
  }

  @override
  List<PlatformType> getSupportedPlatforms() => [
    PlatformType.android,
    PlatformType.iOS,
    PlatformType.web,
    PlatformType.linux,
    PlatformType.macOS,
    PlatformType.windows,
  ];
}
