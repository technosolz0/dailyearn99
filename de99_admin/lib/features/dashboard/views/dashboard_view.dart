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

// New Feature Imports
import 'package:de99_admin/features/quiz_manager/views/quiz_manager_view.dart';
import 'package:de99_admin/features/wallet_manager/views/wallet_manager_view.dart';
import 'package:de99_admin/features/spin_engine/views/spin_engine_view.dart';
import 'package:de99_admin/features/fruit_manager/views/fruit_manager_view.dart';
import 'package:de99_admin/features/puzzle_manager/views/puzzle_manager_view.dart';
import 'package:de99_admin/features/arrow_manager/views/arrow_manager_view.dart';
import 'package:de99_admin/features/word_manager/views/word_manager_view.dart';
import 'package:de99_admin/features/portfolio_manager/views/portfolio_manager_view.dart';
import 'package:de99_admin/features/promo_codes/views/promo_codes_view.dart';
import 'package:de99_admin/features/lottery_engine/views/lottery_engine_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class NavigationItemSpec {
  final String title;
  final String shortTitle;
  final IconData icon;

  const NavigationItemSpec({
    required this.title,
    required this.shortTitle,
    required this.icon,
  });
}

class _DashboardViewState extends State<DashboardView> {
  int _currentIndex = 0;

  static const List<NavigationItemSpec> _navSpecs = [
    NavigationItemSpec(
      title: 'Overview Dashboard',
      shortTitle: 'Overview',
      icon: Icons.dashboard_outlined,
    ),
    NavigationItemSpec(
      title: 'User Management',
      shortTitle: 'Users',
      icon: Icons.people_outline,
    ),
    NavigationItemSpec(
      title: 'Pending Requests',
      shortTitle: 'Requests',
      icon: Icons.swap_horiz_outlined,
    ),
    NavigationItemSpec(
      title: 'Contests Controller',
      shortTitle: 'Contests',
      icon: Icons.sports_esports_outlined,
    ),
    NavigationItemSpec(
      title: 'Mines Controller',
      shortTitle: 'Mines',
      icon: Icons.grid_on_outlined,
    ),
    NavigationItemSpec(
      title: 'Plinko Controller',
      shortTitle: 'Plinko',
      icon: Icons.blur_linear_outlined,
    ),
    NavigationItemSpec(
      title: 'Notifications Manager',
      shortTitle: 'Alerts',
      icon: Icons.notifications_active_outlined,
    ),
    NavigationItemSpec(
      title: 'Quiz Manager',
      shortTitle: 'Quiz',
      icon: Icons.quiz_outlined,
    ),
    NavigationItemSpec(
      title: 'Wallet Manager',
      shortTitle: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
    ),
    NavigationItemSpec(
      title: 'Spin Engine',
      shortTitle: 'Spin Wheel',
      icon: Icons.rotate_right_outlined,
    ),
    NavigationItemSpec(
      title: 'Fruit Manager',
      shortTitle: 'Fruit Slicing',
      icon: Icons.restaurant_outlined,
    ),
    NavigationItemSpec(
      title: 'Puzzle Manager',
      shortTitle: 'Slide Puzzle',
      icon: Icons.extension_outlined,
    ),
    NavigationItemSpec(
      title: 'Arrow Manager',
      shortTitle: 'Go Arrows',
      icon: Icons.navigation_outlined,
    ),
    NavigationItemSpec(
      title: 'Word Manager',
      shortTitle: 'Word Puzzle',
      icon: Icons.font_download_outlined,
    ),
    NavigationItemSpec(
      title: 'Portfolio Manager',
      shortTitle: 'Portfolio',
      icon: Icons.web_outlined,
    ),
    NavigationItemSpec(
      title: 'Promo Codes',
      shortTitle: 'Promo Codes',
      icon: Icons.local_offer_outlined,
    ),
    NavigationItemSpec(
      title: 'Lottery Engine',
      shortTitle: 'Lucky Draw',
      icon: Icons.casino_outlined,
    ),
  ];

