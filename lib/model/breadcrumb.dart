class Breadcrumb {
  final String message;
  final DateTime timestamp;
  final String? category;
  final Map<String, dynamic> data;

  Breadcrumb(
    this.message, {
    DateTime? timestamp,
    this.category,
    this.data = const <String, dynamic>{},
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    if (category != null) 'category': category,
    if (data.isNotEmpty) 'data': data,
  };

  static Breadcrumb fromJson(Map<String, dynamic> json) => Breadcrumb(
    json['message']?.toString() ?? '',
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    category: json['category']?.toString(),
    data:
        (json['data'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{},
  );
}
