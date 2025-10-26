import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ErrorLogger {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static String? _appVersion;
  static Map<String, dynamic>? _deviceData;

  // Initialize device info and app version (call this in main.dart)
  static Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          _deviceData = {
            'platform': 'Android',
            'model': androidInfo.model,
            'manufacturer': androidInfo.manufacturer,
            'version': androidInfo.version.release,
            'sdk_int': androidInfo.version.sdkInt,
          };
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          _deviceData = {
            'platform': 'iOS',
            'model': iosInfo.model,
            'name': iosInfo.name,
            'system_version': iosInfo.systemVersion,
          };
        }
      } else {
        final webInfo = await _deviceInfo.webBrowserInfo;
        _deviceData = {
          'platform': 'Web',
          'browser': webInfo.browserName.toString(),
          'user_agent': webInfo.userAgent,
        };
      }
    } catch (e) {
      debugPrint('Failed to initialize ErrorLogger: $e');
      // Set a default device data in case of initialization failure
      _deviceData = {
        'platform': kIsWeb ? 'Web (Init Failed)' : 'Mobile/Desktop (Init Failed)',
        'error': e.toString(),
        'app_version': _appVersion, // Still try to get app version
      };
    }
  }

  // Log database errors
  static Future<void> logDatabaseError(
      String message, {
        String? errorCode,
        dynamic errorDetails,
        String? stackTrace,
        String? functionName,
        String? operation,
        Map<String, dynamic>? requestData,
        Map<String, dynamic>? responseData,
        ErrorSeverity severity = ErrorSeverity.error,
      }) async {
    await _logError(
      errorType: ErrorType.database,
      message: message,
      errorCode: errorCode,
      errorDetails: errorDetails,
      stackTrace: stackTrace,
      functionName: functionName,
      operation: operation,
      requestData: requestData,
      responseData: responseData,
      severity: severity,
    );
  }

  // Log API errors
  static Future<void> logApiError(
      String message, {
        String? errorCode,
        dynamic errorDetails,
        String? stackTrace,
        String? functionName,
        String? operation,
        Map<String, dynamic>? requestData,
        Map<String, dynamic>? responseData,
        ErrorSeverity severity = ErrorSeverity.error,
      }) async {
    await _logError(
      errorType: ErrorType.api,
      message: message,
      errorCode: errorCode,
      errorDetails: errorDetails,
      stackTrace: stackTrace,
      functionName: functionName,
      operation: operation,
      requestData: requestData,
      responseData: responseData,
      severity: severity,
    );
  }

  // Log validation errors
  static Future<void> logValidationError(
      String message, {
        String? errorCode,
        dynamic errorDetails,
        String? functionName,
        String? operation,
        Map<String, dynamic>? requestData,
        ErrorSeverity severity = ErrorSeverity.warning,
      }) async {
    await _logError(
      errorType: ErrorType.validation,
      message: message,
      errorCode: errorCode,
      errorDetails: errorDetails,
      functionName: functionName,
      operation: operation,
      requestData: requestData,
      severity: severity,
    );
  }

  // Log authentication errors
  static Future<void> logAuthError(
      String message, {
        String? errorCode,
        dynamic errorDetails,
        String? functionName,
        String? operation,
        ErrorSeverity severity = ErrorSeverity.error,
      }) async {
    await _logError(
      errorType: ErrorType.authentication,
      message: message,
      errorCode: errorCode,
      errorDetails: errorDetails,
      functionName: functionName,
      operation: operation,
      severity: severity,
    );
  }

  // Log UI errors
  static Future<void> logUiError(
      String message, {
        String? errorCode,
        dynamic errorDetails,
        String? stackTrace,
        String? functionName,
        ErrorSeverity severity = ErrorSeverity.warning,
      }) async {
    await _logError(
      errorType: ErrorType.ui,
      message: message,
      errorCode: errorCode,
      errorDetails: errorDetails,
      stackTrace: stackTrace,
      functionName: functionName,
      severity: severity,
    );
  }

  // Log business logic errors
  static Future<void> logBusinessLogicError(
      String message, {
        String? errorCode,
        dynamic errorDetails,
        String? stackTrace,
        String? functionName,
        String? operation,
        Map<String, dynamic>? requestData,
        ErrorSeverity severity = ErrorSeverity.error,
      }) async {
    await _logError(
      errorType: ErrorType.businessLogic,
      message: message,
      errorCode: errorCode,
      errorDetails: errorDetails,
      stackTrace: stackTrace,
      functionName: functionName,
      operation: operation,
      requestData: requestData,
      severity: severity,
    );
  }

  // Generic error logging method
  static Future<void> _logError({
    required ErrorType errorType,
    required String message,
    String? errorCode,
    dynamic errorDetails,
    String? stackTrace,
    String? functionName,
    String? operation,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    ErrorSeverity severity = ErrorSeverity.error,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      // Get platform info
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'flutter_web';
      } else if (Platform.isAndroid) {
        platform = 'flutter_android';
      } else if (Platform.isIOS) {
        platform = 'flutter_ios';
      }

      final response = await supabase.rpc('log_error', params: {
        'p_error_type': errorType.value,
        'p_error_message': message,
        'p_severity': severity.value,
        'p_error_code': errorCode,
        'p_error_details': errorDetails != null ?
        (errorDetails is Map ? errorDetails : {'details': errorDetails.toString()}) : null,
        'p_stack_trace': stackTrace,
        'p_user_id': currentUser?.id,
        'p_session_id': currentUser?.id, // You might want to generate a proper session ID
        'p_function_name': functionName,
        'p_operation': operation,
        'p_request_data': requestData,
        'p_response_data': responseData,
        'p_platform': platform,
        'p_app_version': _appVersion,
        'p_device_info': _deviceData,
      });

      debugPrint('Error logged with ID: $response');
    } catch (e) {
      // Don't let error logging crash the app
      debugPrint('Failed to log error: $e');
    }
  }

  // Helper method to catch and log Flutter errors
  static Future<T?> catchAndLog<T>(
      Future<T> Function() operation, {
        required String operationName,
        ErrorType errorType = ErrorType.system,
        ErrorSeverity severity = ErrorSeverity.error,
        Map<String, dynamic>? context,
      }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      await _logError(
        errorType: errorType,
        message: error.toString(),
        stackTrace: stackTrace.toString(),
        operation: operationName,
        requestData: context,
        severity: severity,
      );
      rethrow;
    }
  }
}

// Enums for better type safety
enum ErrorType {
  database('database'),
  api('api'),
  validation('validation'),
  authentication('authentication'),
  authorization('authorization'),
  network('network'),
  ui('ui'),
  businessLogic('business_logic'),
  system('system'),
  externalService('external_service');

  const ErrorType(this.value);
  final String value;
}

enum ErrorSeverity {
  critical('critical'),
  error('error'),
  warning('warning'),
  info('info');

  const ErrorSeverity(this.value);
  final String value;
}

// Extension for easy error logging on exceptions
extension ErrorLoggingExtension on Exception {
  Future<void> logError({
    ErrorType errorType = ErrorType.system,
    ErrorSeverity severity = ErrorSeverity.error,
    String? operation,
    String? functionName,
    Map<String, dynamic>? context,
  }) async {
    await ErrorLogger._logError(
      errorType: errorType,
      message: toString(),
      operation: operation,
      functionName: functionName,
      requestData: context,
      severity: severity,
    );
  }
}