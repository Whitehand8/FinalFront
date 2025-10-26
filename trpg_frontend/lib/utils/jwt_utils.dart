import 'dart:convert';

Map<String, dynamic>? parseJwtPayload(String Token) {
  try {
    final parts = Token.split('.');
    if (parts.length != 3) return null;

    final normalized = base64Url.normalize(parts[1]);
    final padded = _padBase64(normalized);
    final bytes = base64Url.decode(padded);
    final payload = utf8.decode(bytes);
    return jsonDecode(payload) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}

// base64 padding 보정 (iOS/Android 호환성)
String _padBase64(String unPadded) {
  final missing = 4 - (unPadded.length % 4);
  if (missing == 4) return unPadded;
  return unPadded + '=' * missing;
}
