import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_app/services/lan_sync_service.dart';

void main() {
  group('LanSyncService multicast protocol', () {
    test('uses Android-compatible multicast address', () {
      expect(LanSyncService.multicastAddressForTesting, '224.0.0.167');
    });

    test('encodes and decodes discovery probe payload', () {
      final payload = LanSyncService.encodeDiscoveryProbeForTesting(
        requestId: 'req-1',
        instanceId: 'instance-a',
      );

      final decoded = LanSyncService.decodeDiscoveryMessageForTesting(payload);

      expect(decoded, isNotNull);
      expect(decoded!['type'], 'discover');
      expect(decoded['requestId'], 'req-1');
      expect(decoded['instanceId'], 'instance-a');
    });

    test('encodes and decodes response payload', () {
      final payload = LanSyncService.encodeDiscoveryResponseForTesting(
        requestId: 'req-1',
        instanceId: 'instance-b',
        name: 'Desktop',
        port: 40123,
        exportPath: '/sync/export',
        hosts: const ['192.168.1.9', '10.0.0.8'],
      );

      final decoded = LanSyncService.decodeDiscoveryMessageForTesting(payload);

      expect(decoded, isNotNull);
      expect(decoded!['type'], 'announce');
      expect(decoded['requestId'], 'req-1');
      expect(decoded['instanceId'], 'instance-b');
      expect(decoded['name'], 'Desktop');
      expect(decoded['port'], 40123);
      expect(decoded['exportPath'], '/sync/export');
      expect(decoded['scheme'], 'https');
      expect(decoded['fingerprint'], isNotEmpty);
      expect(decoded['hosts'], ['192.168.1.9', '10.0.0.8']);
    });

    test('returns null for invalid discovery message payload', () {
      expect(
        LanSyncService.decodeDiscoveryMessageForTesting(
          utf8.encode('not-json'),
        ),
        isNull,
      );
    });

    test('builds peer candidates from valid response payload', () {
      final candidates = LanSyncService.extractPeerCandidatesForTesting(
        {
          'type': 'announce',
          'requestId': 'req-1',
          'instanceId': 'instance-b',
          'name': 'Desktop',
          'scheme': 'https',
          'fingerprint': LanSyncService.certificateFingerprintForTesting,
          'port': 40123,
          'exportPath': 'sync/export',
          'hosts': ['192.168.1.9', '8.8.8.8', '192.168.1.9'],
        },
        selfAddresses: const {'192.168.1.7'},
        selfInstanceId: 'instance-a',
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.name, 'Desktop');
      expect(candidates.single.host, '192.168.1.9');
      expect(candidates.single.port, 40123);
      expect(candidates.single.exportPath, '/sync/export');
      expect(candidates.single.dedupKey, 'instance-b|192.168.1.9|40123');
    });

    test('rejects self response, invalid fingerprint and invalid port', () {
      expect(
        LanSyncService.extractPeerCandidatesForTesting(
          {
            'type': 'announce',
            'requestId': 'req-1',
            'instanceId': 'instance-a',
            'scheme': 'https',
            'fingerprint': LanSyncService.certificateFingerprintForTesting,
            'port': 40123,
            'hosts': ['192.168.1.8'],
          },
          selfAddresses: const {'192.168.1.7'},
          selfInstanceId: 'instance-a',
        ),
        isEmpty,
      );

      expect(
        LanSyncService.extractPeerCandidatesForTesting(
          {
            'type': 'announce',
            'requestId': 'req-1',
            'instanceId': 'instance-b',
            'scheme': 'https',
            'fingerprint': 'different',
            'port': 40123,
            'hosts': ['192.168.1.8'],
          },
          selfAddresses: const {'192.168.1.7'},
          selfInstanceId: 'instance-a',
        ),
        isEmpty,
      );

      expect(
        LanSyncService.extractPeerCandidatesForTesting(
          {
            'type': 'announce',
            'requestId': 'req-1',
            'instanceId': 'instance-b',
            'scheme': 'https',
            'fingerprint': LanSyncService.certificateFingerprintForTesting,
            'port': 0,
            'hosts': ['192.168.1.8'],
          },
          selfAddresses: const {'192.168.1.7'},
          selfInstanceId: 'instance-a',
        ),
        isEmpty,
      );
    });

    test('filters out self addresses from response payload', () {
      final candidates = LanSyncService.extractPeerCandidatesForTesting(
        {
          'type': 'announce',
          'requestId': 'req-1',
          'instanceId': 'instance-b',
          'scheme': 'https',
          'fingerprint': LanSyncService.certificateFingerprintForTesting,
          'port': 40123,
          'hosts': ['192.168.1.7', '10.0.0.4', '192.168.1.12'],
        },
        selfAddresses: const {'192.168.1.7', '10.0.0.4'},
        selfInstanceId: 'instance-a',
      );

      expect(candidates.map((item) => item.host).toList(), ['192.168.1.12']);
    });
  });
}
