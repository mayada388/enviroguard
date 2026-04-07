import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAddAdminPage extends StatefulWidget {
  const AdminAddAdminPage({super.key});

  @override
  State<AdminAddAdminPage> createState() => _AdminAddAdminPageState();
}

class _AdminAddAdminPageState extends State<AdminAddAdminPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<String?> _fetchAdminCodeFromFirestore() async {
    
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('app')
        .get();

    final data = doc.data();
    final code = (data?['adminCode'] ?? '').toString().trim();
    return code.isEmpty ? null : code;
  }

  Future<void> _addAdminInvite(String email) async {
  
    final emailLower = email.trim().toLowerCase();

    await FirebaseFirestore.instance
        .collection('admin_invites')
        .doc(emailLower)
        .set({
      'email': emailLower,
      'enabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final enteredCode = _codeCtrl.text.trim();

      final realCode = await _fetchAdminCodeFromFirestore();
      if (realCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin code is not set in Firestore (settings/app).'),
          ),
        );
        return;
      }

      if (enteredCode != realCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong admin code')),
        );
        return;
      }

      await _addAdminInvite(email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin added: $email')),
      );

      _emailCtrl.clear();
      _codeCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF32345F);
    const backgroundColor = Color(0xFFF7F7FB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Admin',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Admin',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B7B7B),
                  ),
                ),
                const SizedBox(height: 12),

                _Label('Admin Email :'),
                _InputField(
                  controller: _emailCtrl,
                  hint: 'example@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Email is required';
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _Label('Admin Code :'),
                _InputField(
                  controller: _codeCtrl,
                  hint: 'Enter admin code',
                  obscureText: _obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Code is required';
                    if (value.length < 4) return 'Code is too short';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 160,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9BE7AE),
                        foregroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Add Admin',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFFAAAAAA),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}