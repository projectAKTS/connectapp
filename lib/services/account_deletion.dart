import 'package:flutter/foundation.dart';

/// True while the signed-in user's account is being deleted. The server
/// removes the profile doc before the app signs out, so the root gate shows
/// a spinner instead of treating the missing doc as "needs onboarding".
final ValueNotifier<bool> accountDeletionInProgress = ValueNotifier(false);
