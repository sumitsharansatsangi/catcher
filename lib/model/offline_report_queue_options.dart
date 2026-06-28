class OfflineReportQueueOptions {
  final bool enabled;
  final String storagePath;
  final int maxReports;
  final int maxAttempts;
  final Duration retryInterval;

  const OfflineReportQueueOptions({
    this.enabled = false,
    this.storagePath = '',
    this.maxReports = 50,
    this.maxAttempts = 3,
    this.retryInterval = const Duration(seconds: 30),
  });
}
