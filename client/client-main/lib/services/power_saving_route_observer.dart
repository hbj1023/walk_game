import 'package:flutter/material.dart';

import 'app_settings_service.dart';

final powerSavingRouteObserver = RouteObserver<ModalRoute<dynamic>>();

mixin CustomPowerSavingRouteAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<dynamic>? _powerSavingRoute;
  bool _isPowerSavingRouteVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _powerSavingRoute) return;
    if (_powerSavingRoute != null) {
      powerSavingRouteObserver.unsubscribe(this);
    }
    _powerSavingRoute = route;
    powerSavingRouteObserver.subscribe(this, route);
  }

  void _setCustomPowerSavingUiVisible(bool visible) {
    if (_isPowerSavingRouteVisible == visible) return;
    _isPowerSavingRouteVisible = visible;
    AppSettingsService.customPowerSavingUiVisible.value = visible;
  }

  @override
  void didPush() => _setCustomPowerSavingUiVisible(true);

  @override
  void didPopNext() => _setCustomPowerSavingUiVisible(true);

  @override
  void didPushNext() => _setCustomPowerSavingUiVisible(false);

  @override
  void didPop() => _setCustomPowerSavingUiVisible(false);

  @override
  void dispose() {
    powerSavingRouteObserver.unsubscribe(this);
    if (_isPowerSavingRouteVisible) {
      AppSettingsService.customPowerSavingUiVisible.value = false;
    }
    super.dispose();
  }
}
