/// Normalized exception thrown by the API client so every feature
/// repository/UI layer can handle errors the same way, regardless
/// of whether they came from a network failure, a 4xx, or a 5xx.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const [],
  });

  final String message;
  final int? statusCode;
  final List<FieldError> fieldErrors;

  bool get isNetworkError => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400 && fieldErrors.isNotEmpty;

  @override
  String toString() => message;
}

class FieldError {
  FieldError({required this.field, required this.message});
  final String field;
  final String message;

  factory FieldError.fromJson(Map<String, dynamic> json) =>
      FieldError(field: json['field'] as String? ?? '', message: json['message'] as String? ?? '');
}
