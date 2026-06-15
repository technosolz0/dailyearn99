import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dailyearn99/core/network/remote_config_service.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(FetchReferralDetailsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final details = state.referralDetails;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Refer & Earn'),
            backgroundColor: AppTheme.darkBg,
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<AppBloc>().add(FetchReferralDetailsEvent());
            },
            color: AppTheme.accentCyan,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            size: 56,
                            color: AppTheme.accentPurple,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Invite Friends, Earn Cash!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Earn ₹50 Bonus Wallet Cash when your friend registers and plays their first contest. Your friend gets ₹20 too!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Referral code wrapper
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderCol),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'YOUR REFERRAL CODE',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      details?.referralCode ?? 'DE99XXXXX',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: AppTheme.accentCyan,
                                  ),
                                  onPressed: () {
                                    if (details != null) {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: details.referralCode,
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                        ..clearSnackBars()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Referral code copied to clipboard!',
                                            ),
                                            backgroundColor:
                                                AppTheme.accentCyan,
                                          ),
                                        );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: details == null
                                ? null
                                : () {
                                    final link = kIsWeb
                                        ? Uri.base.origin
                                        : getIt<RemoteConfigService>().updateUrl;
                                    final shareText =
                                        "Hey! Join me on DailyEarn99, play exciting games, and earn real cash! 🎮💰\n\n"
                                        "Use my Referral Code: ${details.referralCode} to get a ₹20 sign-up bonus instantly!\n\n"
                                        "${kIsWeb ? 'Join on Web now' : 'Download the App now'}: $link";
                                    Share.share(shareText);
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: details == null
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          AppTheme.accentCyan,
                                          AppTheme.accentPurple,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: details == null
                                    ? Colors.white.withOpacity(0.05)
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: details == null
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppTheme.accentCyan
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.share,
                                    color: details == null
                                        ? AppTheme.textMuted
                                        : Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SHARE CODE & INVITE',
                                    style: TextStyle(
                                      color: details == null
                                          ? AppTheme.textMuted
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Analytics Row
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'TOTAL INVITES',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${details?.referralCount ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'TOTAL EARNED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${details?.bonusEarned.toStringAsFixed(0) ?? 0}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentEmerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Invites log header
                  const Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: AppTheme.accentCyan,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'SUCCESSFUL REFERRALS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Referral history items list
                  if (state.isReferralLoading &&
                      (details == null || details.referrals.isEmpty))
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    )
                  else if (details == null || details.referrals.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No referrals recorded yet.\nShare your code to start earning!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: details.referrals.length,
                      itemBuilder: (context, index) {
                        final item = details.referrals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.cardBg,
                              child: Icon(
                                Icons.person,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            title: Text(
                              item.referredUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Referred on ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: item.bonusGiven
                                    ? AppTheme.accentEmerald.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: item.bonusGiven
                                      ? AppTheme.accentEmerald.withOpacity(0.3)
                                      : AppTheme.borderCol,
                                ),
                              ),
                              child: Text(
                                item.bonusGiven
                                    ? 'Earned +₹50'
                                    : 'Pending play',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.bonusGiven
                                      ? AppTheme.accentEmerald
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
