import 'dart:convert';
import 'package:dio/dio.dart';

abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => message;

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiTimeoutException(
          message: 'Connection timed out. Please check your network connection.',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String errorMessage = 'A server error occurred ($statusCode).';

        dynamic parsedData = data;
        if (parsedData is String && parsedData.trim().startsWith('{')) {
          try {
            parsedData = jsonDecode(parsedData);
          } catch (_) {}
        }

        if (parsedData is Map) {
          final errObj = parsedData['errors'] ?? parsedData['error'];
          if (errObj is Map && errObj.isNotEmpty) {
            final firstVal = errObj.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              errorMessage = firstVal.first.toString();
            } else if (firstVal != null) {
              errorMessage = firstVal.toString();
            }
          } else if (errObj is List && errObj.isNotEmpty) {
            errorMessage = errObj.first.toString();
          } else if (errObj is String && errObj.trim().isNotEmpty) {
            errorMessage = errObj.trim();
          } else if (parsedData.containsKey('message') && parsedData['message'] != null) {
            final msgStr = parsedData['message'].toString().trim();
            if (msgStr.isNotEmpty && msgStr.toLowerCase() != 'server error') {
              errorMessage = msgStr;
            }
          } else if (parsedData.containsKey('msg') && parsedData['msg'] != null) {
            errorMessage = parsedData['msg'].toString().trim();
          }
        } else if (parsedData is String && parsedData.isNotEmpty) {
          if (parsedData.trim().startsWith('<') || parsedData.contains('<!DOCTYPE html>')) {
            errorMessage = 'Server is currently undergoing maintenance. Please try again later.';
          } else {
            errorMessage = parsedData.length > 150 ? '${parsedData.substring(0, 147)}...' : parsedData;
          }
        }

        switch (statusCode) {
          case 400:
            return BadRequestException(
              message: errorMessage,
              statusCode: statusCode,
              details: data,
            );
          case 401:
            return UnauthorizedException(
              message: errorMessage.contains('Unauthorized')
                  ? 'Session expired. Please log in again.'
                  : errorMessage,
              statusCode: statusCode,
              details: data,
            );
          case 403:
            return ForbiddenException(
              message: 'Access denied. You do not have permission for this action.',
              statusCode: statusCode,
              details: data,
            );
          case 404:
            return NotFoundException(
              message: 'Requested resource not found.',
              statusCode: statusCode,
              details: data,
            );
          case 409:
            return ConflictException(
              message: errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Action already recorded on server.',
              statusCode: statusCode,
              details: data,
            );
          case 422:
            return ValidationException(
              message: errorMessage,
              statusCode: statusCode,
              details: data,
            );
          case 500:
          case 502:
          case 503:
          case 504:
            return ServerException(
              message: (errorMessage.isNotEmpty && !errorMessage.startsWith('A server error occurred'))
                  ? errorMessage
                  : 'Internal server error. Please try again later.',
              statusCode: statusCode,
              details: data,
            );
          default:
            return UnknownApiException(
              message: errorMessage,
              statusCode: statusCode,
              details: data,
            );
        }

      case DioExceptionType.cancel:
        return const RequestCancelledException(
          message: 'Request was cancelled.',
        );

      case DioExceptionType.connectionError:
        return const NetworkConnectionException(
          message: 'Unable to connect to server. Please verify your internet connection.',
        );

      case DioExceptionType.badCertificate:
        return const BadCertificateException(
          message: 'Security certificate verification failed.',
        );

      case DioExceptionType.unknown:
        return UnknownApiException(
          message: error.message ?? 'An unexpected network error occurred.',
        );
    }
  }
}

class NetworkConnectionException extends ApiException {
  const NetworkConnectionException({required super.message});
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException({required super.message, super.statusCode});
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({required super.message, super.statusCode, super.details});
}

class ForbiddenException extends ApiException {
  const ForbiddenException({required super.message, super.statusCode, super.details});
}

class NotFoundException extends ApiException {
  const NotFoundException({required super.message, super.statusCode, super.details});
}

class BadRequestException extends ApiException {
  const BadRequestException({required super.message, super.statusCode, super.details});
}

class ConflictException extends ApiException {
  const ConflictException({required super.message, super.statusCode, super.details});
}

class ValidationException extends ApiException {
  const ValidationException({required super.message, super.statusCode, super.details});
}

class ServerException extends ApiException {
  const ServerException({required super.message, super.statusCode, super.details});
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException({required super.message});
}

class BadCertificateException extends ApiException {
  const BadCertificateException({required super.message});
}

class UnknownApiException extends ApiException {
  const UnknownApiException({required super.message, super.statusCode, super.details});
}
