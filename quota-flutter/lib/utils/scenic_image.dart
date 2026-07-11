import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Random inspirational backdrop photos for the fullscreen quote view,
/// pulled from loremflickr (keyword-tagged Flickr photos, no API key).
/// Cached per quote for the session; returns null when offline so the
/// caller can fall back to a gradient.

const _themes = [
  'sunset',
  'sunrise',
  'mountains',
  'ocean',
  'starry,night',
  'forest,mist',
  'clouds,sky',
];

// Session salt so each app run gets a fresh set of photos.
final _salt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

final Map<String, Future<Uint8List?>> _cache = {};

Future<Uint8List?> scenicImageFor(String quoteId) =>
    _cache.putIfAbsent(quoteId, () async {
      final seed = (quoteId.hashCode ^ _salt).abs();
      final theme = _themes[seed % _themes.length];
      final uri = Uri.parse(
          'https://loremflickr.com/1080/1920/$theme?lock=${seed % 10000}');
      try {
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (_) {
        // Offline or fetch failed; caller falls back to a gradient.
      }
      _cache.remove(quoteId);
      return null;
    });
