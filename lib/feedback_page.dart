import 'package:flutter/material.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int q1 = 1;
  int q2 = 1;
  int q3 = 1;
  int q4 = 1;
  int q5 = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
           // مربع كبير يحتوي كل الاسئلة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 
                  const Center(
                    child: Text(
                      'Feedback Survey',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue, 
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ratingQuestion(
                      '1. Ease of Use: Is the app interface clear and easy to navigate?',
                      q1, (val) => setState(() => q1 = val)),
                  const SizedBox(height: 12),
                  _ratingQuestion(
                      '2. Content Quality: Are the tips and data in the app useful?',
                      q2, (val) => setState(() => q2 = val)),
                  const SizedBox(height: 12),
                  _ratingQuestion(
                      '3. App Design: Is the app design attractive and organized?',
                      q3, (val) => setState(() => q3 = val)),
                  const SizedBox(height: 12),
                  _ratingQuestion(
                      '4. App Performance: Is the app smooth and fast?',
                      q4, (val) => setState(() => q4 = val)),
                  const SizedBox(height: 12),
                  _ratingQuestion(
                      '5. Overall Satisfaction: Overall, how do you rate your experience?',
                      q5, (val) => setState(() => q5 = val)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Feedback submitted successfully!')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingQuestion(String question, int currentValue, Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(color: Colors.black), 
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              int value = index + 1;
              return ChoiceChip(
                label: Text('$value'),
                selected: currentValue == value,
                onSelected: (_) => onChanged(value),
              );
            }),
          ),
        ],
      ),
    );
  }
}