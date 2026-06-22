part of 'lan_sync_service.dart';

extension LanSyncServiceDiscovery on LanSyncService {
  Future<List<LanSyncPeerInfo>> discoverPeers({
    int port = LanSyncService._defaultPort,
  }) async {
    if (_peerDiscoveryFuture != null) {
      return _peerDiscoveryFuture!;
    }

    _cachedPeers = const [];
    final future = _discoverPeersInternal(port);
    _peerDiscoveryFuture = future;
    try {
      final peers = await future;
      _cachedPeers = peers;
      return peers;
    } finally {
      if (identical(_peerDiscoveryFuture, future)) {
        _peerDiscoveryFuture = null;
      }
    }
  }

  Future<List<LanSyncPeerInfo>> _discoverPeersInternal(int port) async {
    _log('Starting peer discovery.');
    final peers = <String, LanSyncPeerInfo>{};

    try {
      final multicastPeers = await _discoverMulticastPeers();
      _log('Multicast discovery returned ${multicastPeers.length} peer(s).');
      for (final peer in multicastPeers) {
        peers[peer.address] = peer;
      }
    } catch (error, stackTrace) {
      _log('Multicast discovery failed: $error');
      debugPrintStack(
        label: '[LanSync] multicast discovery stack',
        stackTrace: stackTrace,
      );
    }

    final emulatorPeers = await _discoverEmulatorPeers(port);
    _log('Emulator discovery returned ${emulatorPeers.length} peer(s).');
    for (final peer in emulatorPeers) {
      peers[peer.address] = peer;
    }

    final availablePeers = peers.values.toList()
      ..sort((a, b) => a.address.compareTo(b.address));
    _log(
      'Peer discovery completed with ${availablePeers.length} unique peer(s): '
      '${availablePeers.map((peer) => peer.address).join(', ')}',
    );
    return availablePeers;
  }

  Future<void> _startMulticastDiscoveryListener(int syncPort) async {
    await LanSyncService._sharedDiscoverySubscription?.cancel();
    LanSyncService._sharedDiscoverySocket?.close();
    LanSyncService._sharedAnnouncementTimer?.cancel();
    LanSyncService._sharedDiscoverySubscription = null;
    LanSyncService._sharedDiscoverySocket = null;

    await _acquirePlatformMulticastLock();

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      LanSyncService._discoveryPort,
      reuseAddress: true,
    );
    socket.readEventsEnabled = true;
    socket.writeEventsEnabled = false;
    socket.multicastHops = 1;
    socket.multicastLoopback = false;
    await _joinDiscoveryMulticastGroups(socket);

    LanSyncService._sharedDiscoverySocket = socket;
    _log(
      'UDP discovery listener started on '
      '0.0.0.0:${LanSyncService._discoveryPort}.',
    );

