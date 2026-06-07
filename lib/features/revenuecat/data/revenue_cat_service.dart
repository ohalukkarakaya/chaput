import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'revenue_cat_config.dart';

enum RevenueCatResultStatus {
  success,
  cancelled,
  notInitialized,
  productNotFound,
  missingEntitlement,
  networkError,
  revenueCatError,
  unsupported,
  invalidRequest,
  unknownError,
}

class RevenueCatResult<T> {
  const RevenueCatResult._({
    required this.status,
    this.data,
    this.message,
    this.errorCode,
    this.exception,
  });

  factory RevenueCatResult.success(T data) {
    return RevenueCatResult._(
      status: RevenueCatResultStatus.success,
      data: data,
    );
  }

  factory RevenueCatResult.failure({
    required RevenueCatResultStatus status,
    String? message,
    PurchasesErrorCode? errorCode,
    Object? exception,
  }) {
    return RevenueCatResult._(
      status: status,
      message: message,
      errorCode: errorCode,
      exception: exception,
    );
  }

  final RevenueCatResultStatus status;
  final T? data;
  final String? message;
  final PurchasesErrorCode? errorCode;
  final Object? exception;

  bool get isSuccess => status == RevenueCatResultStatus.success;
  bool get isCancelled => status == RevenueCatResultStatus.cancelled;
}

class RevenueCatPurchaseData {
  const RevenueCatPurchaseData({
    required this.productId,
    required this.customerInfo,
    required this.storeTransaction,
    required this.hasChaputSubscription,
  });

  final String productId;
  final CustomerInfo customerInfo;
  final StoreTransaction storeTransaction;
  final bool hasChaputSubscription;
}

class RevenueCatRestoreData {
  const RevenueCatRestoreData({
    required this.customerInfo,
    required this.hasChaputSubscription,
  });

  final CustomerInfo customerInfo;
  final bool hasChaputSubscription;
}

class RevenueCatLoginData {
  const RevenueCatLoginData({
    required this.customerInfo,
    required this.created,
  });

