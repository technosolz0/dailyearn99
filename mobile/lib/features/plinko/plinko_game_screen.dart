import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/models/plinko_model.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/widgets/deposit_bottom_sheet.dart';

class PlinkoGameScreen extends StatefulWidget {
  const PlinkoGameScreen({super.key});

  @override
  State<PlinkoGameScreen> createState() => _PlinkoGameScreenState();
}

class _PlinkoGameScreenState extends State<PlinkoGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _betController = TextEditingController(text: '10');

  double _selectedChip = 10.0;
  int _selectedRows = 10;
  String _selectedRisk = 'medium'; // 'low', 'medium', 'high'
  bool _isDropping = false;

  // Ball animation state
  List<Offset> _animationPathPoints = [];
  Offset? _currentBallPosition;
  int _lastTickIndex = -1;

  // Default multipliers fallback matching backend seeds
  static const Map<int, Map<String, List<double>>> _fallbackMultipliers = {
    10: {
      "low": [16.0, 9.0, 2.0, 1.4, 1.1, 1.0, 1.1, 1.4, 2.0, 9.0, 16.0],
      "medium": [22.0, 5.0, 2.0, 1.4, 0.6, 0.4, 0.6, 1.4, 2.0, 5.0, 22.0],
      "high": [110.0, 15.0, 4.0, 1.8, 0.7, 0.3, 0.7, 1.8, 4.0, 15.0, 110.0]
    },
    11: {
      "low": [24.0, 10.0, 3.0, 1.8, 1.2, 1.0, 1.0, 1.2, 1.8, 3.0, 10.0, 24.0],
      "medium": [33.0, 8.0, 3.0, 1.6, 0.7, 0.5, 0.5, 0.7, 1.6, 3.0, 8.0, 33.0],
      "high": [170.0, 24.0, 8.1, 2.0, 0.7, 0.2, 0.2, 0.7, 2.0, 8.1, 24.0, 170.0]
    },
    12: {
      "low": [33.0, 11.0, 4.0, 2.0, 1.3, 1.1, 1.0, 1.1, 1.3, 2.0, 4.0, 11.0, 33.0],
      "medium": [50.0, 11.0, 4.0, 2.0, 1.1, 0.6, 0.3, 0.6, 1.1, 2.0, 4.0, 11.0, 50.0],
      "high": [260.0, 33.0, 11.0, 4.0, 2.0, 0.5, 0.2, 0.5, 2.0, 4.0, 11.0, 33.0, 260.0]
    },
    13: {
      "low": [43.0, 13.0, 6.0, 3.0, 1.3, 1.2, 1.0, 1.0, 1.2, 1.3, 3.0, 6.0, 13.0, 43.0],
      "medium": [76.0, 14.0, 6.0, 3.0, 1.3, 0.7, 0.4, 0.4, 0.7, 1.3, 3.0, 6.0, 14.0, 76.0],
      "high": [420.0, 56.0, 18.0, 6.0, 3.0, 1.0, 0.2, 0.2, 1.0, 3.0, 6.0, 18.0, 56.0, 420.0]
    },
    14: {
      "low": [56.0, 18.0, 8.0, 3.8, 2.0, 1.2, 1.0, 1.0, 1.0, 1.2, 2.0, 3.8, 8.0, 18.0, 56.0],
      "medium": [110.0, 18.0, 8.0, 3.8, 1.5, 1.0, 0.5, 0.2, 0.5, 1.0, 1.5, 3.8, 8.0, 18.0, 110.0],
      "high": [620.0, 83.0, 27.0, 8.0, 3.0, 1.3, 0.5, 0.2, 0.5, 1.3, 3.0, 8.0, 27.0, 83.0, 620.0]
    },
    15: {
      "low": [79.0, 24.0, 10.0, 4.8, 2.5, 1.5, 1.0, 1.0, 1.0, 1.0, 1.5, 2.5, 4.8, 10.0, 24.0, 79.0],
      "medium": [180.0, 29.0, 11.0, 5.0, 2.0, 1.1, 0.6, 0.3, 0.3, 0.6, 1.1, 2.0, 5.0, 11.0, 29.0, 180.0],
      "high": [1000.0, 130.0, 37.0, 11.0, 4.0, 1.5, 1.0, 0.5, 0.5, 1.0, 1.5, 4.0, 11.0, 37.0, 130.0, 1000.0]
    },
    16: {
      "low": [110.0, 33.0, 12.0, 6.0, 3.0, 1.8, 1.2, 1.0, 1.0, 1.0, 1.2, 1.8, 3.0, 6.0, 12.0, 33.0, 110.0],
      "medium": [260.0, 43.0, 15.0, 6.0, 3.0, 1.5, 1.0, 0.5, 0.3, 0.5, 1.0, 1.5, 3.0, 6.0, 15.0, 43.0, 260.0],
      "high": [1000.0, 130.0, 43.0, 14.0, 5.0, 2.0, 1.3, 0.5, 0.2, 0.5, 1.3, 2.0, 5.0, 14.0, 43.0, 130.0, 1000.0]
    }
  };

  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(ResetPlinkoEvent());
    context.read<AppBloc>().add(FetchPlinkoHistoryEvent());
    context.read<AppBloc>().add(FetchPlinkoSettingsEvent());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _animationController.addListener(_onBallAnimationUpdate);
  }

  @override
  void dispose() {
    _animationController.removeListener(_onBallAnimationUpdate);
    _animationController.dispose();
    _betController.dispose();
    super.dispose();
  }

  void _onBallAnimationUpdate() {
    if (_animationPathPoints.isEmpty) return;

    final progress = _animationController.value;
    final double pathProgress = progress * (_animationPathPoints.length - 1);
    final int index = pathProgress.floor();
    final double t = pathProgress - index;

    if (index >= _animationPathPoints.length - 1) {
      _currentBallPosition = _animationPathPoints.last;
    } else {
      // Linear interpolation between consecutive points
      final p1 = _animationPathPoints[index];
      final p2 = _animationPathPoints[index + 1];

      // Add a bouncing arc (parabola) effect between pegs
      final double bounceHeight = index == _animationPathPoints.length - 2 ? 0.0 : 16.0;
      final double arcY = -sin(t * pi) * bounceHeight;

      _currentBallPosition = Offset(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t + arcY,
      );
    }

    // Play light haptic feedback at each bounce peak/drop segment transition
    if (index != _lastTickIndex) {
      _lastTickIndex = index;
      HapticFeedback.lightImpact();
    }

    setState(() {});
  }

  void _triggerBallDrop(List<int> path, PlinkoPlayResultModel result) {
    // Generate physical coordinates on our grid representation
    // Let's assume a canvas size of width x height
    // We compute positions on a scale of 0 to 1 inside a custom painter, then scale to size.
    final List<Offset> points = [];

    // Point 0: Drop entry from top center
    points.add(const Offset(0.5, 0.05));

    // Follow path bouncing left/right on pins
    // Pin at step i represents the sum of path indices up to step i
    int activePinIndex = 0;
    for (int i = 0; i < path.length; i++) {
      activePinIndex += path[i];
      // Map coordinates: row starts from 1 to R. Pin index goes from 0 to row.
      // row spacing = 0.8 / R
      // spacing between pins = 0.6 / R
      final double rowY = 0.08 + (i + 1) * (0.75 / _selectedRows);
      final double rowX = 0.5 + (activePinIndex - (i + 1) / 2.0) * (0.7 / _selectedRows);
      points.add(Offset(rowX, rowY));
    }

    // Add a final landing point in the bucket
    final double bucketY = 0.08 + (_selectedRows + 1.2) * (0.75 / _selectedRows);
    final double bucketX = 0.5 + (activePinIndex - _selectedRows / 2.0) * (0.7 / _selectedRows);
    points.add(Offset(bucketX, bucketY));

    setState(() {
      _isDropping = true;
      _animationPathPoints = points;
      _currentBallPosition = points.first;
      _lastTickIndex = -1;
    });

    _animationController.reset();
    _animationController.forward().then((_) {
      setState(() {
        _isDropping = false;
      });
      context.read<AppBloc>().add(LoadProfileEvent());
      _showResultOverlay(result);
    });
  }

  void _showResultOverlay(PlinkoPlayResultModel result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final bool isWin = result.winAmount > result.betAmount;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isWin ? AppTheme.accentEmerald : AppTheme.borderCol,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isWin
                      ? AppTheme.accentEmerald.withOpacity(0.2)
                      : Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isWin
                        ? AppTheme.accentEmerald.withOpacity(0.1)
                        : AppTheme.accentRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWin ? Icons.emoji_events_outlined : Icons.sentiment_dissatisfied,
                    color: isWin ? AppTheme.accentEmerald : AppTheme.accentRed,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isWin ? '🏆 WINNER!' : 'BET COMPLETED',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isWin ? AppTheme.accentEmerald : Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isWin
                      ? 'Multiplier: ${result.multiplier}x'
                      : 'Multiplier: ${result.multiplier}x',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'RETURN: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '₹${result.winAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isWin ? AppTheme.accentEmerald : AppTheme.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'CONTINUE',
                  type: CustomButtonType.primary,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.read<AppBloc>().add(ResetPlinkoEvent());
                    context.read<AppBloc>().add(FetchPlinkoHistoryEvent());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _executeBet() {
    final double betAmount = double.tryParse(_betController.text.trim()) ?? 0.0;
    if (betAmount < 1.0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Minimum bet size is ₹1.00.'), backgroundColor: AppTheme.accentRed),
        );
      return;
    }
    context.read<AppBloc>().add(PlayPlinkoEvent(betAmount, _selectedRows, _selectedRisk));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (prev, curr) =>
          prev.isPlinkoLoading != curr.isPlinkoLoading ||
          prev.latestPlinkoResult != curr.latestPlinkoResult ||
          prev.plinkoError != curr.plinkoError,
      listener: (context, state) {
        if (state.plinkoError != null && !_isDropping) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text(state.plinkoError!), backgroundColor: AppTheme.accentRed),
            );
        }
        if (state.latestPlinkoResult != null && !_isDropping) {
          _triggerBallDrop(state.latestPlinkoResult!.path, state.latestPlinkoResult!);
        }
      },
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final user = state.currentUser;
          final double totalUsable =
              (user?.depositBalance ?? 0.0) + (user?.winningBalance ?? 0.0) + (user?.bonusBalance ?? 0.0);
          final double betVal = double.tryParse(_betController.text.trim()) ?? 0.0;
          final bool hasSuffFunds = totalUsable >= betVal;

          final multipliers = _fallbackMultipliers[_selectedRows]?[_selectedRisk] ?? [];

          return Scaffold(
            appBar: AppBar(
              title: Text('Plinko Originals', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              backgroundColor: AppTheme.darkBg,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history, color: AppTheme.accentCyan),
                  onPressed: () => _showHistoryDrawer(context),
                  tooltip: 'Play History',
                ),
              ],
            ),
            body: Column(
              children: [
                // Top wallet bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('WALLET BALANCE',
                                  style: TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('₹${totalUsable.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
                            ],
                          ),
                          Row(
                            children: [
                              _subBal('Dep', user?.depositBalance ?? 0.0, AppTheme.accentCyan),
                              const SizedBox(width: 8),
                              _subBal('Win', user?.winningBalance ?? 0.0, AppTheme.accentEmerald),
                              const SizedBox(width: 8),
                              _subBal('Bon', user?.bonusBalance ?? 0.0, AppTheme.accentPurple),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                // Plinko Pyramid simulation canvas
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderCol),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: PlinkoPyramidPainter(
                                  rows: _selectedRows,
                                  multipliers: multipliers,
                                  ballPosition: _currentBallPosition,
                                  isDropping: _isDropping,
                                ),
                              ),
                            ),
                          ),
                          if (_isDropping)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                            )
                        ],
                      ),
                    ),
                  ),
                ),

                // Operational Settings & Stake Panel
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    border: const Border(top: BorderSide(color: AppTheme.borderCol)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row selector & Risk Selector
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedRows,
                                decoration: const InputDecoration(
                                  labelText: 'Rows Count',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                                dropdownColor: AppTheme.cardBg,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                items: List.generate(7, (index) => 10 + index)
                                    .map((rows) => DropdownMenuItem<int>(value: rows, child: Text('$rows Rows')))
                                    .toList(),
                                onChanged: _isDropping
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedRows = val;
                                          });
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedRisk,
                                decoration: const InputDecoration(
                                  labelText: 'Risk Mode',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                                dropdownColor: AppTheme.cardBg,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                items: ['low', 'medium', 'high']
                                    .map((risk) => DropdownMenuItem<String>(
                                        value: risk, child: Text(risk.substring(0, 1).toUpperCase() + risk.substring(1))))
                                    .toList(),
                                onChanged: _isDropping
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedRisk = val;
                                          });
                                        }
                                      },
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Chips Stake Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [10, 50, 100, 250].map((chip) {
                            final isSel = _selectedChip == chip;
                            final color = chip == 10
                                ? AppTheme.accentCyan
                                : (chip == 50
                                    ? AppTheme.accentPurple
                                    : (chip == 100 ? AppTheme.accentEmerald : AppTheme.accentAmber));
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: InkWell(
                                  onTap: _isDropping
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            _selectedChip = chip.toDouble();
                                            _betController.text = chip.toString();
                                          });
                                        },
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSel ? color.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isSel ? color : AppTheme.borderCol, width: isSel ? 1.5 : 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '₹$chip',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSel ? color : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Stake input field
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _betController,
                                keyboardType: TextInputType.number,
                                enabled: !_isDropping,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedChip = double.tryParse(val) ?? 0.0;
                                  });
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Bet amount',
                                  prefixIcon: Icon(Icons.currency_rupee, size: 16),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: !hasSuffFunds && !_isDropping
                                  ? CustomButton(
                                      text: 'ADD FUNDS',
                                      type: CustomButtonType.primary,
                                      height: 44,
                                      onPressed: () {
                                        DepositBottomSheet.show(context, defaultAmount: betVal - totalUsable);
                                      },
                                    )
                                  : CustomButton(
                                      text: 'PLACE BET',
                                      type: CustomButtonType.primary,
                                      height: 44,
                                      isLoading: _isDropping || state.isPlinkoLoading,
                                      onPressed: (_isDropping || state.isPlinkoLoading) ? null : _executeBet,
                                    ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _subBal(String name, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(name.toUpperCase(), style: const TextStyle(fontSize: 6, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
        Text('₹${val.toInt()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _showHistoryDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return BlocBuilder<AppBloc, AppState>(
          builder: (ctx, state) {
            final history = state.plinkoHistory;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Plinko Stakes History', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.isPlinkoLoading && history.isEmpty)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)))
                  else if (history.isEmpty)
                    const Expanded(
                        child: Center(
                            child: Text('No Plinko stakes logged yet.',
                                style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textMuted))))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (ctx, index) {
                          final item = history[index];
                          final isWin = item.winAmount > item.betAmount;
                          final dateStr =
                              '${item.createdAt.day}/${item.createdAt.month} ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isWin ? AppTheme.accentEmerald.withOpacity(0.1) : AppTheme.accentRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(isWin ? Icons.trending_up : Icons.trending_flat,
                                    color: isWin ? AppTheme.accentEmerald : AppTheme.accentAmber, size: 18),
                              ),
                              title: Text(
                                'Multiplier: ${item.multiplier}x (${item.mode.toUpperCase()})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              subtitle: Text(
                                '$dateStr • Bet: ₹${item.betAmount.toInt()} | ${item.rows} Rows',
                                style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                              ),
                              trailing: Text(
                                '₹${item.winAmount.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isWin ? AppTheme.accentEmerald : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class PlinkoPyramidPainter extends CustomPainter {
  final int rows;
  final List<double> multipliers;
  final Offset? ballPosition;
  final bool isDropping;

  PlinkoPyramidPainter({
    required this.rows,
    required this.multipliers,
    required this.ballPosition,
    required this.isDropping,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double spacingY = size.height * 0.75 / rows;
    final double spacingX = size.width * 0.7 / rows;

    // 1. Draw Pegs (Pins) Pyramid
    final Paint pinPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    for (int r = 0; r <= rows; r++) {
      // Row r has r + 1 pins
      final double y = size.height * 0.08 + r * spacingY;
      for (int p = 0; p <= r; p++) {
        final double x = size.width * 0.5 + (p - r / 2.0) * spacingX;
        canvas.drawCircle(Offset(x, y), 3.5, pinPaint);
      }
    }

    // 2. Draw landing buckets at the bottom
    final double bucketY = size.height * 0.08 + (rows + 1.2) * spacingY;
    final double bucketH = 26.0;
    final double bucketW = spacingX * 0.95;

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int b = 0; b <= rows; b++) {
      final double bucketX = size.width * 0.5 + (b - rows / 2.0) * spacingX;

      // Color mapping matching screenshot: pink on edges, orange -> yellow -> light center
      Color bucketColor = AppTheme.cardBg;
      final int mid = rows ~/ 2;
      final double distanceFactor = (b - mid).abs() / mid.toDouble();

      if (distanceFactor >= 0.8) {
        bucketColor = const Color(0xFFFF2D55); // Vibrant Pink
      } else if (distanceFactor >= 0.5) {
        bucketColor = const Color(0xFFF39C12); // Orange
      } else if (distanceFactor >= 0.2) {
        bucketColor = const Color(0xFFF1C40F); // Gold/Yellow
      } else {
        bucketColor = const Color(0xFFF5B041); // Light Gold
      }

      final Paint bucketPaint = Paint()
        ..color = bucketColor
        ..style = PaintingStyle.fill;

      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bucketX, bucketY), width: bucketW, height: bucketH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, bucketPaint);

      // Multiplier Text inside bucket
      final String multText = multipliers.length > b ? multipliers[b].toStringAsFixed(1) : '1.0';
      textPainter.text = TextSpan(
        text: multText,
        style: GoogleFonts.outfit(
          fontSize: rows > 13 ? 7 : 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          bucketX - textPainter.width / 2,
          bucketY - textPainter.height / 2,
        ),
      );
    }

    // 3. Draw drop channel arrow guide at top
    final Paint guidePaint = Paint()
      ..color = AppTheme.accentCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.5, 0.0),
      Offset(size.width * 0.5, size.height * 0.05),
      guidePaint,
    );

    // 4. Draw Ball if dropping
    if (isDropping && ballPosition != null) {
      final double px = ballPosition!.dx * size.width;
      final double py = ballPosition!.dy * size.height;

      // Outer glow of the ball
      final Paint glowPaint = Paint()
        ..color = const Color(0xFFFF2D55).withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(px, py), 12.0, glowPaint);

      // Inner core of the ball (Pink matching stakes)
      final Paint ballPaint = Paint()
        ..color = const Color(0xFFFF2D55)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), 7.0, ballPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PlinkoPyramidPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.multipliers != multipliers ||
        oldDelegate.ballPosition != ballPosition ||
        oldDelegate.isDropping != isDropping;
  }
}
