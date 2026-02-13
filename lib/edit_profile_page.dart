
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _picker = ImagePicker();
  File? _pickedImage;

  bool _loading = true;
  bool _saving = false;
  bool _removing = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  /// ================= HEALTH CONDITIONS =================
  final List<String> _conditions = [
    "Asthma",
    "COPD",
    "Bronchitis",
    "Allergies",
    "Heart Disease",
    "Hypertension",
    "Pregnancy",
    "Children (Under 12)",
    "Elderly (60+)",
    "Low Immunity",
  ];

  final Set<String> _selectedConditions = {};

  /// ================= PERSONAL ALERTS =================
  final List<String> _pollutantAlerts = [
    "PM2.5",
    "PM10",
    "O3",
    "CO",
    "SO2",
    "Forecast (10 min)",
    "Rapid Change",
  ];

  final Set<String> _selectedAlerts = {};
  final Set<String> _manualAlerts = {};
  final Map<String, int> _autoAlertCount = {};
  final Set<String> _autoRecommendedAlerts = {};

  final Map<String, List<String>> _recommendedAlertsByCondition = {
    "Asthma": ["PM2.5", "O3", "Forecast (10 min)", "Rapid Change"],
    "COPD": ["PM2.5", "O3", "Forecast (10 min)"],
    "Bronchitis": ["PM2.5", "PM10", "Forecast (10 min)"],
    "Allergies": ["PM10", "PM2.5", "Rapid Change"],
    "Heart Disease": ["PM2.5", "CO", "Forecast (10 min)"],
    "Hypertension": ["PM2.5", "CO", "Forecast (10 min)"],
    "Pregnancy": ["PM2.5", "PM10", "O3", "Forecast (10 min)"],
    "Children (Under 12)": ["PM2.5", "PM10", "Forecast (10 min)"],
    "Elderly (60+)": ["PM2.5", "PM10", "Forecast (10 min)"],
    "Low Immunity": ["PM2.5", "Forecast (10 min)"],
  };

  void _applyRecommendedAlertsFor(String condition) {
    final rec = _recommendedAlertsByCondition[condition];
    if (rec == null) return;

    for (final a in rec) {
      final newCount = (_autoAlertCount[a] ?? 0) + 1;
      _autoAlertCount[a] = newCount;
      _selectedAlerts.add(a);
      _autoRecommendedAlerts.add(a);
    }
  }

  void _removeRecommendedAlertsFor(String condition) {
    final rec = _recommendedAlertsByCondition[condition];
    if (rec == null) return;

    for (final a in rec) {
      final current = _autoAlertCount[a] ?? 0;
      if (current <= 0) continue;

      final newCount = current - 1;

      if (newCount == 0) {
        _autoAlertCount.remove(a);
        _autoRecommendedAlerts.remove(a);
        if (!_manualAlerts.contains(a)) {
          _selectedAlerts.remove(a);
        }
      } else {
        _autoAlertCount[a] = newCount;
      }
    }
  }

  /// ================= OTHER SETTINGS =================
  bool _quietHours = false;
  bool _tips = true;

  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _fromHHmm(String s, TimeOfDay fallback) {
    final parts = s.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  // ================= IMAGE HELPERS =================

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x == null) return;
    setState(() => _pickedImage = File(x.path));
  }

  Future<String?> _uploadImageAndGetUrl(User user) async {
    if (_pickedImage == null) return null;

    final ref = FirebaseStorage.instance
        .ref()
        .child('user_profiles')
        .child('${user.uid}.jpg');

    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _removePhoto() async {
    final user = _user;
    if (user == null) return;

    setState(() => _removing = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${user.uid}.jpg');

      try {
        await ref.delete();
      } catch (_) {}

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'photoUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _pickedImage = null);

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

  // ================= LOAD / SAVE =================

  Future<void> _loadProfileFromFirestore() async {
    final user = _user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();

      if (!doc.exists) {
        _nameCtrl.text = user.displayName ?? '';
        _emailCtrl.text = user.email ?? '';

        await ref.set(
          {
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        setState(() => _loading = false);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      _nameCtrl.text = (data['name'] ?? user.displayName ?? '').toString();
      _emailCtrl.text = (data['email'] ?? user.email ?? '').toString();

      _selectedConditions.clear();
      final hc = data['healthConditions'];
      if (hc is List) {
        for (final x in hc) {
          _selectedConditions.add(x.toString());
        }
      }

      _selectedAlerts.clear();
      _manualAlerts.clear();
      _autoAlertCount.clear();
      _autoRecommendedAlerts.clear();
      for (final c in _selectedConditions) {
        _applyRecommendedAlertsFor(c);
      }

      final pa = data['personalAirAlerts'];
      if (pa is Map) {
        for (final p in _pollutantAlerts) {
          final v = pa[p];
          if (v == true) {
            _selectedAlerts.add(p);
            _manualAlerts.add(p);
          } else if (v == false) {
            _selectedAlerts.remove(p);
            _manualAlerts.remove(p);
          }
        }
      }

      final qh = data['quietHours'];
      if (qh is Map) {
        _quietHours = (qh['enabled'] == true);
        final startStr = (qh['start'] ?? '').toString();
        final endStr = (qh['end'] ?? '').toString();
        if (startStr.isNotEmpty) _start = _fromHHmm(startStr, _start);
        if (endStr.isNotEmpty) _end = _fromHHmm(endStr, _end);
      }

      _tips = (data['tipsEnabled'] == true);

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  Future<void> _saveProfileToFirestore() async {
    final user = _user;
    if (user == null) return;

    setState(() => _saving = true);

    final Map<String, bool> personalAirAlerts = {
      for (final p in _pollutantAlerts) p: _selectedAlerts.contains(p),
    };

    try {
      String? photoUrl;
      if (_pickedImage != null) {
        photoUrl = await _uploadImageAndGetUrl(user);
      }

      final payload = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'healthConditions': _selectedConditions.toList(),
        'personalAirAlerts': personalAirAlerts,
        'quietHours': {
          'enabled': _quietHours,
          'start': _toHHmm(_start),
          'end': _toHHmm(_end),
        },
        'tipsEnabled': _tips,
        'updatedAt': FieldValue.serverTimestamp(),
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      final newName = _nameCtrl.text.trim();
      if (newName.isNotEmpty) {
        await user.updateDisplayName(newName);
        await user.reload();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Firebase ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Health Profile")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final savedPhotoUrl = (data?['photoUrl'] ?? '').toString().trim();

          ImageProvider? avatar;
          if (_pickedImage != null) {
            avatar = FileImage(_pickedImage!);
          } else if (savedPhotoUrl.isNotEmpty) {
            avatar = NetworkImage(savedPhotoUrl);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ✅ AVATAR فوق (نفس الادمن)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: (_saving || _removing) ? null : _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: const Color(0xFFF1F1F1),
                                backgroundImage: avatar,
                                child: avatar == null
                                    ? Icon(Icons.person, size: 44, color: Colors.grey[500])
                                    : null,
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF32345F),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to change photo',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        if (savedPhotoUrl.isNotEmpty || _pickedImage != null)
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: (_saving || _removing) ? null : _removePhoto,
                              child: _removing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Remove photo',
                                      style: TextStyle(color: Color(0xFFD65B66)),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _section(
                    title: "Basic Information",
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: "Full Name"),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: "Email"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _section(
  title: "Security",
  child: Column(
    children: [
      ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text("Change Password"),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showPasswordDialog,
      ),
      ListTile(
        leading: const Icon(Icons.email_outlined),
        title: const Text("Change Email"),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showChangeEmailDialog,
      ),
    ],
  ),
),

                  const SizedBox(height: 16),

                  _section(
                    title: "Health Conditions",
                    subtitle: "Select all that apply (auto recommends alerts)",
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _conditions.map((c) {
                        return FilterChip(
                          label: Text(c),
                          selected: _selectedConditions.contains(c),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedConditions.add(c);
                                _applyRecommendedAlertsFor(c);
                              } else {
                                _selectedConditions.remove(c);
                                _removeRecommendedAlertsFor(c);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _section(
                    title: "Personal Air Alerts",
                    subtitle:
                        "⭐ Recommended based on selected conditions (You can select more)",
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pollutantAlerts.map((p) {
                        final isSelected = _selectedAlerts.contains(p);
                        final isRecommended = _autoRecommendedAlerts.contains(p);

                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p),
                              if (isRecommended) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.star, size: 16),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedAlerts.add(p);
                                _manualAlerts.add(p);
                              } else {
                                _selectedAlerts.remove(p);
                                _manualAlerts.remove(p);

                                if ((_autoAlertCount[p] ?? 0) > 0) {
                                  _selectedAlerts.add(p);
                                  _autoRecommendedAlerts.add(p);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _section(
                    title: "Quiet Hours",
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _quietHours,
                          title: const Text("Disable notifications during sleep"),
                          onChanged: (v) => setState(() => _quietHours = v),
                        ),
                        if (_quietHours)
                          Row(
                            children: [
                              Expanded(
                                child: _timeTile("Start", _start, () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _start,
                                  );
                                  if (t != null) setState(() => _start = t);
                                }),
                              ),
                              Expanded(
                                child: _timeTile("End", _end, () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _end,
                                  );
                                  if (t != null) setState(() => _end = t);
                                }),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SwitchListTile(
                    value: _tips,
                    title: const Text("Personalized Health Tips"),
                    onChanged: (v) => setState(() => _tips = v),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_saving || _removing) ? null : _saveProfileToFirestore,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Save Changes"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _section({required String title, Widget? child, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          child ?? const SizedBox(),
        ],
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return ListTile(
      title: Text(label),
      subtitle: Text(time.format(context)),
      onTap: onTap,
    );
  }

 void _showPasswordDialog() {
  final currentPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final confirmNewPassCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Change Password"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: currentPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Current Password"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "New Password"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmNewPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Confirm New Password"),
          ),
          const SizedBox(height: 8),

          // ✅ يظهر دايم من البداية
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                final email = user?.email;

                if (email == null || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No email found for this account")),
                  );
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password reset email sent ✅")),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text("Forgot password?"),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            final newPass = newPassCtrl.text.trim();
            final confirmPass = confirmNewPassCtrl.text.trim();

            // ✅ تحقق قبل أي شي
            if (newPass.isEmpty || confirmPass.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill all fields")),
              );
              return;
            }

            if (newPass != confirmPass) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("New passwords do not match")),
              );
              return;
            }

            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              // ✅ re-auth باستخدام الباسورد القديم
              final cred = EmailAuthProvider.credential(
                email: user.email!,
                password: currentPassCtrl.text.trim(),
              );

              await user.reauthenticateWithCredential(cred);

              // ✅ تحديث الباسورد
              await user.updatePassword(newPass);

              if (!mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Password updated successfully ✅")),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $e")),
              );
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

  void _showChangeEmailDialog() {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Change Email"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: "New Email"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Confirm Password"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final cred = EmailAuthProvider.credential(
                email: user.email!,
                password: passwordController.text.trim(),
              );

              await user.reauthenticateWithCredential(cred);

              await user.verifyBeforeUpdateEmail(
                emailController.text.trim(),
              );

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({
                'email': emailController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              if (!mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Verification email sent")),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $e")),
              );
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

}