  void _navigateToTab(String shortTitle) {
    final index = _navSpecs.indexWhere((item) => item.shortTitle == shortTitle);
    if (index != -1) {
      setState(() {
        _currentIndex = index;
      });
      if (index == 0) {
        context.read<StatsCubit>().fetchStats();
      }
    }
  }

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
                    'Quick Links & Shortcuts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isWide)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.8,
                      children: [
                        _buildQuickActionCard(
                          title: 'Mines Game Panel',
                          subtitle: 'Manage house edge, maintenance, and safety overrides',
                          icon: Icons.grid_on,
                          color: AdminTheme.primary,
                          onTap: () => _navigateToTab('Mines'),
                        ),
                        _buildQuickActionCard(
                          title: 'Plinko Game Panel',
                          subtitle: 'Manage bets, rows, and bucket probabilities',
                          icon: Icons.blur_linear,
                          color: AdminTheme.info,
                          onTap: () => _navigateToTab('Plinko'),
                        ),
                        _buildQuickActionCard(
                          title: 'Spin Wheel Engine',
                          subtitle: 'Configure spin RTPs, metrics, and logs',
                          icon: Icons.rotate_right,
                          color: AdminTheme.success,
                          onTap: () => _navigateToTab('Spin Wheel'),
                        ),
                        _buildQuickActionCard(
                          title: 'Lucky Draw Engine',
                          subtitle: 'Manage schedules and execute drawings',
                          icon: Icons.casino,
                          color: AdminTheme.warning,
                          onTap: () => _navigateToTab('Lucky Draw'),
                        ),
                        _buildQuickActionCard(
                          title: 'Quiz Manager',
                          subtitle: 'Manage questions database and active math contests',
                          icon: Icons.quiz,
                          color: AdminTheme.secondary,
                          onTap: () => _navigateToTab('Quiz'),
                        ),
                        _buildQuickActionCard(
                          title: 'Promo Codes',
                          subtitle: 'Manage system-wide deposit/signup promotion codes',
                          icon: Icons.local_offer,
                          color: Colors.pinkAccent,
                          onTap: () => _navigateToTab('Promo Codes'),
                        ),
                      ],
                    )
                  else ...[
                    _buildQuickActionCard(
                      title: 'Mines Game Panel',
                      subtitle: 'Manage house edge, maintenance, and safety overrides',
                      icon: Icons.grid_on,
                      color: AdminTheme.primary,
                      onTap: () => _navigateToTab('Mines'),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionCard(
                      title: 'Plinko Game Panel',
                      subtitle: 'Manage bets, rows, and bucket probabilities',
                      icon: Icons.blur_linear,
                      color: AdminTheme.info,
                      onTap: () => _navigateToTab('Plinko'),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionCard(
                      title: 'Spin Wheel Engine',
                      subtitle: 'Configure spin RTPs, metrics, and logs',
                      icon: Icons.rotate_right,
                      color: AdminTheme.success,
                      onTap: () => _navigateToTab('Spin Wheel'),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionCard(
                      title: 'Lucky Draw Engine',
                      subtitle: 'Manage schedules and execute drawings',
                      icon: Icons.casino,
                      color: AdminTheme.warning,
                      onTap: () => _navigateToTab('Lucky Draw'),
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

  Widget _buildNavigationList({required bool isDrawer}) {
    final navItems = _navSpecs;
    return Column(
      children: [
        // Premium Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AdminTheme.surfaceDark, AdminTheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: AdminTheme.borderColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AdminTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: AdminTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILYEARN99',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.textMain,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Admin Console v2.0',
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable List of Navigation Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: navItems.length,
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = _currentIndex == index;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AdminTheme.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? const Border(
                            left: BorderSide(
                              color: AdminTheme.primary,
                              width: 3.5,
                            ),
                          )
                        : null,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(
                      left: isSelected ? 12.5 : 16,
                      right: 16,
                    ),
                    leading: Icon(
                      item.icon,
                      color: isSelected ? AdminTheme.primary : AdminTheme.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? AdminTheme.textMain : AdminTheme.textMuted,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13.5,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                      if (index == 0) {
                        context.read<StatsCubit>().fetchStats();
                      }
                      if (isDrawer) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // Footer / Logout Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AdminTheme.borderColor),
            ),
          ),
          child: InkWell(
            onTap: () => _showLogoutConfirmation(),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: const [
                  Icon(
                    Icons.logout_rounded,
                    color: AdminTheme.error,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Logout Session',
                    style: TextStyle(
                      color: AdminTheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation() {
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
      const QuizManagerView(),
      const WalletManagerView(),
      const SpinEngineView(),
      const FruitManagerView(),
      const PuzzleManagerView(),
      const ArrowManagerView(),
      const WordManagerView(),
      const PortfolioManagerView(),
      const PromoCodesView(),
      const LotteryEngineView(),
    ];

    final bool isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(_navSpecs[_currentIndex].title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AdminTheme.error),
            onPressed: _showLogoutConfirmation,
          ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: AdminTheme.surfaceDark,
              child: _buildNavigationList(isDrawer: true),
            ),
      body: isWide
          ? Row(
              children: [
                Container(
                  width: 260,
                  color: AdminTheme.surfaceDark,
                  child: _buildNavigationList(isDrawer: false),
                ),
                const VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: AdminTheme.borderColor,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: tabs,
                  ),
                ),
              ],
            )
          : IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
    );
  }
}
