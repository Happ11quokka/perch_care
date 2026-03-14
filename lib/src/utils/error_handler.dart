import 'dart:async';
import 'dart:io';

import '../../l10n/app_localizations.dart';
import '../services/api/api_client.dart';

enum ErrorContext {
  general,
  petSave,
  weightSave,
  login,
  signup,
  forgotPassword,
  socialLogin,
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

    // API 에러 — 컨텍스트별 분기
    if (error is ApiException) {
      // 서버 에러는 컨텍스트와 무관하게 동일
      if (error.statusCode >= 500) {
        return l10n.error_server;
      }

      switch (context) {
        case ErrorContext.login:
          return _getLoginError(error, l10n);
        case ErrorContext.signup:
          return _getSignupError(error, l10n);
        case ErrorContext.forgotPassword:
          return _getForgotPasswordError(error, l10n);
        case ErrorContext.socialLogin:
          return _getSocialLoginError(error, l10n);
        default:
          return _getGeneralApiError(error, l10n, context);
      }
    }

    // 일반 폴백
    return _getContextualMessage(context, l10n);
  }

  /// 이메일 로그인 에러
  static String _getLoginError(ApiException error, AppLocalizations l10n) {
    switch (error.statusCode) {
      case 401:
        return l10n.error_loginInvalidCredentials;
      case 404:
        return l10n.error_loginUserNotFound;
      case 422:
        return l10n.error_invalidData;
      default:
        return l10n.error_loginRetry;
    }
  }

  /// 회원가입 에러
  static String _getSignupError(ApiException error, AppLocalizations l10n) {
    switch (error.statusCode) {
      case 409:
        return l10n.error_signupEmailExists;
      case 422:
        return l10n.error_signupInvalidData;
      default:
        return l10n.error_unexpected;
    }
  }

  /// 비밀번호 찾기 에러
  static String _getForgotPasswordError(
      ApiException error, AppLocalizations l10n) {
    switch (error.statusCode) {
      case 404:
        return l10n.error_forgotPasswordUserNotFound;
      case 429:
        return l10n.error_tooManyRequests;
      default:
        return l10n.error_unexpected;
    }
  }

  /// 소셜 로그인 에러
  static String _getSocialLoginError(
      ApiException error, AppLocalizations l10n) {
    switch (error.statusCode) {
      case 409:
        return l10n.error_socialAccountConflict;
      default:
        return l10n.error_unexpected;
    }
  }

  /// 일반 API 에러 (비인증 컨텍스트)
  static String _getGeneralApiError(
      ApiException error, AppLocalizations l10n, ErrorContext context) {
    switch (error.statusCode) {
      case 401:
      case 403:
        return l10n.error_authRequired;
      case 409:
        return l10n.error_conflict;
      case 422:
        return l10n.error_invalidData;
      case 404:
        return l10n.error_notFound;
      default:
        return _getContextualMessage(context, l10n);
    }
  }

  static String _getContextualMessage(
      ErrorContext context, AppLocalizations l10n) {
    switch (context) {
      case ErrorContext.petSave:
        return l10n.error_savePetFailed;
      case ErrorContext.weightSave:
        return l10n.error_saveWeightFailed;
      case ErrorContext.login:
        return l10n.error_loginRetry;
      case ErrorContext.signup:
      case ErrorContext.forgotPassword:
      case ErrorContext.socialLogin:
      case ErrorContext.general:
        return l10n.error_unexpected;
    }
  }
}
