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
import 'package:de99_admin/features/mines/views/mines_panel_view.dart';
import 'package:de99_admin/features/plinko/views/plinko_panel_view.dart';

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
    'Mines Controller',
    'Plinko Controller',
    'Notifications Manager',
  ];

  @override
  void initState() {
    super.initState();
    // Load stats on startup
    context.read<StatsCubit>().fetchStats();
  }

  Widget _buildOverviewTab() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );

    return RefreshIndicator(
      onRefresh: () => context.read<StatsCubit>().fetchStats(),
      child: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state is StatsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AdminTheme.primary),
            );
          } else if (state is StatsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: AdminTheme.error,
                    ),
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
            final bool isWide = MediaQuery.of(context).size.width > 800;

            final List<Widget> statWidgets = [
              _buildStatCard(
                title: 'Total Users',
                value: stats.totalUsers.toString(),
                icon: Icons.people_outline,
                color: AdminTheme.primary,
              ),
              _buildStatCard(
                title: 'Platform Net Revenue',
                value: currencyFormatter.format(stats.totalRevenue),
                icon: Icons.account_balance_wallet_outlined,
                color: stats.totalRevenue >= 0
                    ? AdminTheme.success
                    : AdminTheme.error,
              ),
              _buildStatCard(
                title: 'Total Deposits',
                value: currencyFormatter.format(stats.totalDeposits),
                icon: Icons.payments_outlined,
                color: AdminTheme.success,
              ),
              _buildStatCard(
                title: 'Winnings Distributed',
                value: currencyFormatter.format(stats.totalWinningsPaid),
                icon: Icons.emoji_events_outlined,
                color: AdminTheme.warning,
              ),
              _buildStatCard(
                title: 'Active Quiz Contests',
                value: stats.activeContests.toString(),
                icon: Icons.stars_outlined,
                color: AdminTheme.info,
              ),
            ];

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

                  if (isWide)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 100,
                      ),
                      itemCount: statWidgets.length,
                      itemBuilder: (context, index) => statWidgets[index],
                    )
                  else
                    ...statWidgets.expand((w) => [w, const SizedBox(height: 16)]),

                  const SizedBox(height: 24),
                  const Text(
                    'Quick Links',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isWide)
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Mines Game Panel',
                            subtitle: 'Manage house edge, maintenance settings, and custom RTP range overrides',
                            icon: Icons.grid_on,
                            color: AdminTheme.primary,
                            onTap: () {
                              setState(() {
                                _currentIndex = 4;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Plinko Game Panel',
                            subtitle: 'Manage bets, rows, game state, and bucket probability rules',
                            icon: Icons.blur_linear,
                            color: AdminTheme.info,
                            onTap: () {
                              setState(() {
                                _currentIndex = 5;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildQuickActionCard(
                      title: 'Mines Game Panel',
                      subtitle: 'Manage house edge, maintenance, and safety overrides',
                      icon: Icons.grid_on,
                      color: AdminTheme.primary,
                      onTap: () {
                        setState(() {
                          _currentIndex = 4;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionCard(
                      title: 'Plinko Game Panel',
                      subtitle: 'Manage bets, rows, and bucket probabilities',
                      icon: Icons.blur_linear,
                      color: AdminTheme.info,
                      onTap: () {
                        setState(() {
                          _currentIndex = 5;
                        });
                      },
                    ),
                  ],
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminTheme.textMain,
                      fontSize: 18,
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

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AdminTheme.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AdminTheme.textMuted),
            ],
          ),
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
      const MinesPanelView(),
      const PlinkoPanelView(),
      const NotificationsView(),
    ];

    final bool isWide = MediaQuery.of(context).size.width > 800;

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
                  content: const Text(
                    'Are you sure you want to end your admin session?',
                  ),
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
                      child: const Text(
                        'LOGOUT',
                        style: TextStyle(color: AdminTheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    if (index == 0) {
                      context.read<StatsCubit>().fetchStats();
                    }
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AdminTheme.primary),
                  unselectedIconTheme: const IconThemeData(color: AdminTheme.textMuted),
                  selectedLabelTextStyle: const TextStyle(color: AdminTheme.primary, fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: const TextStyle(color: AdminTheme.textMuted),
                  backgroundColor: AdminTheme.surfaceDark,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Users'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.swap_horiz_outlined),
                      selectedIcon: Icon(Icons.swap_horiz),
                      label: Text('Requests'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.sports_esports_outlined),
                      selectedIcon: Icon(Icons.sports_esports),
                      label: Text('Contests'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_on_outlined),
                      selectedIcon: Icon(Icons.grid_on),
                      label: Text('Mines'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.blur_linear_outlined),
                      selectedIcon: Icon(Icons.blur_linear),
                      label: Text('Plinko'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.notifications_active_outlined),
                      selectedIcon: Icon(Icons.notifications_active),
                      label: Text('Alerts'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AdminTheme.borderColor),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: tabs),
                ),
              ],
            )
          : IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
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
                  icon: Icon(Icons.grid_on_outlined),
                  activeIcon: Icon(Icons.grid_on),
                  label: 'Mines',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.blur_linear_outlined),
                  activeIcon: Icon(Icons.blur_linear),
                  label: 'Plinko',
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