  final CustomerInfo customerInfo;
  final bool created;
}

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  bool _initialized = false;
  bool _listenerAttached = false;
  CustomerInfo? _latestCustomerInfo;
  final _customerInfoController = StreamController<CustomerInfo>.broadcast();

  bool get isInitialized => _initialized;
  CustomerInfo? get latestCustomerInfo => _latestCustomerInfo;
  Stream<CustomerInfo> get customerInfoUpdates =>
      _customerInfoController.stream;

  Future<RevenueCatResult<void>> init({String? appUserId}) async {
    if (_initialized) {
      return RevenueCatResult.success(null);
    }

    final apiKey = RevenueCatConfig.apiKeyForPlatform(defaultTargetPlatform);
    if (apiKey.trim().isEmpty) {
      return RevenueCatResult.failure(
        status: RevenueCatResultStatus.invalidRequest,
        message: 'RevenueCat API key is missing.',
      );
    }

    try {
      await Purchases.setLogLevel(
        kReleaseMode ? LogLevel.warn : LogLevel.debug,
      );
      final alreadyConfigured = await _isSdkConfigured();
      if (!alreadyConfigured) {
        final configuration = PurchasesConfiguration(apiKey);
        if (appUserId != null && appUserId.trim().isNotEmpty) {
          configuration.appUserID = appUserId.trim();
        }
        await Purchases.configure(configuration);
      }
      _initialized = true;
      _attachCustomerInfoListener();
      return RevenueCatResult.success(null);
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<void>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<void>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<CustomerInfo>> getCustomerInfo() async {
    final initialized = await _ensureInitialized<CustomerInfo>();
    if (initialized != null) return initialized;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _setLatestCustomerInfo(customerInfo);
      return RevenueCatResult.success(customerInfo);
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<CustomerInfo>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<CustomerInfo>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<bool>> hasChaputSubscription() async {
    final customerInfoResult = await getCustomerInfo();
    if (!customerInfoResult.isSuccess) {
      return RevenueCatResult.failure(
        status: customerInfoResult.status,
        message: customerInfoResult.message,
        errorCode: customerInfoResult.errorCode,
        exception: customerInfoResult.exception,
      );
    }

    final hasEntitlement = isChaputSubscriptionActive(customerInfoResult.data!);
    if (!hasEntitlement) {
      return RevenueCatResult.failure(
        status: RevenueCatResultStatus.missingEntitlement,
        message: 'RevenueCat entitlement is not active.',
      );
    }
    return RevenueCatResult.success(true);
  }

  Future<RevenueCatResult<PurchaseResult>> purchasePackage(
    Package package,
  ) async {
    final initialized = await _ensureInitialized<PurchaseResult>();
    if (initialized != null) return initialized;

    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _setLatestCustomerInfo(result.customerInfo);
      // TODO: Send this transaction to the existing backend confirmation flow.
      return RevenueCatResult.success(result);
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<PurchaseResult>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<PurchaseResult>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<RevenueCatPurchaseData>> purchaseProductId(
    String productId,
  ) async {
    final initialized = await _ensureInitialized<RevenueCatPurchaseData>();
    if (initialized != null) return initialized;

    final requestedProductId = productId.trim();
    if (requestedProductId.isEmpty) {
      return RevenueCatResult.failure(
        status: RevenueCatResultStatus.invalidRequest,
        message: 'Product id is empty.',
      );
    }
    final logicalProductId = RevenueCatProductIds.logicalProductId(
      requestedProductId,
    );
    final storeProductId = RevenueCatProductIds.storeProductIdForPlatform(
      logicalProductId,
      defaultTargetPlatform,
    );

    try {
      final product = await _findStoreProduct(logicalProductId);
      if (product == null) {
        return RevenueCatResult.failure(
          status: RevenueCatResultStatus.productNotFound,
          message: 'RevenueCat product was not found: $storeProductId',
        );
      }
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.storeProduct(product),
      );

      _setLatestCustomerInfo(purchaseResult.customerInfo);
      // TODO: Send this transaction to the existing backend confirmation flow.
      return RevenueCatResult.success(
        RevenueCatPurchaseData(
          productId: logicalProductId,
          customerInfo: purchaseResult.customerInfo,
          storeTransaction: purchaseResult.storeTransaction,
          hasChaputSubscription: isChaputSubscriptionActive(
            purchaseResult.customerInfo,
          ),
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<RevenueCatPurchaseData>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<RevenueCatPurchaseData>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<RevenueCatRestoreData>> restorePurchases() async {
    final initialized = await _ensureInitialized<RevenueCatRestoreData>();
    if (initialized != null) return initialized;

    try {
      final customerInfo = await Purchases.restorePurchases();
      _setLatestCustomerInfo(customerInfo);
      return RevenueCatResult.success(
        RevenueCatRestoreData(
          customerInfo: customerInfo,
          hasChaputSubscription: isChaputSubscriptionActive(customerInfo),
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<RevenueCatRestoreData>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<RevenueCatRestoreData>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<Offerings>> getOfferings() async {
    final initialized = await _ensureInitialized<Offerings>();
    if (initialized != null) return initialized;

    try {
      return RevenueCatResult.success(await Purchases.getOfferings());
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<Offerings>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<Offerings>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<List<StoreProduct>>> getProducts(
    List<String> productIds, {
    ProductCategory? productCategory,
  }) async {
    final initialized = await _ensureInitialized<List<StoreProduct>>();
    if (initialized != null) return initialized;

    final ids = productIds
        .map((id) => RevenueCatProductIds.logicalProductId(id.trim()))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return RevenueCatResult.failure(
        status: RevenueCatResultStatus.invalidRequest,
        message: 'Product id list is empty.',
      );
    }

    try {
      if (productCategory != null) {
        final storeIds = ids
            .map(
              (id) => RevenueCatProductIds.storeProductIdForPlatform(
                id,
                defaultTargetPlatform,
              ),
            )
            .toList(growable: false);
        final products = await Purchases.getProducts(
          storeIds,
          productCategory: productCategory,
        );
        return RevenueCatResult.success(products);
      }

      final subscriptionIds = ids
          .where((id) => !RevenueCatProductIds.isConsumable(id))
          .toList(growable: false);
      final consumableIds = ids
          .where(RevenueCatProductIds.isConsumable)
          .toList(growable: false);
      final products = <StoreProduct>[];

      if (subscriptionIds.isNotEmpty) {
        final storeSubscriptionIds = subscriptionIds
            .map(
              (id) => RevenueCatProductIds.storeProductIdForPlatform(
                id,
                defaultTargetPlatform,
              ),
            )
            .toList(growable: false);
        products.addAll(
          await Purchases.getProducts(
            storeSubscriptionIds,
            productCategory: ProductCategory.subscription,
          ),
        );
      }
      if (consumableIds.isNotEmpty) {
        products.addAll(
          await Purchases.getProducts(
            consumableIds,
            productCategory: ProductCategory.nonSubscription,
          ),
        );
      }

      return RevenueCatResult.success(products);
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<List<StoreProduct>>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<List<StoreProduct>>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<RevenueCatLoginData>> logInWithBackendUserId(
    String userId, {
    String? email,
    String? displayName,
    String? username,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return RevenueCatResult.failure(
        status: RevenueCatResultStatus.invalidRequest,
        message: 'Backend user id is empty.',
      );
    }

    if (!_initialized) {
      final result = await init(appUserId: trimmedUserId);
      if (!result.isSuccess) {
        return RevenueCatResult.failure(
          status: result.status,
          message: result.message,
          errorCode: result.errorCode,
          exception: result.exception,
        );
      }
    }

    try {
      final currentAppUserId = await Purchases.appUserID;
      if (currentAppUserId == trimmedUserId) {
        await _setBackendUserAttributes(
          userId: trimmedUserId,
          email: email,
          displayName: displayName,
          username: username,
        );
        final customerInfo = await Purchases.getCustomerInfo();
        _setLatestCustomerInfo(customerInfo);
        return RevenueCatResult.success(
          RevenueCatLoginData(customerInfo: customerInfo, created: false),
        );
      }

      final result = await Purchases.logIn(trimmedUserId);
      await _setBackendUserAttributes(
        userId: trimmedUserId,
        email: email,
        displayName: displayName,
        username: username,
      );
      _setLatestCustomerInfo(result.customerInfo);
      return RevenueCatResult.success(
        RevenueCatLoginData(
          customerInfo: result.customerInfo,
          created: result.created,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<RevenueCatLoginData>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<RevenueCatLoginData>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<CustomerInfo>> logOut() async {
    try {
      final configured = _initialized || await _isSdkConfigured();
      if (!configured) {
        return RevenueCatResult.failure(
          status: RevenueCatResultStatus.notInitialized,
          message: 'RevenueCat SDK is not configured.',
        );
      }
      final isAnonymous = await Purchases.isAnonymous;
      if (isAnonymous) {
        return RevenueCatResult.failure(
          status: RevenueCatResultStatus.invalidRequest,
          message: 'RevenueCat user is already anonymous.',
        );
      }
      final customerInfo = await Purchases.logOut();
      _setLatestCustomerInfo(customerInfo);
      return RevenueCatResult.success(customerInfo);
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<CustomerInfo>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<CustomerInfo>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<void>> presentCustomerCenter() async {
    final initialized = await _ensureInitialized<void>();
    if (initialized != null) return initialized;

    try {
      await RevenueCatUI.presentCustomerCenter();
      return RevenueCatResult.success(null);
    } on PlatformException catch (error, stackTrace) {
      return _platformFailure<void>(error, stackTrace);
    } catch (error, stackTrace) {
      return _unknownFailure<void>(error, stackTrace);
    }
  }

  Future<RevenueCatResult<void>> openCustomerCenter() {
    return presentCustomerCenter();
  }

  bool isChaputSubscriptionActive(CustomerInfo customerInfo) {
    return customerInfo
            .entitlements
            .active[RevenueCatConfig.chaputSubscriptionEntitlement]
            ?.isActive ==
        true;
  }

  Future<StoreProduct?> _findStoreProduct(String productId) async {
    final logicalProductId = RevenueCatProductIds.logicalProductId(productId);
    final storeProductId = RevenueCatProductIds.storeProductIdForPlatform(
      logicalProductId,
      defaultTargetPlatform,
    );
    final products = await Purchases.getProducts([
      storeProductId,
    ], productCategory: RevenueCatProductIds.categoryFor(logicalProductId));
    if (products.isEmpty) return null;
    return products.first;
  }

  void _attachCustomerInfoListener() {
    if (_listenerAttached) return;
    Purchases.addCustomerInfoUpdateListener(_setLatestCustomerInfo);
    _listenerAttached = true;
  }

  void _setLatestCustomerInfo(CustomerInfo customerInfo) {
    _latestCustomerInfo = customerInfo;
    if (!_customerInfoController.isClosed) {
      _customerInfoController.add(customerInfo);
    }
  }

  Future<void> _setBackendUserAttributes({
    required String userId,
    String? email,
    String? displayName,
    String? username,
  }) async {
    try {
      final attributes = <String, String>{'backend_user_id': userId};
      final trimmedUsername = username?.trim();
      if (trimmedUsername != null && trimmedUsername.isNotEmpty) {
        attributes['username'] = trimmedUsername;
      }
      await Purchases.setAttributes(attributes);

      final trimmedEmail = email?.trim();
      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        await Purchases.setEmail(trimmedEmail);
      }

      final trimmedDisplayName = displayName?.trim();
      if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
        await Purchases.setDisplayName(trimmedDisplayName);
      }
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'RevenueCat attribute sync failed',
        name: 'RevenueCatService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _isSdkConfigured() async {
    try {
      return await Purchases.isConfigured;
    } catch (_) {
      return false;
    }
  }

  Future<RevenueCatResult<T>?> _ensureInitialized<T>() async {
    if (_initialized) return null;
    final result = await init();
    if (result.isSuccess) return null;
    return RevenueCatResult.failure(
      status: result.status,
      message: result.message,
      errorCode: result.errorCode,
      exception: result.exception,
    );
  }

  RevenueCatResult<T> _platformFailure<T>(
    PlatformException error,
    StackTrace stackTrace,
  ) {
    final errorCode = _safeRevenueCatErrorCode(error);
    final status = switch (errorCode) {
      PurchasesErrorCode.purchaseCancelledError =>
        RevenueCatResultStatus.cancelled,
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        RevenueCatResultStatus.productNotFound,
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError ||
      PurchasesErrorCode.apiEndpointBlocked =>
        RevenueCatResultStatus.networkError,
      PurchasesErrorCode.unsupportedError => RevenueCatResultStatus.unsupported,
      _ => RevenueCatResultStatus.revenueCatError,
    };

    developer.log(
      'RevenueCat platform error: ${error.message ?? error.code}',
      name: 'RevenueCatService',
      error: error,
      stackTrace: stackTrace,
    );

    return RevenueCatResult.failure(
      status: status,
      message: error.message ?? 'RevenueCat request failed.',
      errorCode: errorCode,
      exception: error,
    );
  }

  RevenueCatResult<T> _unknownFailure<T>(Object error, StackTrace stackTrace) {
    developer.log(
      'RevenueCat unknown error',
      name: 'RevenueCatService',
      error: error,
      stackTrace: stackTrace,
    );

    return RevenueCatResult.failure(
      status: RevenueCatResultStatus.unknownError,
      message: error.toString(),
      exception: error,
    );
  }

  PurchasesErrorCode? _safeRevenueCatErrorCode(PlatformException error) {
    try {
      return PurchasesErrorHelper.getErrorCode(error);
    } catch (_) {
      return null;
    }
  }
}
