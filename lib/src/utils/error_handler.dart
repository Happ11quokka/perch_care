import 'dart:async';
import 'dart:io';

import '../../l10n/app_localizations.dart';
import '../services/api/api_client.dart';

enum ErrorContext {
  general,
  petSave,
  weightSave,
  login,
}

class ErrorHandler {
  ErrorHandler._();

  /// 예외를 사용자 친화적 로컬라이즈된 메시지로 변환
  static String getUserMessage(
    dynamic error,
    AppLocalizations l10n, {
    ErrorContext context = ErrorContext.general,
  }) {
    // 네트워크 에러
    if (error is SocketException || error is TimeoutException) {
      return l10n.error_network;
    }

    // API 에러 (상태 코드 기반)
    if (error is ApiException) {
      if (error.statusCode >= 500) {
        return l10n.error_server;
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return l10n.error_authRequired;
      }
      if (error.statusCode == 409) {
        return l10n.error_conflict;
      }
      if (error.statusCode == 422) {
        return l10n.error_invalidData;
      }
      if (error.statusCode == 404) {
        return l10n.error_notFound;
      }
      return _getContextualMessage(context, l10n);
    }

    // 일반 폴백
    return _getContextualMessage(context, l10n);
  }

  static String _getContextualMessage(ErrorContext context, AppLocalizations l10n) {
    switch (context) {
      case ErrorContext.petSave:
        return l10n.error_savePetFailed;
      case ErrorContext.weightSave:
        return l10n.error_saveWeightFailed;
      case ErrorContext.login:
        return l10n.error_loginRetry;
      case ErrorContext.general:
        return l10n.error_unexpected;
    }
  }
}
