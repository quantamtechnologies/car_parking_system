import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class OfflineQueueStorage {
  OfflineQueueStorage._(this._prefs);

  final SharedPreferences _prefs;

  static Future<OfflineQueueStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OfflineQueueStorage._(prefs);
  }

  SharedPreferences get prefs => _prefs;
}

class OfflineQueueService {
  OfflineQueueService({required OfflineQueueStorage storage}) : _storage = storage;

  final OfflineQueueStorage _storage;
  static const _queueKey = 'smart_parking_offline_queue';

  Future<List<Map<String, dynamic>>> loadQueue() async {
    final raw = _storage.prefs.getStringList(_queueKey) ?? const [];
    return raw
        .map((item) => Map<String, dynamic>.from(jsonDecode(item) as Map))
        .toList(growable: true);
  }

  Future<void> enqueue(String kind, Map<String, dynamic> payload) async {
    final queue = await loadQueue();
    queue.add({
      'kind': kind,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _storage.prefs.setStringList(_queueKey, queue.map(jsonEncode).toList());
  }

  Future<void> clear() async {
    await _storage.prefs.remove(_queueKey);
  }

  Future<int> count() async => (await loadQueue()).length;

  Future<void> flush(SmartParkingApi api) async {
    final queue = await loadQueue();
    final remaining = <Map<String, dynamic>>[];

    for (final item in queue) {
      try {
        final kind = item['kind']?.toString() ?? '';
        final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? const {});
        switch (kind) {
          case 'entry':
            await api.createEntry(payload);
            break;
          case 'exit':
            await api.prepareExit(payload);
            break;
          case 'payment':
            await api.confirmCashPayment(payload);
            break;
          default:
            remaining.add(item);
        }
      } catch (_) {
        remaining.add(item);
      }
    }

    await _storage.prefs.setStringList(_queueKey, remaining.map(jsonEncode).toList());
  }
}
