import 'package:flutter/foundation.dart'; // For debugPrint

// lib/models/chat.dart
class ChatMessage {
  // Use int? for ID as it comes from the backend database (might be null for optimistic updates).
  final int? id;
  // Use int for senderId as per backend DTO.
  final int senderId;
  final String content;
  // Use DateTime and name it 'sentAt' to match backend DTO.
  final DateTime sentAt;
  // Removed 'sender' nickname field - Not part of the core message data from backend.
  // Fetch sender info separately in the UI if needed, using senderId.

  ChatMessage({
    this.id,
    required this.senderId,
    required this.content,
    required this.sentAt,
  });

  /// Creates a ChatMessage from a JSON map, matching the backend's MessageResponseDto.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    int? parsedId;
    if (json['id'] != null) {
      // Ensure ID is parsed as int. Handle potential String case if necessary.
      if (json['id'] is String) {
        parsedId = int.tryParse(json['id']);
      } else if (json['id'] is int) {
        parsedId = json['id'];
      } else {
         debugPrint('Warning: ChatMessage ID format unexpected: ${json['id']}');
      }
    }

    int parsedSenderId;
    // Ensure senderId is parsed as int.
    if (json['senderId'] is String) {
        parsedSenderId = int.tryParse(json['senderId'] ?? '') ?? 0; // Default to 0 or handle error
    } else if (json['senderId'] is int) {
        parsedSenderId = json['senderId'];
    } else {
        debugPrint('Warning: ChatMessage senderId format unexpected: ${json['senderId']}');
        parsedSenderId = 0; // Default or throw error
    }


    DateTime parsedSentAt;
    try {
      // Backend sends 'sentAt' as an ISO 8601 string.
      parsedSentAt = DateTime.parse(json['sentAt'] as String);
    } catch (e) {
      debugPrint('Error parsing sentAt timestamp: ${json['sentAt']} - $e');
      parsedSentAt = DateTime.now(); // Fallback to current time if parsing fails
    }

    return ChatMessage(
      id: parsedId,
      senderId: parsedSenderId,
      content: json['content'] as String? ?? '', // Handle potential null content
      sentAt: parsedSentAt,
    );
  }

  /// Converts a ChatMessage instance to a JSON map.
  /// Note: This might not be directly used for sending messages if the backend
  /// expects a different structure (like CreateChatMessageDto within CreateChatMessagesDto).
  Map<String, dynamic> toJson() {
    return {
      // Include id only if it's not null (usually not sent when creating a new message)
      if (id != null) 'id': id,
      'senderId': senderId,
      'content': content,
      // Use 'sentAt' key and ISO 8601 format.
      'sentAt': sentAt.toIso8601String(),
    };
  }

  // --- Equality and HashCode ---
  // Updated to use the correct fields for comparison.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id && // Compare ID
          senderId == other.senderId && // Compare senderId
          sentAt == other.sentAt; // Compare sentAt

  @override
  // Use id, senderId, and sentAt for hashCode calculation.
  int get hashCode => id.hashCode ^ senderId.hashCode ^ sentAt.hashCode;
}