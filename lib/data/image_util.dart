import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// 갤러리에서 사진을 골라 용량을 줄인 JPEG base64 문자열로 반환한다.
/// 취소하면 null. Firestore 문서(1MB) 한도를 고려해 720px/품질70으로 압축.
Future<String?> pickResizedPhotoBase64() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final raw = await picked.readAsBytes();
  final jpg = _resizeJpeg(raw, maxSide: 720, quality: 70);
  return base64Encode(jpg);
}

Uint8List _resizeJpeg(Uint8List bytes, {int maxSide = 720, int quality = 70}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  img.Image out = decoded;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > maxSide) {
    if (decoded.width >= decoded.height) {
      out = img.copyResize(decoded, width: maxSide);
    } else {
      out = img.copyResize(decoded, height: maxSide);
    }
  }
  return img.encodeJpg(out, quality: quality);
}
