import 'package:cloud_firestore/cloud_firestore.dart';

/// 팀/그룹 (관리자 생성). 4자리 PIN으로 접근/가입.
class Group {
  final String id;
  final String name;
  final String pin; // 4자리
  final int memberCount;

  const Group({
    required this.id,
    required this.name,
    required this.pin,
    this.memberCount = 0,
  });

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Group(
      id: doc.id,
      name: (m['name'] as String?) ?? '',
      pin: (m['pin'] as String?) ?? '',
      memberCount: (m['memberCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// PIN 없이 공개되는 그룹 요약(멘토 선택 목록용).
class GroupInfo {
  final String id;
  final String name;
  const GroupInfo({required this.id, required this.name});
}

/// 관리자용: 멤버의 로그인 계정 정보(아이디=이메일).
class MemberAccount {
  final String uid;
  final String name;
  final String email; // 로그인 아이디
  const MemberAccount(
      {required this.uid, required this.name, required this.email});
}
