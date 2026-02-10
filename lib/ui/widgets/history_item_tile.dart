import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snappath_tray/logic/clipboard_engine.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryItemTile extends StatelessWidget {
  final SmartAction action;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final Color? customBubbleColor;
  final Color? customTextColor;

  const HistoryItemTile({
    super.key,
    required this.action,
    this.onDelete,
    this.onTap,
    this.customBubbleColor,
    this.customTextColor,
  });

  @override
  Widget build(BuildContext context) {
    bool isLinkOrFile =
        action.type == SmartActionType.url ||
        action.type == SmartActionType.file ||
        action.type == SmartActionType.image ||
        action.type == SmartActionType.phone ||
        action.type == SmartActionType.email;

    final isMe = action.isMe;
    final alignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    // Use custom color if provided, otherwise default logic
    final bubbleColor =
        customBubbleColor ??
        (isMe
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));

    final textColor =
        customTextColor ?? Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (Only for received messages)
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getColor(context).withValues(alpha: 0.2),
              child: Icon(_getIcon(), size: 16, color: _getColor(context)),
            ),
            const SizedBox(width: 8),
          ],

          // Chat Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.content,
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Actions
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: action.content),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to Clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.copy, size: 14, color: Colors.grey),
                        ),
                      ),
                      if (onDelete != null) ...[
                        // Delete Action
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                      if (isLinkOrFile) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _launchAction,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Avatar (Hidden for sent messages)
        ],
      ),
    );
  }

  Future<void> _launchAction() async {
    try {
      final Uri uri;
      if (action.type == SmartActionType.url) {
        uri = Uri.parse(action.content);
      } else if (action.type == SmartActionType.email) {
        uri = Uri.parse('mailto:${action.content}');
      } else if (action.type == SmartActionType.phone) {
        uri = Uri.parse('tel:${action.content}');
      } else {
        // Fallback for files/images (basic attempt)
        uri = Uri.parse(action.content);
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Try launching as external application mode for non-web links
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch: $e");
    }
  }

  IconData _getIcon() {
    switch (action.type) {
      case SmartActionType.url:
        return Icons.link;
      case SmartActionType.email:
        return Icons.email;
      case SmartActionType.phone:
        return Icons.phone;
      case SmartActionType.image:
        return Icons.image;
      case SmartActionType.file:
        return Icons.insert_drive_file;
      default:
        return Icons.text_fields;
    }
  }

  Color _getColor(BuildContext context) {
    switch (action.type) {
      case SmartActionType.url:
        return Colors.blue;
      case SmartActionType.email:
        return Colors.red;
      case SmartActionType.phone:
        return Colors.green;
      case SmartActionType.image:
        return Colors.purple;
      case SmartActionType.file:
        return Colors.orangeAccent;
      default:
        return Theme.of(context).primaryColor;
    }
  }
}
