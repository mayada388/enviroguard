import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageSensorsPage extends StatefulWidget {
  const AdminManageSensorsPage({super.key});

  @override
  State<AdminManageSensorsPage> createState() => _AdminManageSensorsPageState();
}

class _AdminManageSensorsPageState extends State<AdminManageSensorsPage> {
  final _sensorsRef = FirebaseFirestore.instance.collection('sensors');

  // Add controllers
  final _addSensorId = TextEditingController();
  final _addSensorType = TextEditingController();
  final _addLocationId = TextEditingController();

  // Update controllers
  String? _selectedSensorId;
  final _newName = TextEditingController();
  final _newStatus = TextEditingController();
  final _newLocationId = TextEditingController();

  // Delete controllers
  final _delSensorId = TextEditingController();
  final _delSensorType = TextEditingController(); 
  final _delLocationId = TextEditingController(); 

  @override
  void dispose() {
    _addSensorId.dispose();
    _addSensorType.dispose();
    _addLocationId.dispose();
    _newName.dispose();
    _newStatus.dispose();
    _newLocationId.dispose();
    _delSensorId.dispose();
    _delSensorType.dispose();
    _delLocationId.dispose();
    super.dispose();
  }

  Future<void> _addSensor() async {
    final sensorId = _addSensorId.text.trim();
    final sensorType = _addSensorType.text.trim();
    final locationId = _addLocationId.text.trim();

    if (sensorId.isEmpty || sensorType.isEmpty || locationId.isEmpty) {
      _toast('Please fill Sensor ID, Sensor Type, and Location');
      return;
    }

    try {
      await _sensorsRef.doc(sensorId).set({
        'deviceId': 'raspberry', 
        'locationId': locationId,
        'sensorName': '', 
        'sensorType': sensorType,
        'status': 'ON', // default
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _toast('Sensor added: $sensorId');
      _addSensorId.clear();
      _addSensorType.clear();
      _addLocationId.clear();
    } catch (e) {
      _toast('Add failed: $e');
    }
  }

  Future<void> _updateSensor() async {
    final id = _selectedSensorId;
    if (id == null || id.isEmpty) {
      _toast('Select Sensor ID first');
      return;
    }

    final updates = <String, dynamic>{};

    final name = _newName.text.trim();
    final status = _newStatus.text.trim();
    final locationId = _newLocationId.text.trim();

    if (name.isNotEmpty) updates['sensorName'] = name;
    if (status.isNotEmpty) {
  final s = status.toUpperCase();
  if (s == 'ON' || s == 'OFF') {
    updates['status'] = s;
  }
}
    if (locationId.isNotEmpty) updates['locationId'] = locationId;

    if (updates.isEmpty) {
      _toast('No changes to update');
      return;
    }

    
    updates['lastUpdate'] = FieldValue.serverTimestamp();

    try {
      await _sensorsRef.doc(id).update(updates);
      _toast('Sensor updated: $id');
      _newName.clear();
      _newStatus.clear();
      _newLocationId.clear();
    } catch (e) {
      _toast('Update failed: $e');
    }
  }

  Future<void> _deleteSensor() async {
    final sensorId = _delSensorId.text.trim();
    if (sensorId.isEmpty) {
      _toast('Enter Sensor ID to delete');
      return;
    }

    try {
      await _sensorsRef.doc(sensorId).delete();
      _toast('Sensor deleted: $sensorId');
      _delSensorId.clear();
      _delSensorType.clear();
      _delLocationId.clear();

      
      if (_selectedSensorId == sensorId) {
        setState(() => _selectedSensorId = null);
      }
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
          'Manage Sensors',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _SectionCard(
              title: 'Add Sensor',
              buttonText: 'Add Sensor',
              buttonColor: const Color(0xFF9BE7AE),
              onPressed: _addSensor,
              fields: [
                _SensorField(label: 'Sensor ID :', controller: _addSensorId),
                _SensorField(label: 'Sensor Type :', controller: _addSensorType),
                _SensorField(label: 'Location :', controller: _addLocationId),
              ],
            ),
            const SizedBox(height: 20),

            _SectionCard(
              title: 'Update Sensor',
              buttonText: 'Update',
              buttonColor: const Color(0xFFFEE0A7),
              onPressed: _updateSensor,
              fields: [
                _SensorDropdownField(
                  label: 'Select Sensor ID :',
                  value: _selectedSensorId,
                  stream: _sensorsRef.orderBy(FieldPath.documentId).snapshots(),
                  onChanged: (v) => setState(() => _selectedSensorId = v),
                ),
                _SensorField(label: 'New Name :', controller: _newName),
                _SensorField(label: 'New Status :', controller: _newStatus),
                _SensorField(label: 'New Location :', controller: _newLocationId),
              ],
            ),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'Delete Sensor',
              buttonText: 'Delete',
              buttonColor: const Color(0xFFFFC7CF),
              onPressed: _deleteSensor,
              fields: [
                _SensorField(label: 'Sensor ID :', controller: _delSensorId),
                _SensorField(label: 'Sensor Type :', controller: _delSensorType),
                _SensorField(label: 'Location :', controller: _delLocationId),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: f,
              )),
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
                child: Text(buttonText,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _SensorField({required this.label, required this.controller});

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

class _SensorDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final ValueChanged<String?> onChanged;

  const _SensorDropdownField({
    required this.label,
    required this.value,
    required this.stream,
    required this.onChanged,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9E9E9)),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final ids = docs.map((d) => d.id).toList();

              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (value != null && ids.contains(value)) ? value : null,
                  hint: const Text('Select'),
                  isExpanded: true,
                  items: ids
                      .map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(id),
                          ))
                      .toList(),
                  onChanged: onChanged,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}