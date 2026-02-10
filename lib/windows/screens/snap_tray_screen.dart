import 'package:flutter/material.dart';
import 'package:snappath_tray/logic/clipboard_engine.dart';
import 'package:snappath_tray/ui/widgets/history_item_tile.dart';
import 'package:snappath_tray/shared/theme_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:snappath_tray/shared/connection_status_chip.dart';
import 'package:snappath_tray/shared/supabase_auth_service.dart';

class SnapTrayScreen extends StatefulWidget {
  const SnapTrayScreen({super.key});

  @override
  State<SnapTrayScreen> createState() => _SnapTrayScreenState();
}

class _SnapTrayScreenState extends State<SnapTrayScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<SmartAction> _history = [];
  final LocalAuthentication _auth = LocalAuthentication();

  final FocusNode _inputFocusNode = FocusNode();

  // UI State
  SmartActionType? _selectedFilter;
  bool _isAppLocked = false;
  bool _isSearchActive = false;
  String _searchQuery = "";

  // Settings State
  double _uiScale = 1.0;

  // Security State
  final bool _isBiometricEnabled = false;
  String? _userPin;

  // Connection State
  // Removed local state in favor of ClipboardEngine stream

  @override
  void initState() {
    super.initState();
    _initEngine();

    // Auto-focus input on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
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

    // Smart Parsing Logic
    final lowerText = text.toLowerCase();

    // 1. Image Check (Extensions)
    if (lowerText.endsWith('.jpg') ||
        lowerText.endsWith('.jpeg') ||
        lowerText.endsWith('.png') ||
        lowerText.endsWith('.gif') ||
        lowerText.endsWith('.webp')) {
      type = SmartActionType.image;
    }
    // 2. File Check (Path or common doc extensions)
    else if (lowerText.endsWith('.pdf') ||
        lowerText.endsWith('.doc') ||
        lowerText.endsWith('.docx') ||
        lowerText.endsWith('.txt') ||
        text.contains(r':\') || // Windows Path
        text.startsWith('/')) {
      // Unix Path
      type = SmartActionType.file;
    }
    // 3. Email Check
    else if (RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(text)) {
      type = SmartActionType.email;
    }
    // 4. Phone Check (Digits, spaces, dashes, plus)
    else if (RegExp(r'^\+?[0-9\-\s]{7,15}$').hasMatch(text)) {
      type = SmartActionType.phone;
    }
    // 5. URL Check
    else if (text.startsWith("http") ||
        text.startsWith("www.") ||
        text.contains(".com")) {
      type = SmartActionType.url;
    }

    final action = SmartAction(type: type, content: text, isMe: true);

    ClipboardEngine().publishAction(action);

    setState(() {
      _history.insert(0, action);
      _textController.clear();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      final action = SmartAction(
        type: SmartActionType.image,
        content: image.path,
      );
      setState(() => _history.insert(0, action));
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.single;
      final action = SmartAction(
        type: SmartActionType.file,
        content: file.name,
      );
      setState(() => _history.insert(0, action));
    }
  }

  Future<void> _authenticate() async {
    if (_isBiometricEnabled) {
      bool authenticated = false;
      try {
        authenticated = await _auth.authenticate(
          localizedReason: 'Scan your fingerprint to authenticate',
          // removing options to be safe with versioning, or use named params if old version
          // options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
      } catch (e) {
        debugPrint("Auth Error: $e");
      }

      if (authenticated) {
        setState(() => _isAppLocked = false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication Failed')),
          );
        }
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

  // ... (Input Area is fine now hopefully)

  // ... (Removed duplicate _buildLockedScreen)

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
                setState(() => _userPin = pinController.text);
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
              const Icon(
                Icons.desktop_windows,
                size: 64,
                color: Colors.deepPurpleAccent,
              ), // Different icon for Windows
              const SizedBox(height: 16),
              const Text(
                "SnapTray",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                "v1.0.0 (Windows)",
                style: TextStyle(color: Colors.grey),
              ),
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
    _textController.dispose();
    _searchController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAppLocked) {
      return _buildLockedScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildTopBar(), // Fixed Header
          if (_selectedFilter != null) _buildActiveFilterIndicator(),
          Expanded(child: _buildHistoryList()),
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(_uiScale)),
            child: _buildInputArea(),
          ),
        ],
      ),
    );
  }

  // Theme Palette Helper
  ({
    Color topBar,
    Color inputBar,
    Color sentBubble,
    Color receivedBubble,
    Color text,
  })
  _getThemePalette() {
    // Default Theme
    return (
      topBar: Theme.of(context).colorScheme.surface,
      inputBar: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      sentBubble: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      receivedBubble: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      text: Theme.of(context).colorScheme.onSurface,
    );
  }

  BoxDecoration _getBackgroundDecoration() {
    return const BoxDecoration(color: Colors.transparent);
  }

  Widget _buildTopBar() {
    final palette = _getThemePalette();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: palette.topBar, // Unified TopBar Color
      child: _isSearchActive
          ? _buildSearchBar()
          : Stack(
              alignment: Alignment.center,
              children: [
                // Left: Hamburger Menu (Combined Settings & Filter)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<dynamic>(
                    icon: Icon(
                      Icons.menu, // 3 line bar
                      size: 28,
                    ),
                    tooltip: "Menu",
                    itemBuilder: (context) {
                      final themeMode = ThemeController.themeMode.value;
                      final isDark =
                          themeMode == ThemeMode.dark ||
                          (themeMode == ThemeMode.system &&
                              MediaQuery.platformBrightnessOf(context) ==
                                  Brightness.dark);

                      return [
                        // --- Filter Section ---
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            "FILTER BY",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        _buildFilterMenuItem(
                          null,
                          "All Items",
                          Icons.all_inclusive,
                        ),
                        _buildFilterMenuItem(
                          SmartActionType.text,
                          "Text",
                          Icons.text_fields,
                        ),
                        _buildFilterMenuItem(
                          SmartActionType.url,
                          "Links",
                          Icons.link,
                        ),
                        _buildFilterMenuItem(
                          SmartActionType.image,
                          "Images",
                          Icons.image,
                        ),
                        _buildFilterMenuItem(
                          SmartActionType.file,
                          "Files",
                          Icons.insert_drive_file,
                        ),

                        const PopupMenuDivider(),

                        // --- Settings Section ---
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            "SETTINGS",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        // Dark Mode Toggle
                        PopupMenuItem(
                          enabled: false,
                          child: StatefulBuilder(
                            builder: (context, setState) {
                              return SwitchListTile(
                                title: const Text("Dark Mode"),
                                value: isDark,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (bool value) {
                                  ThemeController.toggleTheme();
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        _buildActionMenuItem(
                          "lock",
                          "Lock SnapTray",
                          Icons.lock_outline,
                          _isAppLocked ? Colors.green : null,
                        ),
                        _buildActionMenuItem(
                          "pin",
                          "Set / Change PIN",
                          Icons.dialpad,
                          _userPin != null ? Colors.blue : null,
                        ),
                        _buildActionMenuItem(
                          "logout",
                          "Log Out",
                          Icons.logout,
                          Colors.redAccent,
                        ),
                        _buildActionMenuItem(
                          "about",
                          "About SnapTray",
                          Icons.info_outline,
                          null,
                        ),
                      ];
                    },
                    onSelected: (value) async {
                      if (value is SmartActionType?) {
                        setState(() => _selectedFilter = value);
                      } else if (value is String) {
                        switch (value) {
                          case "lock":
                            setState(() => _isAppLocked = true);
                            break;
                          case "pin":
                            _showSetPinDialog();
                            break;
                          case "logout":
                            // Assuming parent rebuilds on auth state change or we restart app.
                            // For this architecture, best to pop or restart.
                            // Since we wrapped MaterialApp, we need a way to signal App to rebuild.

                            // If we clear state and trigger a rebuild of the main App widget...
                            // The easiest way is to use a global event or callback if possible.
                            // Or just restart the app logic.
                            // Actually, since SnapTrayScreen is inside the MaterialApp, we can't easily rebuild the root.
                            // BUT, we can just clear prefs and tell user to restart or handle it if we had a state management solution.
                            // Let's implement a simple "Restart" or verify connection to parent.
                            // Ideally, we pass a logout callback. But simpler:
                            await SupabaseAuthService().logout();
                            // Hack for prototype: Trigger a full app re-evaluation
                            // In a real app we'd use Riverpod/Provider/Bloc.
                            // We will show a dialog saying "Logged Out" and use phoenix/restart or just navigating.
                            if (mounted) {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const Scaffold(
                                    body: Center(
                                      child: Text(
                                        "Logged Out. Please Restart.",
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              // In a real scenario with proper state lifting:
                              // widget.onLogout();
                            }
                            // Actually, in the `_SnapTrayAppState`, we can check login status on resume?
                            // Or better, let's just make it simple:
                            // Since we are in `windows/app.dart`, we don't have easy access to `setState` of that parent from here.
                            // I'll update it to just show a "Logged Out" message for now as a PoC.
                            break;
                          case "about":
                            _showAboutDialog();
                            break;
                        }
                      }
                    },
                  ),
                ),

                // Center: Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SnapTray',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<bool>(
                      stream: ClipboardEngine().statusStream,
                      initialData: ClipboardEngine().isConnected,
                      builder: (context, snapshot) {
                        final isConnected = snapshot.data ?? false;
                        return ConnectionStatusChip(isConnected: isConnected);
                      },
                    ),
                  ],
                ),

                // Right: Search
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.search_rounded),
                    onPressed: () => setState(() => _isSearchActive = true),
                    tooltip: "Search",
                  ),
                ),
              ],
            ),
    );
  }

  // _showConnectionDialog removed as authentication and connection are handled via Supabase

  // Helper for Filter Menu Items
  PopupMenuItem<SmartActionType?> _buildFilterMenuItem(
    SmartActionType? value,
    String text,
    IconData icon,
  ) {
    final isSelected = _selectedFilter == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : null,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  // Helper for Action Menu Items
  PopupMenuItem<String> _buildActionMenuItem(
    String value,
    String text,
    IconData icon,
    Color? iconColor,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: "Search history...",
                border: InputBorder.none,
                isDense: true, // Compact for desktop
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _isSearchActive = false;
                _searchController.clear();
                _searchQuery = "";
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            "Filter: ",
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            _getFilterName(_selectedFilter!),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedFilter = null),
            child: const Icon(Icons.close, size: 14, color: Colors.grey),
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
    final palette = _getThemePalette();

    List<SmartAction> filtered = _selectedFilter == null
        ? _history
        : _history.where((item) => item.type == _selectedFilter).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) => item.content.toLowerCase().contains(_searchQuery))
          .toList();
    }

    Widget content;
    if (filtered.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_none, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text("No items", style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return HistoryItemTile(
            action: item,
            customBubbleColor: item.isMe
                ? palette.sentBubble
                : palette.receivedBubble,
            customTextColor: palette.text,
          );
        },
      );
    }

    return Expanded(
      child: Container(
        decoration: _getBackgroundDecoration(),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(_uiScale)),
          child: content,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final palette = _getThemePalette();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: palette.inputBar,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add_circle_outline, color: null),
            tooltip: "Attach",
            onSelected: (value) {
              if (value == 'gallery') _pickImage(ImageSource.gallery);
              if (value == 'file') _pickFile();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'gallery',
                child: Row(
                  children: [
                    Icon(Icons.photo_library),
                    SizedBox(width: 12),
                    Text('Photos / Videos'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'file',
                child: Row(
                  children: [
                    Icon(Icons.folder_open),
                    SizedBox(width: 12),
                    Text('File System'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                style: TextStyle(color: palette.text),
                onSubmitted: (_) {
                  _handleSend();
                  _inputFocusNode.requestFocus();
                },
                decoration: InputDecoration(
                  hintText: "Type or paste to Snap...",
                  hintStyle: TextStyle(color: palette.text.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              _handleSend();
              _inputFocusNode.requestFocus();
            },
            icon: Icon(
              Icons.send_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: "Send",
          ),
        ],
      ),
    );
  }

  Widget _buildLockedScreen() {
    return Scaffold(
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              const Text(
                "SnapTray Locked",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              if (_userPin != null) ...[
                TextField(
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                    hintText: "PIN",
                    counterText: "",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (val.length == 4) {
                      _verifyPin(val);
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],

              if (_isBiometricEnabled)
                FilledButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text("Use Windows Hello"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                )
              else if (_userPin == null && !_isBiometricEnabled)
                TextButton(
                  onPressed: () => setState(() => _isAppLocked = false),
                  child: const Text("Dev Unlock"),
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
