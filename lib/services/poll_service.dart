import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poll.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Poll>> getActivePolls() {
    print('Fetching active polls...'); // Debug print
    return _firestore
        .collection('polls')
        .doc('poll1')  // Since your data is under poll1 document
        .snapshots()
        .map((doc) {
          print('Raw data: ${doc.data()}'); // Debug print
          if (!doc.exists) {
            print('No document found!'); // Debug print
            return [];
          }
          return [Poll.fromMap(doc.data()!, doc.id)];
        });
  }

  Future<void> submitPollAnswer(String pollId, String answer, String userId) async {
    // First, ensure the results map exists
    await _firestore.collection('polls').doc(pollId).set({
      'results': {answer: 0},
    }, SetOptions(merge: true));

    // Then update the count
    await _firestore.collection('polls').doc(pollId).update({
      'results.$answer': FieldValue.increment(1),
    });
  }
}
