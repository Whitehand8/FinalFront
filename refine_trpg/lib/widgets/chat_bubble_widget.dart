// widgets/chat_bubble_widget.dart
import 'package:flutter/material.dart';

class ChatBubbleWidget extends StatelessWidget {
  final String playerName;
  final String message;
  final bool isMe; // Flag to indicate if the message is from the current user

  const ChatBubbleWidget({
    super.key,
    required this.playerName,
    required this.message,
    this.isMe = false, // Default to false (message from others)
  });

  @override
  Widget build(BuildContext context) {
    // Determine alignment and color based on isMe flag
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer;
    final textColor = isMe ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSecondaryContainer;
    final nameColor = isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    return Container(
      // Align the entire bubble container to the right if isMe is true
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        constraints: BoxConstraints(
           // Limit bubble width to 70% of screen width
           maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
             topLeft: const Radius.circular(12.0),
             topRight: const Radius.circular(12.0),
             bottomLeft: isMe ? const Radius.circular(12.0) : const Radius.circular(0), // Pointy corner for others
             bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12.0), // Pointy corner for me
          ),
          boxShadow: [ // Add subtle shadow for depth
             BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
             ),
          ],
        ),
        // Column holds the sender name and message content
        child: Column(
          // Align text content within the bubble (start for others, end for me)
          crossAxisAlignment: alignment,
          mainAxisSize: MainAxisSize.min, // Fit content size
          children: [
            // Display player name with specific color and bold style
            Text(
              playerName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: nameColor,
              ),
            ),
            const SizedBox(height: 4.0), // Spacing between name and message
            // Display the message content
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ),
              // Align text within the Text widget itself (useful for longer messages)
              textAlign: isMe ? TextAlign.end : TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
}
