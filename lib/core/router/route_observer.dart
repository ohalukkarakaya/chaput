import 'package:flutter/material.dart';

class ChaputRouteObserver extends RouteObserver<ModalRoute<void>> {
  final Map<Route<dynamic>, bool> _coveredByPageRoute = {};

  bool isCoveredByPageRoute(Route<dynamic>? route) {
    if (route == null) return true;
    return _coveredByPageRoute[route] ?? true;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _coveredByPageRoute[previousRoute] = route is PageRoute;
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _coveredByPageRoute.remove(route);
    if (previousRoute != null) {
      _coveredByPageRoute.remove(previousRoute);
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _coveredByPageRoute.remove(route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      _coveredByPageRoute.remove(oldRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

final ChaputRouteObserver routeObserver = ChaputRouteObserver();
