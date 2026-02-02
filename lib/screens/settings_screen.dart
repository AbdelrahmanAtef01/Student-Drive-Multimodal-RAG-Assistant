import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>)
  onUpdate; // Callback to update Dashboard user state

  SettingsScreen({required this.user, required this.onUpdate});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passCtrl;
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['name']);
    _emailCtrl = TextEditingController(text: widget.user['email']);
    _passCtrl = TextEditingController(text: widget.user['password']);
  }

  void _saveChanges() async {
    setState(() => _isLoading = true);
    bool success = await _auth.updateUser(
      widget.user['uid'],
      _nameCtrl.text,
      _emailCtrl.text,
      _passCtrl.text,
    );

    if (success) {
      // Update local state passed back to Dashboard
      widget.onUpdate({
        ...widget.user,
        'name': _nameCtrl.text,
        'email': _emailCtrl.text,
        'password': _passCtrl.text,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Profile Updated Successfully")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update profile.")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Account Settings"),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                child: Icon(Icons.person, size: 50, color: Colors.grey),
              ),
              SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.all(20)),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("Save Changes", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
