import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/models/blackjack_model.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/widgets/deposit_bottom_sheet.dart';
import 'package:dailyearn99/features/blackjack/widgets/table_painter.dart';
import 'package:dailyearn99/features/blackjack/widgets/shoe_and_tray.dart';
import 'package:dailyearn99/features/blackjack/widgets/playing_card.dart';
import 'package:dailyearn99/features/blackjack/widgets/poker_chip.dart';
import 'package:dailyearn99/features/blackjack/widgets/chips_selector_row.dart';
import 'package:dailyearn99/features/blackjack/widgets/action_button.dart';

class BlackjackGameScreen extends StatefulWidget {
  const BlackjackGameScreen({super.key});

  @override
  State<BlackjackGameScreen> createState() => _BlackjackGameScreenState();
}

class _BlackjackGameScreenState extends State<BlackjackGameScreen> {
  final TextEditingController _betController = TextEditingController(
    text: '100.0',
  );
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch initial data on startup
    context.read<AppBloc>().add(FetchActiveBlackjackEvent());
    context.read<AppBloc>().add(FetchBlackjackHistoryEvent());
    context.read<AppBloc>().add(FetchBlackjackSettingsEvent());
  }

  @override
  void dispose() {
    _betController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int calculateHandValue(List<BlackjackCardModel> hand) {
    int val = hand.fold(0, (sum, card) => sum + card.value);
    int aces = hand.where((card) => card.rank == 'A').length;
    while (val > 21 && aces > 0) {
      val -= 10;
      aces -= 1;
    }
    return val;
  }

  void _adjustBet(double factor, double minBet, double maxBet) {
    final currentVal = double.tryParse(_betController.text) ?? minBet;
    final newVal = (currentVal * factor).clamp(minBet, maxBet);
    setState(() {
      _betController.text = newVal.toStringAsFixed(0);
    });
  }

  void _setMaxBet(double minBet, double maxBet) {
    final profile = context.read<AppBloc>().state.currentUser;
    final balance =
        (profile?.depositBalance ?? 0.0) + (profile?.winningBalance ?? 0.0);
    final maxBetAllowed = balance.clamp(minBet, maxBet);
    setState(() {
      _betController.text = maxBetAllowed.toStringAsFixed(0);
    });
  }

  void _startGame(AppState state) {
    final bet = double.tryParse(_betController.text) ?? 100.0;
    final totalUsable =
        (state.currentUser?.depositBalance ?? 0.0) +
        (state.currentUser?.winningBalance ?? 0.0) +
        (state.currentUser?.bonusBalance ?? 0.0);

    if (totalUsable < bet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance. Please deposit funds first.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    context.read<AppBloc>().add(StartBlackjackEvent(bet));
    HapticFeedback.mediumImpact();
  }

  void _hit(BlackjackGameModel game) {
    context.read<AppBloc>().add(HitBlackjackEvent(game.id));
    HapticFeedback.lightImpact();
  }

  void _stand(BlackjackGameModel game) {
    context.read<AppBloc>().add(StandBlackjackEvent(game.id));
    HapticFeedback.mediumImpact();
  }

  void _doubleDown(BlackjackGameModel game, double totalUsable) {
    final neededBet = game.betAmount;
    if (totalUsable < neededBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance to double down.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    context.read<AppBloc>().add(DoubleBlackjackEvent(game.id));
    HapticFeedback.vibrate();
  }

  void _split(BlackjackGameModel game, double totalUsable) {
    final neededBet = game.betAmount;
    if (totalUsable < neededBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance to split hand.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    context.read<AppBloc>().add(SplitBlackjackEvent(game.id));
    HapticFeedback.vibrate();
  }

  void _resetGame() {
    context.read<AppBloc>().add(ResetBlackjackEvent());
    context.read<AppBloc>().add(FetchBlackjackHistoryEvent());
    HapticFeedback.selectionClick();
  }

  void _scrollToHistory() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B13), // Deep Navy background
      body: BlocConsumer<AppBloc, AppState>(
        listener: (context, state) {
          if (state.blackjackError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.blackjackError!),
                backgroundColor: AppTheme.accentRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.blackjackSettings?.maintenanceMode == true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.construction,
                      size: 80,
                      color: AppTheme.accentAmber,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Under Maintenance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Blackjack is currently down for maintenance. Please check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          final game = state.activeBlackjackGame;
          final balance = state.currentUser != null
              ? (state.currentUser!.depositBalance +
                    state.currentUser!.winningBalance +
                    state.currentUser!.bonusBalance)
              : 0.0;

          final minBet = state.blackjackSettings?.minBet ?? 100.0;
          final maxBet = state.blackjackSettings?.maxBet ?? 10000.0;

          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0F172A), // Slate 900
                        Color(0xFF020617), // Slate 950
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Top Bar Header
                          _buildTopHeader(balance, context),
                          const SizedBox(height: 16),

                          // 2. Stats Boxes (Left: Min/Max Bet, Right: Session stats)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildMinMaxPanel(minBet, maxBet),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSessionPanel(
                                  state.blackjackHistory,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3. Radial Gradient Felt Table
                          _buildFeltTable(game),
                          const SizedBox(height: 20),

                          // 4. Game Control / Active Game Action Panel
                          _buildControlOrActionPanel(
                            state,
                            game,
                            balance,
                            minBet,
                            maxBet,
                          ),
                          const SizedBox(height: 24),

                          // 5. History List
                          _buildHistoryList(state.blackjackHistory),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildTopHeader(double balance, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // _buildHeaderIconButton(
        //   icon: Icons.menu,
        //   onTap: () {
        //     // Fallback back navigation
        //     Navigator.pop(context);
        //   },
        // ),
        GestureDetector(
          onTap: () => DepositBottomSheet.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '₹ ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald green plus
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 12),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stack(
            //   clipBehavior: Clip.none,
            //   children: [
            //     _buildHeaderIconButton(
            //       icon: Icons.card_giftcard,
            //       onTap: () {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           const SnackBar(content: Text('Rewards coming soon!')),
            //         );
            //       },
            //     ),
            //     Positioned(
            //       right: -2,
            //       top: -2,
            //       child: Container(
            //         padding: const EdgeInsets.all(4),
            //         decoration: const BoxDecoration(
            //           color: Color(0xFFEF4444),
            //           shape: BoxShape.circle,
            //         ),
            //         child: const Text(
            //           '3',
            //           style: TextStyle(
            //             color: Colors.white,
            //             fontSize: 8,
            //             fontWeight: FontWeight.bold,
            //           ),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(width: 8),
            _buildHeaderIconButton(
              icon: Icons.settings,
              onTap: () {
                _showRulesDialog();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  // --- STATS BOXES ---
  Widget _buildMinMaxPanel(double minBet, double maxBet) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MIN BET',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹ ${minBet.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            'MAX BET',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹ ${maxBet.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPanel(List<BlackjackGameModel> history) {
    int wins = 0;
    int losses = 0;
    int push = 0;

    for (final record in history) {
      final totalBet = record.betAmount + record.splitBetAmount;
      if (record.winAmount > totalBet) {
        wins++;
      } else if (record.winAmount == totalBet && record.winAmount > 0) {
        push++;
      } else {
        losses++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR SESSION',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildSessionStatRow(
            icon: Icons.emoji_events_outlined,
            iconColor: const Color(0xFFEAB308), // gold trophy
            label: 'WINS',
            value: wins,
          ),
          const SizedBox(height: 6),
          _buildSessionStatRow(
            icon: Icons.cancel_outlined,
            iconColor: const Color(0xFFEF4444), // red cancel
            label: 'LOSSES',
            value: losses,
          ),
          const SizedBox(height: 6),
          _buildSessionStatRow(
            icon: Icons.remove_circle_outline,
            iconColor: const Color(0xFF3B82F6), // blue remove
            label: 'PUSH',
            value: push,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // --- FELT TABLE BACKGROUND ---
  Widget _buildFeltTable(BlackjackGameModel? game) {
    final dVal = game != null ? calculateHandValue(game.dealerHand) : 0;
    final dealerValStr = game == null
        ? ""
        : (game.isInProgress ? '$dVal' : '$dVal');

    final pVal = game != null ? calculateHandValue(game.playerHand1) : 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          colors: [
            Color(0xFF074D32), // Deep rich green center
            Color(0xFF032B1B), // Dark felt edges
            Color(0xFF011A0F), // Almost black outer bounds
          ],
          radius: 0.95,
          center: Alignment.center,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 3,
        ), // Dark gunmetal border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Curved table lines and gold markings
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: TableLinesPainter()),
              ),
            ),

            // Left Discard Shoe
            const Positioned(left: -12, top: 24, child: DiscardTrayWidget()),

            // Right Dealer Shoe
            const Positioned(right: -12, top: 24, child: DealerShoeWidget()),

            // Main game layout elements inside felt
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 24.0,
                horizontal: 16.0,
              ),
              child: Column(
                children: [
                  // 1. DEALER HAND SECTION
                  _buildHandHeader(
                    title: 'DEALER',
                    score: game != null ? dealerValStr : null,
                    isActive: game != null && game.isInProgress,
                  ),
                  const SizedBox(height: 10),
                  if (game == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCardPlaceholder(),
                        const SizedBox(width: 8),
                        _buildCardPlaceholder(),
                      ],
                    )
                  else
                    CardStack(
                      cards: game.dealerHand,
                      isDealerHand: true,
                      isGameInProgress: game.isInProgress,
                      cardStartOffset: const Offset(160, -30),
                    ),

                  // Center vertical spacing to preserve curved text visibility
                  const SizedBox(height: 140),

                  // 2. PLAYER HAND SECTION
                  if (game == null)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCardPlaceholder(),
                            const SizedBox(width: 8),
                            _buildCardPlaceholder(),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildHandHeader(
                          title: 'YOU',
                          score: null,
                          isActive: false,
                        ),
                      ],
                    )
                  else if (!game.isSplit) ...[
                    CardStack(
                      cards: game.playerHand1,
                      scoreLabel: '$pVal',
                      cardStartOffset: const Offset(160, -220),
                    ),
                    const SizedBox(height: 12),
                    _buildHandHeader(
                      title: 'YOU',
                      score: '$pVal',
                      isActive: game.isInProgress,
                    ),
                    const SizedBox(height: 10),
                    _buildBetPill(game.betAmount),
                  ] else ...[
                    _buildSplitHands(game),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandHeader({
    required String title,
    String? score,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color(0xFF22D3EE).withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: title.startsWith('HAND') || title == 'YOU'
                  ? const Color(0xFF10B981)
                  : Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (score != null && score.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              height: 10,
              width: 1,
              color: Colors.white24,
            ),
            Text(
              score,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBetPill(double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PokerChipWidget(
            label: '',
            color: Color(0xFF1D4ED8),
            size: 16.0,
          ),
          const SizedBox(width: 8),
          Text(
            '₹ ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitHands(BlackjackGameModel game) {
    final p1Val = calculateHandValue(game.playerHand1);
    final p2Val = calculateHandValue(game.playerHand2);
    final isHand1Active = game.currentHandIndex == 0 && game.isInProgress;
    final isHand2Active = game.currentHandIndex == 1 && game.isInProgress;

    return Row(
      children: [
        // Hand 1 (Left Side)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isHand1Active
                  ? const Color(0xFF083344).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHand1Active
                    ? const Color(0xFF22D3EE).withOpacity(0.4)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                CardStack(
                  cards: game.playerHand1,
                  scoreLabel: '$p1Val',
                  cardWidth: 54.0,
                  cardHeight: 80.0,
                  overlapOffset: 16.0,
                  cardStartOffset: const Offset(200, -220),
                  isSplit: true,
                ),
                const SizedBox(height: 10),
                _buildHandHeader(
                  title: 'HAND 1',
                  score: '$p1Val',
                  isActive: isHand1Active,
                ),
                const SizedBox(height: 6),
                _buildBetPill(game.betAmount),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Hand 2 (Right Side)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isHand2Active
                  ? const Color(0xFF064E3B).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHand2Active
                    ? const Color(0xFF10B981).withOpacity(0.4)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                CardStack(
                  cards: game.playerHand2,
                  scoreLabel: '$p2Val',
                  cardWidth: 54.0,
                  cardHeight: 80.0,
                  overlapOffset: 16.0,
                  cardStartOffset: const Offset(100, -220),
                  isSplit: true,
                ),
                const SizedBox(height: 10),
                _buildHandHeader(
                  title: 'HAND 2',
                  score: '$p2Val',
                  isActive: isHand2Active,
                ),
                const SizedBox(height: 6),
                _buildBetPill(game.splitBetAmount),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardPlaceholder() {
    return Container(
      width: 74,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: const Center(
        child: Icon(Icons.add_card_outlined, color: Colors.white24, size: 24),
      ),
    );
  }

  // --- CONTROL OR ACTION PANEL ---
  Widget _buildControlOrActionPanel(
    AppState state,
    BlackjackGameModel? game,
    double balance,
    double minBet,
    double maxBet,
  ) {
    final isGameActive = game != null && game.isInProgress;

    if (!isGameActive && game == null) {
      return _buildBettingControlSection(state, minBet, maxBet);
    } else if (isGameActive) {
      return _buildActionButtons(game, balance);
    } else {
      return _buildCompletedBanner(game!);
    }
  }

  Widget _buildBettingControlSection(
    AppState state,
    double minBet,
    double maxBet,
  ) {
    final currentBet = double.tryParse(_betController.text) ?? minBet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.casino_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _betController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter bet amount',
                          hintStyle: TextStyle(
                            color: Colors.white30,
                            fontSize: 13,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                    const Text(
                      'INR',
                      style: TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildQuickBetButton('1/2', () => _adjustBet(0.5, minBet, maxBet)),
            const SizedBox(width: 4),
            _buildQuickBetButton('2x', () => _adjustBet(2.0, minBet, maxBet)),
            const SizedBox(width: 4),
            _buildQuickBetButton('Max', () => _setMaxBet(minBet, maxBet)),
          ],
        ),
        const SizedBox(height: 16),
        ChipsSelectorRow(
          selectedBet: currentBet,
          onBetSelected: (val) {
            setState(() {
              _betController.text = val.toStringAsFixed(0);
            });
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981), // Emerald green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            elevation: 4,
            shadowColor: const Color(0xFF10B981).withOpacity(0.3),
          ),
          onPressed: state.isBlackjackLoading ? null : () => _startGame(state),
          child: state.isBlackjackLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text(
                  'START CASINO BET',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQuickBetButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 38,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.06),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BlackjackGameModel game, double balance) {
    bool canSplit = false;
    final activeHand = game.currentHandIndex == 0
        ? game.playerHand1
        : game.playerHand2;
    if (!game.isSplit && activeHand.length == 2) {
      final c1 = activeHand[0];
      final c2 = activeHand[1];
      canSplit =
          (c1.value == c2.value || c1.rank == c2.rank) &&
          balance >= game.betAmount;
    }

    bool canDouble = activeHand.length == 2 && balance >= game.betAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ActionButtonWidget(
              label: 'HIT',
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 28,
              ),
              gradientColors: const [
                Color(0xFF065F46),
                Color(0xFF10B981),
              ], // Green
              isEnabled: true,
              onTap: () => _hit(game),
            ),
            const SizedBox(width: 8),
            ActionButtonWidget(
              label: 'STAND',
              icon: const Icon(
                Icons.front_hand_outlined,
                color: Colors.white,
                size: 28,
              ),
              gradientColors: const [
                Color(0xFF1E3A8A),
                Color(0xFF3B82F6),
              ], // Blue
              isEnabled: true,
              onTap: () => _stand(game),
            ),
            const SizedBox(width: 8),
            ActionButtonWidget(
              label: 'DOUBLE',
              icon: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '2x',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              gradientColors: const [
                Color(0xFF5B21B6),
                Color(0xFF8B5CF6),
              ], // Purple
              isEnabled: canDouble,
              onTap: () => _doubleDown(game, balance),
            ),
            const SizedBox(width: 8),
            ActionButtonWidget(
              label: 'SPLIT',
              icon: Transform.rotate(
                angle: 0.15,
                child: const Icon(
                  Icons.style_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              gradientColors: const [
                Color(0xFF9D174D),
                Color(0xFFEC4899),
              ], // Pink/Red
              isEnabled: canSplit,
              onTap: () => _split(game, balance),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Draw the chip betting selector under active actions but dimmed/disabled
        Opacity(
          opacity: 0.4,
          child: ChipsSelectorRow(
            selectedBet: game.betAmount,
            onBetSelected: (_) {},
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedBanner(BlackjackGameModel game) {
    Color bannerBg = AppTheme.accentRed.withOpacity(0.15);
    Color textCol = AppTheme.accentRed;
    String textMsg = 'LOST ROUND';

    final winAmt = game.winAmount;
    final totalBet = game.betAmount + game.splitBetAmount;

    if (winAmt > totalBet) {
      bannerBg = AppTheme.accentEmerald.withOpacity(0.15);
      textCol = AppTheme.accentEmerald;
      textMsg = game.isSplit
          ? '🎉 SPLIT WIN! Payout: ₹${winAmt.toStringAsFixed(2)}'
          : '🎉 PLAYER WINS! Payout: ₹${winAmt.toStringAsFixed(2)}';
      if (game.hand1Status == 'BLACKJACK' && !game.isSplit) {
        textMsg = '🃏 NATURAL BLACKJACK! Payout: ₹${winAmt.toStringAsFixed(2)}';
      }
    } else if (winAmt == totalBet && winAmt > 0) {
      bannerBg = AppTheme.accentAmber.withOpacity(0.15);
      textCol = AppTheme.accentAmber;
      textMsg = 'PUSH (TIE) - Bet Returned';
    } else if (game.isSplit && winAmt > 0) {
      bannerBg = AppTheme.accentCyan.withOpacity(0.15);
      textCol = AppTheme.accentCyan;
      textMsg = 'PARTIAL WIN! Payout: ₹${winAmt.toStringAsFixed(2)}';
    } else {
      textMsg = game.hand1Status == 'BUST'
          ? '💥 PLAYER BUSTED! Lost ₹${totalBet.toStringAsFixed(2)}'
          : 'DEALER WINS! Lost ₹${totalBet.toStringAsFixed(2)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: textCol.withOpacity(0.3)),
          ),
          child: Text(
            textMsg,
            style: TextStyle(
              color: textCol,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.06),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          onPressed: _resetGame,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_outlined, size: 18),
              SizedBox(width: 8),
              Text(
                'PLAY AGAIN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- HISTORY LIST ---
  Widget _buildHistoryList(List<BlackjackGameModel> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Blackjack Turnover History',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            GestureDetector(
              onTap: _scrollToHistory,
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF22D3EE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length > 5
              ? 5
              : history.length, // show last 5 in dashboard view
          itemBuilder: (context, index) {
            final record = history[index];
            final totalBet = record.betAmount + record.splitBetAmount;
            final isWin = record.winAmount > totalBet;
            final isPush = record.winAmount == totalBet && record.winAmount > 0;
            final isPartial =
                record.isSplit &&
                record.winAmount > 0 &&
                record.winAmount < totalBet;

            Color statusCol = const Color(0xFFEF4444);
            String titleText = 'Lost Bet';
            IconData icon = Icons.trending_down;
            if (isWin) {
              statusCol = const Color(0xFF10B981);
              titleText = 'Won ₹${record.winAmount.toStringAsFixed(1)}';
              icon = Icons.trending_up;
            } else if (isPush) {
              statusCol = const Color(0xFFFBBF24);
              titleText = 'Push (Tie)';
              icon = Icons.trending_flat;
            } else if (isPartial) {
              statusCol = const Color(0xFF22D3EE);
              titleText = 'Returned ₹${record.winAmount.toStringAsFixed(1)}';
              icon = Icons.trending_flat;
            }

            final timeStr =
                '${record.createdAt.day}/${record.createdAt.month} ${record.createdAt.hour}:${record.createdAt.minute.toString().padLeft(2, '0')}';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusCol.withOpacity(0.12),
                  child: Icon(icon, color: statusCol, size: 20),
                ),
                title: Text(
                  titleText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Bet: ₹${totalBet.toStringAsFixed(1)}${record.isSplit ? " (Split)" : ""} | $timeStr',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text(
          'Blackjack (21) Rules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Objective:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22D3EE),
                ),
              ),
              Text(
                'Get a hand value closer to 21 than the dealer without exceeding 21. If you exceed 21, you bust and lose.',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Card Values:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22D3EE),
                ),
              ),
              Text(
                '• 2–10: Face value.\n• Jack, Queen, King: 10 points.\n• Ace: 1 or 11 points (whichever benefits you most).',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Actions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22D3EE),
                ),
              ),
              Text(
                '• Hit: Request another card.\n'
                '• Stand: Keep your current cards and end turn.\n'
                '• Double Down: Double your bet and receive exactly 1 more card.\n'
                '• Split Hand: Split your identical value cards into two independent hands (requires matching second bet).',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Payouts:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22D3EE),
                ),
              ),
              Text(
                '• Regular Win: 1:1 payout.\n• Natural Blackjack: 3:2 payout.\n• Push: Bet returned.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'GOT IT',
              style: TextStyle(
                color: Color(0xFF22D3EE),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
