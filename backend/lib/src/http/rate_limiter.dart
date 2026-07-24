import 'package:dart_frog/dart_frog.dart';

/// A simple in-memory fixed-window rate limiter, keyed by client.
///
/// Suitable for a single-instance deployment (as here). A multi-instance
/// deployment would use a shared store (e.g. Redis) instead.
class RateLimiter {
  RateLimiter({required this.maxRequests, required this.window});

  final int maxRequests;
  final Duration window;
  final _hits = <String, List<DateTime>>{};

  /// Records a request for [key] and returns true if it is within the limit.
  bool allow(String key) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    final hits = _hits.putIfAbsent(key, () => <DateTime>[])
      ..removeWhere((t) => t.isBefore(cutoff));
    if (hits.length >= maxRequests) return false;
    hits.add(now);
    return true;
  }
}

/// Public lead submissions: 10 per minute per client IP.
final publicSubmissionLimiter =
    RateLimiter(maxRequests: 10, window: const Duration(minutes: 1));

/// Best-effort client IP: prefer the proxy's X-Forwarded-For (Render/Vercel
/// set this), falling back to a shared bucket when unavailable.
String clientIp(RequestContext context) {
  final fwd = context.request.headers['x-forwarded-for'] ??
      context.request.headers['X-Forwarded-For'];
  if (fwd != null && fwd.isNotEmpty) {
    return fwd.split(',').first.trim();
  }
  return 'unknown';
}
