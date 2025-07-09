import 'package:flutter/material.dart';
import '../models/poll.dart';

class PollResults extends StatelessWidget {
  final Poll poll;

  const PollResults({super.key, required this.poll});

  @override
  Widget build(BuildContext context) {
    final total = poll.results.values.fold<int>(0, (sum, count) => sum + count);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poll.question,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...poll.optionsList.map((option) {
              final count = poll.results[option] ?? 0;
              final percentage = total > 0 ? (count / total * 100) : 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    Text('${percentage.toStringAsFixed(1)}% ($count votes)'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
