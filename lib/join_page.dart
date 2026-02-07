import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class JoinPage extends StatelessWidget {
  const JoinPage({super.key});

  final String instagram = 'https://instagram.com/example';
  final String snapchat = 'https://snapchat.com/add/example';
  final String xPlatform = 'https://x.com/example';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Us'),
        centerTitle: true,
      ),
      body: Center( 
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => _launchUrl(instagram),
                child: const Text('Instagram'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _launchUrl(snapchat),
                child: const Text('Snapchat'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _launchUrl(xPlatform),
                child: const Text('X Platform'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}