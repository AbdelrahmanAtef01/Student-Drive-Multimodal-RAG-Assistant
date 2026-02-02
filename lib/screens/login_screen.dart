import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _isRegistering = false;
  // Default role for new users
  String _selectedRole = 'student';

  void _submit() async {
    setState(() => _isLoading = true);
    if (_isRegistering) {
      if (_emailCtrl.text.isEmpty ||
          _passCtrl.text.isEmpty ||
          _nameCtrl.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Please fill all fields.")));
        setState(() => _isLoading = false);
        return;
      }
      // Registration Logic with Role
      await _auth.createUser(
        _emailCtrl.text,
        _passCtrl.text,
        _nameCtrl.text,
        _selectedRole,
      );
      setState(() {
        _isRegistering = false;
        _selectedRole = 'student'; // Reset
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Account Created. Please Login.")));
    } else {
      // Login Logic
      final user = await _auth.login(_emailCtrl.text, _passCtrl.text);
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Invalid Credentials.")));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // The background is handled by main.dart wrapper.
    // We make scaffold transparent to show it.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "College Drive\nStudy Partner",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 30),
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Role Dropdown
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down),
                        items: [
                          DropdownMenuItem(
                            value: 'student',
                            child: Text("Student Account"),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text("Admin / TA Account"),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedRole = val!),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
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
                SizedBox(height: 30),
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        // Button text color fixed by theme in main.dart
                        child: Text(
                          _isRegistering ? "Create Account" : "Login",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () =>
                      setState(() => _isRegistering = !_isRegistering),
                  child: Text(
                    _isRegistering
                        ? "Already have an account? Login"
                        : "Need an account? Register",
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
