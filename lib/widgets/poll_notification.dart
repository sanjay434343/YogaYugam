import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
import '../services/auth_service.dart';

class PollNotification extends StatefulWidget {
  final Poll poll;

  const PollNotification({super.key, required this.poll});

  @override
  State<PollNotification> createState() => _PollNotificationState();
}

class _PollNotificationState extends State<PollNotification> {
  String? _selectedOption;
  final _pollService = PollService();
  final _authService = AuthService();

  Future<void> _submitAnswer() async {
    if (_selectedOption == null) return;

    try {
      await _pollService.submitPollAnswer(
        widget.poll.id,
        _selectedOption!,
        _authService.currentUser?.uid ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting response: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.poll.question,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...widget.poll.optionsList.map((option) => RadioListTile(
                  title: Text(option),
                  value: option,
                  groupValue: _selectedOption,
                  onChanged: (value) {
                    setState(() => _selectedOption = value as String);
                  },
                )),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedOption != null ? _submitAnswer : null,
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
