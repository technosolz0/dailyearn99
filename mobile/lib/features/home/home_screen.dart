import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:target99/core/theme/app_theme.dart';
import 'package:target99/core/models/contest_model.dart';
import 'package:target99/features/app_bloc.dart';
import 'package:target99/features/contest/quiz_screen.dart';
import 'package:target99/core/utils/razorpay_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch contests when home opens
    context.read<AppBloc>().add(FetchContestsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final user = state.currentUser;

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
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'target99 Lobbies',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Welcome back, ${user?.phone ?? ""}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        if (user?.kycStatus == "VERIFIED")
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.accentEmerald.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'KYC OK',
                              style: TextStyle(
                                fontSize: 8,
                                color: AppTheme.accentEmerald,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                          'ACTIVE CONTESTS',
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
                if (state.isContestsLoading && state.contests.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  )
                else if (state.contests.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No active contests at this moment.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final contest = state.contests[index];
                      return _buildContestCard(context, contest, user);
                    }, childCount: state.contests.length),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
                      const Text(
                        'START TIME',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${contest.startTime.hour}:${contest.startTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 14,
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
                    child: isJoined
                        ? ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QuizScreen(contest: contest),
                                ),
                              ).then((_) {
                                // Refresh when returning
                                context.read<AppBloc>().add(
                                  FetchContestsEvent(),
                                );
                                context.read<AppBloc>().add(LoadProfileEvent());
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentPurple,
                            ),
                            child: const Text(
                              'PLAY QUIZ NOW',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: contest.isFull
                                ? null
                                : () {
                                    _showJoinConfirmation(context, contest);
                                  },
                            child: Text(
                              contest.isFull ? 'SLOTS FULL' : 'JOIN CONTEST',
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinConfirmation(BuildContext context, ContestModel contest) {
    final user = context.read<AppBloc>().state.currentUser;
    if (user == null) return;

    final double maxBonusToUse = contest.entryFee * 0.10;
    final double actualBonusToUse = user.bonusBalance < maxBonusToUse ? user.bonusBalance : maxBonusToUse;
    final double requiredFromOthers = contest.entryFee - actualBonusToUse;
    final double totalOthers = user.depositBalance + user.winningBalance;
    final bool hasSufficientBalance = totalOthers >= requiredFromOthers;
    final double shortfall = requiredFromOthers - totalOthers;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                if (contest.prizeRules != null && contest.prizeRules!.isNotEmpty) ...[
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
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(rankText, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Text('₹${rule.prize.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentEmerald)),
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
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Insufficient Wallet Balance',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentRed, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Shortfall: ₹${shortfall.toStringAsFixed(2)}\nYour Usable Balance: ₹${(totalOthers + actualBonusToUse).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      
                      final depositAmount = shortfall.ceilToDouble();
                      
                      RazorpayService.openRazorpayPaymentSheet(
                        context: context,
                        amount: depositAmount,
                        onSuccess: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deposited ₹${depositAmount.toInt()} successfully! Re-opening registration...'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                          
                          Future.delayed(const Duration(milliseconds: 600), () {
                            if (context.mounted) {
                              _showJoinConfirmation(context, contest);
                            }
                          });
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                    ),
                    child: Text('ADD ₹${shortfall.ceil()} VIA RAZORPAY'),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<AppBloc>().add(JoinContestEvent(contest.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Registered for ${contest.title}!'),
                          backgroundColor: AppTheme.accentEmerald,
                        ),
                      );
                    },
                    child: const Text('CONFIRM & REGISTER'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


