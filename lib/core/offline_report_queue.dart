import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:catcher/model/offline_report_queue_options.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:catcher/utils/catcher_logger.dart';
import 'package:flutter/material.dart';

class OfflineReportQueue {
  final OfflineReportQueueOptions options;
  final CatcherLogger logger;
  bool _flushing = false;

  OfflineReportQueue(this.options, this.logger);

  bool get isEnabled => options.enabled && options.storagePath.isNotEmpty;

  File get _file => File(options.storagePath);

  Future<void> enqueue(Report report, ReportHandler handler) async {
    if (!isEnabled) {
      return;
    }
    try {
      final items = await _readItems();
      items.add(<String, dynamic>{
        'handler': handler.runtimeType.toString(),
        'attempts': 0,
        'nextAttemptAt': DateTime.now()
            .add(options.retryInterval)
            .toIso8601String(),
        'report': report.toJson(
          enableCustomParameters: true,
        ),
      });
      final start = items.length > options.maxReports
          ? items.length - options.maxReports
          : 0;
      await _writeItems(items.sublist(start));
    } on Object catch (exception) {
      logger.warning('Failed to queue report offline: $exception');
    }
  }

  Future<void> flush(
    List<ReportHandler> handlers,
    BuildContext? context,
  ) async {
    if (!isEnabled || _flushing) {
      return;
    }
    if (handlers.isEmpty) {
      return;
    }
    _flushing = true;
    try {
      final now = DateTime.now();
      final items = await _readItems();
      final remaining = <Map<String, dynamic>>[];
      for (final item in items) {
        final nextAttemptAt = DateTime.tryParse(
          item['nextAttemptAt']?.toString() ?? '',
        );
        if (nextAttemptAt != null && now.isBefore(nextAttemptAt)) {
          remaining.add(item);
          continue;
        }
        final handlerName = item['handler']?.toString();
        final handler = handlers.firstWhere(
          (handler) => handler.runtimeType.toString() == handlerName,
          orElse: () => handlers.first,
        );
        final reportJson = (item['report'] as Map).cast<String, dynamic>();
        final success = await handler.handle(
          Report.fromJson(reportJson),
          context,
        );
        if (!success) {
          final attempts = (item['attempts'] as int? ?? 0) + 1;
          if (attempts < options.maxAttempts) {
            item['attempts'] = attempts;
            item['nextAttemptAt'] = now
                .add(options.retryInterval * attempts)
                .toIso8601String();
            remaining.add(item);
          }
        }
      }
      await _writeItems(remaining);
    } on Object catch (exception) {
      logger.warning('Failed to flush offline reports: $exception');
    } finally {
      _flushing = false;
    }
  }

  Future<List<Map<String, dynamic>>> _readItems() async {
    if (!_file.existsSync()) {
      return <Map<String, dynamic>>[];
    }
    final content = await _file.readAsString();
    if (content.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    return (jsonDecode(content) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<void> _writeItems(List<Map<String, dynamic>> items) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(items), flush: true);
  }
}
