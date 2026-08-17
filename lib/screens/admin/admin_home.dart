import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_service.dart';
import '../../l10n/app_strings.dart';
import '../reports/reports_screen.dart';
import 'admin_groups_screen.dart';
import 'admin_manage_screen.dart';
import 'admin_reward_screen.dart';

/// 관리자 전용 홈. 보고서 관리 / 출석 확인 2개 탭.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  Future<void> _logout() async {
    await context.read<AuthService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ReportsScreen(adminView: true),
      AdminGroupsScreen(showLogout: true, onLogout: _logout),
      AdminRewardScreen(showLogout: true, onLogout: _logout),
      AdminManageScreen(showLogout: true, onLogout: _logout),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            selectedIcon: const Icon(Icons.description),
            label: tr(context, 'admin_nav_reports'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: tr(context, 'admin_nav_groups'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.card_giftcard_outlined),
            selectedIcon: const Icon(Icons.card_giftcard),
            label: tr(context, 'admin_nav_reward'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: const Icon(Icons.admin_panel_settings),
            label: tr(context, 'admin_nav_manage'),
          ),
        ],
      ),
    );
  }
}
