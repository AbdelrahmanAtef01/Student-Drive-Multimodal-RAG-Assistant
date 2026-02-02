import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ChatService {
  Future<Map<String, dynamic>> sendMessage({
    required String userId,
    required String sessionId,
    required String role,
    required String message,
    List<String>? filterFileIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.chatApiUrl),
        headers: {"Content-Type": "application/json", "x-api_key": "atef_123"},
        body: jsonEncode({
          "user_id": userId,
          "session_id": sessionId,
          "role": role,
          "message": message,
          "filter_file_ids": filterFileIds,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Server Error: ${response.body}");
      }
    } catch (e) {
      throw Exception("Connection Failed: $e");
    }
  }
}
