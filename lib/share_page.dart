import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SharePage extends StatelessWidget {
  const SharePage({super.key});

  final String appLink = 'https://example.com/app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share App'),
        centerTitle: true,
      ),
      body: Center( 
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appLink,
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: appLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
                child: const Text('Copy Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}