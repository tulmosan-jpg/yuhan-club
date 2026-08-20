import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_config.dart';
import '../data/auth_service.dart';
import '../data/messaging_service.dart';
import '../l10n/app_strings.dart';
import 'admin/admin_home.dart';
import 'dashboard/dashboard_screen.dart';
import 'reports/reports_screen.dart';
import 'activities/activities_screen.dart';
import 'attendance/attendance_screen.dart';
import 'certifications/certifications_screen.dart';

/// 하단 탭 네비게이션 셸.
/// 관리자 로그인 세션에서는 보고서 관리 화면만 노출한다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  // 출석 탭 리워드 섹션으로 스크롤 요청 신호(값이 바뀔 때마다 스크롤).
  final ValueNotifier<int> _rewardScroll = ValueNotifier(0);
  // 출석 탭이 보일 때마다 그룹 목록을 다시 불러오게 하는 신호.
  final ValueNotifier<int> _groupsRefresh = ValueNotifier(0);
  // 홈 탭이 보일 때마다 대시보드를 다시 로드하게 하는 신호.
  final ValueNotifier<int> _homeRefresh = ValueNotifier(0);

  void _goTo(int i) {
    setState(() => _index = i);
    if (i == 0) _homeRefresh.value++;
    if (i == 3) _groupsRefresh.value++;
  }

  // 홈 리워드 노드 → 출석 탭으로 이동 + 리워드 섹션으로 스크롤.
  void _goToReward() {
    setState(() => _index = 3);
    _groupsRefresh.value++;
    _rewardScroll.value++;
  }

  @override
  void dispose() {
    _rewardScroll.dispose();
    _groupsRefresh.dispose();
    _homeRefresh.dispose();
    super.dispose();
  }

  // 관리자 여부를 실제 admins 컬렉션으로 확인(세션 플래그 대신 → 재시작에도 견고).
  late final Future<bool> _adminCheck =
      context.read<AuthService>().checkIsAdmin();

  @override
  void initState() {
    super.initState();
    // 로그인 세션에서 FCM 토큰 등록 + 알림 설정 동기화(서버 푸시 수신).
    if (!AppConfig.useMock) {
      MessagingService.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminCheck,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // 관리자 → 보고서/출석만. 일반 회원 → 전체 앱.
        return snap.data == true ? const AdminHome() : _buildMemberShell(context);
      },
    );
  }

  Widget _buildMemberShell(BuildContext context) {
    final pages = [
      DashboardScreen(
          onNavigate: _goTo, onReward: _goToReward, refresh: _homeRefresh),
      ReportsScreen(onNeedMentor: () => _goTo(3)),
      const ActivitiesScreen(),
      AttendanceScreen(
          rewardScroll: _rewardScroll, groupsRefresh: _groupsRefresh),
      const CertificationsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: tr(context, 'nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            selectedIcon: const Icon(Icons.description),
            label: tr(context, 'nav_reports'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign_outlined),
            selectedIcon: const Icon(Icons.campaign),
            label: tr(context, 'nav_activities'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_available_outlined),
            selectedIcon: const Icon(Icons.event_available),
            label: tr(context, 'nav_attendance'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.workspace_premium_outlined),
            selectedIcon: const Icon(Icons.workspace_premium),
            label: tr(context, 'nav_certs'),
          ),
        ],
      ),
    );
  }
}
