import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/models/user_model.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/models/contest_model.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/features/contest/quiz_screen.dart';
import 'package:dailyearn99/core/widgets/deposit_bottom_sheet.dart';
import 'package:dailyearn99/features/image_puzzle/screens/puzzle_lobby_screen.dart';
import 'package:dailyearn99/features/word_puzzle/screens/word_lobby_screen.dart';
import 'package:dailyearn99/features/fruit_slicing/screens/fruit_lobby_screen.dart';
import 'package:dailyearn99/features/go_arrows/screens/arrow_lobby_screen.dart';
import 'package:dailyearn99/features/notifications/screens/notifications_screen.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';
import 'package:dailyearn99/core/utils/date_formatter.dart';
import 'package:dailyearn99/features/lottery/screens/lottery_lobby_screen.dart';
import 'package:dailyearn99/features/lottery/repository/lottery_repository.dart';
import 'package:dailyearn99/core/widgets/lottery_countdown_dialog.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/features/mines/mines_game_screen.dart';
import 'package:dailyearn99/features/plinko/plinko_game_screen.dart';
import 'package:dailyearn99/features/blackjack/blackjack_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _hasShownLotteryPopup = false;

  @override
  void initState() {
    super.initState();
    // Fetch contests when home opens
    context.read<AppBloc>().add(FetchContestsEvent());

    // Check and show lottery popup on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowLotteryPopup();
    });
  }

  Future<void> _checkAndShowLotteryPopup() async {
    if (_hasShownLotteryPopup) return;

    try {
      final repository = LotteryRepository(getIt<ApiClient>());
      final draws = await repository.fetchLotteryDraws();

      final activeDraws = draws.where(
        (draw) =>
            draw.status == 'OPEN' && draw.drawTime.isAfter(DateTime.now()),
      );

      if (activeDraws.isEmpty) return;
      final activeDraw = activeDraws.first;

      _hasShownLotteryPopup = true;

      if (!mounted) return;

      final shouldBuy = await LotteryCountdownDialog.show(context, activeDraw);
      if (shouldBuy == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LotteryLobbyScreen()),
        ).then((_) {
          if (mounted) {
            context.read<AppBloc>().add(LoadProfileEvent());
          }
        });
      }
    } catch (e) {
      print("Error showing lottery popup on home screen: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final user = state.currentUser;
        final activeContests = state.contests.where((contest) {
          final isCompleted =
              user?.completedContestIds.contains(contest.id) ?? false;
          return !isCompleted;
        }).toList();

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<AppBloc>().add(FetchContestsEvent());
              context.read<AppBloc>().add(LoadProfileEvent());
            },
            color: AppTheme.accentCyan,
            child: CustomScrollView(
              slivers: [
                // Top Header Bar
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: AppTheme.darkBg,
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'DailyEarn99',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Welcome back, ${user?.phone ?? ""}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // if (user?.kycStatus == "VERIFIED")
                        //   Padding(
                        //     padding: const EdgeInsets.only(
                        //       left: 5.0,
                        //       right: 15,
                        //     ),
                        //     child: Container(
                        //       padding: const EdgeInsets.symmetric(
                        //         horizontal: 6,
                        //         vertical: 2,
                        //       ),
                        //       decoration: BoxDecoration(
                        //         color: AppTheme.accentEmerald.withOpacity(0.1),
                        //         borderRadius: BorderRadius.circular(4),
                        //         border: Border.all(
                        //           color: AppTheme.accentEmerald.withOpacity(
                        //             0.3,
                        //           ),
                        //         ),
                        //       ),
                        //       child: const Text(
                        //         'KYC OK',
                        //         style: TextStyle(
                        //           fontSize: 8,
                        //           color: AppTheme.accentEmerald,
                        //           fontWeight: FontWeight.bold,
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                      ],
                    ),
                  ),
                ),

                // Balance summary card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Card(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.cardBg,
                              Colors.white.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL WALLET BALANCE',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${user?.totalBalance.toStringAsFixed(2) ?? "0.00"}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: AppTheme.borderCol, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _balanceSubItem(
                                  'Deposit',
                                  '₹${user?.depositBalance.toStringAsFixed(2) ?? "0.00"}',
                                  AppTheme.accentCyan,
                                ),
                                _balanceSubItem(
                                  'Winnings',
                                  '₹${user?.winningBalance.toStringAsFixed(2) ?? "0.00"}',
                                  AppTheme.accentEmerald,
                                ),
                                _balanceSubItem(
                                  'Bonus',
                                  '₹${user?.bonusBalance.toStringAsFixed(2) ?? "0.00"}',
                                  AppTheme.accentPurple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Redesigned Game Arenas Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🎮 GAME ZONES',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Compete & earn real cash rewards',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.accentCyan.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentEmerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '5 LIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Lucky Draw Arena full-width featured card (moved in front)
                        _buildFeaturedGameCard(
                          context: context,
                          title: 'Lottery Lucky Draw',
                          emoji: '🎟️',
                          desc:
                              'Join daily draws with massive cash prizes. Buy tickets now!',
                          badge: 'LIVE JACKPOT',
                          colors: [
                            const Color(0xFF0D1B2A),
                            const Color(0xFF0F3A40),
                          ],
                          borderColor: AppTheme.accentTeal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LotteryLobbyScreen(),
                              ),
                            ).then((_) {
                              context.read<AppBloc>().add(LoadProfileEvent());
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturedGameCard(
                          context: context,
                          title: 'Mines',
                          emoji: '💣',
                          desc:
                              'Stake style provably fair Mines. Select tiles & Cash Out instantly!',
                          badge: 'HOT CASINO',
                          colors: [
                            const Color(0xFF0F212E),
                            const Color(0xFF1E3545),
                          ],
                          borderColor: const Color(0xFF00E676),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MinesGameScreen(),
                              ),
                            ).then((_) {
                              if (context.mounted) {
                                context.read<AppBloc>().add(LoadProfileEvent());
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturedGameCard(
                          context: context,
                          title: 'Plinko',
                          emoji: '🔴',
                          desc:
                              'Drop balls down the peg pyramid, hit multipliers & multiply your stake!',
                          badge: 'NEW CASINO',
                          colors: [
                            const Color(0xFF1E0E1B),
                            const Color(0xFF33152C),
                          ],
                          borderColor: const Color(0xFFFF2D55),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlinkoGameScreen(),
                              ),
                            ).then((_) {
                              if (context.mounted) {
                                context.read<AppBloc>().add(LoadProfileEvent());
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturedGameCard(
                          context: context,
                          title: 'Blackjack',
                          emoji: '🃏',
                          desc:
                              'Play classic 21. Hit, stand, double down, or split to beat the dealer!',
                          badge: 'LIVE CLASSIC',
                          colors: [
                            const Color(0xFF0F2027),
                            const Color(0xFF203A43),
                          ],
                          borderColor: AppTheme.accentTeal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BlackjackGameScreen(),
                              ),
                            ).then((_) {
                              if (context.mounted) {
                                context.read<AppBloc>().add(LoadProfileEvent());
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Grid of 4 main mini-games (2x2 grid)
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                          children: [
                            _buildGameGridItem(
                              context: context,
                              title: 'Image Puzzle',
                              emoji: '🧩',
                              desc: 'Rearrange & win cash',
                              tag: 'PUZZLE',
                              colors: [
                                const Color(0xFF151030),
                                const Color(0xFF2E1A47),
                              ],
                              borderColor: AppTheme.accentPurple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PuzzleLobbyScreen(),
                                  ),
                                ).then((_) {
                                  context.read<AppBloc>().add(
                                    LoadProfileEvent(),
                                  );
                                });
                              },
                            ),
                            _buildGameGridItem(
                              context: context,
                              title: 'Word Puzzle',
                              emoji: '🔤',
                              desc: 'Unscramble words',
                              tag: 'BRAIN',
                              colors: [
                                const Color(0xFF0F1B29),
                                const Color(0xFF132A44),
                              ],
                              borderColor: AppTheme.accentCyan,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const WordLobbyScreen(),
                                  ),
                                ).then((_) {
                                  context.read<AppBloc>().add(
                                    LoadProfileEvent(),
                                  );
                                });
                              },
                            ),
                            _buildGameGridItem(
                              context: context,
                              title: 'Fruit Slice',
                              emoji: '🍓',
                              desc: 'Slice & dodge bombs',
                              tag: 'ACTION',
                              colors: [
                                const Color(0xFF2C0A02),
                                const Color(0xFF4A190C),
                              ],
                              borderColor: const Color(0xFFFF4500),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FruitLobbyScreen(),
                                  ),
                                ).then((_) {
                                  context.read<AppBloc>().add(
                                    LoadProfileEvent(),
                                  );
                                });
                              },
                            ),
                            _buildGameGridItem(
                              context: context,
                              title: 'Go Arrows',
                              emoji: '🏹',
                              desc: 'Fly blocks off-screen',
                              tag: 'REFLEX',
                              colors: [
                                const Color(0xFF2D1D00),
                                const Color(0xFF140F2D),
                              ],
                              borderColor: const Color(0xFFFF9900),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ArrowLobbyScreen(),
                                  ),
                                ).then((_) {
                                  context.read<AppBloc>().add(
                                    LoadProfileEvent(),
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Contests Section Header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flash_on,
                          color: AppTheme.accentCyan,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ACTIVE QUIZ CONTESTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Contests List
                if (state.isContestsLoading && activeContests.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  )
                else if (activeContests.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No active contests at this moment.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final contest = activeContests[index];
                      return _buildContestCard(context, contest, user);
                    }, childCount: activeContests.length),
                  ),

                // Bottom padding
                // const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _balanceSubItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGameGridItem({
    required BuildContext context,
    required String title,
    required String emoji,
    required String desc,
    required String tag,
    required List<Color> colors,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withOpacity(0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 7.5,
                          color: borderColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedGameCard({
    required BuildContext context,
    required String title,
    required String emoji,
    required String desc,
    required String badge,
    required List<Color> colors,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor.withOpacity(0.5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 8,
                            color: borderColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: borderColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContestCard(
    BuildContext context,
    ContestModel contest,
    UserModel? user,
  ) {
    // Check if the current user has joined this contest.
    // In our simplified setup, we can fetch participation records if needed,
    // or simulate this based on a state variable.
    // In our backend, the participant count is updated.
    // Let's check if user joined. We will manage joining state cleanly.
    // Let's implement a checking mechanism or track joined contests in user session.
    // Since AppBloc updates state with contest list, we can join a contest, and the backend increments `joined_slots`.
    // Let's mock the "Joined" indicator for local testing based on whether they clicked join.
    // We can also query active participations. Since we want simple UI, we can check if they joined.
    // Wait, let's keep track of joined contests dynamically or simulate.
    // To do it properly, we can add a list of joined contest IDs in the AppState!
    // But since we want to keep it simple, we can check if they already joined by making sure we show playing state.
    // Let's check if the contest slots has incremented or store joined IDs.
    // Wait! Let's edit AppState in app_bloc.dart or just check in HomeScreen? Let's check.
    // Actually, in the backend, the `joined_slots` is updated, and when we submit score, it fails if not joined.
    // Let's check if we joined a contest. We can store joined contest IDs inside a local list in state or in a preference.
    // Let's edit `app_bloc.dart` to hold `joinedContestIds`!
    // Wait! Yes! We can store `joinedContestIds` inside `AppState`. E.g., when joining succeeds, add that contestId to the list!
    // Wait, let's look at `app_bloc.dart` to see if we can edit it or if we can do it inside HomeScreen state.
    // It's very easy to store `joinedContestIds` in a simple static list or local state since it is a single-session demo.
    // Let's just track it in the AppState! Let's modify `app_bloc.dart` shortly if needed, or simply maintain a static list in main.dart or a global variable.
    // Let's check: actually, in a production app, the API `GET /contests` could return whether the user joined, or we can fetch joined contests.
    // Since we don't have a specific `GET /joined-contests`, let's just add `Set<int> joinedContests` to our AppState. It is super clean!
    // Let's do that by updating `AppState` and `AppBloc`.

    // Wait! How does the card render right now?
    // Let's see: we can track which contests are joined by adding a local `joinedContests` Set inside HomeScreen, or keep track globally.
    // Let's keep a global static `Set<int> joinedContestIds = {};` inside a helper class, or inside HomeScreen!
    // Let's define a global class `UserSession` in `mobile` that keeps track of joined contest IDs. It is extremely simple and avoids rewriting too much code.
    // Let's define it inside `lib/features/home/home_screen.dart` as a static Set for simplicity and 100% reliability.

    final isJoined = user?.joinedContestIds.contains(contest.id) ?? false;
    final isCompleted = user?.completedContestIds.contains(contest.id) ?? false;
    final fillPercentage = contest.joinedSlots / contest.totalSlots;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      contest.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Entry: ₹${contest.entryFee.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Prize pool display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRIZE POOL',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${contest.prizePool.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        (contest.status == 'ACTIVE' &&
                                isJoined &&
                                contest.endTime != null)
                            ? 'ENDS IN'
                            : 'START TIME',
                        style: const TextStyle(
                          fontSize: 8,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      (contest.status == 'ACTIVE' &&
                              isJoined &&
                              contest.endTime != null)
                          ? ContestCountdown(endTime: contest.endTime!)
                          : Text(
                              (contest.status == 'COMPLETED' ||
                                      (contest.status == 'ACTIVE' && !isJoined))
                                  ? formatContestDateTime(contest.startTime)
                                  : '${contest.startTime.hour}:${contest.startTime.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize:
                                    (contest.status == 'COMPLETED' ||
                                        (contest.status == 'ACTIVE' &&
                                            !isJoined))
                                    ? 10
                                    : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar slots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${contest.joinedSlots} / ${contest.totalSlots} slots filled',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  if (isJoined)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'REGISTERED',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppTheme.accentPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: fillPercentage,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentCyan,
                ),
                borderRadius: BorderRadius.circular(2),
                minHeight: 4,
              ),
              const SizedBox(height: 16),

              // CTA Buttons
              Row(
                children: [
                  Expanded(
                    child: () {
                      if (contest.status == 'COMPLETED') {
                        if (isCompleted) {
                          return CustomButton(
                            text: 'QUIZ COMPLETED',
                            onPressed: null,
                            height: 44,
                            borderRadius: 10,
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CustomButton(
                                text: 'CONTEST CLOSED',
                                onPressed: null,
                                height: 44,
                                borderRadius: 10,
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Started at: ${formatContestDateTime(contest.startTime)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      } else if (contest.status == 'ACTIVE') {
                        if (isCompleted) {
                          return CustomButton(
                            text: 'QUIZ COMPLETED',
                            onPressed: null,
                            height: 44,
                            borderRadius: 10,
                          );
                        } else if (isJoined) {
                          return CustomButton(
                            text: 'PLAY QUIZ NOW',
                            onPressed: () {
                              _showLanguageSelectionSheet(context, contest);
                            },
                            backgroundColor: AppTheme.accentPurple,
                            foregroundColor: Colors.white,
                            height: 44,
                            borderRadius: 10,
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CustomButton(
                                text: 'REGISTRATION CLOSED',
                                onPressed: null,
                                height: 44,
                                borderRadius: 10,
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Started at: ${formatContestDateTime(contest.startTime)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      } else {
                        // UPCOMING
                        if (isJoined) {
                          return CustomButton(
                            text: 'REGISTERED',
                            onPressed: null,
                            height: 44,
                            borderRadius: 10,
                          );
                        } else {
                          return CustomButton(
                            text: contest.isFull
                                ? 'SLOTS FULL'
                                : 'JOIN CONTEST',
                            onPressed: contest.isFull
                                ? null
                                : () {
                                    _showJoinConfirmation(context, contest);
                                  },
                            type: CustomButtonType.primary,
                            height: 44,
                            borderRadius: 10,
                          );
                        }
                      }
                    }(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectionSheet(BuildContext context, ContestModel contest) {
    String selectedLanguage = 'en';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Quiz Language',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose the language you prefer to play this contest in.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildLanguageOptionCard(
                        label: 'English',
                        subLabel: 'Standard English',
                        code: 'en',
                        isSelected: selectedLanguage == 'en',
                        onTap: () {
                          setModalState(() {
                            selectedLanguage = 'en';
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildLanguageOptionCard(
                        label: 'हिंदी',
                        subLabel: 'Hindi language',
                        code: 'hi',
                        isSelected: selectedLanguage == 'hi',
                        onTap: () {
                          setModalState(() {
                            selectedLanguage = 'hi';
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildLanguageOptionCard(
                        label: 'मराठी',
                        subLabel: 'Marathi language',
                        code: 'mr',
                        isSelected: selectedLanguage == 'mr',
                        onTap: () {
                          setModalState(() {
                            selectedLanguage = 'mr';
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildLanguageOptionCard(
                        label: 'ગુજરાતી',
                        subLabel: 'Gujarati language',
                        code: 'gu',
                        isSelected: selectedLanguage == 'gu',
                        onTap: () {
                          setModalState(() {
                            selectedLanguage = 'gu';
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      CustomButton(
                        text: 'START QUIZ NOW',
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                contest: contest,
                                language: selectedLanguage,
                              ),
                            ),
                          ).then((_) {
                            if (context.mounted) {
                              context.read<AppBloc>().add(FetchContestsEvent());
                              context.read<AppBloc>().add(LoadProfileEvent());
                            }
                          });
                        },
                        backgroundColor: AppTheme.accentPurple,
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOptionCard({
    required String label,
    required String subLabel,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentCyan.withOpacity(0.08)
              : Colors.white.withOpacity(0.02),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : AppTheme.borderCol,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                  width: 2,
                ),
                color: isSelected ? AppTheme.accentCyan : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinConfirmation(BuildContext context, ContestModel contest) {
    final user = context.read<AppBloc>().state.currentUser;
    if (user == null) return;

    final double maxBonusToUse = contest.entryFee * 0.10;
    final double actualBonusToUse = user.bonusBalance < maxBonusToUse
        ? user.bonusBalance
        : maxBonusToUse;
    final double requiredFromOthers = contest.entryFee - actualBonusToUse;
    final double totalOthers = user.depositBalance + user.winningBalance;
    final bool hasSufficientBalance = totalOthers >= requiredFromOthers;
    final double shortfall = requiredFromOthers - totalOthers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Confirm Registration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Joining: ${contest.title}',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Entry Fee', style: TextStyle(fontSize: 14)),
                      Text(
                        '₹${contest.entryFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fee will be deducted from your Wallet balances.\nBonus Wallet can pay up to 10% of the fee.',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  if (contest.prizeRules != null &&
                      contest.prizeRules!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.borderCol, height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'PRIZE BREAKDOWN',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: SingleChildScrollView(
                        child: Column(
                          children: contest.prizeRules!.map((rule) {
                            final rankText = rule.minRank == rule.maxRank
                                ? 'Rank ${rule.minRank}'
                                : 'Ranks ${rule.minRank}-${rule.maxRank}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rankText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  Text(
                                    '₹${rule.prize.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentEmerald,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!hasSufficientBalance) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accentRed.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.accentRed,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Insufficient Wallet Balance',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentRed,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Shortfall: ₹${shortfall.toStringAsFixed(2)}\nYour Usable Balance: ₹${(totalOthers + actualBonusToUse).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'ADD ₹${shortfall.ceil()} VIA UPI / BANK',
                      onPressed: () {
                        Navigator.pop(ctx);
                        DepositBottomSheet.show(
                          context,
                          defaultAmount: shortfall,
                        );
                      },
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'CONFIRM & REGISTER',
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<AppBloc>().add(
                          JoinContestEvent(contest.id),
                        );
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('Registered for ${contest.title}!'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                      },
                      type: CustomButtonType.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ContestCountdown extends StatefulWidget {
  final DateTime endTime;
  const ContestCountdown({super.key, required this.endTime});

  @override
  State<ContestCountdown> createState() => _ContestCountdownState();
}

class _ContestCountdownState extends State<ContestCountdown> {
  late Timer _timer;
  late Duration _difference;

  @override
  void initState() {
    super.initState();
    _calculateDifference();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateDifference();
        });
      }
    });
  }

  void _calculateDifference() {
    _difference = widget.endTime.difference(DateTime.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_difference.isNegative) {
      return const Text(
        'ENDED',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.accentRed,
        ),
      );
    }

    final hours = _difference.inHours.toString().padLeft(2, '0');
    final minutes = (_difference.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_difference.inSeconds % 60).toString().padLeft(2, '0');

    final displayStr = _difference.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';

    return Text(
      displayStr,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.accentCyan,
      ),
    );
  }
}
