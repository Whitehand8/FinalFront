import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
// TODO: Ensure ChatMessage model path is correct after potential refactoring
import 'package:refine_trpg/models/chat.dart'; //
import 'auth_service.dart'; // For authentication token
// TODO: Potentially import user profile/state management service to get senderId/nickname
// import 'user_profile_service.dart';

class ChatService with ChangeNotifier {
  // --- Constants ---
  static const String _baseUrl = 'http://localhost:11123'; // Backend base URL
  static const String _chatNamespace = '/chat'; // Chat WebSocket namespace from backend

  // --- State Variables ---
  final String _roomIdString; // Room ID (expected as String by constructor)
  late final int _roomIdInt; // Room ID parsed as int for backend DTOs

  IO.Socket? _socket; // The WebSocket connection instance

  final List<ChatMessage> _messages = []; // Internal list of messages
  List<ChatMessage> get messages => List.unmodifiable(_messages); // Public getter for messages

  bool _isLoadingHistory = false; // Flag for loading state
  bool get isLoadingHistory => _isLoadingHistory; // Public getter for loading state

  bool _isConnected = false; // Track connection status
  bool get isConnected => _isConnected;

  String? _error; // To store potential errors
  String? get error => _error;

  // TODO: Implement proper user ID management
  int? _currentUserId; // Store the user ID as int, fetched after login

  // --- Constructor ---
  ChatService(this._roomIdString) { // Expect roomId as String initially
    try {
      _roomIdInt = int.parse(_roomIdString); // Parse to int for backend API calls
      _initialize();
    } catch (e) {
      debugPrint('Error parsing roomId: $_roomIdString. Invalid format.');
      _setError('Invalid Room ID format.');
    }
  }

  // --- Initialization ---
  Future<void> _initialize() async {
    // TODO: Fetch the current user ID after login - this needs proper implementation
    // Example placeholder - replace with actual logic e.g., using AuthService or a dedicated user state manager
    _currentUserId = await _getCurrentUserIdFromAuth(); // Fetch user ID

    if (_currentUserId == null) {
      _setError('User not authenticated. Cannot initialize chat.');
      return;
    }

    await connect(); // Connect WebSocket
  }

  // Placeholder function - replace with actual logic
  Future<int?> _getCurrentUserIdFromAuth() async {
    // Example: Decode JWT or get from Auth service state
    final token = await AuthService.getToken();
    if (token != null) {
      try {
        final payload = AuthService.parseJwt(token); // Assuming parseJwt returns Map<String, dynamic>
        // Assuming the user ID is stored under the 'sub' claim (standard JWT practice)
        // or potentially another key like 'userId' depending on backend setup
        final userId = payload['id']; // Adjust key 'id' if necessary based on backend JWT payload
        if (userId is int) {
          return userId;
        } else if (userId is String) {
          return int.tryParse(userId);
        }
      } catch (e) {
        debugPrint('Error parsing JWT for user ID: $e');
        return null;
      }
    }
    return null;
  }

  // --- WebSocket Connection & Management ---

