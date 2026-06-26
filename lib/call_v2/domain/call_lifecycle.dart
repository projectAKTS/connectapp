enum CallLifecycle {
  ringing,
  accepted,
  active,
  completed,
  declined,
  cancelled,
  missed,
  failed;

  bool get isTerminal {
    switch (this) {
      case CallLifecycle.completed:
      case CallLifecycle.declined:
      case CallLifecycle.cancelled:
      case CallLifecycle.missed:
      case CallLifecycle.failed:
        return true;
      case CallLifecycle.ringing:
      case CallLifecycle.accepted:
      case CallLifecycle.active:
        return false;
    }
  }

  bool get isNonTerminal => !isTerminal;
}
