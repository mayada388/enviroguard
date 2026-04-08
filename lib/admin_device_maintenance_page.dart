import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDeviceMaintenancePage extends StatelessWidget {
  const AdminDeviceMaintenancePage({super.key});

  CollectionReference<Map<String, dynamic>> get _devicesRef =>
      FirebaseFirestore.instance.collection('devices');

  String _formatTimestamp(dynamic value) {
    if (value == null) return '- -';

    DateTime? dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    }

    if (dt == null) return '- -';

    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    return '$y-$m-$d  $hh:$mm';
  }

  
  bool _isOn(dynamic status) {
    final s = status?.toString().toLowerCase();
    return s == 'on' || s == 'true' || s == '1';
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
          'Device Maintenance',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _devicesRef
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final isEmpty = docs.isEmpty;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal, 
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12), 
                        child: DataTable(
                          columnSpacing: 18,
                          dividerThickness: 0.5,
                          headingRowColor: MaterialStateProperty.all(Color(0xFFE3F0FF)), 
                          headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F6FED),
                          fontSize: 13,
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 12.5,
                          ),
                          columns: const [
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Device ID')),
                            DataColumn(label: Text('Main Type')),
                            DataColumn(label: Text('Performed By')),
                            DataColumn(label: Text('Sensor ID')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Timestamp')),
                          ],
                          rows: isEmpty
                              ? List.generate(
                                  3,
                                  (index) => const DataRow(
                                    cells: [
                                      DataCell(Text('- -')),
                                      DataCell(Text('- -')),
                                      DataCell(Text('- -')),
                                      DataCell(Text('- -')),
                                      DataCell(Text('- -')),
                                      DataCell(Text('- -')),
                                      DataCell(Text('- -')),
                                    ],
                                  ),
                                )
                              : docs.map((d) {
                                  final data = d.data();

                                  final description =
                                      (data['description'] ?? '- -').toString();
                                  final deviceId = d.id;
                                  final mainType =
                                      (data['mainType'] ?? '- -').toString();
                                  final performedBy =
                                      (data['performedBy'] ?? '- -')
                                          .toString();
                                  final sensorId =
                                      (data['sensorId'] ?? '- -').toString();
                                  final status = data['status'];
                                  final timestamp = data['timestamp'];

                                  final isOn = _isOn(status);

                                  Widget buildCell(String text) {
                                    return SizedBox(
                                      width: 120,
                                      child: Text(
                                        text,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }

                                  return DataRow(
                                    cells: [
                                      DataCell(buildCell(description)),
                                      DataCell(buildCell(deviceId)),
                                      DataCell(buildCell(mainType)),
                                      DataCell(buildCell(performedBy)),
                                      DataCell(buildCell(sensorId)),
                                      DataCell(_StatusChip(isOn: isOn)),
                                      DataCell(
                                          buildCell(_formatTimestamp(timestamp))),
                                    ],
                                  );
                                }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                if (isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'No devices connected yet',
                      style: TextStyle(color: Colors.grey),
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

class _StatusChip extends StatelessWidget {
  final bool isOn;

  const _StatusChip({required this.isOn});

  @override
  Widget build(BuildContext context) {
    final bg = isOn ? const Color(0xFFE7F7EC) : const Color(0xFFFFE8EA);
    final fg = isOn ? const Color(0xFF1B7A3A) : const Color(0xFFB0232E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOn ? 'ON' : 'OFF',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}