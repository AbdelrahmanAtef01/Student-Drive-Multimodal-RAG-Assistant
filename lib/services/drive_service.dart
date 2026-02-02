import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../utils/constants.dart';

// Custom Model
class DriveFile {
  final String id;
  final String name;
  final String? webViewLink;

  DriveFile({required this.id, required this.name, this.webViewLink});
}

class DriveService {
  // Define scopes
  static const _scopes = [drive.DriveApi.driveReadonlyScope];

  // NOTE: No "signIn" method needed. Service Accounts auth automatically.

  Future<List<DriveFile>> listFiles() async {
    try {
      // 1. Load the Key from Assets
      final jsonString = await rootBundle.loadString(
        'assets/service_account.json',
      );
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);

      // 2. Authenticate
      final client = await clientViaServiceAccount(accountCredentials, _scopes);
      final driveApi = drive.DriveApi(client);

      // 3. List Files
      final q =
          "'${AppConstants.targetDriveFolderId}' in parents and trashed = false";
      final fileList = await driveApi.files.list(
        q: q,
        $fields: "files(id, name, mimeType, webViewLink, iconLink)",
      );

      client.close();

      if (fileList.files == null) return [];

      return fileList.files!
          .map(
            (f) => DriveFile(
              id: f.id ?? '',
              name: f.name ?? 'Untitled',
              webViewLink: f.webViewLink,
            ),
          )
          .toList();
    } catch (e) {
      print("❌ SERVICE ACCOUNT ERROR: $e");
      return [];
    }
  }
}
