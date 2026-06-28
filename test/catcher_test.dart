import 'package:catcher/catcher.dart';
import 'package:catcher/utils/report_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report fingerprint is stable for same error and stack frame', () {
    final stackTrace = StackTrace.fromString(
      '#0 main (package:app/main.dart:1)',
    );

    final first = Report.createFingerprint('boom', stackTrace);
    final second = Report.createFingerprint('boom', stackTrace);

    expect(first, second);
    expect(first, isNotEmpty);
  });

  test('report serializes enrichment fields', () {
    final report = Report(
      'boom',
      StackTrace.empty,
      DateTime.utc(2026),
      const <String, dynamic>{},
      const <String, dynamic>{},
      const <String, dynamic>{'orderId': '123'},
      null,
      PlatformType.android,
      null,
      severity: ReportSeverity.fatal,
      breadcrumbs: <Breadcrumb>[Breadcrumb('opened checkout')],
      tags: const <String, dynamic>{'feature': 'checkout'},
      user: const <String, dynamic>{'id': 'u1'},
    );

    final json = report.toJson(enableCustomParameters: true);
    final restored = Report.fromJson(json);

    expect(json['severity'], 'fatal');
    expect(json['fingerprint'], report.fingerprint);
    expect(json['customParameters'], {'orderId': '123'});
    expect(restored.breadcrumbs.single.message, 'opened checkout');
    expect(restored.tags['feature'], 'checkout');
  });

  test('redactor removes sensitive values by key and pattern', () {
    final redactor = ReportRedactor(RedactionOptions.defaults());

    final result = redactor.redactMap(<String, dynamic>{
      'email': 'user@example.com',
      'message': 'Bearer abc.def',
      'nested': <String, dynamic>{'token': 'secret-value'},
    });

    expect(result['email'], '[REDACTED]');
    expect(result['message'], '[REDACTED]');
    expect((result['nested'] as Map<String, dynamic>)['token'], '[REDACTED]');
  });
}
