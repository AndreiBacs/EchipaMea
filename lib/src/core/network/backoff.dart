/// Delays between reconnection attempts: [initial], doubling each time, up to
/// [max]. [reset] once a connection succeeds.
class Backoff {
  Backoff({
    this.initial = const Duration(seconds: 2),
    this.max = const Duration(seconds: 60),
  });

  final Duration initial;
  final Duration max;
  int _attempt = 0;

  Duration next() {
    final delay = initial * (1 << _attempt);
    // Stop doubling once past the cap, so the shift can never overflow.
    if (delay < max) _attempt++;
    return delay < max ? delay : max;
  }

  void reset() => _attempt = 0;
}
