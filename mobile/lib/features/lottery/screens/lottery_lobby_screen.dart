import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';
import '../models/lottery_models.dart';
import '../repository/lottery_repository.dart';
import 'package:dailyearn99/core/utils/date_formatter.dart';

class LotteryLobbyScreen extends StatefulWidget {
  const LotteryLobbyScreen({super.key});

  @override
  State<LotteryLobbyScreen> createState() => _LotteryLobbyScreenState();
}

class _LotteryLobbyScreenState extends State<LotteryLobbyScreen>
    with SingleTickerProviderStateMixin {
  late final LotteryRepository _repository;
  late final TabController _tabController;
  Timer? _countdownTimer;

  List<LotteryDrawModel> _draws = [];
  List<LotteryTicketModel> _myTickets = [];
  bool _isLoadingDraws = false;
  bool _isLoadingTickets = false;
  String? _drawsError;
  String? _ticketsError;

  @override
  void initState() {
    super.initState();
    _repository = LotteryRepository(getIt<ApiClient>());
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);

    _refreshAll();

    // Start a periodic timer to update countdowns every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      _fetchDraws();
    } else if (_tabController.index == 1) {
      _fetchTickets();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchDraws(), _fetchTickets()]);
  }

  Future<void> _fetchDraws() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDraws = true;
      _drawsError = null;
    });
    try {
      final list = await _repository.fetchLotteryDraws();
      if (mounted) {
        setState(() {
          _draws = list;
          _isLoadingDraws = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _drawsError = e.toString().replaceAll('Exception: ', '');
          _isLoadingDraws = false;
        });
      }
    }
  }

  Future<void> _fetchTickets() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTickets = true;
      _ticketsError = null;
    });
    try {
      final list = await _repository.fetchMyTickets();
      if (mounted) {
        setState(() {
          _myTickets = list;
          _isLoadingTickets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ticketsError = e.toString().replaceAll('Exception: ', '');
          _isLoadingTickets = false;
        });
      }
    }
  }

  String _getCountdownText(DateTime targetTime) {
    final difference = targetTime.difference(DateTime.now());
    if (difference.isNegative) {
      return "Processing Draw...";
    }
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
      return "$days days, ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m";
    }
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0A1B),
      appBar: AppBar(
        title: const Text(
          '🎟️ LUCKY DRAW ARENA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 15,
          ),
        ),
        backgroundColor: const Color(0xFF140F2D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentCyan,
          labelColor: AppTheme.accentCyan,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'ACTIVE DRAWS'),
            Tab(text: 'MY TICKETS'),
            Tab(text: 'WINNERS HISTORY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveDrawsTab(),
          _buildMyTicketsTab(),
          _buildWinnersHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildActiveDrawsTab() {
    if (_isLoadingDraws && _draws.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }

    if (_drawsError != null) {
      return _buildErrorPlaceholder(_drawsError!, _fetchDraws);
    }

    final activeDraws = _draws.where((d) => d.status == 'OPEN').toList();

    if (activeDraws.isEmpty) {
      return const Center(
        child: Text(
          'No active lottery draws right now.\nCheck back later!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDraws,
      color: AppTheme.accentCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activeDraws.length,
        itemBuilder: (context, index) {
          return _buildDrawCard(activeDraws[index]);
        },
      ),
    );
  }

  Widget _buildDrawCard(LotteryDrawModel draw) {
    final remaining = draw.drawTime.difference(DateTime.now());
    final isDrawClosed = remaining.isNegative;
    final fillPercentage = draw.joinedTickets / draw.maxTickets;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF19143C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
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
                    draw.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Price: ₹${draw.ticketPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricBlock(
                  'PRIZE POOL',
                  '₹${draw.prizePool.toStringAsFixed(0)}',
                  AppTheme.accentEmerald,
                ),
                _buildMetricBlock(
                  'TICKETS SOLD',
                  '${draw.joinedTickets}/${draw.maxTickets}',
                  Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fillPercentage,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.accentCyan,
              ),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DRAW COUNTDOWN',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white38,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCountdownText(draw.drawTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDrawClosed
                            ? Colors.orangeAccent
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                CustomButton(
                  text: 'BUY TICKET',
                  onPressed: isDrawClosed ? null : () => _showBuySheet(draw),
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  height: 36,
                  borderRadius: 8,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBlock(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: Colors.white38,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showBuySheet(LotteryDrawModel draw) {
    final double userBalance =
        context.read<AppBloc>().state.currentUser?.totalBalance ?? 0.0;
    final bool canAfford = userBalance >= draw.ticketPrice;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F2D),
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
                  'Confirm Ticket Purchase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  draw.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ticket Price',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    Text(
                      '₹${draw.ticketPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Wallet Balance',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    Text(
                      '₹${userBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: canAfford
                            ? AppTheme.accentEmerald
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!canAfford) ...[
                  const Text(
                    'Insufficient balance. Please deposit funds first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: 'BUY NOW',
                        onPressed: !canAfford
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _buyTicketProcess(draw.id);
                              },
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.black,
                        height: 44,
                        borderRadius: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _buyTicketProcess(int drawId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      ),
    );

    try {
      final ticket = await _repository.buyTicket(drawId);
      if (mounted) {
        Navigator.pop(context); // Close loader spinner
        // Refresh balance in AppBloc
        context.read<AppBloc>().add(LoadProfileEvent());
        _fetchDraws();
        _fetchTickets();

        // Show Ticket success dialog
        _showTicketDialog(ticket);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader spinner
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    }
  }

  void _showTicketDialog(LotteryTicketModel ticket) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF140F2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.accentEmerald,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ticket Purchased!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.drawTitle ?? 'Daily Draw',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 20),

                // Digital Ticket Rendering Widget
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR UNIQUE TICKET NUMBER',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ticket.ticketNumber,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'DONE',
                  onPressed: () => Navigator.pop(ctx),
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  height: 40,
                  borderRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyTicketsTab() {
    if (_isLoadingTickets && _myTickets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }

    if (_ticketsError != null) {
      return _buildErrorPlaceholder(_ticketsError!, _fetchTickets);
    }

    if (_myTickets.isEmpty) {
      return const Center(
        child: Text(
          'You haven\'t purchased any tickets yet.\nJoin a draw to view your tickets here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTickets,
      color: AppTheme.accentCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, index) {
          final ticket = _myTickets[index];
          return _buildTicketLayoutCard(ticket);
        },
      ),
    );
  }

  Widget _buildTicketLayoutCard(LotteryTicketModel ticket) {
    final isDrawn = ticket.drawStatus == 'COMPLETED';
    final isWinner = ticket.isWinner;
    final isCancelled = ticket.drawStatus == 'CANCELLED';

    String ticketOutcome = 'WAITING FOR DRAW';
    Color outcomeColor = Colors.orangeAccent;
    if (isCancelled) {
      ticketOutcome = 'DRAW CANCELLED (REFUNDED)';
      outcomeColor = Colors.redAccent;
    } else if (isDrawn) {
      if (isWinner) {
        ticketOutcome = 'WINNER: ₹${ticket.rewardAmount.toStringAsFixed(0)}!';
        outcomeColor = AppTheme.accentEmerald;
      } else {
        ticketOutcome = 'BETTER LUCK NEXT TIME';
        outcomeColor = Colors.white38;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF19143C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Left ticket punch hole decoration
            Positioned(
              left: -8,
              top: 50,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D0A1B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Right ticket punch hole decoration
            Positioned(
              right: -8,
              top: 50,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D0A1B),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ticket.drawTitle ?? 'Lucky Draw',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Ticket #${ticket.id}',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TICKET NUMBER',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white38,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.ticketNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCyan,
                              letterSpacing: 1.0,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DRAW STATUS',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white38,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticketOutcome,
                            style: TextStyle(
                              fontSize: 11,
                              color: outcomeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnersHistoryTab() {
    final completedDraws = _draws
        .where((d) => d.status == 'COMPLETED')
        .toList();

    if (completedDraws.isEmpty) {
      return const Center(
        child: Text(
          'No winners declared yet.\nHistory will update after draws complete!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDraws,
      color: AppTheme.accentCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: completedDraws.length,
        itemBuilder: (context, index) {
          final draw = completedDraws[index];
          final formattedDate = formatContestDateTime(draw.drawTime);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: const Color(0xFF13102C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draw.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Draw finished: $formattedDate',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Prize Pool: ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '₹${draw.prizePool.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppTheme.accentEmerald,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'WINNING TICKET',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentCyan.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          draw.winningNumber ?? '-',
                          style: const TextStyle(
                            color: AppTheme.accentCyan,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorPlaceholder(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
