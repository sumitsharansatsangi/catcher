import 'dart:convert';
import 'dart:io';

import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:flutter/material.dart';

class JsonFileHandler extends ReportHandler {
  final File file;
  final bool prettyPrint;
  final bool handleWhenRejected;

  JsonFileHandler(
    this.file, {
    this.prettyPrint = false,
    this.handleWhenRejected = false,
  });

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    try {
      await file.parent.create(recursive: true);
      final encoder = prettyPrint
          ? const JsonEncoder.withIndent('  ')
          : const JsonEncoder();
      final line = encoder.convert(report.toJson(enableCustomParameters: true));
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      return true;
    } on Object catch (exception) {
      logger.warning('JsonFileHandler failed: $exception');
      return false;
    }
  }

  @override
  List<PlatformType> getSupportedPlatforms() => [
    PlatformType.android,
    PlatformType.iOS,
    PlatformType.linux,
    PlatformType.macOS,
    PlatformType.windows,
  ];

  @override
  bool shouldHandleWhenRejected() => handleWhenRejected;
}
