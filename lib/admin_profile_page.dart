import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  final Color primaryColor = const Color(0xFF32345F);
  final Color backgroundColor = const Color(0xFFF9F9FB);

  File? _pickedImage;
  bool _saving = false;
  bool _removing = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x == null) return;

    setState(() {
      _pickedImage = File(x.path);
    });
  }

  Future<String?> _uploadImageAndGetUrl(User user) async {
    if (_pickedImage == null) return null;

    final ref = FirebaseStorage.instance
        .ref()
        .child('admin_profiles')
        .child('${user.uid}.jpg');

    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();

      String? photoUrl;
      if (_pickedImage != null) {
        photoUrl = await _uploadImageAndGetUrl(user);
      }

      final data = <String, dynamic>{
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = _user;
    if (user == null) return;

    setState(() => _removing = true);

    try {
      
      final ref = FirebaseStorage.instance
          .ref()
          .child('admin_profiles')
          .child('${user.uid}.jpg');

      
      try {
        await ref.delete();
      } catch (_) {}

      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      
      if (mounted) {
        setState(() {
          _pickedImage = null;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo removed ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Admin Profile',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final savedName = (data?['name'] ?? '').toString().trim();
          final savedPhotoUrl = (data?['photoUrl'] ?? '').toString().trim();

          
          if (_nameController.text.isEmpty && savedName.isNotEmpty) {
            _nameController.text = savedName;
          }

          ImageProvider? avatar;
          if (_pickedImage != null) {
            avatar = FileImage(_pickedImage!);
          } else if (savedPhotoUrl.isNotEmpty) {
            avatar = NetworkImage(savedPhotoUrl);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: (_saving || _removing) ? null : _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: const Color(0xFFF1F1F1),
                              backgroundImage: avatar,
                              child: avatar == null
                                  ? Icon(Icons.person, size: 48, color: Colors.grey[500])
                                  : null,
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Admin Name',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: primaryColor, width: 1.2),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: (_saving || _removing) ? null : _saveProfile,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // زر إزالة الصورة يظهر لو فيه صورة محفوظة أو مختارة
                      if (savedPhotoUrl.isNotEmpty || _pickedImage != null)
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD65B66)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: (_saving || _removing) ? null : _removePhoto,
                            child: _removing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Remove photo',
                                    style: TextStyle(
                                      color: Color(0xFFD65B66),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}