part of 'lan_sync_service.dart';

extension LanSyncServicePlatform on LanSyncService {
  Future<String> _getDeviceName() {
    return _deviceNameFuture ??= _resolveDeviceName();
  }

  Future<String> _resolveDeviceName() async {
    if (Platform.isAndroid) {
      try {
        final platformName = await LanSyncService._platformChannel
            .invokeMethod<String>('getDeviceName');
        final normalizedPlatformName = platformName?.trim() ?? '';
        _log(
          'Android platform device name candidate: "$normalizedPlatformName".',
        );
        if (!_isGenericPeerName(normalizedPlatformName)) {
          _log('Using Android platform device name "$normalizedPlatformName".');
          return normalizedPlatformName;
        }
      } catch (error) {
        _log('Failed to resolve Android device name: $error');
      }
    }

    final hostname = Platform.localHostname.trim();
    _log('Platform.localHostname candidate: "$hostname".');
    if (!_isGenericPeerName(hostname)) {
      _log('Using hostname device name "$hostname".');
      return hostname;
    }

    if (Platform.isAndroid) {
      _log('Falling back to generic Android device name.');
      return 'Android Device';
    }
    if (Platform.isWindows) {
      return 'Windows PC';
    }

    return 'LAN Sync Device';
  }

  Future<void> _acquirePlatformMulticastLock() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await LanSyncService._platformChannel.invokeMethod<void>(
        'acquireMulticastLock',
      );
      _log('Android multicast lock acquired.');
    } catch (error) {
      _log('Failed to acquire Android multicast lock: $error');
    }
  }

  Future<void> _releasePlatformMulticastLock() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await LanSyncService._platformChannel.invokeMethod<void>(
        'releaseMulticastLock',
      );
      _log('Android multicast lock released.');
    } catch (error) {
      _log('Failed to release Android multicast lock: $error');
    }
  }

  String? _resolveAdbPath() {
    final executable = Platform.isWindows ? 'adb.exe' : 'adb';
    final androidHome = Platform.environment['ANDROID_HOME'];
    if (androidHome != null && androidHome.isNotEmpty) {
      final candidate = path.join(androidHome, 'platform-tools', executable);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    final androidSdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
    if (androidSdkRoot != null && androidSdkRoot.isNotEmpty) {
      final candidate = path.join(androidSdkRoot, 'platform-tools', executable);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      final candidate = path.join(
        localAppData,
        'Android',
        'sdk',
        'platform-tools',
        executable,
      );
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }
}
