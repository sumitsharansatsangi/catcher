class RedactionOptions {
  static final List<RegExp> defaultPatterns = <RegExp>[
    RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ),
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    RegExp(
      r'''(token|secret|password|api[_-]?key)\s*[:=]\s*["']?[^"'\s,}]+''',
      caseSensitive: false,
    ),
  ];

  final bool enabled;
  final String replacement;
  final List<String> parameterKeys;
  final List<RegExp> patterns;

  const RedactionOptions({
    this.enabled = false,
    this.replacement = '[REDACTED]',
    this.parameterKeys = const <String>[
      'androidId',
      'deviceId',
      'digitalProductId',
      'email',
      'hostName',
      'identifierForVendor',
      'machineId',
      'password',
      'productId',
      'registeredOwner',
      'secret',
      'systemGUID',
      'token',
    ],
    this.patterns = const <RegExp>[],
  });

  factory RedactionOptions.defaults() => RedactionOptions(
    enabled: true,
    patterns: defaultPatterns,
  );
}
