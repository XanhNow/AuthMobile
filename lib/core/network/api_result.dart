class ApiEnvelope<T> {
  const ApiEnvelope({required this.data, required this.metadata});

  final T data;
  final ApiMetadata metadata;
}

class ApiMetadata {
  const ApiMetadata({
    required this.contractVersion,
    required this.correlationId,
    required this.requestId,
    required this.timestampUtc,
  });

  factory ApiMetadata.fromJson(Map<String, dynamic> json) {
    return ApiMetadata(
      contractVersion: json['contractVersion'] as String? ?? '',
      correlationId: json['correlationId'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      timestampUtc: DateTime.tryParse(json['timestampUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String contractVersion;
  final String correlationId;
  final String requestId;
  final DateTime timestampUtc;
}

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    required this.details,
    this.metadata,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Unexpected error.',
      details: (json['details'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ApiErrorDetail.fromJson)
          .toList(growable: false),
      metadata: json['metadata'] is Map<String, dynamic>
          ? ApiMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  final String code;
  final String message;
  final List<ApiErrorDetail> details;
  final ApiMetadata? metadata;
}

class ApiErrorDetail {
  const ApiErrorDetail({
    required this.code,
    required this.message,
    this.target,
  });

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      target: json['target'] as String?,
    );
  }

  final String code;
  final String message;
  final String? target;
}
