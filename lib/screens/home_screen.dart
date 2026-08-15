import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_service.dart';
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

  void _goTo(int i) => setState(() => _index = i);

  // 관리자 여부를 실제 admins 컬렉션으로 확인(세션 플래그 대신 → 재시작에도 견고).
  late final Future<bool> _adminCheck =
      context.read<AuthService>().checkIsAdmin();

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
      DashboardScreen(onNavigate: _goTo),
      const ReportsScreen(),
      const ActivitiesScreen(),
      const AttendanceScreen(),
      const CertificationsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
