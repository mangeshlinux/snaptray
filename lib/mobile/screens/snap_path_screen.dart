import 'package:flutter/material.dart';
import 'package:snappath_tray/logic/clipboard_engine.dart';
import 'package:snappath_tray/ui/widgets/history_item_tile.dart';
import 'package:snappath_tray/shared/theme_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snappath_tray/shared/connection_status_chip.dart';
import 'package:snappath_tray/shared/supabase_auth_service.dart';

class SnapPathScreen extends StatefulWidget {
  const SnapPathScreen({super.key});

  @override
  State<SnapPathScreen> createState() => _SnapPathScreenState();
}

class _SnapPathScreenState extends State<SnapPathScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final List<SmartAction> _history = [];
  final LocalAuthentication _auth = LocalAuthentication();
  SharedPreferences? _prefs;

  // UI State
  SmartActionType? _selectedFilter;
  bool _isAppLocked = false;

  // Security State
  bool _isBiometricEnabled = false;
  String? _userPin;

  // Theme State
  final FocusNode _inputFocusNode = FocusNode();
  double _textScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _initEngine();
    _loadSettings();

    WidgetsBinding.instance.addObserver(this);

    // Auto-focus input on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-focus when coming back to the app
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _userPin = _prefs?.getString('user_pin');
      _isBiometricEnabled = _prefs?.getBool('biometric_enabled') ?? false;
      _textScaleFactor = _prefs?.getDouble('text_scale_factor') ?? 1.0;
    });
  }

  Future<void> _initEngine() async {
    final engine = ClipboardEngine();
    await engine.initialize();

    engine.clipboardStream.listen((action) {
      if (mounted) {
        setState(() {
          _history.insert(0, action);
        });
      }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    SmartActionType type = SmartActionType.text;
    if (ClipboardEngine.urlRegex.hasMatch(text)) {
      type = SmartActionType.url;
    } else if (ClipboardEngine.emailRegex.hasMatch(text)) {
      type = SmartActionType.email;
    } else if (ClipboardEngine.phoneRegex.hasMatch(text)) {
      type = SmartActionType.phone;
    }

    // Create action with isMe = true for alignment
    final action = SmartAction(type: type, content: text, isMe: true);

    // Engine will handle publishing and local add via stream?
    // In new engine, _processText adds to stream AND publishes.
    // But here we are manually adding to history?
    // Let's defer to engine to process text which adds to stream.
    // But wait, the engine has `_processText` which is private.
    // I should probably make `ClipboardEngine` have a public `processText` or `sendText`.

    // Actually, looking at new engine code:
    // It has `publishAction`.
    // It has `_clipboardController` which `clipboardStream` comes from.
    // If I call `publishAction`, it goes to cloud. It does NOT presumably add to local stream unless I do it manually.
    // The old `_processText` did both.

    // Let's keep `_handleSend` logic here for UI update, but use `publishAction`.
    ClipboardEngine().publishAction(action);

    setState(() {
      _history.insert(0, action);
      _textController.clear();
    });
  }

  void _deleteItem(int index) {
    setState(() {
      _history.removeAt(index);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      final action = SmartAction(
        type: SmartActionType.image,
        content: image.path,
        isMe: true,
      );
      setState(() {
        _history.insert(0, action);
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = result.files.single;
      final action = SmartAction(
        type: SmartActionType.file,
        content: file.name,
        isMe: true,
      );
      setState(() {
        _history.insert(0, action);
      });
    }
  }

  Future<void> _authenticate() async {
    if (!_isBiometricEnabled) return;

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access SnapPath',
      );

      if (didAuthenticate) {
        setState(() => _isAppLocked = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Authentication error: $e')));
      }
    }
  }

  void _verifyPin(String inputPin) {
    if (inputPin == _userPin) {
      setState(() => _isAppLocked = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect PIN'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setPin(String pin) async {
    await _prefs?.setString('user_pin', pin);
    setState(() => _userPin = pin);
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (enabled) {
      final bool canAuthenticate =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometrics not supported on this device'),
            ),
          );
        }
        return;
      }
    }
    await _prefs?.setBool('biometric_enabled', enabled);
    setState(() => _isBiometricEnabled = enabled);
  }

  Future<void> _setTextScale(double scale) async {
    await _prefs?.setDouble('text_scale_factor', scale);
    setState(() => _textScaleFactor = scale);
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set App PIN"),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(hintText: "Enter 4-digit PIN"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text.length == 4) {
                _setPin(pinController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PIN Set Successfully")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Text("About"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apps, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                "SnapPath",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text("v1.1.0", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              const Text("Developed by Antigravity"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // Theme Palette Helper
  _getThemePalette() {
    // Default Theme
    return (
      topBar: Colors.transparent,
      inputBar: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      sentBubble: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      receivedBubble: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      text: Theme.of(context).colorScheme.onSurface,
    );
  }

  BoxDecoration _getBackgroundDecoration() {
    return BoxDecoration(color: Theme.of(context).colorScheme.surface);
  }

  // Helper for Theme Card Preview Gradient

  @override
  Widget build(BuildContext context) {
    if (_isAppLocked) {
      return _buildLockedScreen();
    }

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_textScaleFactor)),
      child: Scaffold(
        body: Container(
          decoration: _getBackgroundDecoration(),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                if (_selectedFilter != null) _buildActiveFilterIndicator(),
                Expanded(child: _buildHistoryList()),
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Text(
            'SnapPath',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 12),
          // Status Light
          StreamBuilder<bool>(
            stream: ClipboardEngine().statusStream,
            initialData: ClipboardEngine().isConnected,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              // Pass user email to chip if connected
              return ConnectionStatusChip(
                isConnected: isConnected,
                // We'll update the chip widget to accept an optional label or just handle it internally
                // For now, let's just keep isConnected.
              );
            },
          ),
          const Spacer(),
          // Filter Button
          PopupMenuButton<SmartActionType?>(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _selectedFilter != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onSelected: (type) {
              setState(() => _selectedFilter = type);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text("All")),
              const PopupMenuItem(
                value: SmartActionType.text,
                child: _FilterItem("Text", Icons.text_fields),
              ),
              const PopupMenuItem(
                value: SmartActionType.file,
                child: _FilterItem("Folder / File", Icons.folder),
              ),
              const PopupMenuItem(
                value: SmartActionType.image,
                child: _FilterItem("Images", Icons.image),
              ),
              const PopupMenuItem(
                value: SmartActionType.url,
                child: _FilterItem("Links", Icons.link),
              ),
              const PopupMenuItem(
                value: SmartActionType.email,
                child: _FilterItem("Mail", Icons.email),
              ),
              const PopupMenuItem(
                value: SmartActionType.phone,
                child: _FilterItem("Contacts", Icons.phone),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Settings Button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
    );
  }

  // _showConnectionDialog removed as authentication is handled via Supabase Auth

  Widget _buildActiveFilterIndicator() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            "Filtering by: ",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            _getFilterName(_selectedFilter!),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedFilter = null),
            child: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterName(SmartActionType type) {
    switch (type) {
      case SmartActionType.text:
        return "Text";
      case SmartActionType.file:
        return "Folder";
      case SmartActionType.image:
        return "Images";
      case SmartActionType.url:
        return "Links";
      case SmartActionType.email:
        return "Mail";
      case SmartActionType.phone:
        return "Contacts";
    }
  }

  Widget _buildHistoryList() {
    List<SmartAction> filtered = _selectedFilter == null
        ? _history
        : _history.where((item) => item.type == _selectedFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_none,
              size: 64,
              color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "No items found",
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return HistoryItemTile(
          action: filtered[index],
          onDelete: () => _deleteItem(index),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final palette = _getThemePalette();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _showAttachmentMenu,
            icon: Icon(
              Icons.attach_file,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                autofocus: true,
                onSubmitted: (_) => _handleSend(),
                decoration: const InputDecoration(
                  hintText: "Type or paste...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.small(
            onPressed: _handleSend,
            elevation: 0,
            backgroundColor: palette.sentBubble.withValues(alpha: 1.0),
            child: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Attach",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachmentOption(
                    Icons.camera_alt,
                    "Camera",
                    Colors.blue,
                    () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _AttachmentOption(Icons.photo, "Gallery", Colors.purple, () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  }),
                  _AttachmentOption(Icons.folder, "Files", Colors.orange, () {
                    Navigator.pop(context);
                    _pickFile();
                  }),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Settings",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.text_fields),
                    title: const Text("Text Size"),
                    trailing: DropdownButton<double>(
                      value: _textScaleFactor,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0.8, child: Text("Small")),
                        DropdownMenuItem(value: 1.0, child: Text("Normal")),
                        DropdownMenuItem(value: 1.2, child: Text("Large")),
                        DropdownMenuItem(
                          value: 1.5,
                          child: Text("Extra Large"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          // Use setState of the Sheet? No, text scale affects global app state, but we need to update the dropdown value locally?
                          // Actually the sheet rebuilds. Using a StatefulBuilder might be needed if this doesn't update, but standard ListTile usually works if parent rebuilds.
                          // Efficient way is to use the callback to update parent state.
                          _setTextScale(value);
                          Navigator.pop(
                            context,
                          ); // Close for immediate effect or just let it update
                        }
                      },
                    ),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text("Dark Theme"),
                    trailing: ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.themeMode,
                      builder: (context, mode, _) {
                        return Switch(
                          value: mode == ThemeMode.dark,
                          onChanged: (_) => ThemeController.toggleTheme(),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "Security",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),

                  // App Lock Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_outline,
                      color: _isAppLocked ? Colors.green : null,
                    ),
                    title: const Text("Lock App Now"),
                    subtitle: const Text("Require unlock immediately"),
                    trailing: Switch(
                      value: _isAppLocked,
                      onChanged: (val) {
                        Navigator.pop(context);
                        setState(() => _isAppLocked = true);
                      },
                    ),
                  ),

                  // PIN Setting
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.dialpad,
                      color: _userPin != null ? Colors.blue : null,
                    ),
                    title: Text(_userPin != null ? "Change PIN" : "Set PIN"),
                    subtitle: Text(
                      _userPin != null ? "PIN acts as fallback" : "Not set",
                    ),
                    onTap: _showSetPinDialog,
                    trailing: const Icon(Icons.chevron_right),
                  ),

                  // Biometric Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fingerprint),
                    title: const Text("Biometrics"),
                    subtitle: const Text("Fingerprint / Face Unlock"),
                    trailing: Switch(
                      value: _isBiometricEnabled,
                      onChanged: (val) {
                        _toggleBiometrics(val);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "Info",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: const Text("About SnapPath"),
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog();
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      await SupabaseAuthService().logout();
                      Navigator.pop(context); // Close Settings
                      if (mounted) {
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const Scaffold(
                              body: Center(
                                child: Text("Logged Out. Please Restart."),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Log Out",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLockedScreen() {
    final TextEditingController pinInputController = TextEditingController();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                "SnapPath Locked",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              if (_userPin != null) ...[
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: pinInputController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(
                      hintText: "Enter PIN",
                      counterText: "",
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        _verifyPin(val);
                        pinInputController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (_isBiometricEnabled)
                FilledButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text("Use Biometrics"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                )
              else if (_userPin == null)
                const Text(
                  "No Security Setup. (Click Settings > Security to config)",
                  style: TextStyle(color: Colors.red),
                ),

              if (_userPin == null && !_isBiometricEnabled)
                TextButton(
                  onPressed: () => setState(() => _isAppLocked = false),
                  child: const Text("Emergency Unlock (Dev Mode)"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FilterItem(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
