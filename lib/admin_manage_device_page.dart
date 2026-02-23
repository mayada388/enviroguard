import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageDevicePage extends StatefulWidget {
  const AdminManageDevicePage({super.key});

  @override
  State<AdminManageDevicePage> createState() => _AdminManageDevicePageState();
}

class _AdminManageDevicePageState extends State<AdminManageDevicePage> {
  //  Firestore collection 
  final CollectionReference<Map<String, dynamic>> _devicesRef =
      FirebaseFirestore.instance.collection('edge_devices');

  // ---------- Add controllers ----------
  final _addId = TextEditingController();
  final _addName = TextEditingController();
  final _addType = TextEditingController();
  final _addLocation = TextEditingController();
  final _addStatus = TextEditingController();

  // ---------- Update controllers ----------
  String? _selectedUpdateId;
  final _updName = TextEditingController();
  final _updType = TextEditingController();
  final _updLocation = TextEditingController();
  final _updStatus = TextEditingController();

  // ---------- Delete controllers ----------
  final _delId = TextEditingController();

  @override
  void dispose() {
    _addId.dispose();
    _addName.dispose();
    _addType.dispose();
    _addLocation.dispose();
    _addStatus.dispose();

    _updName.dispose();
    _updType.dispose();
    _updLocation.dispose();
    _updStatus.dispose();

    _delId.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== ADD DEVICE =====================
  Future<void> _addDevice() async {
    final id = _addId.text.trim();
    if (id.isEmpty) {
      _toast('Device ID is required');
      return;
    }

    final data = <String, dynamic>{
      // نخزن نفس الحقول اللي عندك بالجدول
      'deviceName': _addName.text.trim(),
      'deviceType': _addType.text.trim(),
      'locationId': _addLocation.text.trim(), // (لو تبغين id للموقع)
      'status': _addStatus.text.trim(), // Online/Offline/Active...
      'lastSeen': FieldValue.serverTimestamp(),
    };

    // نظّف القيم الفاضية عشان ما تتخزن ""
    data.removeWhere((k, v) => v is String && v.trim().isEmpty);

    try {
      await _devicesRef.doc(id).set(data, SetOptions(merge: true));
      _toast('Device added/updated: $id');

      _addId.clear();
      _addName.clear();
      _addType.clear();
      _addLocation.clear();
      _addStatus.clear();
    } catch (e) {
      _toast('Add failed: $e');
    }
  }

  // ===================== UPDATE DEVICE =====================
  Future<void> _updateDevice() async {
    final id = _selectedUpdateId?.trim();
    if (id == null || id.isEmpty) {
      _toast('Select Device ID first');
      return;
    }

    final updates = <String, dynamic>{};

    final name = _updName.text.trim();
    final type = _updType.text.trim();
    final loc = _updLocation.text.trim();
    final status = _updStatus.text.trim();

    if (name.isNotEmpty) updates['deviceName'] = name;
    if (type.isNotEmpty) updates['deviceType'] = type;
    if (loc.isNotEmpty) updates['locationId'] = loc;
    if (status.isNotEmpty) updates['status'] = status;

    // لو تبغين كل تحديث يسوي آخر ظهور
    updates['lastSeen'] = FieldValue.serverTimestamp();

    if (updates.length == 1 && updates.containsKey('lastSeen')) {
      _toast('Write something to update');
      return;
    }

    try {
      await _devicesRef.doc(id).set(updates, SetOptions(merge: true));
      _toast('Device updated: $id');

      _updName.clear();
      _updType.clear();
      _updLocation.clear();
      _updStatus.clear();
    } catch (e) {
      _toast('Update failed: $e');
    }
  }

  // ===================== DELETE DEVICE =====================
  Future<void> _deleteDevice() async {
    final id = _delId.text.trim();
    if (id.isEmpty) {
      _toast('Device ID is required');
      return;
    }

    try {
      await _devicesRef.doc(id).delete();
      _toast('Device deleted: $id');

      // لو كان محدد للتحديث، افصليه
      if (_selectedUpdateId == id) {
        setState(() => _selectedUpdateId = null);
      }
      _delId.clear();
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
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
          'Manage Devices',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ===================== ADD DEVICE =====================
            _SectionCard(
              title: 'Add Device',
              buttonText: 'Add Device',
              buttonColor: const Color(0xFF9BE7AE),
              onPressed: _addDevice,
              fields: [
                _Field(label: 'Device ID :', controller: _addId),
                _Field(label: 'Device Name :', controller: _addName),
                _Field(label: 'Device Type :', controller: _addType),
                _Field(label: 'Location :', controller: _addLocation),
                _Field(label: 'Status :', controller: _addStatus),
              ],
            ),

            const SizedBox(height: 20),

            // ===================== UPDATE DEVICE =====================
            _SectionCard(
              title: 'Update Device',
              buttonText: 'Update',
              buttonColor: const Color(0xFFFEE0A7),
              onPressed: _updateDevice,
              fields: [
                _DeviceIdDropdownField(
                  label: 'Select Device ID :',
                  devicesRef: _devicesRef,
                  value: _selectedUpdateId,
                  onChanged: (v) => setState(() => _selectedUpdateId = v),
                ),
                _Field(label: 'New Device Name :', controller: _updName),
                _Field(label: 'New Device Type :', controller: _updType),
                _Field(label: 'New Location :', controller: _updLocation),
                _Field(label: 'New Status :', controller: _updStatus),
              ],
            ),

            const SizedBox(height: 20),

            // ===================== DELETE DEVICE =====================
            _SectionCard(
              title: 'Delete Device',
              buttonText: 'Delete',
              buttonColor: const Color(0xFFFFC7CF),
              onPressed: _deleteDevice,
              fields: [
                _Field(label: 'Device ID :', controller: _delId),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Section Card =====================
class _SectionCard extends StatelessWidget {
  final String title;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;
  final List<Widget> fields;

  const _SectionCard({
    required this.title,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B7B7B),
            ),
          ),
          const SizedBox(height: 12),
          ...fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: f,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 140,
              height: 38,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: const Color(0xFF32345F),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Text Field =====================
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _Field({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFAAAAAA),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9E9E9)),
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== Dropdown from Firestore =====================
class _DeviceIdDropdownField extends StatelessWidget {
  final String label;
  final CollectionReference<Map<String, dynamic>> devicesRef;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DeviceIdDropdownField({
    required this.label,
    required this.devicesRef,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: devicesRef.orderBy(FieldPath.documentId).snapshots(),
      builder: (context, snapshot) {
        final ids = snapshot.data?.docs.map((d) => d.id).toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFAAAAAA),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9E9E9)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: ids.contains(value) ? value : null,
                  hint: const Text('Select...'),
                  items: ids
                      .map(
                        (id) => DropdownMenuItem(
                          value: id,
                          child: Text(id),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}