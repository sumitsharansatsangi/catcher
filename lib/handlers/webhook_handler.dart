import 'dart:async';

import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:catcher/utils/catcher_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class WebhookHandler extends ReportHandler {
  final Dio _dio = Dio();

  final Uri endpointUri;
  final Map<String, dynamic> headers;
  final String? bearerToken;
  final Duration requestTimeout;
  final Duration responseTimeout;
  final bool printLogs;
  final FutureOr<dynamic> Function(Report report)? bodyBuilder;

  WebhookHandler(
    this.endpointUri, {
    Map<String, dynamic>? headers,
    this.bearerToken,
    this.requestTimeout = const Duration(seconds: 5),
    this.responseTimeout = const Duration(seconds: 5),
    this.printLogs = false,
    this.bodyBuilder,
  }) : headers = headers ?? const <String, dynamic>{};

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    try {
      if (report.platformType != PlatformType.web &&
          !(await CatcherUtils.isInternetConnectionAvailable())) {
        _printLog('No internet connection available');
        return false;
      }
      final mutableHeaders = <String, dynamic>{...headers};
      if (bearerToken != null) {
        mutableHeaders['Authorization'] = 'Bearer $bearerToken';
      }
      final body = bodyBuilder == null
          ? report.toJson(enableCustomParameters: true)
          : await bodyBuilder!(report);
      final response = await _dio.post<dynamic>(
        endpointUri.toString(),
        data: body,
        options: Options(
          sendTimeout: requestTimeout,
          receiveTimeout: responseTimeout,
          headers: mutableHeaders,
        ),
      );
      _printLog('Webhook response status: ${response.statusCode}');
      final statusCode = response.statusCode ?? 0;
      return statusCode >= 200 && statusCode < 300;
    } on Object catch (exception) {
      _printLog('WebhookHandler failed: $exception');
      return false;
    }
  }

  void _printLog(String log) {
    if (printLogs) {
      logger.info(log);
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
