import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // ✅ لا تحطي قيم افتراضية، خليها فاضية وتتعبي من Firestore
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  /// ================= HEALTH CONDITIONS (MATCH YOUR PROJECT) =================
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

  /// ================= PERSONAL ALERTS (BASED ON YOUR SENSORS) =================
  final List<String> _pollutantAlerts = [
    "PM2.5",
    "PM10",
    "O3",
    "CO",
    "SO2",
    "Forecast (10 min)",
    "Rapid Change",
  ];

  /// Selected alerts (auto + manual)
  final Set<String> _selectedAlerts = {};

  /// Alerts selected manually by the user
  final Set<String> _manualAlerts = {};

  /// Count how many selected conditions recommend each alert (handles overlaps)
  final Map<String, int> _autoAlertCount = {};

  /// ⭐ Alerts that are currently recommended (for star display)
  final Set<String> _autoRecommendedAlerts = {};

  /// ================= RECOMMENDED ALERTS RULES =================
  /// IMPORTANT: Strings must match _conditions + _pollutantAlerts exactly.
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
      _autoRecommendedAlerts.add(a); // show ⭐
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

        // remove ⭐
        _autoRecommendedAlerts.remove(a);

        // remove alert ONLY if user didn't manually select it
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

  bool _loading = true;

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

  Future<void> _loadProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();

      // ✅ لو ما فيه doc: نعبي من Auth وننشئ doc بسيط
      if (!doc.exists) {
        _nameCtrl.text = user.displayName ?? '';
        _emailCtrl.text = user.email ?? '';

        await ref.set({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() => _loading = false);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // الاسم/الايميل
      _nameCtrl.text = (data['name'] ?? user.displayName ?? '').toString();
      _emailCtrl.text = (data['email'] ?? user.email ?? '').toString();

      // healthConditions (array)
      _selectedConditions.clear();
      final hc = data['healthConditions'];
      if (hc is List) {
        for (final x in hc) {
          _selectedConditions.add(x.toString());
        }
      }

      // أعيدي تطبيق الريكومندد بناءً على الحالات الصحية
      _selectedAlerts.clear();
      _manualAlerts.clear();
      _autoAlertCount.clear();
      _autoRecommendedAlerts.clear();
      for (final c in _selectedConditions) {
        _applyRecommendedAlertsFor(c);
      }

      // personalAirAlerts (map) -> نخليها هي المصدر النهائي (true/false)
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

      // quietHours (map)
      final qh = data['quietHours'];
      if (qh is Map) {
        _quietHours = (qh['enabled'] == true);
        final startStr = (qh['start'] ?? '').toString();
        final endStr = (qh['end'] ?? '').toString();
        if (startStr.isNotEmpty) _start = _fromHHmm(startStr, _start);
        if (endStr.isNotEmpty) _end = _fromHHmm(endStr, _end);
      }

      // tipsEnabled (bool)
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // personalAirAlerts map (كل خيار true/false)
    final Map<String, bool> personalAirAlerts = {
      for (final p in _pollutantAlerts) p: _selectedAlerts.contains(p),
    };

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
    };

    try {
      // ✅ Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      // ✅ (اختياري) حدّث Auth displayName عشان أي مكان يعتمد عليه
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Health Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// ================= Basic Info =================
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

              /// ================= Security =================
              _section(
                title: "Security",
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text("Change Password"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPasswordDialog,
                ),
              ),

              const SizedBox(height: 16),

              /// ================= Health Conditions =================
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

              /// ================= Personal Air Alerts =================
              _section(
                title: "Personal Air Alerts",
                subtitle: "⭐ Recommended based on selected conditions",
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

              /// ================= Quiet Hours =================
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

              /// ================= Tips =================
              SwitchListTile(
                value: _tips,
                title: const Text("Personalized Health Tips"),
                onChanged: (v) => setState(() => _tips = v),
              ),

              const SizedBox(height: 20),

              /// ================= Save =================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfileToFirestore,
                  child: const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ================= Helpers =================

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
          if (subtitle != null) Text(subtitle, style: const TextStyle(color: Colors.grey)),
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Password"),
        content: const Text("Password change UI (connect later to backend)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}