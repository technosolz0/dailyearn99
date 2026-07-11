import 'dart:math';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/models/plinko_model.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/widgets/deposit_bottom_sheet.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';

class PlinkoGameScreen extends StatefulWidget {
  const PlinkoGameScreen({super.key});

  @override
  State<PlinkoGameScreen> createState() => _PlinkoGameScreenState();
}

class _PlinkoGameScreenState extends State<PlinkoGameScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _lastTickTime = 0.0;

  final TextEditingController _betController = TextEditingController(
    text: '10',
  );

  double _selectedChip = 10.0;
  int _selectedRows = 10;
  String _selectedRisk = 'medium'; // 'low', 'medium', 'high'

  // Audio & Speed options
  bool _isSoundEnabled = true;
  bool _isTurboMode = false;
  DateTime _lastCollisionSoundTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCollisionHapticTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Game Loop physics lists
  final List<ActiveBall> _activeBalls = [];
  final Map<Offset, double> _activePegs =
      {}; // Coordinates normalized -> progress (1.0 -> 0.0)
  final Map<int, double> _activeBuckets = {}; // Index -> progress (1.0 -> 0.0)
  final List<PlinkoParticle> _particles = [];
  final List<FloatingWinBubble> _floatingWins = [];

  // Play Modes
  bool _isAutoMode = false;
  bool _isAutoPlayActive = false;
  int _autoPlayRemainingBets = 10;
  bool _isInfiniteAutoPlay = false;
  double _autoPlayIntervalSeconds = 0.4;
  double _timeSinceLastAutoDrop = 0.0;

  bool _isLocalLoading = false;
  bool _isAutoPlayLoading = false;

  // Active seeds for Provably Fair simulation
  String _clientSeed = "client_seed_daily99";
  final String _serverSeedHash =
      "d5c80a671cf298492accd4ff0e68cf09fef56fef95b34bc229aa1a26d15a9ab9";
  int _nonce = 0;

  // Default multipliers fallback matching backend seeds
  static const Map<int, Map<String, List<double>>> _fallbackMultipliers = {
    8: {
      "low": [5.6, 1.6, 1.1, 1.0, 0.5, 1.0, 1.1, 1.6, 5.6],
      "medium": [13.0, 3.0, 1.3, 0.7, 0.4, 0.7, 1.3, 3.0, 13.0],
      "high": [29.0, 4.0, 1.5, 0.3, 0.2, 0.3, 1.5, 4.0, 29.0],
    },
    9: {
      "low": [5.6, 2.0, 1.6, 1.0, 0.7, 0.7, 1.0, 1.6, 2.0, 5.6],
      "medium": [18.0, 4.0, 1.6, 0.9, 0.5, 0.5, 0.9, 1.6, 4.0, 18.0],
      "high": [43.0, 7.0, 2.0, 0.6, 0.2, 0.2, 0.6, 2.0, 7.0, 43.0],
    },
    10: {
      "low": [16.0, 9.0, 2.0, 1.4, 1.1, 1.0, 1.1, 1.4, 2.0, 9.0, 16.0],
      "medium": [22.0, 5.0, 2.0, 1.4, 0.6, 0.4, 0.6, 1.4, 2.0, 5.0, 22.0],
      "high": [110.0, 15.0, 4.0, 1.8, 0.7, 0.3, 0.7, 1.8, 4.0, 15.0, 110.0],
    },
    11: {
      "low": [24.0, 10.0, 3.0, 1.8, 1.2, 1.0, 1.0, 1.2, 1.8, 3.0, 10.0, 24.0],
      "medium": [33.0, 8.0, 3.0, 1.6, 0.7, 0.5, 0.5, 0.7, 1.6, 3.0, 8.0, 33.0],
      "high": [
        170.0,
        24.0,
        8.1,
        2.0,
        0.7,
        0.2,
        0.2,
        0.7,
        2.0,
        8.1,
        24.0,
        170.0,
      ],
    },
    12: {
      "low": [
        33.0,
        11.0,
        4.0,
        2.0,
        1.3,
        1.1,
        1.0,
        1.1,
        1.3,
        2.0,
        4.0,
        11.0,
        33.0,
      ],
      "medium": [
        50.0,
        11.0,
        4.0,
        2.0,
        1.1,
        0.6,
        0.3,
        0.6,
        1.1,
        2.0,
        4.0,
        11.0,
        50.0,
      ],
      "high": [
        260.0,
        33.0,
        11.0,
        4.0,
        2.0,
        0.5,
        0.2,
        0.5,
        2.0,
        4.0,
        11.0,
        33.0,
        260.0,
      ],
    },
    13: {
      "low": [
        43.0,
        13.0,
        6.0,
        3.0,
        1.3,
        1.2,
        1.0,
        1.0,
        1.2,
        1.3,
        3.0,
        6.0,
        13.0,
        43.0,
      ],
      "medium": [
        76.0,
        14.0,
        6.0,
        3.0,
        1.3,
        0.7,
        0.4,
        0.4,
        0.7,
        1.3,
        3.0,
        6.0,
        14.0,
        76.0,
      ],
      "high": [
        420.0,
        56.0,
        18.0,
        6.0,
        3.0,
        1.0,
        0.2,
        0.2,
        1.0,
        3.0,
        6.0,
        18.0,
        56.0,
        420.0,
      ],
    },
    14: {
      "low": [
        56.0,
        18.0,
        8.0,
        3.8,
        2.0,
        1.2,
        1.0,
        1.0,
        1.0,
        1.2,
        2.0,
        3.8,
        8.0,
        18.0,
        56.0,
      ],
      "medium": [
        110.0,
        18.0,
        8.0,
        3.8,
        1.5,
        1.0,
        0.5,
        0.2,
        0.5,
        1.0,
        1.5,
        3.8,
        8.0,
        18.0,
        110.0,
      ],
      "high": [
        620.0,
        83.0,
        27.0,
        8.0,
        3.0,
        1.3,
        0.5,
        0.2,
        0.5,
        1.3,
        3.0,
        8.0,
        27.0,
        83.0,
        620.0,
      ],
    },
    15: {
      "low": [
        79.0,
        24.0,
        10.0,
        4.8,
        2.5,
        1.5,
        1.0,
        1.0,
        1.0,
        1.0,
        1.5,
        2.5,
        4.8,
        10.0,
        24.0,
        79.0,
      ],
      "medium": [
        180.0,
        29.0,
        11.0,
        5.0,
        2.0,
        1.1,
        0.6,
        0.3,
        0.3,
        0.6,
        1.1,
        2.0,
        5.0,
        11.0,
        29.0,
        180.0,
      ],
      "high": [
        1000.0,
        130.0,
        37.0,
        11.0,
        4.0,
        1.5,
        1.0,
        0.5,
        0.5,
        1.0,
        1.5,
        4.0,
        11.0,
        37.0,
        130.0,
        1000.0,
      ],
    },
    16: {
      "low": [
        110.0,
        33.0,
        12.0,
        6.0,
        3.0,
        1.8,
        1.2,
        1.0,
        1.0,
        1.0,
        1.2,
        1.8,
        3.0,
        6.0,
        12.0,
        33.0,
        110.0,
      ],
      "medium": [
        260.0,
        43.0,
        15.0,
        6.0,
        3.0,
        1.5,
        1.0,
        0.5,
        0.3,
        0.5,
        1.0,
        1.5,
        3.0,
        6.0,
        15.0,
        43.0,
        260.0,
      ],
      "high": [
        1000.0,
        130.0,
        43.0,
        14.0,
        5.0,
        2.0,
        1.3,
        0.5,
        0.2,
        0.5,
        1.3,
        2.0,
        5.0,
        14.0,
        43.0,
        130.0,
        1000.0,
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(FetchPlinkoHistoryEvent());
    context.read<AppBloc>().add(FetchPlinkoSettingsEvent());

    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _betController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final double now = elapsed.inMicroseconds / 1000000.0;
    double dt = now - _lastTickTime;
    if (dt > 0.05) dt = 0.05; // Cap delta time during frame drops
    _lastTickTime = now;

    _updateGame(dt);
  }

  void _updateGame(double dt) {
    if (!mounted) return;

    bool needsRepaint = false;
    final double stepDuration = _isTurboMode ? 0.11 : 0.26;

    // 1. Update active balls using high-precision stopwatch time
    for (int i = _activeBalls.length - 1; i >= 0; i--) {
      final ball = _activeBalls[i];
      final double elapsed = ball.stopwatch.elapsedMicroseconds / 1000000.0;
      needsRepaint = true;

      final int step = (elapsed / stepDuration).floor();

      if (step != ball.currentStep) {
        if (step >= 1 && step <= _selectedRows + 1) {
          if (step < ball.pathPoints.length) {
            final Offset pegNormalized = ball.pathPoints[step];
            _activePegs[pegNormalized] = 1.0;

            final now = DateTime.now();
            if (_isSoundEnabled) {
              if (now.difference(_lastCollisionSoundTime).inMilliseconds >=
                  60) {
                SystemSound.play(SystemSoundType.click);
                _lastCollisionSoundTime = now;
              }
            }
            if (now.difference(_lastCollisionHapticTime).inMilliseconds >= 80) {
              HapticFeedback.lightImpact();
              _lastCollisionHapticTime = now;
            }
          }
        }
        ball.currentStep = step;
      }

      if (step >= ball.pathPoints.length - 1) {
        // Ball reached bucket
        _activeBuckets[ball.finalBucket] = 1.0;
        _spawnParticles(ball.finalBucket, ball.multiplier);
        _spawnFloatingWin(ball.finalBucket, ball.winAmount, ball.multiplier);
        HapticFeedback.mediumImpact();

        ball.stopwatch.stop();
        _activeBalls.removeAt(i);

        // Update balances in Bloc
        context.read<AppBloc>().add(LoadProfileEvent());
        context.read<AppBloc>().add(FetchPlinkoHistoryEvent());
      } else {
        // Interpolate position using stopwatch elapsed progress
        final double u = (elapsed % stepDuration) / stepDuration;
        final Offset pA = ball.pathPoints[step];
        final Offset pB = ball.pathPoints[step + 1];

        final double x = pA.dx + (pB.dx - pA.dx) * u;
        final double y = pA.dy + (pB.dy - pA.dy) * u - 0.018 * sin(u * pi);

        ball.position = Offset(x, y);
      }
    }

    // 2. Update Peg Collisions
    if (_activePegs.isNotEmpty) {
      _activePegs.updateAll((key, val) => val - dt * 4.0);
      _activePegs.removeWhere((key, val) => val <= 0.0);
      needsRepaint = true;
    }

    // 3. Update Bucket Collisions
    if (_activeBuckets.isNotEmpty) {
      _activeBuckets.updateAll((key, val) => val - dt * 3.0);
      _activeBuckets.removeWhere((key, val) => val <= 0.0);
      needsRepaint = true;
    }

    // 4. Update Particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.elapsed += dt;
      needsRepaint = true;

      p.position += p.velocity * dt;
      p.velocity = Offset(p.velocity.dx, p.velocity.dy + 1.2 * dt);
      p.opacity = (1.0 - p.elapsed / p.lifetime).clamp(0.0, 1.0);

      if (p.elapsed >= p.lifetime) {
        _particles.removeAt(i);
      }
    }

    // 5. Update Floating Win Toasts
    for (int i = _floatingWins.length - 1; i >= 0; i--) {
      final f = _floatingWins[i];
      f.elapsed += dt;
      needsRepaint = true;

      f.position = Offset(f.position.dx, f.position.dy - 0.08 * dt);
      f.opacity = (1.0 - f.elapsed / 1.5).clamp(0.0, 1.0);

      if (f.elapsed >= 1.5) {
        _floatingWins.removeAt(i);
      }
    }

    // 6. Update Auto Play Drop Timers
    if (_isAutoPlayActive) {
      _timeSinceLastAutoDrop += dt;
      final double interval = _isTurboMode ? 0.22 : _autoPlayIntervalSeconds;
      if (_timeSinceLastAutoDrop >= interval) {
        _timeSinceLastAutoDrop = 0.0;
        _executeAutoBet();
      }
    }

    if (needsRepaint) {
      setState(() {});
    }
  }

  void _spawnParticles(int bucketIndex, double multiplier) {
    if (multiplier < 1.1) return;

    final int count = multiplier >= 10.0 ? 25 : 12;
    final double spacingX = 0.7 / _selectedRows;
    final double bucketX = 0.5 + (bucketIndex - _selectedRows / 2.0) * spacingX;
    final double bucketY =
        0.08 + (_selectedRows + 1.2) * (0.75 / _selectedRows);

    final random = Random();
    final List<Color> colors = multiplier >= 10.0
        ? [
            const Color(0xFFFFD700),
            const Color(0xFFFF4500),
            const Color(0xFFFF00FF),
          ]
        : [const Color(0xFF00E676), const Color(0xFF00D2FF), Colors.white];

    for (int i = 0; i < count; i++) {
      final double angle = -pi / 6 - random.nextDouble() * (2 * pi / 3);
      final double speed = 0.12 + random.nextDouble() * 0.25;
      final double lifetime = 0.5 + random.nextDouble() * 0.5;

      _particles.add(
        PlinkoParticle(
          position: Offset(bucketX, bucketY),
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          color: colors[random.nextInt(colors.length)],
          size: 2.0 + random.nextDouble() * 2.5,
          lifetime: lifetime,
        ),
      );
    }
  }

  void _spawnFloatingWin(int bucketIndex, double amount, double multiplier) {
    final double spacingX = 0.7 / _selectedRows;
    final double bucketX = 0.5 + (bucketIndex - _selectedRows / 2.0) * spacingX;
    final double bucketY =
        0.08 + (_selectedRows + 1.2) * (0.75 / _selectedRows);

    _floatingWins.add(
      FloatingWinBubble(
        id:
            DateTime.now().microsecondsSinceEpoch.toString() +
            Random().nextInt(100).toString(),
        amount: amount,
        multiplier: multiplier,
        position: Offset(bucketX, bucketY - 0.05),
      ),
    );
  }

  void _triggerBallDrop(List<int> path, PlinkoPlayResultModel result) {
    final List<Offset> points = [];

    // Top central drop point
    points.add(const Offset(0.5, 0.03));

    int activePinIndex = 0;
    for (int i = 0; i <= _selectedRows; i++) {
      final double rowY = 0.08 + i * (0.75 / _selectedRows);
      final double rowX =
          0.5 + (activePinIndex - i / 2.0) * (0.7 / _selectedRows);
      points.add(Offset(rowX, rowY));

      if (i < path.length) {
        activePinIndex += path[i];
      }
    }

    // Landing bucket coordinate
    final double bucketY =
        0.08 + (_selectedRows + 1.2) * (0.75 / _selectedRows);
    final double bucketX =
        0.5 + (activePinIndex - _selectedRows / 2.0) * (0.7 / _selectedRows);
    points.add(Offset(bucketX, bucketY));

    setState(() {
      _nonce++;
      _activeBalls.add(
        ActiveBall(
          id:
              DateTime.now().microsecondsSinceEpoch.toString() +
              Random().nextInt(100).toString(),
          pathPoints: points,
          betAmount: result.betAmount,
          multiplier: result.multiplier,
          winAmount: result.winAmount,
          finalBucket: result.finalBucket,
        ),
      );
    });
  }

  void _executeManualBet() async {
    if (_isLocalLoading) return;

    final double betAmount = double.tryParse(_betController.text.trim()) ?? 0.0;
    if (betAmount < 1.0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Minimum bet size is ₹1.00.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      return;
    }

    final state = context.read<AppBloc>().state;
    final user = state.currentUser;
    final double totalBalance =
        (user?.depositBalance ?? 0.0) +
        (user?.winningBalance ?? 0.0) +
        (user?.bonusBalance ?? 0.0);

    if (totalBalance < betAmount) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance. Please add funds.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      return;
    }

    setState(() {
      _isLocalLoading = true;
    });

    try {
      final response = await getIt<ApiClient>().post(
        ApiConstants.plinkoPlay,
        data: {
          'bet_amount': betAmount,
          'rows': _selectedRows,
          'mode': _selectedRisk,
        },
      );

      final result = PlinkoPlayResultModel.fromJson(response.data);
      _triggerBallDrop(result.path, result);
    } catch (e, stackTrace) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.handle(e, stackTrace)),
            backgroundColor: AppTheme.accentRed,
          ),
        );
    } finally {
      setState(() {
        _isLocalLoading = false;
      });
    }
  }

  void _executeAutoBet() async {
    if (_isAutoPlayLoading) return;

    if (!_isInfiniteAutoPlay && _autoPlayRemainingBets <= 0) {
      _stopAutoPlay();
      return;
    }

    final double betAmount = double.tryParse(_betController.text.trim()) ?? 0.0;
    if (betAmount < 1.0) {
      _stopAutoPlay();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Minimum bet size is ₹1.00.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      return;
    }

    final state = context.read<AppBloc>().state;
    final user = state.currentUser;
    final double totalBalance =
        (user?.depositBalance ?? 0.0) +
        (user?.winningBalance ?? 0.0) +
        (user?.bonusBalance ?? 0.0);

    if (totalBalance < betAmount) {
      _stopAutoPlay();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance. Auto play stopped.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      return;
    }

    if (!_isInfiniteAutoPlay) {
      setState(() {
        _autoPlayRemainingBets--;
      });
    }

    _isAutoPlayLoading = true;

    try {
      final response = await getIt<ApiClient>().post(
        ApiConstants.plinkoPlay,
        data: {
          'bet_amount': betAmount,
          'rows': _selectedRows,
          'mode': _selectedRisk,
        },
      );

      final result = PlinkoPlayResultModel.fromJson(response.data);
      _triggerBallDrop(result.path, result);
    } catch (e) {
      _stopAutoPlay();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Auto Play error: ${e.toString()}'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
    } finally {
      _isAutoPlayLoading = false;
    }
  }

  void _startAutoPlay() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isAutoPlayActive = true;
      _timeSinceLastAutoDrop =
          _autoPlayIntervalSeconds; // trigger drop immediately
    });
  }

  void _stopAutoPlay() {
    setState(() {
      _isAutoPlayActive = false;
    });
  }

  void _showProvablyFairDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.security, color: Color(0xFF00E676)),
              const SizedBox(width: 8),
              Text(
                'Provably Fair Verification',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DailyEarn99 uses a cryptographically secure system. Each Plinko path is generated by hashing the seeds before the drop begins.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CLIENT SEED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: _clientSeed),
                  onChanged: (val) {
                    _clientSeed = val;
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SERVER SEED HASH (SHA-256)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Text(
                    _serverSeedHash,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NONCE (GAMES PLAYED)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '$_nonce',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D2FF),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppTheme.borderCol),
                const Text(
                  'Verify outcomes on SHA-512 validators using:\nHMAC_SHA512(server_seed, client_seed + "-" + nonce)',
                  style: TextStyle(
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final user = state.currentUser;
        final double totalUsable =
            (user?.depositBalance ?? 0.0) +
            (user?.winningBalance ?? 0.0) +
            (user?.bonusBalance ?? 0.0);
        final double betVal =
            double.tryParse(_betController.text.trim()) ?? 0.0;
        final bool hasSuffFunds = totalUsable >= betVal;

        final multipliers =
            _fallbackMultipliers[_selectedRows]?[_selectedRisk] ?? [];

        if (state.plinkoSettings?.maintenanceMode == true) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Plinko Originals',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppTheme.darkBg,
            ),
            body: Center(
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
                      'Plinko game is currently down for maintenance. Please check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Plinko Originals',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
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
              // Top wallet balance dashboard
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
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
                            const Text(
                              'WALLET BALANCE',
                              style: TextStyle(
                                fontSize: 8,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalUsable.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _subBal(
                              'Dep',
                              user?.depositBalance ?? 0.0,
                              AppTheme.accentCyan,
                            ),
                            const SizedBox(width: 8),
                            _subBal(
                              'Win',
                              user?.winningBalance ?? 0.0,
                              AppTheme.accentEmerald,
                            ),
                            const SizedBox(width: 8),
                            _subBal(
                              'Bon',
                              user?.bonusBalance ?? 0.0,
                              AppTheme.accentPurple,
                            ),
                          ],
                        ),
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
                    color: const Color(0xFF071B2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderCol, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Ticking game simulation canvas
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: PlinkoPyramidPainter(
                                rows: _selectedRows,
                                multipliers: multipliers,
                                activeBalls: _activeBalls,
                                activePegs: _activePegs,
                                activeBuckets: _activeBuckets,
                                particles: _particles,
                                floatingWins: _floatingWins,
                              ),
                            ),
                          ),
                        ),

                        // Float buttons top-right on Canvas
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            children: [
                              // Turbo Mode Toggle
                              _circleIconButton(
                                icon: Icons.flash_on,
                                color: _isTurboMode
                                    ? const Color(0xFFFFD700)
                                    : Colors.white24,
                                tooltip: 'Turbo Mode',
                                onPressed: () {
                                  setState(() {
                                    _isTurboMode = !_isTurboMode;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              // Sound Toggle
                              _circleIconButton(
                                icon: _isSoundEnabled
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                color: _isSoundEnabled
                                    ? const Color(0xFF00D2FF)
                                    : Colors.white24,
                                tooltip: 'Sound Effects',
                                onPressed: () {
                                  setState(() {
                                    _isSoundEnabled = !_isSoundEnabled;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom control board
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  border: const Border(
                    top: BorderSide(color: AppTheme.borderCol),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Manual / Auto play toggle
                      Row(
                        children: [
                          Expanded(
                            child: _tabButton('MANUAL', !_isAutoMode, () {
                              _stopAutoPlay();
                              setState(() => _isAutoMode = false);
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _tabButton('AUTO', _isAutoMode, () {
                              setState(() => _isAutoMode = true);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Rows count & Risk difficulty
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedRows,
                              decoration: const InputDecoration(
                                labelText: 'Rows Count',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                              dropdownColor: AppTheme.cardBg,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              items: List.generate(9, (index) => 8 + index)
                                  .map(
                                    (rows) => DropdownMenuItem<int>(
                                      value: rows,
                                      child: Text('$rows Rows'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isAutoPlayActive
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
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                              dropdownColor: AppTheme.cardBg,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              items: ['low', 'medium', 'high']
                                  .map(
                                    (risk) => DropdownMenuItem<String>(
                                      value: risk,
                                      child: Text(
                                        risk.substring(0, 1).toUpperCase() +
                                            risk.substring(1),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isAutoPlayActive
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedRisk = val;
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick chip selectors (double, half, values)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ...[10, 50, 100, 250].map((chip) {
                            final isSel = _selectedChip == chip;
                            final color = chip == 10
                                ? AppTheme.accentCyan
                                : (chip == 50
                                      ? AppTheme.accentPurple
                                      : (chip == 100
                                            ? AppTheme.accentEmerald
                                            : AppTheme.accentAmber));
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2.0,
                                ),
                                child: InkWell(
                                  onTap: _isAutoPlayActive
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            _selectedChip = chip.toDouble();
                                            _betController.text = chip
                                                .toString();
                                          });
                                        },
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? color.withOpacity(0.12)
                                          : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSel
                                            ? color
                                            : AppTheme.borderCol,
                                        width: isSel ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '₹$chip',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSel ? color : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          // Half / Double multipliers
                          _betAdjBtn('½', () {
                            final double val =
                                double.tryParse(_betController.text.trim()) ??
                                10.0;
                            final double newVal = max(1.0, val / 2);
                            _betController.text = newVal.toStringAsFixed(0);
                            setState(() => _selectedChip = newVal);
                          }),
                          _betAdjBtn('2x', () {
                            final double val =
                                double.tryParse(_betController.text.trim()) ??
                                10.0;
                            final double newVal = min(5000.0, val * 2);
                            _betController.text = newVal.toStringAsFixed(0);
                            setState(() => _selectedChip = newVal);
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Auto count selection panel (If Auto Mode active)
                      if (_isAutoMode) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Auto Bets Count: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            ...[10, 50, 100].map((bets) {
                              final isSel =
                                  _autoPlayRemainingBets == bets &&
                                  !_isInfiniteAutoPlay;
                              return ChoiceChip(
                                label: Text(
                                  '$bets',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: isSel,
                                onSelected: _isAutoPlayActive
                                    ? null
                                    : (sel) {
                                        if (sel) {
                                          setState(() {
                                            _autoPlayRemainingBets = bets;
                                            _isInfiniteAutoPlay = false;
                                          });
                                        }
                                      },
                              );
                            }),
                            ChoiceChip(
                              label: const Text(
                                '∞',
                                style: TextStyle(fontSize: 11),
                              ),
                              selected: _isInfiniteAutoPlay,
                              onSelected: _isAutoPlayActive
                                  ? null
                                  : (sel) {
                                      if (sel) {
                                        setState(() {
                                          _isInfiniteAutoPlay = true;
                                        });
                                      }
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Place Bet execution
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _betController,
                              keyboardType: TextInputType.number,
                              enabled: !_isAutoPlayActive,
                              onChanged: (val) {
                                setState(() {
                                  _selectedChip = double.tryParse(val) ?? 0.0;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'Bet amount',
                                prefixIcon: Icon(
                                  Icons.currency_rupee,
                                  size: 16,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: !hasSuffFunds && !_isAutoPlayActive
                                ? CustomButton(
                                    text: 'ADD FUNDS',
                                    type: CustomButtonType.primary,
                                    height: 44,
                                    onPressed: () {
                                      DepositBottomSheet.show(
                                        context,
                                        defaultAmount: betVal - totalUsable,
                                      );
                                    },
                                  )
                                : (_isAutoMode
                                      ? (_isAutoPlayActive
                                            ? CustomButton(
                                                text: _isInfiniteAutoPlay
                                                    ? 'STOP AUTO (∞)'
                                                    : 'STOP AUTO ($_autoPlayRemainingBets)',
                                                type: CustomButtonType.danger,
                                                height: 44,
                                                onPressed: _stopAutoPlay,
                                              )
                                            : CustomButton(
                                                text: 'START AUTO',
                                                type: CustomButtonType.primary,
                                                height: 44,
                                                onPressed: _startAutoPlay,
                                              ))
                                      : CustomButton(
                                          text: 'DROP BALL',
                                          type: CustomButtonType.primary,
                                          height: 44,
                                          isLoading: _isLocalLoading,
                                          onPressed: _isLocalLoading
                                              ? null
                                              : _executeManualBet,
                                        )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _tabButton(String text, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accentCyan.withOpacity(0.12)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.accentCyan : AppTheme.borderCol,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active ? AppTheme.accentCyan : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _betAdjBtn(String text, VoidCallback onTap) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: InkWell(
        onTap: _isAutoPlayActive ? null : onTap,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
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
            final history = state.plinkoHistory;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plinko Stakes History',
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
                  if (state.isPlinkoLoading && history.isEmpty)
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
                          'No Plinko stakes logged yet.',
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
                                  color: isWin
                                      ? AppTheme.accentEmerald.withOpacity(0.1)
                                      : AppTheme.accentRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isWin
                                      ? Icons.trending_up
                                      : Icons.trending_flat,
                                  color: isWin
                                      ? AppTheme.accentEmerald
                                      : AppTheme.accentAmber,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                'Multiplier: ${item.multiplier}x (${item.mode.toUpperCase()})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                '$dateStr • Bet: ₹${item.betAmount.toInt()} | ${item.rows} Rows',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              trailing: Text(
                                '₹${item.winAmount.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isWin
                                      ? AppTheme.accentEmerald
                                      : Colors.white,
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
}

class ActiveBall {
  final String id;
  final List<Offset> pathPoints;
  final double betAmount;
  final double multiplier;
  final double winAmount;
  final int finalBucket;
  final Stopwatch stopwatch = Stopwatch()..start();

  int currentStep = 0;
  Offset position = const Offset(0.5, 0.03);

  ActiveBall({
    required this.id,
    required this.pathPoints,
    required this.betAmount,
    required this.multiplier,
    required this.winAmount,
    required this.finalBucket,
  });
}

class PlinkoParticle {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final double lifetime;
  double elapsed = 0.0;
  double opacity = 1.0;

  PlinkoParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifetime,
  });
}

class FloatingWinBubble {
  final String id;
  final double amount;
  final double multiplier;
  Offset position;
  double elapsed = 0.0;
  double opacity = 1.0;

  FloatingWinBubble({
    required this.id,
    required this.amount,
    required this.multiplier,
    required this.position,
  });
}

class PlinkoPyramidPainter extends CustomPainter {
  final int rows;
  final List<double> multipliers;
  final List<ActiveBall> activeBalls;
  final Map<Offset, double> activePegs;
  final Map<int, double> activeBuckets;
  final List<PlinkoParticle> particles;
  final List<FloatingWinBubble> floatingWins;

  PlinkoPyramidPainter({
    required this.rows,
    required this.multipliers,
    required this.activeBalls,
    required this.activePegs,
    required this.activeBuckets,
    required this.particles,
    required this.floatingWins,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double spacingY = size.height * 0.75 / rows;
    final double spacingX = size.width * 0.7 / rows;

    // Draw grid background line design to make it feel premium
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw vertical center line
    canvas.drawLine(
      Offset(size.width * 0.5, 0.0),
      Offset(size.width * 0.5, size.height),
      gridPaint,
    );

    // 1. Draw Pegs (Pins) Pyramid
    final Paint normalPinPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    for (int r = 0; r <= rows; r++) {
      final double y = size.height * 0.08 + r * spacingY;
      for (int p = 0; p <= r; p++) {
        final double x = size.width * 0.5 + (p - r / 2.0) * spacingX;
        final Offset pegOffset = Offset(x / size.width, y / size.height);

        // Find if this peg is currently flashing
        double flashProgress = 0.0;
        for (final entry in activePegs.entries) {
          // Check proximity
          if ((entry.key.dx - pegOffset.dx).abs() < 0.001 &&
              (entry.key.dy - pegOffset.dy).abs() < 0.001) {
            flashProgress = entry.value;
            break;
          }
        }

        if (flashProgress > 0.0) {
          // Draw a neon glow behind peg
          final Paint glowPaint = Paint()
            ..color = const Color(0xFF00E676).withOpacity(0.3 * flashProgress)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawCircle(Offset(x, y), 8.5 + 4.0 * flashProgress, glowPaint);

          // Draw the flashing peg
          final Paint flashPinPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(x, y),
            3.5 + 1.5 * flashProgress,
            flashPinPaint,
          );
        } else {
          canvas.drawCircle(Offset(x, y), 3.5, normalPinPaint);
        }
      }
    }

    // 2. Draw landing buckets at the bottom
    final double bucketY = size.height * 0.08 + (rows + 1.2) * spacingY;
    final double bucketH = 26.0;
    final double bucketW = spacingX * 0.92;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int b = 0; b <= rows; b++) {
      final double bucketX = size.width * 0.5 + (b - rows / 2.0) * spacingX;

      // Color mapping: pink on edges, orange -> yellow -> green in middle
      Color bucketColor;
      final int mid = rows ~/ 2;
      final double distanceFactor = (b - mid).abs() / mid.toDouble();

      if (distanceFactor >= 0.8) {
        bucketColor = const Color(0xFFFF2D55); // Neon Red/Pink
      } else if (distanceFactor >= 0.5) {
        bucketColor = const Color(0xFFFF9500); // Neon Orange
      } else if (distanceFactor >= 0.2) {
        bucketColor = const Color(0xFFFFCC00); // Neon Gold/Yellow
      } else {
        bucketColor = const Color(0xFF34C759); // Neon Green
      }

      // Check if this bucket is expanding
      double scale = 1.0;
      if (activeBuckets.containsKey(b)) {
        final progress = activeBuckets[b]!;
        scale = 1.0 + 0.15 * sin(progress * pi); // pulse expansion
      }

      final Paint bucketPaint = Paint()
        ..color = bucketColor
        ..style = PaintingStyle.fill;

      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bucketX, bucketY),
          width: bucketW * scale,
          height: bucketH * scale,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, bucketPaint);

      // Draw a subtle border outline
      final Paint borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);

      // Multiplier Text inside bucket
      final String multText = multipliers.length > b
          ? multipliers[b].toStringAsFixed(1)
          : '1.0';
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

    // 3. Draw Drop Entry Guide Arrow
    final Paint guidePaint = Paint()
      ..color = const Color(0xFF00D2FF).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.5, 0.0),
      Offset(size.width * 0.5, size.height * 0.05),
      guidePaint,
    );

    // 4. Draw Particles
    for (final p in particles) {
      final Paint pPaint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.position.dx * size.width, p.position.dy * size.height),
        p.size,
        pPaint,
      );
    }

    // 5. Draw Falling Glowing Green Balls
    for (final ball in activeBalls) {
      final double px = ball.position.dx * size.width;
      final double py = ball.position.dy * size.height;

      // Glow outline
      final Paint glowPaint = Paint()
        ..color = const Color(0xFF00E676).withOpacity(0.35)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(px, py), 12.0, glowPaint);

      // Ball Core
      final Paint ballPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), 7.0, ballPaint);

      // Ball Inner Highlight
      final Paint lightPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px - 2.0, py - 2.0), 2.0, lightPaint);
    }

    // 6. Draw Floating Win Text (Bubbles)
    for (final f in floatingWins) {
      final double px = f.position.dx * size.width;
      final double py = f.position.dy * size.height;

      // Drop shadow for win text
      textPainter.text = TextSpan(
        text: '+₹${f.amount.toStringAsFixed(1)}',
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.black.withOpacity(f.opacity),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          px - textPainter.width / 2 + 1.0,
          py - textPainter.height / 2 + 1.0,
        ),
      );

      // Neon cyan/gold win text
      textPainter.text = TextSpan(
        text: '+₹${f.amount.toStringAsFixed(1)}',
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color:
              (f.multiplier >= 2.0
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF00D2FF))
                  .withOpacity(f.opacity),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(px - textPainter.width / 2, py - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlinkoPyramidPainter oldDelegate) {
    return true; // We repaint on ticker updates
  }
}