    LanSyncService._sharedDiscoverySubscription = socket.listen((event) async {
      if (event != RawSocketEvent.read) {
        return;
      }

      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        await _handleDiscoveryDatagram(socket, datagram!, syncPort);
      }
    });

    _startAnnouncementTimer(syncPort);
    await _announcePresence(socket, syncPort, requestId: '', multicast: true);
  }

  Future<void> _joinDiscoveryMulticastGroups(RawDatagramSocket socket) async {
    final multicastGroup = InternetAddress(LanSyncService._multicastAddress);
    final interfaces = await _listPrivateIpv4Interfaces();

    if (interfaces.isEmpty) {
      socket.joinMulticast(multicastGroup);
      _log(
        'Joined multicast group ${LanSyncService._multicastAddress} '
        'using default interface.',
      );
      return;
    }

    final joinedInterfaces = <String>{};
    for (final interface in interfaces) {
      try {
        socket.joinMulticast(multicastGroup, interface);
        joinedInterfaces.add(interface.name);
        _log(
          'Joined multicast group ${LanSyncService._multicastAddress} '
          'on interface ${interface.name}.',
        );
      } catch (error) {
        _log(
          'Failed to join multicast group ${LanSyncService._multicastAddress} '
          'on interface ${interface.name}: $error',
        );
      }
    }

    if (joinedInterfaces.isNotEmpty) {
      return;
    }

    socket.joinMulticast(multicastGroup);
    _log(
      'Joined multicast group ${LanSyncService._multicastAddress} using '
      'default interface after per-interface join failed.',
    );
  }

  Future<void> _handleDiscoveryDatagram(
    RawDatagramSocket socket,
    Datagram datagram,
    int syncPort,
  ) async {
    final message = LanSyncService.decodeDiscoveryMessageForTesting(
      datagram.data,
    );
    if (message == null) {
      return;
    }

    final messageType = '${message[LanSyncService._discoveryTypeKey] ?? ''}'
        .trim();
    if (messageType == LanSyncService._discoveryResponseType) {
      _log(
        'Received announce from ${datagram.address.address}:${datagram.port}.',
      );
      unawaited(_registerDiscoveryAnnouncement(message));
      return;
    }
    if (messageType != LanSyncService._discoveryProbeType) {
      return;
    }

    final requestId = '${message[LanSyncService._discoveryRequestIdKey] ?? ''}'
        .trim();
    final requesterInstanceId =
        '${message[LanSyncService._discoveryInstanceIdKey] ?? ''}'.trim();
    if (requestId.isEmpty || requesterInstanceId == _instanceId) {
      return;
    }

    _log(
      'Received discover from ${datagram.address.address}:${datagram.port} '
      'requestId=$requestId.',
    );
    await _announcePresence(
      socket,
      syncPort,
      requestId: requestId,
      multicast: true,
      targetAddress: datagram.address,
      targetPort: datagram.port,
    );
  }

  Future<List<LanSyncPeerInfo>> _discoverMulticastPeers() async {
    final socket = LanSyncService._sharedDiscoverySocket;
    if (socket == null) {
      _log('Discovery listener is unavailable.');
      return cachedPeers;
    }

    final requestId = _buildRequestId();
    final payload = LanSyncService.encodeDiscoveryProbeForTesting(
      requestId: requestId,
      instanceId: _instanceId,
    );
    _log(
      'Sending discover to ${LanSyncService._multicastAddress}:'
      '${LanSyncService._discoveryPort} requestId=$requestId.',
    );
    await _sendDatagramViaInterfaces(
      payload,
      InternetAddress(LanSyncService._multicastAddress),
      LanSyncService._discoveryPort,
      fallbackSocket: socket,
      logLabel: 'discover',
      preserveSourcePort: true,
    );

    await Future<void>.delayed(LanSyncService._discoveryTimeout);
    return cachedPeers;
  }

  void _startAnnouncementTimer(int syncPort) {
    LanSyncService._sharedAnnouncementTimer?.cancel();
    LanSyncService._sharedAnnouncementTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        final socket = LanSyncService._sharedDiscoverySocket;
        if (socket == null) {
          return;
        }
        unawaited(
          _announcePresence(socket, syncPort, requestId: '', multicast: true),
        );
      },
    );
  }

  Future<void> _announcePresence(
    RawDatagramSocket socket,
    int syncPort, {
    required String requestId,
    required bool multicast,
    InternetAddress? targetAddress,
    int? targetPort,
  }) async {
    final hosts = (await _listSelfAddresses()).toList()
      ..sort(_comparePeerHosts);
    if (hosts.isEmpty) {
      _log('No private IPv4 addresses available for announcement.');
      return;
    }

    final response = LanSyncService.encodeDiscoveryResponseForTesting(
      requestId: requestId,
      instanceId: _instanceId,
      name: await _getDeviceName(),
      port: syncPort,
      exportPath: LanSyncService._serviceExportPath,
      hosts: hosts,
    );

    if (multicast) {
      _log(
        'Broadcasting announce to '
        '${LanSyncService._multicastAddress}:${LanSyncService._discoveryPort}.',
      );
      await _sendDatagramViaInterfaces(
        response,
        InternetAddress(LanSyncService._multicastAddress),
        LanSyncService._discoveryPort,
        fallbackSocket: socket,
        logLabel: 'announce',
      );
    }

    if (targetAddress != null && targetPort != null) {
      _log('Sending direct announce to ${targetAddress.address}:$targetPort.');
      await _sendDatagramViaInterfaces(
        response,
        targetAddress,
        targetPort,
        fallbackSocket: socket,
        logLabel: 'direct-announce',
      );
    }
  }

  Future<void> _sendDatagramViaInterfaces(
    List<int> payload,
    InternetAddress destination,
    int port, {
    required RawDatagramSocket fallbackSocket,
    required String logLabel,
    bool preserveSourcePort = false,
  }) async {
    if (preserveSourcePort) {
      fallbackSocket.send(payload, destination, port);
      _log(
        'Sent $logLabel via bound listener socket to '
        '${destination.address}:$port.',
      );
    }

    final sourceAddresses = await _listSelfAddresses();
    if (sourceAddresses.isEmpty) {
      if (!preserveSourcePort) {
        fallbackSocket.send(payload, destination, port);
        _log(
          'Sent $logLabel via fallback socket to '
          '${destination.address}:$port.',
        );
      }
      return;
    }

    var sent = preserveSourcePort;
    final sortedAddresses = sourceAddresses.toList()..sort(_comparePeerHosts);
    for (final sourceAddress in sortedAddresses) {
      try {
        final sender = await RawDatagramSocket.bind(
          InternetAddress(sourceAddress),
          0,
        );
        try {
          sender.writeEventsEnabled = false;
          sender.readEventsEnabled = false;
          sender.multicastHops = 1;
          sender.multicastLoopback = false;
          sender.send(payload, destination, port);
          sent = true;
          _log(
            'Sent $logLabel from $sourceAddress '
            'to ${destination.address}:$port.',
          );
        } finally {
          sender.close();
        }
      } catch (error) {
        _log(
          'Failed to send $logLabel from $sourceAddress to '
          '${destination.address}:$port: $error',
        );
      }
    }

    if (!sent && !preserveSourcePort) {
      fallbackSocket.send(payload, destination, port);
      _log(
        'Sent $logLabel via fallback socket to ${destination.address}:$port.',
      );
    }
  }

  Future<void> _registerDiscoveryAnnouncement(
    Map<String, dynamic> message,
  ) async {
    final selfAddresses = await _listSelfAddresses();
    final candidates = _extractPeerCandidates(
      message,
      selfAddresses: selfAddresses,
      selfInstanceId: _instanceId,
    );
    if (candidates.isEmpty) {
      return;
    }

    for (final candidate in candidates) {
      _log(
        'Probing announced peer ${candidate.host}:${candidate.port} '
        'exportPath=${candidate.exportPath}.',
      );
      final peer = await _probePeer(
        candidate.host,
        candidate.port,
        exportPath: candidate.exportPath,
        advertisedName: candidate.name,
      );
      if (peer != null) {
        _mergeCachedPeer(peer);
        _log('Registered announced peer ${peer.name} at ${peer.address}.');
        return;
      }
    }
  }

  void _mergeCachedPeer(LanSyncPeerInfo peer) {
    final next = <String, LanSyncPeerInfo>{
      for (final item in _cachedPeers) item.address: item,
    };
    next[peer.address] = peer;
    _cachedPeers = next.values.toList()
      ..sort((a, b) => a.address.compareTo(b.address));
  }

  Future<LanSyncPeerInfo?> _probePeer(
    String host,
    int port, {
    String? displayAddress,
    String? exportPath,
    String? advertisedName,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1200)
      ..badCertificateCallback = (certificate, host, port) {
        final fingerprint = sha256.convert(certificate.der).toString();
        if (host.isEmpty || port <= 0) {
          return false;
        }
        return fingerprint == LanSyncService._certificateFingerprint;
      };

    try {
      final request = await client.getUrl(
        Uri.parse('https://$host:$port${LanSyncService._serviceInfoPath}'),
      );
      final response = await request.close().timeout(
        const Duration(milliseconds: 1500),
      );
      if (response.statusCode != HttpStatus.ok) {
        _log(
          'Probe to $host:$port returned HTTP ${response.statusCode} '
          'on ${LanSyncService._serviceInfoPath}.',
        );
        return null;
      }

      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final rawName = '${decoded['name'] ?? host}'.trim();
      final name = _normalizePeerName(
        rawName,
        host,
        fallbackName: advertisedName,
      );
      final resolvedExportPath = _normalizeExportPath(
        exportPath ??
            '${decoded['exportUrl'] ?? LanSyncService._serviceExportPath}',
      );
      return LanSyncPeerInfo(
        name: name.isEmpty ? host : name,
        address: displayAddress ?? '$host:$port',
        exportUrl: 'https://$host:$port$resolvedExportPath',
      );
    } on SocketException catch (error) {
      _log('Probe socket error for $host:$port: $error');
      return null;
    } on TimeoutException catch (error) {
      _log('Probe timeout for $host:$port: $error');
      return null;
    } on HandshakeException catch (error) {
      _log('Probe TLS handshake failed for $host:$port: $error');
      return null;
    } on HttpException catch (error) {
      _log('Probe HTTP error for $host:$port: $error');
      return null;
    } on FormatException catch (error) {
      _log('Probe response format error for $host:$port: $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Set<String>> _listSelfAddresses() async {
    return {
      for (final interface in await _listPrivateIpv4Interfaces())
        ...interface.addresses
            .map((address) => address.address)
            .where(_isPrivateIpv4),
    };
  }

  Future<List<NetworkInterface>> _listPrivateIpv4Interfaces() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    return interfaces
        .where(
          (interface) => interface.addresses.any(
            (address) => _isPrivateIpv4(address.address),
          ),
        )
        .toList();
  }

  int _comparePeerHosts(String a, String b) {
    final aScore = _hostPriority(a);
    final bScore = _hostPriority(b);
    if (aScore != bScore) {
      return aScore.compareTo(bScore);
    }

    return a.compareTo(b);
  }

  int _hostPriority(String host) {
    if (host.startsWith('192.168.')) {
      return 0;
    }
    if (host.startsWith('172.')) {
      return 1;
    }
    if (host.startsWith('10.')) {
      return 2;
    }
    if (host == '127.0.0.1') {
      return 3;
    }

    return 4;
  }

  Future<List<LanSyncPeerInfo>> _discoverEmulatorPeers(int targetPort) async {
    final adbPath = _resolveAdbPath();
    if (adbPath == null) {
      return const [];
    }

    try {
      final devicesResult = await Process.run(adbPath, ['devices']);
      if (devicesResult.exitCode != 0) {
        _log('adb devices failed with exit code ${devicesResult.exitCode}.');
        return const [];
      }

      final lines = '${devicesResult.stdout}'.split('\n');
      final emulatorSerials = lines
          .map((line) => line.trim())
          .where(
            (line) => line.startsWith('emulator-') && line.endsWith('\tdevice'),
          )
          .map((line) => line.split('\t').first)
          .toList();

      final peers = <LanSyncPeerInfo>[];
      for (final serial in emulatorSerials) {
        final serialPort = int.tryParse(serial.split('-').last);
        final localPort = serialPort == null ? null : 42000 + serialPort;
        if (localPort == null) {
          continue;
        }

        final forwardResult = await Process.run(adbPath, [
          '-s',
          serial,
          'forward',
          'tcp:$localPort',
          'tcp:$targetPort',
        ]);
        if (forwardResult.exitCode != 0) {
          _log(
            'adb forward failed for $serial '
            'with exit code ${forwardResult.exitCode}.',
          );
          continue;
        }

        final peer = await _probePeer(
          '127.0.0.1',
          localPort,
          displayAddress: '$serial (127.0.0.1:$localPort)',
        );
        if (peer != null) {
          peers.add(
            LanSyncPeerInfo(
              name: '${peer.name} [$serial]',
              address: '$serial (127.0.0.1:$localPort)',
              exportUrl: peer.exportUrl,
            ),
          );
        }
      }

      return peers;
    } on ProcessException catch (error) {
      _log('Emulator discovery process exception: $error');
      return const [];
    }
  }
}
