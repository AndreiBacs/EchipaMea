/// Collapses concurrent calls into one in-flight run.
///
/// Used for token refresh: when several requests hit 401 at once, they must
/// share one refresh. Refresh tokens rotate, so a second parallel refresh would
/// present the token the first one just spent -- and the server treats that as
/// theft and revokes the whole session.
class SingleFlight<T> {
  Future<T>? _inFlight;

  Future<T> run(Future<T> Function() task) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = task().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }
}
