import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:target99/core/theme/app_theme.dart';
import 'package:target99/core/models/spin_model.dart';
import 'package:target99/core/widgets/custom_button.dart';
import 'package:target99/features/app_bloc.dart';
import 'package:target99/core/network/remote_config_service.dart';
import 'package:target99/core/utils/dependency_injection.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  final _betController = TextEditingController(text: '10');
  double _selectedChip = 10.0;
  bool _isSpinning = false;

  // 12 sectors matching the backend segment indices
  static const List<Map<String, dynamic>> wheelSectors = [
    {"label": "Lose", "isWin": false, "color": AppTheme.cardBg},
    {"label": "1.1x", "isWin": true, "color": AppTheme.accentCyan},
    {"label": "Try Again", "isWin": false, "color": AppTheme.cardBg},
    {"label": "1.5x", "isWin": true, "color": AppTheme.accentPurple},
    {"label": "Better Luck", "isWin": false, "color": AppTheme.cardBg},
    {"label": "2x", "isWin": true, "color": AppTheme.accentCyan},
    {"label": "0x", "isWin": false, "color": AppTheme.cardBg},
    {"label": "1x", "isWin": true, "color": AppTheme.accentEmerald},
    {"label": "3x", "isWin": true, "color": AppTheme.accentAmber},
    {"label": "1.2x", "isWin": true, "color": AppTheme.accentPurple},
    {"label": "Lose", "isWin": false, "color": AppTheme.cardBg},
    {"label": "5x", "isWin": true, "color": AppTheme.accentAmber},
  ];

  @override
  void initState() {
    super.initState();
    // Reset previous spin result to prevent auto-spin when opening
    context.read<AppBloc>().add(ResetSpinEvent());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Initialize animation to 0 radians
    _animation = Tween<double>(begin: 0, end: 0).animate(_animationController);

    // Fetch spin history
    context.read<AppBloc>().add(FetchSpinHistoryEvent());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _betController.dispose();
    super.dispose();
  }

  void _triggerSpinAnimation(int targetIndex, SpinResultModel result) {
    setState(() {
      _isSpinning = true;
    });

    // Pointer is at the top (270 degrees / -pi/2).
    // Each sector is 30 degrees (pi / 6 radians).
    // Sector center is: index * 30 + 15.
    // To align sector center with pointer (270 degrees):
    // Rotation = 270 - (index * 30 + 15) degrees.
    // We add 5 full rotations (360 * 5) for high excitement!
    final double currentAngle = _animation.value % (2 * pi);
    final double targetDegrees =
        360 * 5 + (270.0 - (targetIndex * 30.0 + 15.0));
    final double targetRadians = targetDegrees * pi / 180.0;

    _animation = Tween<double>(begin: currentAngle, end: targetRadians).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Tactile Haptic boundaries cross tracker
    double lastAngle = currentAngle;
    final double sectorStep = 30.0 * pi / 180.0; // 30 degrees in radians

    _animation.addListener(() {
      final double diff = (_animation.value - lastAngle).abs();
      if (diff >= sectorStep * 0.8) {
        HapticFeedback.lightImpact();
        lastAngle = _animation.value;
      }
    });

    _animationController.reset();
    _animationController.forward().then((_) {
      setState(() {
        _isSpinning = false;
      });
      _showResultOverlay(result);
    });
  }

  void _showResultOverlay(SpinResultModel result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final bool isWin = result.winAmount > 0;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
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
                    isWin
                        ? Icons.emoji_events_outlined
                        : Icons.sentiment_dissatisfied,
                    color: isWin ? AppTheme.accentEmerald : AppTheme.accentRed,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isWin ? '🏆 BIG WINNER!' : 'TRY AGAIN!',
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
                      ? 'You hit a massive ${result.multiplier}x multiplier!'
                      : 'Better luck next time! The wheel is waiting.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                if (isWin) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderCol),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'WON: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          '₹${result.winAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                CustomButton(
                  text: 'CONTINUE PLAY',
                  type: CustomButtonType.primary,
                  onPressed: () {
                    Navigator.of(context).pop(); // Close result overlay dialog
                    context.read<AppBloc>().add(
                      ResetSpinEvent(),
                    ); // Clear the spin result
                    context.read<AppBloc>().add(FetchSpinHistoryEvent());
                  },
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'GO BACK',
                  type: CustomButtonType.secondary,
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop(); // Close result overlay dialog
                    // navigator.pop(); // Go back to Home
                    context.read<AppBloc>().add(
                      ResetSpinEvent(),
                    ); // Clear the spin result
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _executeSpinRequest() {
    final double betAmount = double.tryParse(_betController.text.trim()) ?? 0.0;
    if (betAmount < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum bet is ₹1.00.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    if (betAmount > 5000.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily responsible gaming limit is ₹5000.00.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    final String idempotencyKey =
        'key_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    context.read<AppBloc>().add(PlaySpinWheelEvent(betAmount, idempotencyKey));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (prev, curr) =>
          prev.isSpinLoading != curr.isSpinLoading ||
          prev.latestSpinResult != curr.latestSpinResult ||
          prev.spinError != curr.spinError,
      listener: (context, state) {
        if (state.spinError != null && !_isSpinning) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.spinError!),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
        if (state.latestSpinResult != null && !_isSpinning) {
          final result = state.latestSpinResult!;
          _triggerSpinAnimation(result.segmentIndex, result);
        }
      },
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final user = state.currentUser;
          final double totalUsable =
              (user?.depositBalance ?? 0.0) +
              (user?.winningBalance ?? 0.0) +
              (user?.bonusBalance ?? 0.0);
          final double betVal =
              double.tryParse(_betController.text.trim()) ?? 0.0;
          final bool hasSuffFunds = totalUsable >= betVal;

          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Casino Spin Wheel',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppTheme.darkBg,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history, color: AppTheme.accentCyan),
                  onPressed: () => _showHistoryDrawer(context),
                  tooltip: 'Spin History',
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Net Balance Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL WALLET BALANCE',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalUsable.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _subBal(
                                'Deposit',
                                user?.depositBalance ?? 0.0,
                                AppTheme.accentCyan,
                              ),
                              const SizedBox(width: 12),
                              _subBal(
                                'Winnings',
                                user?.winningBalance ?? 0.0,
                                AppTheme.accentEmerald,
                              ),
                              const SizedBox(width: 12),
                              _subBal(
                                'Bonus',
                                user?.bonusBalance ?? 0.0,
                                AppTheme.accentPurple,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Casino Wheel Canvas Section
                  Center(
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow Backing
                          Container(
                            width: 275,
                            height: 275,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentCyan.withOpacity(0.08),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),

                          // Animated Custom Painter Canvas Wheel
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _animation.value,
                                child: CustomPaint(
                                  size: const Size(260, 260),
                                  painter: WheelPainter(sectors: wheelSectors),
                                ),
                              );
                            },
                          ),

                          // Outer casino boundary border decoration
                          Container(
                            width: 270,
                            height: 270,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.borderCol.withOpacity(0.12),
                                width: 5,
                              ),
                            ),
                          ),

                          // Golden Pointer Arrow Pins
                          Positioned(
                            top: 0,
                            child: CustomPaint(
                              size: const Size(20, 25),
                              painter: PointerPainter(),
                            ),
                          ),

                          // Decorative Center Cap Dial Pin
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.darkBg,
                              border: Border.all(
                                color: AppTheme.accentCyan,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentCyan.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.casino,
                                size: 14,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bet Amount selector
                  const Text(
                    'CHOOSE BET SIZE (INR)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Interactive Neon Chips selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [10, 50, 100, 250].map((chip) {
                      final isSel = _selectedChip == chip;
                      Color cColor = AppTheme.accentCyan;
                      if (chip == 50) cColor = AppTheme.accentPurple;
                      if (chip == 100) cColor = AppTheme.accentEmerald;
                      if (chip == 250) cColor = AppTheme.accentAmber;

                      return GestureDetector(
                        onTap: _isSpinning
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _selectedChip = chip.toDouble();
                                  _betController.text = chip.toString();
                                });
                              },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel
                                ? cColor.withOpacity(0.12)
                                : AppTheme.cardBg,
                            border: Border.all(
                              color: isSel ? cColor : AppTheme.borderCol,
                              width: isSel ? 2 : 1.2,
                            ),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: cColor.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '₹$chip',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isSel ? cColor : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Manual bet input
                  TextField(
                    controller: _betController,
                    keyboardType: TextInputType.number,
                    enabled: !_isSpinning,
                    onChanged: (val) {
                      setState(() {
                        _selectedChip = double.tryParse(val) ?? 0.0;
                      });
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.money, color: AppTheme.accentCyan),
                      hintText: 'Enter custom bet amount',
                      labelText: 'Bet Size (₹)',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Launch Spin Wheel CTA Button
                  if (!hasSuffFunds && !_isSpinning) ...[
                    CustomButton(
                      text: 'ADD ₹${(betVal - totalUsable).ceil()} TO SPIN',
                      type: CustomButtonType.primary,
                      height: 52.0,
                      onPressed: () {
                        final shortfall = betVal - totalUsable;
                        _showAdminDepositBottomSheet(context, shortfall);
                      },
                    ),
                  ] else ...[
                    CustomButton(
                      text: 'SPIN CASINO WHEEL',
                      type: CustomButtonType.primary,
                      height: 52.0,
                      isLoading: _isSpinning || state.isSpinLoading,
                      onPressed: (_isSpinning || state.isSpinLoading)
                          ? null
                          : _executeSpinRequest,
                    ),
                  ],
                  const SizedBox(height: 16),

                  const Text(
                    '🔒 Dynamic RTP Payout Guarantee. Multiplier generated securely on backend engine only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                  ),
                ],
              ),
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
        Text(
          name.toUpperCase(),
          style: const TextStyle(
            fontSize: 6,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '₹${val.toInt()}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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
            final history = state.spinHistory;
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spin Turn-over History',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.isSpinLoading && history.isEmpty)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    )
                  else if (history.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No spin transactions logged yet.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (ctx, index) {
                          final spin = history[index];
                          final isWin = spin.winAmount > 0;
                          final dateStr =
                              '${spin.createdAt.day}/${spin.createdAt.month} ${spin.createdAt.hour}:${spin.createdAt.minute.toString().padLeft(2, '0')}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isWin
                                      ? AppTheme.accentEmerald.withOpacity(0.1)
                                      : AppTheme.accentRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isWin
                                      ? Icons.casino
                                      : Icons.remove_circle_outline,
                                  color: isWin
                                      ? AppTheme.accentEmerald
                                      : AppTheme.accentRed,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                isWin
                                    ? 'WINNER (${spin.wheelSegment})'
                                    : 'LOSS (${spin.wheelSegment})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                '$dateStr • Charged: ₹${spin.betAmount.toInt()}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              trailing: Text(
                                isWin
                                    ? '+₹${spin.winAmount.toStringAsFixed(0)}'
                                    : '₹${spin.betAmount.toInt()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isWin
                                      ? AppTheme.accentEmerald
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdminDepositBottomSheet(
    BuildContext context,
    double defaultAmount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final remoteConfig = getIt<RemoteConfigService>();
        final String upiId = remoteConfig.adminUpiId;
        final String bankHolder = remoteConfig.adminBankHolder;
        final String bankName = remoteConfig.adminBankName;
        final String bankAccount = remoteConfig.adminBankAccount;
        final String bankIfsc = remoteConfig.adminBankIfsc;
        final String supportPhone = remoteConfig.adminContactPhone;
        final String supportEmail = remoteConfig.adminContactEmail;

        final TextEditingController amountController = TextEditingController(
          text: defaultAmount.ceil().toString(),
        );
        final TextEditingController utrController = TextEditingController();
        int activeTab = 0; // 0 for UPI, 1 for Bank

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header handle indicator
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Instant Manual Payout',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Transfer payment to the Admin details below. After payment is complete, enter the transaction UTR number to instantly credit your wallet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Custom Slide Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderCol),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => activeTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: activeTab == 0
                                        ? AppTheme.accentCyan.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: activeTab == 0
                                        ? Border.all(
                                            color: AppTheme.accentCyan
                                                .withOpacity(0.5),
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'UPI Transfer',
                                      style: TextStyle(
                                        color: activeTab == 0
                                            ? AppTheme.accentCyan
                                            : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => activeTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: activeTab == 1
                                        ? AppTheme.accentPurple.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: activeTab == 1
                                        ? Border.all(
                                            color: AppTheme.accentPurple
                                                .withOpacity(0.5),
                                          )
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Bank Account',
                                      style: TextStyle(
                                        color: activeTab == 1
                                            ? AppTheme.accentPurple
                                            : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tabs view content
                      if (activeTab == 0) ...[
                        // UPI Info Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppTheme.borderCol),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'OFFICIAL UPI ADDRESS',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        upiId,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy,
                                        color: AppTheme.accentCyan,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: upiId),
                                        );
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'UPI ID copied to clipboard.',
                                            ),
                                            backgroundColor:
                                                AppTheme.accentCyan,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Bank details Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppTheme.borderCol),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _adminDetailCopyRow(ctx, 'BANK NAME', bankName),
                                const Divider(
                                  color: AppTheme.borderCol,
                                  height: 16,
                                ),
                                _adminDetailCopyRow(
                                  ctx,
                                  'HOLDER NAME',
                                  bankHolder,
                                ),
                                const Divider(
                                  color: AppTheme.borderCol,
                                  height: 16,
                                ),
                                _adminDetailCopyRow(
                                  ctx,
                                  'ACCOUNT NUMBER',
                                  bankAccount,
                                ),
                                const Divider(
                                  color: AppTheme.borderCol,
                                  height: 16,
                                ),
                                _adminDetailCopyRow(ctx, 'IFSC CODE', bankIfsc),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Admin Support block
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.support_agent,
                                  color: AppTheme.accentAmber,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'ADMIN SUPPORT & QUERIES',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentAmber,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_android,
                                      size: 14,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      supportPhone,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 12,
                                    color: AppTheme.accentAmber,
                                  ),
                                  label: const Text(
                                    'COPY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.accentAmber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: supportPhone),
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Support phone copied.'),
                                        backgroundColor: AppTheme.accentAmber,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 14,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      supportEmail,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 12,
                                    color: AppTheme.accentAmber,
                                  ),
                                  label: const Text(
                                    'COPY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.accentAmber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: supportEmail),
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Support email copied.'),
                                        backgroundColor: AppTheme.accentAmber,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Manual Payment Inputs
                      const Text(
                        'SUBMIT PAYMENT RECEIPT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid (₹)',
                          hintText: 'Enter amount paid',
                          prefixText: '₹ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: utrController,
                        keyboardType: TextInputType.number,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: 'UTR / Transaction ID',
                          hintText: '12-digit payment transaction number',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit request button
                      ElevatedButton(
                        onPressed: () {
                          final double? amt = double.tryParse(
                            amountController.text.trim(),
                          );
                          final String utr = utrController.text.trim();

                          if (amt == null || amt <= 0.0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid amount.'),
                                backgroundColor: AppTheme.accentRed,
                              ),
                            );
                            return;
                          }
                          if (utr.length != 12) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid 12-digit UTR/Reference ID.',
                                ),
                                backgroundColor: AppTheme.accentRed,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          // Process manual payment pending deposit with UTR verification
                          context.read<AppBloc>().add(
                            DepositMoneyEvent(amt, utr: utr),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Deposit request of ₹${amt.toStringAsFixed(2)} submitted successfully for verification! (UTR: $utr)',
                              ),
                              backgroundColor: AppTheme.accentEmerald,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: const Text('I HAVE PAID - CONFIRM DEPOSIT'),
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

  Widget _adminDetailCopyRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, color: AppTheme.accentPurple, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied to clipboard.'),
                backgroundColor: AppTheme.accentPurple,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Custom Painter to draw Wheel wedges cleanly
class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> sectors;

  WheelPainter({required this.sectors});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppTheme.borderCol.withOpacity(0.08)
      ..strokeWidth = 1.0;

    final double arcAngle = 2 * pi / sectors.length; // 30 degrees in radians

    for (int i = 0; i < sectors.length; i++) {
      final sector = sectors[i];

      // Alternate colors
      fillPaint.color = sector["color"] as Color;
      if (fillPaint.color == AppTheme.cardBg && i % 4 == 2) {
        fillPaint.color = AppTheme.darkBg;
      }

      final double startAngle = i * arcAngle;

      // Draw arc wedge
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        true,
        fillPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        true,
        borderPaint,
      );

      // Draw Sector Label
      canvas.save();
      final double middleAngle = startAngle + (arcAngle / 2);

      // Move origin to center
      canvas.translate(radius, radius);
      canvas.rotate(middleAngle);

      // Draw text
      final label = sector["label"] as String;
      final bool isWin = sector["isWin"] as bool;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isWin ? Colors.black : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Position label inside the wedge radially
      final double offsetRadius = radius * 0.65;
      canvas.translate(offsetRadius, -textPainter.height / 2);

      // Rotate label to align outwards
      canvas.rotate(pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter to draw pointer arrow pin at top
class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppTheme.accentAmber
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    // Shadow
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, paint);

    // Accent line
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
