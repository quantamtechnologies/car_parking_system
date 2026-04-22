import 'package:dio/dio.dart';

String apiErrorMessage(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return 'Your session could not be verified. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'You do not have permission to complete this action.';
    }
    if (statusCode == 404) {
      return 'The requested record could not be found.';
    }

    final extracted = _extractText(error.response?.data);
    if (extracted != null && extracted.isNotEmpty) {
      return extracted;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'The connection is unstable or unavailable. Check the network and try again.';
      case DioExceptionType.badCertificate:
        return 'The connection could not be verified securely.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!.trim();
    }
  }

  final text = error?.toString().trim();
  if (text != null && text.isNotEmpty) {
    return text;
  }
  return fallback;
}

bool isOfflineDioError(Object? error) {
  if (error is! DioException) {
    return false;
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError =>
      true,
    _ => false,
  };
}

String? _extractText(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _extractText(item);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }
  if (value is Map) {
    for (final key in const ['detail', 'message', 'error', 'non_field_errors']) {
      final nested = _extractText(value[key]);
      if (nested != null) {
        return nested;
      }
    }
    for (final entry in value.values) {
      final nested = _extractText(entry);
      if (nested != null) {
        return nested;
      }
    }
  }
  return null;
}
