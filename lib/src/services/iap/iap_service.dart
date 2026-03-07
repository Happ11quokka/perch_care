import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../analytics/analytics_service.dart';
import '../api/api_client.dart';
import '../premium/premium_service.dart';

/// IAP 이벤트 콜백 타입
typedef IapEventCallback = void Function(IapEvent event);

/// IAP 이벤트 종류
enum IapEvent {
  purchaseSuccess,
  purchaseRestored,
  purchaseFailed,
  purchasePending,
  purchaseCanceled,
}

/// 인앱 구매 서비스 — 구독 구매, 복원, 서버 검증 처리
class IapService {
  IapService._();
  static final instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final _api = ApiClient.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _initialized = false;

  // 상품 ID 상수
  static const monthlyId = 'perchcare_premium_monthly';
  static const yearlyId = 'perchcare_premium_yearly';
  static const _productIds = {monthlyId, yearlyId};

  // UI 이벤트 콜백
  IapEventCallback? onEvent;

  // 마지막 에러 메시지
  String? lastError;

  /// Getters
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => List.unmodifiable(_products);

  ProductDetails? get monthlyProduct =>
      _products.where((p) => p.id == monthlyId).firstOrNull;
  ProductDetails? get yearlyProduct =>
      _products.where((p) => p.id == yearlyId).firstOrNull;

  /// 초기화: 스트림 리스닝 시작 + 상품 로드
  Future<void> initialize() async {
    if (_initialized) return;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('[IapService] Store not available');
      return;
    }

    // 구매 스트림 리스닝
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('[IapService] Purchase stream error: $error');
      },
    );

    // 상품 정보 로드
    await _loadProducts();

    _initialized = true;
    debugPrint(
      '[IapService] Initialized (${_products.length} products loaded)',
    );
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IapService] Products not found: ${response.notFoundIDs}');
      }
      if (response.error != null) {
        debugPrint('[IapService] Product query error: ${response.error}');
      }

      _products = response.productDetails;
      debugPrint(
        '[IapService] Loaded products: ${_products.map((p) => '${p.id}=${p.price}').join(', ')}',
      );
    } catch (e) {
      debugPrint('[IapService] Failed to load products: $e');
    }
  }

  /// 구독 구매 시작
  Future<bool> buySubscription(ProductDetails product) async {
    if (!_isAvailable) {
      lastError = '스토어를 사용할 수 없습니다';
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('[IapService] Purchase started: $started for ${product.id}');
      return started;
    } catch (e) {
      debugPrint('[IapService] Buy error: $e');
      lastError = e.toString();
      return false;
    }
  }

  /// 구매 복원
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    try {
      await _iap.restorePurchases();
      debugPrint('[IapService] Restore purchases initiated');
    } catch (e) {
      debugPrint('[IapService] Restore error: $e');
      lastError = e.toString();
      onEvent?.call(IapEvent.purchaseFailed);
    }
  }

  /// 스트림 이벤트 처리
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final analytics = AnalyticsService.instance;
    final store = Platform.isIOS ? 'apple' : 'google';

    for (final purchase in purchases) {
      debugPrint(
        '[IapService] Purchase update: ${purchase.productID} status=${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          final success = await _verifyAndDeliver(purchase, isRestore: false);
          if (success) {
            analytics.logPurchaseSuccess(
              store: store,
              productId: purchase.productID,
            );
          } else {
            analytics.logPurchaseFailed(
              store: store,
              productId: purchase.productID,
              reason: lastError ?? 'verification_failed',
            );
          }
          // completePurchase는 검증 성공/실패 무관하게 호출해야 거래가 정리됨
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        case PurchaseStatus.restored:
          final success = await _verifyAndDeliver(purchase, isRestore: true);
          if (success) {
            analytics.logPurchaseSuccess(
              store: store,
              productId: purchase.productID,
              isRestore: true,
            );
            analytics.logRestoreSuccess(store: store);
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        case PurchaseStatus.error:
          lastError = purchase.error?.message ?? '구매 처리 중 오류가 발생했습니다';
          debugPrint('[IapService] Purchase error: ${purchase.error}');
          analytics.logPurchaseFailed(
            store: store,
            productId: purchase.productID,
            reason: purchase.error?.message ?? 'store_error',
          );
          onEvent?.call(IapEvent.purchaseFailed);
        case PurchaseStatus.pending:
          debugPrint('[IapService] Purchase pending');
          onEvent?.call(IapEvent.purchasePending);
        case PurchaseStatus.canceled:
          debugPrint('[IapService] Purchase canceled');
          onEvent?.call(IapEvent.purchaseCanceled);
      }
    }
  }

  /// 서버 검증 → PremiumService 캐시 갱신. 성공 시 true 반환.
  Future<bool> _verifyAndDeliver(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    final store = Platform.isIOS ? 'apple' : 'google';
    final endpoint = isRestore
        ? '/premium/purchases/restore'
        : '/premium/purchases/verify';
    final transactionId = _resolveTransactionId(purchase);

    if (transactionId == null) {
      lastError = '거래 식별자를 찾을 수 없습니다';
      onEvent?.call(IapEvent.purchaseFailed);
      return false;
    }

    // 최대 3회 지수 백오프 재시도
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final body = isRestore
            ? {'store': store, 'transaction_id': transactionId}
            : {
                'store': store,
                'product_id': purchase.productID,
                'transaction_id': transactionId,
              };

        final response = await _api.post(endpoint, body: body);
        final result = response as Map<String, dynamic>;

        if (result['success'] == true) {
          // 캐시 갱신
          PremiumService.instance.invalidateCache();
          onEvent?.call(
            isRestore ? IapEvent.purchaseRestored : IapEvent.purchaseSuccess,
          );
          debugPrint(
            '[IapService] Server verification success: tier=${result['tier']}',
          );
          return true;
        } else {
          lastError = '서버 검증에 실패했습니다';
          onEvent?.call(IapEvent.purchaseFailed);
          return false;
        }
      } catch (e) {
        debugPrint(
          '[IapService] Server verification attempt ${attempt + 1} failed: $e',
        );
        if (attempt < 2) {
          // 지수 백오프: 1초, 2초, 4초
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
          lastError = '서버 검증에 실패했습니다. 네트워크를 확인하고 다시 시도해주세요.';
          onEvent?.call(IapEvent.purchaseFailed);
        }
      }
    }
    return false;
  }

  String? _resolveTransactionId(PurchaseDetails purchase) {
    if (Platform.isIOS) {
      final purchaseId = purchase.purchaseID?.trim();
      if (purchaseId != null && purchaseId.isNotEmpty) {
        return purchaseId;
      }
    }

    final verificationId = purchase.verificationData.serverVerificationData
        .trim();
    if (verificationId.isEmpty) {
      return null;
    }
    return verificationId;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
