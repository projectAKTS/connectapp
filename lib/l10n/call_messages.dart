import 'package:connect_app/l10n/l10n.dart';

/// Call status messages are set as English text deep in the call flow,
/// including during teardown when no BuildContext is safe to use. They are
/// translated only where they are drawn; unknown text is shown as is.
class CallMessages {
  CallMessages._();

  static String localize(AppLocalizations l, String message) {
    switch (message) {
      case 'Call ended':
        return l.callEnded;
      case 'Call connection failed. Please try again.':
        return l.callConnectionFailed;
      case 'Call connection timed out. Please try again.':
        return l.callTimedOut;
      case 'Call network failed. Please try again.':
        return l.callNetworkFailed;
      case 'Call setup failed. Please try again.':
        return l.callSetupFailed;
      case 'Microphone permission is required for this call.':
        return l.callMicRequired;
      case 'No answer':
        return l.callNoAnswer;
      case 'User declined or unavailable':
        return l.callDeclined;
      case 'User unavailable':
        return l.callUnavailable;
    }
    return message;
  }
}
