import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// 프로필 사진 관리. 갤러리에서 고른 이미지를 256px JPEG로 리사이즈해
/// `users/{uid}.photoBase64` 에 저장한다(Firebase Storage 불필요 = 무료).
/// 리사이즈 후 보통 10~30KB라 Firestore 1MB 문서 한도에 안전하다.
class ProfileService {
  ProfileService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ImagePicker _picker = ImagePicker();

  String? get _uid => _auth.currentUser?.uid;

  /// 저장된 프로필 사진 바이트. 없으면 null.
  Future<Uint8List?> load() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    final b64 = doc.data()?['photoBase64'] as String?;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// 갤러리에서 사진을 골라 리사이즈 후 저장. 반환값은 표시용 바이트.
  /// 사용자가 취소하면 null.
  Future<Uint8List?> pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final raw = await picked.readAsBytes();
    final jpg = _toThumbnailJpeg(raw);

    final uid = _uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).set(
        {'photoBase64': base64Encode(jpg)},
        SetOptions(merge: true),
      );
    }
    return jpg;
  }

  /// 프로필 사진 제거.
  Future<void> remove() async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'photoBase64': FieldValue.delete()},
      SetOptions(merge: true),
    );
  }

  /// 256px 정사각 중심 크롭 JPEG로 변환(플랫폼 무관 일관 처리).
  Uint8List _toThumbnailJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    // 정사각 중심 크롭
    final side = decoded.width < decoded.height ? decoded.width : decoded.height;
    final cropped = img.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = img.copyResize(cropped, width: 256, height: 256);
    return img.encodeJpg(resized, quality: 80);
  }
}
