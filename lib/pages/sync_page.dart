import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/password_repository.dart';
import '../services/lan_sync_service.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({
    super.key,
    required this.repository,
    required this.syncService,
  });

  final PasswordRepository repository;
  final LanSyncService syncService;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final TextEditingController _serverController = TextEditingController();

  List<LanSyncPeerInfo> _discoveredPeers = const [];
  LanSyncPeerInfo? _selectedPeer;
  StreamSubscription<LanSyncCompletionEvent>? _syncEventSubscription;
  bool _isSyncing = false;
  bool _isDiscovering = false;
  bool _isPreparing = true;
  String? _serviceError;

  @override
  void initState() {
    super.initState();
    _syncEventSubscription = widget.syncService.syncEvents.listen(
      _handleSyncEvent,
    );
    _initializeSync();
  }

  @override
  void dispose() {
    _syncEventSubscription?.cancel();
    _serverController.dispose();
    super.dispose();
  }

  void _handleSyncEvent(LanSyncCompletionEvent event) {
    _showMessage('收到对方 ${event.peerName} 设备的数据，已经同步完成');
  }

  Future<void> _initializeSync() async {
    setState(() {
      _isPreparing = true;
      _serviceError = null;
      _discoveredPeers = widget.syncService.cachedPeers;
    });

    try {
      if (!widget.syncService.isRunning) {
        await widget.syncService.startServer();
      }
    } catch (error, stackTrace) {
      debugPrint('Sync service start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _serviceError = '$error';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isPreparing = false;
      });
    }
  }

  Future<void> _discoverPeers() async {
    if (_isDiscovering) {
      return;
    }

    setState(() {
      _isDiscovering = true;
      _discoveredPeers = const [];
      _selectedPeer = null;
    });

    try {
      final peers = await widget.syncService.discoverPeers();
      if (!mounted) {
        return;
      }
      setState(() {
        _discoveredPeers = peers;
      });
    } catch (error) {
      _showMessage('扫描设备失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  Future<void> _syncSelectedPeer() async {
    final peer = _selectedPeer;
    if (peer == null) {
      _showMessage('请先选择要同步的设备');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await widget.syncService.syncWithPeer(peer.exportUrl);
    } catch (error) {
      _showMessage('同步失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _syncFromServer() async {
    final address = _serverController.text.trim();
    if (address.isEmpty) {
      _showMessage('请输入服务器 IP 或地址');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await widget.syncService.syncWithPeer(address);
    } catch (error) {
      _showMessage('同步失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final syncButtonLabel = _isSyncing
        ? '同步中...'
        : _selectedPeer == null
        ? '请选择设备'
        : '与 ${_selectedPeer!.name} 双向同步';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_serviceError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3B7B1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本机同步服务启动失败',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF9B3D34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _serviceError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9B3D34),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _SectionCard(
            title: '局域网同步',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _isDiscovering ? null : _discoverPeers,
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(_isDiscovering ? '扫描中...' : '扫描设备'),
                    ),
                    FilledButton.icon(
                      onPressed: _isSyncing || _selectedPeer == null
                          ? null
                          : _syncSelectedPeer,
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(syncButtonLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_isPreparing)
                  const Text('正在准备本机同步服务...')
                else if (_isDiscovering && _discoveredPeers.isEmpty)
                  const Text('正在扫描局域网设备...')
                else if (_discoveredPeers.isEmpty)
                  const Text('暂未发现可同步设备，点击“扫描设备”手动刷新。')
                else
                  Column(
                    children: _discoveredPeers.map((peer) {
                      final isSelected = _selectedPeer?.address == peer.address;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isSyncing
                              ? null
                              : () {
                                  setState(() {
                                    _selectedPeer = peer;
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE4EEE6)
                                  : const Color(0xFFF3EEE3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF607A69)
                                    : const Color(0xFFE1D9CB),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        peer.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(peer.address),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF607A69),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: '服务器同步',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: '192.168.1.23:40123 或 https://192.168.1.23:40123',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '输入服务器 IP、IP:端口或完整同步地址后，会与对方执行一次双向数据合并。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSyncing ? null : _syncFromServer,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(_isSyncing ? '同步中...' : '与服务器双向同步'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8E0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
