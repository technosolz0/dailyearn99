import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/models/blackjack_model.dart';
import 'package:dailyearn99/features/app_bloc.dart';

class BlackjackGameScreen extends StatefulWidget {
  const BlackjackGameScreen({super.key});

  @override
  State<BlackjackGameScreen> createState() => _BlackjackGameScreenState();
}

class _BlackjackGameScreenState extends State<BlackjackGameScreen> {
  final TextEditingController _betController = TextEditingController(
    text: '10.0',
  );

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
      _betController.text = newVal.toStringAsFixed(1);
    });
  }

  void _setMaxBet(double minBet, double maxBet) {
    final profile = context.read<AppBloc>().state.currentUser;
    final balance =
        (profile?.depositBalance ?? 0.0) + (profile?.winningBalance ?? 0.0);
    final maxBetAllowed = balance.clamp(minBet, maxBet);
    setState(() {
      _betController.text = maxBetAllowed.toStringAsFixed(1);
    });
  }

  void _startGame(AppState state) {
    final bet = double.tryParse(_betController.text) ?? 10.0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        title: const Text(
          'BLACKJACK ORIGINALS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.accentCyan),
            onPressed: () => _showRulesDialog(),
          ),
        ],
      ),
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final feltWidget = _buildFeltTable(game);
              final controlWidget = _buildControlPanel(state, game, balance);

              if (isNarrow) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildBalanceHeader(balance),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: feltWidget,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: controlWidget,
                      ),
                      _buildHistoryList(state.blackjackHistory),
                    ],
                  ),
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildBalanceHeader(balance),
                            const SizedBox(height: 24),
                            feltWidget,
                            const SizedBox(height: 24),
                            _buildHistoryList(state.blackjackHistory),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 320,
                      color: AppTheme.cardBg,
                      padding: const EdgeInsets.all(20.0),
                      child: controlWidget,
                    ),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBalanceHeader(double balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderCol, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.accentCyan,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'YOUR BALANCE',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeltTable(BlackjackGameModel? game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1921), // Felt style deep dark teal-blue
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3545), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dealer Hand Section
          _buildDealerHandSection(game),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E3545), thickness: 1),
          // Casino Table felt decoration text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              children: [
                Text(
                  'BLACKJACK PAYS 3 TO 2',
                  style: TextStyle(
                    color: AppTheme.accentAmber.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dealer must stand on 17 and draw to 16',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E3545), thickness: 1),
          const SizedBox(height: 12),
          // Player Hand(s) Section
          _buildPlayerHandSection(game),
        ],
      ),
    );
  }

  Widget _buildDealerHandSection(BlackjackGameModel? game) {
    if (game == null) {
      return Column(
        children: [
          const Text(
            'DEALER HAND',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCardPlaceholder(),
              const SizedBox(width: 8),
              _buildCardPlaceholder(),
            ],
          ),
        ],
      );
    }

    final dVal = calculateHandValue(game.dealerHand);
    final dealerValStr = game.isInProgress ? '$dVal + ?' : '$dVal';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'DEALER HAND',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3545),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dealerValStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...game.dealerHand.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildCard(c),
              ),
            ),
            if (game.isInProgress)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildCardBack(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerHandSection(BlackjackGameModel? game) {
    if (game == null) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCardPlaceholder(),
              const SizedBox(width: 8),
              _buildCardPlaceholder(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'PLAYER HAND',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (!game.isSplit) {
      final pVal = calculateHandValue(game.playerHand1);
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: game.playerHand1
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildCard(c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'PLAYER HAND',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.accentCyan.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$pVal',
                  style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Split Hands rendering
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
                  ? AppTheme.accentCyan.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHand1Active
                    ? AppTheme.accentCyan.withOpacity(0.3)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: game.playerHand1
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _buildCard(c, sizeScale: 0.8),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'HAND 1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isHand1Active
                            ? AppTheme.accentCyan.withOpacity(0.2)
                            : Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$p1Val',
                        style: TextStyle(
                          color: isHand1Active
                              ? AppTheme.accentCyan
                              : AppTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isHand1Active)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'ACTIVE HAND',
                      style: TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                  ? AppTheme.accentEmerald.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHand2Active
                    ? AppTheme.accentEmerald.withOpacity(0.3)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: game.playerHand2
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _buildCard(c, sizeScale: 0.8),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'HAND 2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isHand2Active
                            ? AppTheme.accentEmerald.withOpacity(0.2)
                            : Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$p2Val',
                        style: TextStyle(
                          color: isHand2Active
                              ? AppTheme.accentEmerald
                              : AppTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isHand2Active)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'ACTIVE HAND',
                      style: TextStyle(
                        color: AppTheme.accentEmerald,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BlackjackCardModel card, {double sizeScale = 1.0}) {
    final width = 56.0 * sizeScale;
    final height = 84.0 * sizeScale;
    final isRed = card.suit == '♥' || card.suit == '♦';
    final cardColor = isRed ? AppTheme.accentRed : const Color(0xFF1F2937);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6 * sizeScale),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Suit in center
          Align(
            alignment: Alignment.center,
            child: Text(
              card.suit,
              style: TextStyle(
                color: cardColor,
                fontSize: 24 * sizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Rank at top-left
          Positioned(
            top: 4 * sizeScale,
            left: 4 * sizeScale,
            child: Text(
              card.rank,
              style: TextStyle(
                color: cardColor,
                fontSize: 13 * sizeScale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Rank at bottom-right
          Positioned(
            bottom: 4 * sizeScale,
            right: 4 * sizeScale,
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(
                card.rank,
                style: TextStyle(
                  color: cardColor,
                  fontSize: 13 * sizeScale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack({double sizeScale = 1.0}) {
    final width = 56.0 * sizeScale;
    final height = 84.0 * sizeScale;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6 * sizeScale),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: width - 12 * sizeScale,
          height: height - 12 * sizeScale,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(4 * sizeScale),
          ),
          child: const Center(
            child: Icon(Icons.casino_outlined, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPlaceholder() {
    return Container(
      width: 56,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: const Center(
        child: Icon(Icons.add_card_outlined, color: Colors.white24, size: 20),
      ),
    );
  }

  Widget _buildControlPanel(
    AppState state,
    BlackjackGameModel? game,
    double balance,
  ) {
    final isGameActive = game != null && game.isInProgress;
    final minBet = state.blackjackSettings?.minBet ?? 10.0;
    final maxBet = state.blackjackSettings?.maxBet ?? 50000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isGameActive && game == null) ...[
          const Text(
            'Bet Amount (INR)',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _betController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    fillColor: AppTheme.cardBg,
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildQuickBetButton(
                '1/2',
                () => _adjustBet(0.5, minBet, maxBet),
              ),
              const SizedBox(width: 4),
              _buildQuickBetButton('2x', () => _adjustBet(2.0, minBet, maxBet)),
              const SizedBox(width: 4),
              _buildQuickBetButton('Max', () => _setMaxBet(minBet, maxBet)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: state.isBlackjackLoading
                ? null
                : () => _startGame(state),
            child: state.isBlackjackLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.black),
                    ),
                  )
                : const Text(
                    'START CASINO BET',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
          ),
        ] else if (isGameActive) ...[
          // Active Round Controls (Hit, Stand, Double, Split)
          _buildActionButtons(game, balance),
        ] else if (game != null && !game.isInProgress) ...[
          // Completed Game State Banner
          _buildCompletedBanner(game),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.borderCol),
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
    // Check if player can split
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

    // Check if player can double down
    bool canDouble = activeHand.length == 2 && balance >= game.betAmount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _hit(game),
                child: const Text(
                  'HIT',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _stand(game),
                child: const Text(
                  'STAND',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        if (canDouble || canSplit) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (canDouble)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _doubleDown(game, balance),
                    child: const Text(
                      'DOUBLE DOWN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (canDouble && canSplit) const SizedBox(width: 10),
              if (canSplit)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _split(game, balance),
                    child: const Text(
                      'SPLIT HAND',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
      // Split hand where user won one and lost one, resulting in partial loss/return
      bannerBg = AppTheme.accentCyan.withOpacity(0.15);
      textCol = AppTheme.accentCyan;
      textMsg = 'PARTIAL WIN! Payout: ₹${winAmt.toStringAsFixed(2)}';
    } else {
      textMsg = game.hand1Status == 'BUST'
          ? '💥 PLAYER BUSTED! Lost ₹${totalBet.toStringAsFixed(2)}'
          : 'DEALER WINS! Lost ₹${totalBet.toStringAsFixed(2)}';
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textCol.withOpacity(0.3)),
          ),
          child: Text(
            textMsg,
            style: TextStyle(
              color: textCol,
              fontWeight: FontWeight.w900,
              fontSize: 13,
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
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderCol),
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

  Widget _buildHistoryList(List<BlackjackGameModel> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Blackjack Turn-over History',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final record = history[index];
              final totalBet = record.betAmount + record.splitBetAmount;
              final isWin = record.winAmount > totalBet;
              final isPush =
                  record.winAmount == totalBet && record.winAmount > 0;
              final isPartial =
                  record.isSplit &&
                  record.winAmount > 0 &&
                  record.winAmount < totalBet;

              Color statusCol = AppTheme.accentRed;
              String titleText = 'Lost Bet';
              if (isWin) {
                statusCol = AppTheme.accentEmerald;
                titleText = 'Won ₹${record.winAmount.toStringAsFixed(1)}';
              } else if (isPush) {
                statusCol = AppTheme.accentAmber;
                titleText = 'Push (Tie)';
              } else if (isPartial) {
                statusCol = AppTheme.accentCyan;
                titleText = 'Returned ₹${record.winAmount.toStringAsFixed(1)}';
              }

              final timeStr =
                  '${record.createdAt.day}/${record.createdAt.month} ${record.createdAt.hour}:${record.createdAt.minute.toString().padLeft(2, '0')}';

              return Card(
                color: AppTheme.cardBg,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusCol.withOpacity(0.1),
                    child: Icon(
                      isWin
                          ? Icons.trending_up
                          : (isPush || isPartial
                                ? Icons.trending_flat
                                : Icons.trending_down),
                      color: statusCol,
                    ),
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
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blackjack (21) Rules'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Objective:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
              Text(
                'Get a hand value closer to 21 than the dealer without exceeding 21. If you exceed 21, you bust and lose.',
              ),
              SizedBox(height: 12),
              Text(
                'Card Values:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
              Text(
                '• 2–10: Face value.\n• Jack, Queen, King: 10 points.\n• Ace: 1 or 11 points (whichever benefits you most).',
              ),
              SizedBox(height: 12),
              Text(
                'Actions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
              Text(
                '• Hit: Request another card.\n'
                '• Stand: Keep your current cards and end turn.\n'
                '• Double Down: Double your bet and receive exactly 1 more card.\n'
                '• Split Hand: Split your identical value cards into two independent hands (requires matching second bet).',
              ),
              SizedBox(height: 12),
              Text(
                'Payouts:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
              Text(
                '• Regular Win: 1:1 payout.\n• Natural Blackjack: 3:2 payout.\n• Push: Bet returned.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}
