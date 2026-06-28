import 'dart:io';

import 'package:catcher/model/breadcrumb.dart';
import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report_severity.dart';
import 'package:flutter/foundation.dart';

class Report {
  /// Error that has been caught
  final dynamic error;

  /// Stack trace of error
  final dynamic stackTrace;

  /// Time when it was caught
  final DateTime dateTime;

  /// Device info
  final Map<String, dynamic> deviceParameters;

  /// Application info
  final Map<String, dynamic> applicationParameters;

  /// Custom parameters passed to report
  final Map<String, dynamic> customParameters;

  /// FlutterErrorDetails data if present
  final FlutterErrorDetails? errorDetails;

  /// Type of platform used
  final PlatformType platformType;

  ///Screenshot of screen where error happens. Screenshot won't work everywhere
  /// (i.e. web platform), so this may be null.
  final File? screenshot;

  /// Severity of the report.
  final ReportSeverity severity;

  /// Stable grouping key generated from error and stack trace.
  final String fingerprint;

  /// Recent application events recorded before the report.
  final List<Breadcrumb> breadcrumbs;

  /// Tags used to filter and group reports.
  final Map<String, dynamic> tags;

  /// Extra runtime metadata attached to report.
  final Map<String, dynamic> extras;

  /// Optional user metadata.
  final Map<String, dynamic> user;

  /// Creates report instance
  Report(
    this.error,
    this.stackTrace,
    this.dateTime,
    this.deviceParameters,
    this.applicationParameters,
    this.customParameters,
    this.errorDetails,
    this.platformType,
    this.screenshot, {
    this.severity = ReportSeverity.error,
    String? fingerprint,
    this.breadcrumbs = const <Breadcrumb>[],
    this.tags = const <String, dynamic>{},
    this.extras = const <String, dynamic>{},
    this.user = const <String, dynamic>{},
  }) : fingerprint = fingerprint ?? createFingerprint(error, stackTrace);

  static String createFingerprint(dynamic error, dynamic stackTrace) {
    final stackLines = stackTrace.toString().split('\n');
    final firstApplicationFrame = stackLines.firstWhere(
      (line) => line.trim().isNotEmpty && !line.contains('dart:async'),
      orElse: () => stackLines.isEmpty ? '' : stackLines.first,
    );
    final source =
        '${error.runtimeType}|$error|'
        '$firstApplicationFrame';
    return _fnv1a32(source);
  }

  static String _fnv1a32(String source) {
    const prime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Report fromJson(Map<String, dynamic> json) {
    final screenshotPath = json['screenshotPath']?.toString();
    return Report(
      json['error'],
      json['stackTrace'],
      DateTime.tryParse(json['dateTime']?.toString() ?? '') ?? DateTime.now(),
      (json['deviceParameters'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      (json['applicationParameters'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      (json['customParameters'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      null,
      PlatformType.values.firstWhere(
        (platform) => platform.name == json['platformType'],
        orElse: () => PlatformType.unknown,
      ),
      screenshotPath == null || screenshotPath.isEmpty
          ? null
          : File(screenshotPath),
      severity: ReportSeverity.values.firstWhere(
        (severity) => severity.name == json['severity'],
        orElse: () => ReportSeverity.error,
      ),
      fingerprint: json['fingerprint']?.toString(),
      breadcrumbs:
          ((json['breadcrumbs'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map((item) => Breadcrumb.fromJson(item.cast<String, dynamic>()))
              .toList(),
      tags:
          (json['tags'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      extras:
          (json['extras'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      user:
          (json['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  /// Creates json from current instance
  Map<String, dynamic> toJson({
    bool enableDeviceParameters = true,
    bool enableApplicationParameters = true,
    bool enableStackTrace = true,
    bool enableCustomParameters = false,
  }) {
    final json = <String, dynamic>{
      'error': error.toString(),
      'dateTime': dateTime.toIso8601String(),
      'platformType': platformType.name,
      'severity': severity.name,
      'fingerprint': fingerprint,
      'breadcrumbs': breadcrumbs
          .map((breadcrumb) => breadcrumb.toJson())
          .toList(),
      'tags': tags,
      'extras': extras,
      'user': user,
      if (screenshot != null) 'screenshotPath': screenshot!.path,
    };
    if (enableDeviceParameters) {
      json['deviceParameters'] = deviceParameters;
    }
    if (enableApplicationParameters) {
      json['applicationParameters'] = applicationParameters;
    }
    if (enableStackTrace) {
      json['stackTrace'] = stackTrace.toString();
    }
    if (enableCustomParameters) {
      json['customParameters'] = customParameters;
    }
    return json;
  }
}
