class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() {
    final parts = [
      if (statusCode != null) 'HTTP $statusCode',
      if (code != null) code,
      message,
    ];
    return parts.join(': ');
  }
}
