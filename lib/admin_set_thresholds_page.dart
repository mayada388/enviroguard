import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSetThresholdsPage extends StatefulWidget {
  const AdminSetThresholdsPage({super.key});

  @override
  State<AdminSetThresholdsPage> createState() => _AdminSetThresholdsPageState();
}

class _AdminSetThresholdsPageState extends State<AdminSetThresholdsPage> {
  // ====== Firestore ======
  final _db = FirebaseFirestore.instance;

  // كل عنصر: label للواجهة + docId في فايرستور
  final List<_PollutantItem> _items = const [
    _PollutantItem(label: 'O₃ Limit', docId: 'O3'),
    _PollutantItem(label: 'SO₂ Limit', docId: 'SO2'),
    _PollutantItem(label: 'CO Limit', docId: 'CO'),
    _PollutantItem(label: 'PM10 Limit', docId: 'PM10'),
    _PollutantItem(label: 'PM2.5 Limit', docId: 'PM2_5'),
  ];

  // Controllers لكل دوكمنت
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
    _loadThresholds();
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

  Future<void> _loadThresholds() async {
    setState(() => _loading = true);

    try {
      // نقرأ كل الدوكمينتس (بالأسماء اللي عندك)
      for (final it in _items) {
        final doc = await _db.collection('thresholds').doc(it.docId).get();
        final data = doc.data() ?? {};

        final maxSafe = data['max_safe'];
        final maxModerate = data['max_moderate'];

        _safeCtrl[it.docId]!.text = (maxSafe ?? '').toString();
        _moderateCtrl[it.docId]!.text = (maxModerate ?? '').toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading thresholds: $e')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  double? _toDouble(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  Future<void> _saveThresholds() async {
    setState(() => _saving = true);

    try {
      final batch = _db.batch();

      for (final it in _items) {
        final safeVal = _toDouble(_safeCtrl[it.docId]!.text);
        final modVal = _toDouble(_moderateCtrl[it.docId]!.text);

        // اختياري: تحقق بسيط
        if (safeVal == null || modVal == null) {
          throw 'Please fill max_safe and max_moderate for ${it.label}';
        }
        if (safeVal > modVal) {
          throw 'max_safe must be <= max_moderate for ${it.label}';
        }

        final ref = _db.collection('thresholds').doc(it.docId);

        // Merge عشان ما نمسح حقول ثانية لو موجودة
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Set Thresholds',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading || _saving ? null : _loadThresholds,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
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
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _items.length; i++) ...[
                        _buildLimitField(
                          label: _items[i].label,
                          docId: _items[i].docId,
                        ),
                        if (i != _items.length - 1) const SizedBox(height: 16),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.w600),
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

  // ================= Limit Field =================
  Widget _buildLimitField({required String label, required String docId}) {
    final safeController = _safeCtrl[docId]!;
    final moderateController = _moderateCtrl[docId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFCC7A87),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            // max_safe
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'max_safe',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: safeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // max_moderate
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'max_moderate',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: moderateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ],
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
  const _PollutantItem({required this.label, required this.docId});
}