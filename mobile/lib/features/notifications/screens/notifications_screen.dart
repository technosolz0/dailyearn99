import 'package:flutter/material.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/notifications/models/notification_model.dart';
import 'package:dailyearn99/features/image_puzzle/screens/puzzle_lobby_screen.dart';
import 'package:dailyearn99/features/word_puzzle/screens/word_lobby_screen.dart';
import 'package:dailyearn99/features/fruit_slicing/screens/fruit_lobby_screen.dart';
import 'package:dailyearn99/features/go_arrows/screens/arrow_lobby_screen.dart';
import 'package:dailyearn99/features/wallet/wallet_screen.dart';
import 'package:dailyearn99/features/spin/spin_wheel_screen.dart';
import 'package:dailyearn99/features/referral/referral_screen.dart';
import 'package:dailyearn99/features/profile/profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _apiClient = getIt<ApiClient>();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _notifications = data
              .map((json) => NotificationModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load notifications.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        String msg = e.toString();
        if (msg.startsWith("Exception: ")) {
          msg = msg.substring("Exception: ".length);
        }
        _error = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      final response = await _apiClient.post(
        '/notifications/$notificationId/read',
      );
      if (response.statusCode == 200) {
        setState(() {
          _notifications = _notifications.map((n) {
            if (n.id == notificationId) {
              return n.copyWith(isRead: true);
            }
            return n;
          }).toList();
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Widget? _getRedirectScreen(NotificationModel notification) {
    final data = notification.data;
    final title = notification.title.toLowerCase();
    final body = notification.body.toLowerCase();

    // 1. Check data payload fields if present
    if (data != null) {
      final category = data['category']?.toString().toUpperCase();

      if (category == 'PUZZLE') {
        return const PuzzleLobbyScreen();
      } else if (category == 'WORD') {
        return const WordLobbyScreen();
      } else if (category == 'FRUIT') {
        return const FruitLobbyScreen();
      } else if (category == 'ARROW') {
        return const ArrowLobbyScreen();
      }
    }

    // 2. Check title and body text for keywords as a robust fallback
    if (title.contains('puzzle') || body.contains('puzzle')) {
      return const PuzzleLobbyScreen();
    } else if (title.contains('word') || body.contains('word') || title.contains('guess') || body.contains('guess')) {
      return const WordLobbyScreen();
    } else if (title.contains('fruit') || body.contains('fruit') || title.contains('slice') || body.contains('slice')) {
      return const FruitLobbyScreen();
    } else if (title.contains('arrow') || body.contains('arrow')) {
      return const ArrowLobbyScreen();
    } else if (title.contains('wallet') ||
        title.contains('deposit') ||
        title.contains('withdrawal') ||
        title.contains('prize') ||
        title.contains('credited') ||
        body.contains('wallet') ||
        body.contains('deposit') ||
        body.contains('withdrawal') ||
        body.contains('credited') ||
        body.contains('prize')) {
      return const WalletScreen();
    } else if (title.contains('spin') || body.contains('spin') || title.contains('jackpot') || body.contains('jackpot')) {
      return const SpinWheelScreen();
    } else if (title.contains('referral') || body.contains('referral') || title.contains('friend') || body.contains('friend') || title.contains('welcome') || body.contains('welcome')) {
      return const ReferralScreen();
    } else if (title.contains('profile') || body.contains('profile') || title.contains('kyc') || body.contains('kyc')) {
      return const ProfileScreen();
    }

    return null;
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    final targetScreen = _getRedirectScreen(notification);
    if (targetScreen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      ).then((_) {
        // Refresh notifications list when returning
        if (mounted) {
          _fetchNotifications();
        }
      });
    } else if (notification.title.toLowerCase().contains('contest') ||
        notification.body.toLowerCase().contains('contest') ||
        notification.title.toLowerCase().contains('lobby') ||
        notification.body.toLowerCase().contains('lobby')) {
      // General contest or lobbies, pop back to home
      Navigator.pop(context);
    } else {
      // Show detail dialog (already marked as read)
      _showNotificationDetail(notification);
    }
  }

  void _showNotificationDetail(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.borderCol, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: AppTheme.accentCyan,
                      size: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(notification.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.borderCol, height: 1),
                const SizedBox(height: 16),
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMain,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('DISMISS'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${localDt.day}/${localDt.month}/${localDt.year} ${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchNotifications,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.accentRed,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchNotifications,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardBg,
                  border: Border.all(color: AppTheme.borderCol, width: 1),
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Notifications Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'ll notify you here when contests start, rewards are paid, or deposits are processed.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: AppTheme.accentCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () => _handleNotificationTap(notification),
              borderRadius: BorderRadius.circular(16),
              child: Card(
                color: notification.isRead
                    ? AppTheme.cardBg.withOpacity(0.6)
                    : AppTheme.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: notification.isRead
                        ? AppTheme.borderCol
                        : AppTheme.accentCyan.withOpacity(0.3),
                    width: notification.isRead ? 1 : 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Dot / Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: notification.isRead
                              ? Colors.white.withOpacity(0.03)
                              : AppTheme.accentCyan.withOpacity(0.1),
                        ),
                        child: Icon(
                          notification.isRead
                              ? Icons.notifications_none_outlined
                              : Icons.notifications_active_outlined,
                          size: 18,
                          color: notification.isRead
                              ? AppTheme.textMuted
                              : AppTheme.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text Contents
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: notification.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      color: notification.isRead
                                          ? AppTheme.textMuted
                                          : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notification.body,
                              style: TextStyle(
                                fontSize: 12,
                                color: notification.isRead
                                    ? AppTheme.textMuted.withOpacity(0.8)
                                    : AppTheme.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _formatDate(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
