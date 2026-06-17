import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/auth/bloc/auth_cubit.dart';
import 'package:de99_admin/features/dashboard/bloc/stats_cubit.dart';
import 'package:de99_admin/features/users/views/users_view.dart';
import 'package:de99_admin/features/requests/views/requests_view.dart';
import 'package:de99_admin/features/contests/views/contests_view.dart';
import 'package:de99_admin/features/notifications/views/notifications_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Overview Dashboard',
    'User Management',
    'Pending Requests',
    'Contests Controller',
    'Notifications Manager',
  ];

  @override
  void initState() {
    super.initState();
    // Load stats on startup
    context.read<StatsCubit>().fetchStats();
  }

  Widget _buildOverviewTab() {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    
    return RefreshIndicator(
      onRefresh: () => context.read<StatsCubit>().fetchStats(),
      child: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state is StatsLoading) {
            return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
          } else if (state is StatsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: AdminTheme.error),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<StatsCubit>().fetchStats(),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is StatsLoaded) {
            final stats = state.stats;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats Grid
                  _buildStatCard(
                    title: 'Total Users',
                    value: stats.totalUsers.toString(),
                    icon: Icons.people_outline,
                    color: AdminTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Platform Net Revenue',
                    value: currencyFormatter.format(stats.totalRevenue),
                    icon: Icons.account_balance_wallet_outlined,
                    color: stats.totalRevenue >= 0 ? AdminTheme.success : AdminTheme.error,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Total Deposits',
                    value: currencyFormatter.format(stats.totalDeposits),
                    icon: Icons.payments_outlined,
                    color: AdminTheme.success,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Winnings Distributed',
                    value: currencyFormatter.format(stats.totalWinningsPaid),
                    icon: Icons.emoji_events_outlined,
                    color: AdminTheme.warning,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Active Quiz Contests',
                    value: stats.activeContests.toString(),
                    icon: Icons.stars_outlined,
                    color: AdminTheme.info,
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AdminTheme.textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _buildOverviewTab(),
      const UsersView(),
      const RequestsView(),
      const ContestsView(),
      const NotificationsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AdminTheme.error),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to end your admin session?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<AuthCubit>().logout();
                      },
                      child: const Text('LOGOUT', style: TextStyle(color: AdminTheme.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Refresh stats when tapping the dashboard tab
          if (index == 0) {
            context.read<StatsCubit>().fetchStats();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports_outlined),
            activeIcon: Icon(Icons.sports_esports),
            label: 'Contests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active_outlined),
            activeIcon: Icon(Icons.notifications_active),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
