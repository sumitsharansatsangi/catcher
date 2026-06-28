import 'package:catcher/model/redaction_options.dart';

class ReportRedactor {
  final RedactionOptions options;
  final Set<String> _keys;

  ReportRedactor(this.options)
    : _keys = options.parameterKeys.map((key) => key.toLowerCase()).toSet();

  dynamic redact(dynamic value, {String? key}) {
    if (!options.enabled) {
      return value;
    }
    if (key != null && _keys.contains(key.toLowerCase())) {
      return options.replacement;
    }
    if (value is String) {
      return _redactString(value);
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (entryKey, entryValue) => MapEntry(
          entryKey.toString(),
          redact(entryValue, key: entryKey.toString()),
        ),
      );
    }
    if (value is Iterable) {
      return value.map(redact).toList();
    }
    return value;
  }

  Map<String, dynamic> redactMap(Map<String, dynamic> values) {
    return redact(values) as Map<String, dynamic>;
  }

  String _redactString(String value) {
    var result = value;
    for (final pattern in options.patterns) {
      result = result.replaceAll(pattern, options.replacement);
    }
    return result;
  }
}
