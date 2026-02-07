import 'package:flutter/material.dart';

class AdminManageSensorsPage extends StatelessWidget {
  const AdminManageSensorsPage({super.key});

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
          'Manage Sensors',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add Sensor (UI only)')),
                );
              },
              fields: const [
                _SensorField(label: 'Sensor ID :'),
                _SensorField(label: 'Sensor Type :'),
                _SensorField(label: 'Location :'),
              ],
            ),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'Update Sensor',
              buttonText: 'Update',
              buttonColor: const Color(0xFFFEE0A7),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Update Sensor (UI only)')),
                );
              },
              fields: const [
                _SensorField(
                  label: 'Select Sensor ID :',
                  isDropdownVisual: true,
                ),
                _SensorField(label: 'New Name :'),
                _SensorField(label: 'New Status :'),
                _SensorField(label: 'New Location :'),
              ],
            ),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'Delete Sensor',
              buttonText: 'Delete',
              buttonColor: const Color(0xFFFFC7CF),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delete Sensor (UI only)')),
                );
              },
              fields: const [
                _SensorField(label: 'Sensor ID :'),
                _SensorField(label: 'Sensor Type :'),
                _SensorField(label: 'Location :'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// الكرت الكامل لكل جزء (Add / Update / Delete)
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

// حقل واحد داخل كل سكشن
class _SensorField extends StatelessWidget {
  final String label;
  final bool isDropdownVisual;

  const _SensorField({
    required this.label,
    this.isDropdownVisual = false,
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
            readOnly: isDropdownVisual, // بس شكل دروب داون – ما فيه منطق حقيقي
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              suffixIcon: isDropdownVisual
                  ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}