  /// Connects to the chat WebSocket server and sets up listeners.
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      debugPrint('Chat socket already connected for room $_roomIdString.');
      return;
    }
    if (_currentUserId == null) {
      debugPrint('User ID not available. Cannot connect chat socket.');
      _setError('Authentication required to connect chat.');
      return;
    }

    _clearError(); // Clear previous errors
    final token = await AuthService.getToken();
    if (token == null) {
      debugPrint('Authentication token not found. Cannot connect chat socket.');
      _setError('Authentication token missing.');
      return;
    }

    debugPrint('Attempting to connect chat socket for room $_roomIdInt with token...');

    // Initialize socket connection
    _socket = IO.io(
      '$_baseUrl$_chatNamespace', // Connect to the specific namespace
      IO.OptionBuilder()
          .setTransports(['websocket']) // Use WebSocket transport
          .disableAutoConnect() // Connect manually
          .setAuth({'token': token}) // Send auth token in 'auth' object ( Matches backend ws-auth.middleware.ts )
          // Remove roomId from query, it will be sent via 'joinRoom' event
          .build(),
    );

    _setupSocketListeners();
    _socket!.connect(); // Manually initiate connection
  }

  /// Sets up listeners for socket events.
  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      debugPrint('Chat socket connected successfully.');
      _isConnected = true;
      _clearError();
      notifyListeners();

      // Emit 'joinRoom' event *after* successful connection
      _socket!.emit('joinRoom', {'roomId': _roomIdInt}); // Use parsed int roomId
      debugPrint('Emitted joinRoom for room ID: $_roomIdInt');

      // Fetch history again to catch up on any missed messages
      fetchChatHistory();
    });

    _socket!.on('joinedRoom', (data) {
        debugPrint('Successfully joined chat room: $data');
        // Handle successful room join confirmation if needed
    });

    _socket!.on('leftRoom', (data) {
        debugPrint('Left chat room: $data');
        // Handle room leave confirmation if needed
    });


    _socket!.on('newMessage', (data) { // Event name matches backend
      try {
        // Backend sends a single MessageResponseDto for newMessage
        final message = ChatMessage.fromJson(data as Map<String, dynamic>); // Use updated ChatMessage.fromJson

        // Basic duplicate check based on ID (if available) or content+timestamp+sender
        if (!_messages.any((m) =>
            (m.id != null && m.id == message.id) || // Check ID if backend provides it
            (m.sentAt == message.sentAt && m.senderId == message.senderId && m.content == message.content))) // Fallback check
         {
          _messages.add(message);
          _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt)); // Sort by sentAt
          notifyListeners();
          // TODO: Implement scroll to bottom logic in UI layer
        } else {
           debugPrint('Duplicate message detected, not adding: ${message.content}');
        }
      } catch (e) {
        debugPrint('Error processing newMessage data: $e');
        debugPrint('Received data: $data');
      }
    });

    _socket!.on('error', (data){ // Listen for backend error events
        debugPrint('Chat socket received error: $data');
        String errorMessage = 'An unknown error occurred.';
        if (data is Map<String, dynamic> && data.containsKey('message')) {
            errorMessage = data['message'];
        } else if (data is String) {
            errorMessage = data;
        }
        _setError(errorMessage); // Set and notify error state
    });

    _socket!.onDisconnect((reason) {
      debugPrint('Chat socket disconnected. Reason: $reason');
      _isConnected = false;
      _setError('Disconnected from chat.'); // Set error on disconnect
      notifyListeners();
      // TODO: Implement reconnection logic if desired
    });

    _socket!.onConnectError((data) {
      debugPrint('Chat socket connection error: $data');
      _isConnected = false;
      _setError('Failed to connect to chat.'); // Set error on connection failure
      notifyListeners();
    });
  }

  /// Disconnects the WebSocket.
  void disconnect() {
    debugPrint('Disconnecting chat socket for room $_roomIdString.');
    _socket?.disconnect();
  }

  // --- HTTP Methods ---

  /// Fetches recent chat messages for the room via HTTP GET request.
  Future<void> fetchChatHistory({int limit = 50}) async {
    if (_isLoadingHistory) return; // Prevent concurrent loading

    _isLoadingHistory = true;
    _clearError(); // Clear error before fetching
    notifyListeners();

    // Correct endpoint based on backend REST API
    final uri = Uri.parse('$_baseUrl/chat/rooms/$_roomIdInt/messages'); // Use int roomId
    final token = await AuthService.getToken();

    debugPrint('[ChatService] Fetching history from: $uri');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json', // Added Accept header
        if (token != null) 'Authorization': 'Bearer $token', // Correct Bearer prefix
      }).timeout(const Duration(seconds: 10)); // Added timeout

       debugPrint('[ChatService] History Response Status: ${response.statusCode}');
       // debugPrint('[ChatService] History Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final fetchedMessages = data
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>)) // Use updated ChatMessage
            .toList();

        // Efficiently merge fetched messages, avoiding duplicates and maintaining order
        final existingMessageIds = _messages.map((m) => m.id).where((id) => id != null).toSet();
        final newMessages = fetchedMessages.where((fm) => fm.id == null || !existingMessageIds.contains(fm.id)).toList();

        if (newMessages.isNotEmpty) {
           _messages.addAll(newMessages);
           _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt)); // Ensure chronological order using sentAt
        }
        _clearError(); // Clear error on success
      } else {
         final errorMessage = 'Failed to load chat history: ${response.statusCode}';
         debugPrint('$errorMessage Body: ${response.body}');
         _setError(errorMessage);
      }
    } on TimeoutException {
       debugPrint('Error fetching chat history: Request timed out.');
       _setError('Chat history request timed out.');
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
       _setError('Could not fetch chat history.');
    } finally {
       _isLoadingHistory = false;
       notifyListeners(); // Notify UI about loading state change and potential new messages/errors
    }
  }

  // --- Sending Messages ---

  /// Sends a single chat message via WebSocket.
  void sendMessage(String content) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Socket not connected. Cannot send message.');
      _setError('Not connected to chat. Please wait or reconnect.');
      // TODO: Implement message queuing or prompt user to reconnect
      return;
    }

    if (_currentUserId == null) {
       debugPrint("Error: Current user ID is not set. Cannot send message.");
       _setError('User identification failed.');
       return;
    }
    if (content.trim().isEmpty) {
        debugPrint("Cannot send empty message.");
        return;
    }

    // Construct the message payload according to CreateChatMessagesDto
    final messagePayload = {
      'roomId': _roomIdInt, // Use integer roomId
      'messages': [
        {
          'content': content,
          'sentAt': DateTime.now().toIso8601String(), // ✅ MODIFIED: Backend requires this
          'senderId': _currentUserId, // ✅ MODIFIED: Backend requires this
        }
      ]
    };

    debugPrint('[ChatService] Emitting sendMessage event with payload: ${jsonEncode(messagePayload)}');

    // Emit the 'sendMessage' event with the correct payload structure
    _socket!.emit('sendMessage', messagePayload);

    // Optimistic UI update (optional but improves user experience)
    // _addOptimisticMessage(content); // Consider adding if needed
  }

  /* // Optional: Optimistic UI update implementation
   void _addOptimisticMessage(String content) {
    if (_currentUserId == null) return;
    // TODO: Need a way to get the current user's nickname
    String senderNickname = "Me"; // Placeholder

    final optimisticMessage = ChatMessage(
        id: null, // No ID from backend yet
        senderId: _currentUserId!,
        sender: senderNickname, // Display name
        content: content,
        sentAt: DateTime.now(), // Client time
    );
     _messages.add(optimisticMessage);
     _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
     notifyListeners();
   }
   */

  // --- Utility Methods ---

  /// Sets the error message and notifies listeners.
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  /// Clears the error message and notifies listeners.
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }


  // --- Lifecycle Management ---

  @override
  void dispose() {
    debugPrint('Disposing ChatService and disconnecting socket for room $_roomIdString.');
    disconnect(); // Ensure disconnection
    _socket?.dispose(); // Release socket resources
    _socket = null;
    _messages.clear();
    super.dispose();
  }
}

// Ensure you have the corresponding ChatMessage model in lib/models/chat.dart
// Example structure based on backend's MessageResponseDto

/* // lib/models/chat.dart (Example - adjust as needed)
class ChatMessage {
  final int? id; // Message ID from backend (nullable for optimistic)
  final int senderId; // Sender's User ID
  final String content; // Message text
  final DateTime sentAt; // Timestamp from backend (use DateTime for easier handling)
  final String? sender; // Optional: Sender's display name (fetch separately if needed)


  ChatMessage({
    this.id,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.sender, // Made optional
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int?, // Handle potential null ID if backend doesn't always provide it initially
      senderId: json['senderId'] as int,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String), // Parse ISO 8601 string
      sender: json['sender'] as String?, // Handle optional sender display name
    );
  }

   // Optional: Add toJson if needed for sending complex objects (though backend DTO is simpler)
   Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'content': content,
        'sentAt': sentAt.toIso8601String(),
        'sender': sender,
      };

}
*/