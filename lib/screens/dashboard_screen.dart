import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../services/drive_service.dart';
import '../services/chat_service.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  DashboardScreen({required this.user});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final DriveService _driveService = DriveService();
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  // Mutable User State
  late Map<String, dynamic> _currentUser;

  String _currentSessionId = "";
  List<DriveFile> _driveFiles = [];
  Set<String> _selectedFileIds = {};

  bool _isDriveLoading = false;
  bool _isChatLoading = false;
  bool _isSidebarCollapsed = false;
  bool _isFilesCollapsed = false;

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _startNewSession(); // Generates a random ID initially
    _loadDriveFiles();

    _bgController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_chatScrollCtrl.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _startNewSession() {
    setState(() {
      _currentSessionId = Uuid().v4();
    });
  }

  void _loadSession(String sessionId) {
    setState(() {
      _currentSessionId = sessionId;
    });
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          user: _currentUser,
          onUpdate: (updatedUser) => setState(() => _currentUser = updatedUser),
        ),
      ),
    );
  }

  Future<void> _loadDriveFiles() async {
    setState(() => _isDriveLoading = true);
    List<DriveFile> files = await _driveService.listFiles();
    setState(() {
      _driveFiles = files;
      _isDriveLoading = false;
    });
  }

  void _sendMessage() async {
    if (_msgCtrl.text.isEmpty) return;
    final text = _msgCtrl.text;
    _msgCtrl.clear();

    setState(() => _isChatLoading = true);

    try {
      await _chatService.sendMessage(
        userId: _currentUser['uid'],
        sessionId: _currentSessionId,
        role: _currentUser['role'],
        message: text,
        filterFileIds: _selectedFileIds.isNotEmpty
            ? _selectedFileIds.toList()
            : null,
      );

      // We don't need to manually write to DB here because the backend does it.
      // But we DO need to make sure the session doc exists for the Sidebar history list.
      // Since your backend writes to 'chat_sessions', let's also ensure our user knows about this session.
      // NOTE: Ideally, the backend would link the session to the user.
      // For now, we rely on the backend writing to 'chat_sessions/{id}'.
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isChatLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // --- SIDEBAR ---
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: _isSidebarCollapsed ? 60 : 250,
              color: Colors.grey[100],
              child: Column(
                children: [
                  SizedBox(height: 10),
                  IconButton(
                    icon: Icon(
                      _isSidebarCollapsed ? Icons.menu : Icons.chevron_left,
                      color: AppColors.primary,
                    ),
                    onPressed: () => setState(
                      () => _isSidebarCollapsed = !_isSidebarCollapsed,
                    ),
                  ),
                  if (!_isSidebarCollapsed) Divider(),

                  // HISTORY STREAM
                  // Backend Path: chat_sessions (Root Collection)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('chat_sessions')
                          .orderBy('updated_at', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return Center(child: CircularProgressIndicator());

                        // Filter logic could go here if your backend saved user_id in the session
                        // For now, showing recent active sessions from the root collection

                        return ListView(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.add_comment,
                                color: AppColors.primary,
                              ),
                              title: _isSidebarCollapsed
                                  ? null
                                  : Text(
                                      "New Chat",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              onTap: _startNewSession,
                            ),
                            ...snapshot.data!.docs.map((doc) {
                              final isCurrent = doc.id == _currentSessionId;
                              final data = doc.data() as Map<String, dynamic>;
                              final label =
                                  data['last_message'] ??
                                  "Session ${doc.id.substring(0, 6)}";

                              return ListTile(
                                title: _isSidebarCollapsed
                                    ? null
                                    : Text(
                                        "$label",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? AppColors.primary
                                              : Colors.black87,
                                        ),
                                      ),
                                leading: Icon(
                                  Icons.chat_bubble_outline,
                                  color: isCurrent
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                selected: isCurrent,
                                selectedTileColor: AppColors.primary
                                    .withOpacity(0.1),
                                onTap: () => _loadSession(doc.id),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ),

                  // USER CONTROLS
                  if (!_isSidebarCollapsed)
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.grey[200],
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey[400],
                                radius: 15,
                                child: Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentUser['name'] ?? "User",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _currentUser['email'] ?? "",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(Icons.settings, size: 20),
                                onPressed: _openSettings,
                                tooltip: "Settings",
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.logout,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: _logout,
                                tooltip: "Logout",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // --- MAIN AREA ---
            Expanded(
              child: Column(
                children: [
                  // DRIVE HEADER
                  _buildDriveHeader(),

                  // CHAT AREA
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _bgController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF5F7FA), Color(0xFFE4E9F2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              transform: GradientRotation(
                                _bgController.value * 2 * 3.14,
                              ),
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: StreamBuilder<QuerySnapshot>(
                        // FIX: Listen to the Backend's path -> chat_sessions/{id}/messages
                        stream: _db
                            .collection('chat_sessions')
                            .doc(_currentSessionId)
                            .collection('messages')
                            .orderBy('timestamp')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !_isChatLoading) {
                            return Center(
                              child: Text(
                                "Start a conversation...",
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final docs = snapshot.hasData
                              ? snapshot.data!.docs
                              : [];
                          if (docs.isNotEmpty || _isChatLoading)
                            _scrollToBottom();

                          return ListView.builder(
                            controller: _chatScrollCtrl,
                            padding: EdgeInsets.all(20),
                            // +1 item for the "Thinking" bubble
                            itemCount: docs.length + (_isChatLoading ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (_isChatLoading && i == docs.length) {
                                return ThinkingBubble();
                              }
                              final data =
                                  docs[i].data() as Map<String, dynamic>;
                              return _buildMessageBubble(data);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // INPUT AREA
                  _buildInputArea(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildDriveHeader() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _isFilesCollapsed ? 52 : 220,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      "Study Material",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_selectedFileIds.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text(
                            "${_selectedFileIds.length}",
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (_isDriveLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _loadDriveFiles,
                      ),
                    IconButton(
                      icon: Icon(
                        _isFilesCollapsed
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                      ),
                      onPressed: () => setState(
                        () => _isFilesCollapsed = !_isFilesCollapsed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isFilesCollapsed)
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                color: Colors.grey[50],
                child: _driveFiles.isEmpty
                    ? Center(
                        child: Text(
                          "No files found.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _driveFiles.length,
                        itemBuilder: (ctx, i) {
                          final file = _driveFiles[i];
                          final isSelected = _selectedFileIds.contains(file.id);
                          return InkWell(
                            onTap: () async {
                              if (file.webViewLink != null)
                                launchUrl(Uri.parse(file.webViewLink!));
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          file.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          "Click to view",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) => setState(
                                      () => val!
                                          ? _selectedFileIds.add(file.id)
                                          : _selectedFileIds.remove(file.id),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 800),
        margin: EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 12,
                    child: Icon(Icons.smart_toy, size: 14, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                ],
                Text(
                  isUser ? "You" : "Study Partner",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (isUser) ...[
                  SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    radius: 12,
                    child: Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12).copyWith(
                  topLeft: isUser ? Radius.circular(12) : Radius.zero,
                  topRight: isUser ? Radius.zero : Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: msg['content'] ?? "",
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  strong: TextStyle(
                    color: isUser ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  a: TextStyle(
                    color: isUser ? Colors.white : AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                onTapLink: (text, href, title) {
                  if (href != null) launchUrl(Uri.parse(href));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: "Ask a question about the selected files...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: AppColors.primary,
            child: _isChatLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// --- VISUAL FEEDBACK WIDGET ---
class ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 24, left: 0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 12,
              child: Icon(Icons.smart_toy, size: 14, color: Colors.white),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Thinking...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
