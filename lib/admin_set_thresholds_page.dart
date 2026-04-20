import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSetThresholdsPage extends StatefulWidget {
  const AdminSetThresholdsPage({super.key});

  @override
  State<AdminSetThresholdsPage> createState() =>
      _AdminSetThresholdsPageState();
}

class _AdminSetThresholdsPageState extends State<AdminSetThresholdsPage> {
  final _db = FirebaseFirestore.instance;

  String? locationId;

  final List<_PollutantItem> _items = const [
    _PollutantItem(label: 'CO₂ Limit', docId: 'CO2'),
    _PollutantItem(label: 'PM10 Limit', docId: 'PM10'),
    _PollutantItem(label: 'PM2.5 Limit', docId: 'PM2_5'),
    _PollutantItem(label: 'NO₂ Limit', docId: 'NO2'),
    _PollutantItem(label: 'O₃ Limit', docId: 'O3'),
  ];

  final Map<String, TextEditingController> _safeCtrl = {};
  final Map<String, TextEditingController> _moderateCtrl = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    for (final it in _items) {
      _safeCtrl[it.docId] = TextEditingController();
      _moderateCtrl[it.docId] = TextEditingController();
    }

    _init();
  }

  @override
  void dispose() {
    for (final c in _safeCtrl.values) {
      c.dispose();
    }
    for (final c in _moderateCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ================= INIT =================
  Future<void> _init() async {
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) throw 'No user';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      locationId = doc.data()?['locationId'];

      if (locationId == null) {
        throw 'No location selected';
      }

      await _loadThresholds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  // ================= LOAD =================
  Future<void> _loadThresholds() async {
    try {
      for (final it in _items) {
        final doc = await _db
            .collection('thresholds')
            .doc(locationId)
            .collection('pollutants')
            .doc(it.docId)
            .get();

        final data = doc.data() ?? {};

        _safeCtrl[it.docId]!.text =
            (data['max_safe'] ?? '').toString();
        _moderateCtrl[it.docId]!.text =
            (data['max_moderate'] ?? '').toString();
      }
    } catch (e) {
      throw 'Error loading thresholds: $e';
    }
  }

  double? _toDouble(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  // ================= SAVE =================
  Future<void> _saveThresholds() async {
    setState(() => _saving = true);

    try {
      final batch = _db.batch();

      for (final it in _items) {
        final safeVal = _toDouble(_safeCtrl[it.docId]!.text);
        final modVal = _toDouble(_moderateCtrl[it.docId]!.text);

        if (safeVal == null || modVal == null) {
          throw 'Please fill values for ${it.label}';
        }

        if (safeVal > modVal) {
          throw 'max_safe must be <= max_moderate for ${it.label}';
        }

        final ref = _db
            .collection('thresholds')
            .doc(locationId)
            .collection('pollutants')
            .doc(it.docId);

        batch.set(ref, {
          'max_safe': safeVal,
          'max_moderate': modVal,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thresholds saved ✅')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
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
        title: const Text(
          'Set Thresholds',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _init,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _items.length; i++) ...[
                        _buildLimitField(
                          label: _items[i].label,
                          docId: _items[i].docId,
                        ),
                        if (i != _items.length - 1)
                          const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: 140,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveThresholds,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC7CF),
                            foregroundColor: primaryColor,
                          ),
                          child: _saving
                              ? const CircularProgressIndicator()
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLimitField({
    required String label,
    required String docId,
  }) {
    final safeController = _safeCtrl[docId]!;
    final moderateController = _moderateCtrl[docId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: safeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'max_safe'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: moderateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'max_moderate'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PollutantItem {
  final String label;
  final String docId;

  const _PollutantItem({
    required this.label,
    required this.docId,
  });
}