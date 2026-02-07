import 'package:cloud_firestore/cloud_firestore.dart';

class ErrorMessages {
  static String friendly(Object error) {
    final msg = error.toString().toLowerCase();

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return "You don't have access to this. Try refreshing!";
        case 'not-found':
          return 'This item has been deleted or moved.';
        case 'unavailable':
          return "Can't reach the server. Check your connection!";
        case 'unauthenticated':
          return 'Your session expired. Please sign in again.';
        case 'deadline-exceeded':
          return 'Request timed out. Try again in a moment.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }

    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return "Can't reach the server. Check your connection!";
    }

    if (msg.contains('permission') || msg.contains('denied')) {
      return "You don't have access to this. Try refreshing!";
    }

    if (msg.contains('not found') || msg.contains('not-found')) {
      return 'This item has been deleted or moved.';
    }

    return 'Something went wrong. Please try again.';
  }
}
