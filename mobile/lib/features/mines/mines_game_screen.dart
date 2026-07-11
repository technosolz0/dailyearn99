import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/models/mines_model.dart';
import 'package:dailyearn99/features/app_bloc.dart';

class MinesGameScreen extends StatefulWidget {
  const MinesGameScreen({super.key});

  @override
  State<MinesGameScreen> createState() => _MinesGameScreenState();
}

class _MinesGameScreenState extends State<MinesGameScreen> {
  final TextEditingController _betController = TextEditingController(
    text: '10.0',
  );
  int _selectedMinesCount = 3;
  List<int> _flipQueue =
      []; // track indices that need flip animations triggered

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    // Check if there is an active game session already on start
    context.read<AppBloc>().add(FetchActiveMinesGameEvent());
    context.read<AppBloc>().add(FetchMinesHistoryEvent());
    context.read<AppBloc>().add(FetchMinesSettingsEvent());
  }

  @override
  void dispose() {
    _betController.dispose();
    super.dispose();
  }

  void _adjustBet(double factor) {
    final currentVal = double.tryParse(_betController.text) ?? 10.0;
    final newVal = (currentVal * factor).clamp(10.0, 5000.0);
    setState(() {
      _betController.text = newVal.toStringAsFixed(1);
    });
  }

  void _setMaxBet() {
    final profile = context.read<AppBloc>().state.currentUser;
    final balance =
        (profile?.depositBalance ?? 0.0) + (profile?.winningBalance ?? 0.0);
    final maxBet = balance.clamp(10.0, 5000.0);
    setState(() {
      _betController.text = maxBet.toStringAsFixed(1);
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
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _flipQueue.clear();
    context.read<AppBloc>().add(StartMinesGameEvent(bet, _selectedMinesCount));
    HapticFeedback.mediumImpact();
  }

  void _revealCell(MinesGameModel game, int index) {
    if (_flipQueue.contains(index)) return;
    setState(() {
      _flipQueue.add(index);
    });
    context.read<AppBloc>().add(RevealMinesCellEvent(game.id, index));
    HapticFeedback.lightImpact();
  }

  void _cashout(MinesGameModel game) {
    context.read<AppBloc>().add(CashoutMinesGameEvent(game.id));
    HapticFeedback.vibrate();
  }

  void _resetGame() {
    context.read<AppBloc>().add(ResetMinesEvent());
    context.read<AppBloc>().add(FetchMinesHistoryEvent());
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F212E), // Stake style dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2C38),
        elevation: 0,
        title: Text(
          'MINES ORIGINALS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
      ),
      body: BlocConsumer<AppBloc, AppState>(
        listener: (context, state) {
          if (state.minesError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.minesError!),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.minesSettings?.maintenanceMode == true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.construction,
                      size: 80,
                      color: Colors.amber,
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
                      'Mines game is currently down for maintenance. Please check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          final game = state.activeMinesGame;
          final balance = state.currentUser != null
              ? (state.currentUser!.depositBalance +
                    state.currentUser!.winningBalance +
                    state.currentUser!.bonusBalance)
              : 0.0;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              final boardWidget = _buildMinesBoard(game);
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
                        padding: const EdgeInsets.all(16.0),
                        child: boardWidget,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: controlWidget,
                      ),
                      _buildHistoryList(state.minesHistory),
                    ],
                  ),
                );
              } else {
                // Wide Desktop/Tablet split layout
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
                            boardWidget,
                            const SizedBox(height: 24),
                            _buildHistoryList(state.minesHistory),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 320,
                      color: const Color(0xFF162531),
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
        color: const Color(0xFF1A2C38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2F4553), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.blueAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'YOUR WALLET',
                style: TextStyle(
                  color: Color(0xFFB1C6D4),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            _formatCurrency(balance),
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

  Widget _buildMinesBoard(MinesGameModel? game) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF162531), // Deep blue-gray
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 25,
          itemBuilder: (context, index) {
            return _buildTile(game, index);
          },
        ),
      ),
    );
  }

  Widget _buildTile(MinesGameModel? game, int index) {
    if (game == null) {
      // Disabled state before game starts
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F4553),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    final isRevealed = game.revealedPositions.contains(index);
    final isGameOver = !game.isInProgress;

    // Determine what is behind this tile
    bool containsMine = false;
    if (isGameOver && game.minesPositions != null) {
      containsMine = game.minesPositions!.contains(index);
    }

    // Interactive clicking behavior
    final canClick = game.isInProgress && !isRevealed;

    return GestureDetector(
      onTap: canClick ? () => _revealCell(game, index) : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: 3.14, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              final angle = rotate.value;
              final isBack = angle >= 1.57;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isBack
                    ? Container(color: const Color(0xFF2F4553))
                    : child,
              );
            },
          );
        },
        child: _buildTileContent(
          index,
          isRevealed,
          isGameOver,
          containsMine,
          game,
        ),
      ),
    );
  }

  Widget _buildTileContent(
    int index,
    bool isRevealed,
    bool isGameOver,
    bool containsMine,
    MinesGameModel game,
  ) {
    if (!isRevealed && !isGameOver) {
      // Hidden, active cell
      return Container(
        key: ValueKey('active_$index'),
        decoration: BoxDecoration(
          color: const Color(0xFF2F4553), // Active greyish blue
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4D708A), width: 1),
        ),
        child: const Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Colors.transparent),
            ),
          ),
        ),
      );
    }

    if (isRevealed && !containsMine) {
      // Revealed Safe Gem
      return Container(
        key: ValueKey('gem_$index'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.diamond, color: Colors.white, size: 28),
        ),
      );
    }

    if (isGameOver) {
      if (containsMine) {
        // Hit Mine (Explosion) or Revealed unclicked mine
        final didPlayerHitThis = game.isLost && game.revealedPositions.isEmpty
            ? false
            : (game.isLost && index == game.revealedPositions.last);
        return Container(
          key: ValueKey('bomb_$index'),
          decoration: BoxDecoration(
            color: didPlayerHitThis
                ? Colors.redAccent
                : const Color(0xFF1E2D3B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: didPlayerHitThis ? Colors.red : Colors.transparent,
              width: 2,
            ),
            boxShadow: didPlayerHitThis
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Opacity(
              opacity: didPlayerHitThis ? 1.0 : 0.6,
              child: const Text('💣', style: TextStyle(fontSize: 28)),
            ),
          ),
        );
      } else {
        // Dimmed Gem at game over
        return Container(
          key: ValueKey('dimmed_gem_$index'),
          decoration: BoxDecoration(
            color: const Color(0xFF101C24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.diamond_outlined,
              color: Colors.greenAccent.withOpacity(0.15),
              size: 24,
            ),
          ),
        );
      }
    }

    return Container(key: ValueKey('empty_$index'));
  }

  Widget _buildControlPanel(
    AppState state,
    MinesGameModel? game,
    double balance,
  ) {
    final isGameActive = game != null && game.isInProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Bet Amount (INR)',
          style: TextStyle(
            color: Color(0xFFB1C6D4),
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
                enabled: !isGameActive,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  fillColor: Color(0xFF1A2C38),
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
            _buildQuickBetButton('1/2', () => _adjustBet(0.5), isGameActive),
            const SizedBox(width: 4),
            _buildQuickBetButton('2x', () => _adjustBet(2.0), isGameActive),
            const SizedBox(width: 4),
            _buildQuickBetButton('Max', _setMaxBet, isGameActive),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Number of Mines',
          style: TextStyle(
            color: Color(0xFFB1C6D4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2C38),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMinesCount,
                    dropdownColor: const Color(0xFF1A2C38),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFB1C6D4),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    isExpanded: true,
                    items: [1, 2, 3, 4, 5, 8, 10, 15, 20, 24]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text('$e Mines'),
                          ),
                        )
                        .toList(),
                    onChanged: isGameActive
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMinesCount = val;
                              });
                            }
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isGameActive
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFFF9100,
                        ), // Intense Orange
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: state.isMinesLoading
                          ? null
                          : () => _cashout(game),
                      child: state.isMinesLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.black,
                                ),
                              ),
                            )
                          : Text(
                              'CASH OUT (${_formatCurrency(game.currentWin)})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    )
                  : (game != null && !game.isInProgress)
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _resetGame,
                      child: const Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676), // Lime Green
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: state.isMinesLoading
                          ? null
                          : () => _startGame(state),
                      child: state.isMinesLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Text(
                              'START CASINO BET',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
            ),
          ],
        ),
        if (isGameActive) ...[
          const SizedBox(height: 16),
          // Multipliers Tracker
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2C38),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2F4553)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Multiplier',
                      style: TextStyle(color: Color(0xFFB1C6D4), fontSize: 12),
                    ),
                    Text(
                      '${game.currentMultiplier.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF2F4553)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Payout',
                      style: TextStyle(color: Color(0xFFB1C6D4), fontSize: 12),
                    ),
                    Text(
                      _formatCurrency(game.currentWin),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (game != null && !game.isInProgress) ...[
          const SizedBox(height: 16),
          // Game Over Options
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: game.isWon
                  ? const Color(0xFF1E3A24)
                  : const Color(0xFF3E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                game.isWon
                    ? '🎉 WON! Payout: ${_formatCurrency(game.currentWin)} (${game.currentMultiplier.toStringAsFixed(2)}x)'
                    : '💥 BOOM! You hit a mine and lost your bet.',
                style: TextStyle(
                  color: game.isWon ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuickBetButton(
    String label,
    VoidCallback onPressed,
    bool disabled,
  ) {
    return SizedBox(
      height: 38,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF2F4553),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: disabled ? null : onPressed,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<MinesGameModel> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mines Turn-over History',
            style: TextStyle(
              color: Color(0xFFB1C6D4),
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
              final isWin = record.status == 'WON';
              final timeStr =
                  '${record.createdAt.day}/${record.createdAt.month} ${record.createdAt.hour}:${record.createdAt.minute.toString().padLeft(2, '0')}';

              return Card(
                color: const Color(0xFF162531),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isWin
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    child: Icon(
                      isWin ? Icons.trending_up : Icons.trending_down,
                      color: isWin ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                  title: Text(
                    isWin
                        ? 'Won ${_formatCurrency(record.currentWin)}'
                        : 'Lost Bet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Bet: ${_formatCurrency(record.betAmount)} | ${record.minesCount} Mines',
                    style: const TextStyle(
                      color: Color(0xFFB1C6D4),
                      fontSize: 11,
                    ),
                  ),
                  trailing: Text(
                    timeStr,
                    style: const TextStyle(
                      color: Color(0xFFB1C6D4),
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

  void _showFairnessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162531),
        title: const Text(
          'Provably Fair Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Our Mines game utilizes a cryptographic verification mechanism ensuring all mine positions are pre-determined before you play and cannot be altered during gameplay.',
                style: TextStyle(color: Color(0xFFB1C6D4), fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'How it works:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '1. The backend securely draws 25 cell indices using cryptographically secure random integers on the start of a bet.\n'
                '2. The positions remain hidden and secure in the database. They are only sent in response JSON payloads once a bomb is struck or you cash out.\n'
                '3. Wallet deductions and credits are strictly locked inside transaction boundaries to protect database balances.',
                style: TextStyle(color: Color(0xFFB1C6D4), fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }
}
