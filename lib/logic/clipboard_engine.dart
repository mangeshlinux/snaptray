import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SmartActionType { url, email, phone, text, image, file }

class SmartAction {
  final SmartActionType type;
  final String content;
  final bool isMe;

  SmartAction({required this.type, required this.content, this.isMe = false});

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'content': content,
    'isMe': isMe,
  };

  factory SmartAction.fromJson(Map<String, dynamic> json) {
    return SmartAction(
      type: SmartActionType.values[json['type'] ?? 3],
      content: json['content'] ?? '',
      isMe: json['isMe'] ?? false,
    );
  }
}

class ClipboardEngine with ClipboardListener {
  static final ClipboardEngine _instance = ClipboardEngine._internal();
  factory ClipboardEngine() => _instance;
  ClipboardEngine._internal();

  final _clipboardController = StreamController<SmartAction>.broadcast();
  Stream<SmartAction> get clipboardStream => _clipboardController.stream;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  // Supabase
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  String? _deviceId;
  String? _userId;

  // Encryption
  final _algorithm = AesGcm.with256bits();
  SecretKey? _secretKey;

  // Regex Patterns
  static final urlRegex = RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );
  static final emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );
  static final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');

  bool get isConnected => _supabase.auth.currentUser != null;

  Future<void> initialize() async {
    _userId = _supabase.auth.currentUser?.id;
    if (_userId == null) return;

    // 1. Initialize Encryption Key (Derive from User ID)
    await _initEncryption();

    // 2. Register/Get Device
    await _registerDevice();

    // 3. Subscribe to Realtime Messages
    _subscribeToMessages();

    // 4. Start Clipboard Watcher (Desktop only)
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      clipboardWatcher.addListener(this);
      await clipboardWatcher.start();
    }

    // 5. Load recent history
    _loadHistory();

    _statusController.add(true);
  }

  Future<void> _initEncryption() async {
    if (_userId == null) return;
    // Derive a stable key from the User ID using SHA-256
    final sha256 = Sha256();
    final hash = await sha256.hash(utf8.encode(_userId!));
    _secretKey = await _algorithm.newSecretKeyFromBytes(hash.bytes);
  }

  Future<void> _registerDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');

    if (_deviceId == null) {
      // Create new device registration
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Unknown Device';
      String deviceType = 'web';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceName = '${webInfo.browserName.name} on ${webInfo.platform}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
        deviceType = 'android';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceName = windowsInfo.computerName;
        deviceType = 'windows';
      }

      try {
        final response = await _supabase
            .from('devices')
            .insert({
              'user_id': _userId,
              'device_name': deviceName,
              'device_type': deviceType,
            })
            .select()
            .single();

        _deviceId = response['id'];
        await prefs.setString('device_id', _deviceId!);
      } catch (e) {
        print('Error registering device: $e');
      }
    }
  }

  void _subscribeToMessages() {
    _channel = _supabase.channel('public:messages');
    _channel
        ?.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            _handleIncomingMessage(newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> record) async {
    try {
      // Ignore own messages
      if (record['sender_device_id'] == _deviceId) return;

      final encryptedContent = record['encrypted_content'] as String;
      final decrypted = await _decrypt(encryptedContent);

      // Format: "TYPE|CONTENT"
      final parts = decrypted.split('|');
      if (parts.length < 2) return;

      final typeStr = parts[0];
      final content = parts.sublist(1).join('|');

      final type = SmartActionType.values.firstWhere(
        (e) => e.toString() == typeStr,
        orElse: () => SmartActionType.text,
      );

      final action = SmartAction(
        type: type,
        content: content,
        isMe: false, // Network message
      );

      _clipboardController.add(action);

      // If Desktop, update clipboard
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        // Only update if it's text/url for now to avoid side effects
        if (type == SmartActionType.text || type == SmartActionType.url) {
          await Clipboard.setData(ClipboardData(text: content));
        }
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(20);

      for (final record in response) {
        // Determine direction
        final isMe = record['sender_device_id'] == _deviceId;

        final encryptedContent = record['encrypted_content'] as String;
        final decrypted = await _decrypt(encryptedContent);

        final parts = decrypted.split('|');
        if (parts.length < 2) continue;

        final typeStr = parts[0];
        final content = parts.sublist(1).join('|');

        final type = SmartActionType.values.firstWhere(
          (e) => e.toString() == typeStr,
          orElse: () => SmartActionType.text,
        );

        final action = SmartAction(type: type, content: content, isMe: isMe);
        _clipboardController.add(action);
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  // --- Processing ---

  @override
  void onClipboardChanged() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      await _processText(data!.text!);
    }
  }

  Future<void> _processText(String text) async {
    SmartActionType type = SmartActionType.text;
    if (urlRegex.hasMatch(text)) {
      type = SmartActionType.url;
    } else if (emailRegex.hasMatch(text)) {
      type = SmartActionType.email;
    } else if (phoneRegex.hasMatch(text)) {
      type = SmartActionType.phone;
    }

    final action = SmartAction(
      type: type,
      content: text,
      isMe: true, // Local origin
    );

    // Add to Local UI
    _clipboardController.add(action);
    // Send to Cloud
    publishAction(action);
  }

  Future<void> publishAction(SmartAction action) async {
    if (_userId == null) return;

    final payload = "${action.type}|${action.content}";
    final encrypted = await _encrypt(payload);

    try {
      await _supabase.from('messages').insert({
        'user_id': _userId,
        // If device ID is null (very early race condition), use header?
        // We'll rely on initialized state.
        'sender_device_id': _deviceId,
        'message_type': action.type.name,
        'encrypted_content': encrypted,
      });
    } catch (e) {
      print('Error publishing: $e');
    }
  }

  // --- Crypto Helpers ---

  Future<String> _encrypt(String text) async {
    if (_secretKey == null) throw Exception("No Key");
    final secretBox = await _algorithm.encrypt(
      utf8.encode(text),
      secretKey: _secretKey!,
    );
    // Combine nonce + ciphertext + mac
    return base64Encode(secretBox.concatenation());
  }

  Future<String> _decrypt(String base64Content) async {
    if (_secretKey == null) throw Exception("No Key");
    final combined = base64Decode(base64Content);

    // AES-GCM 256: 12 bytes nonce, 16 bytes MAC
    final secretBox = SecretBox.fromConcatenation(
      combined,
      nonceLength: 12,
      macLength: 16,
    );

    final clearText = await _algorithm.decrypt(
      secretBox,
      secretKey: _secretKey!,
    );
    return utf8.decode(clearText);
  }
}
