import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/features/app_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final user = state.currentUser;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            backgroundColor: AppTheme.darkBg,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.accentCyan.withOpacity(0.1),
                          child: const Icon(Icons.person, size: 40, color: AppTheme.accentCyan),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.phone ?? 'Anonymous Player',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Player ID: #${user?.id ?? "000"}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Details listing
                Card(
                  child: Column(
                    children: [
                      _profileTile(Icons.phone_iphone, 'Phone Number', user?.phone ?? '-'),
                      const Divider(color: AppTheme.borderCol, height: 1),
                      _profileTile(Icons.card_giftcard, 'My Referral Code', user?.referralCode ?? '-'),
                      const Divider(color: AppTheme.borderCol, height: 1),
                      _profileTile(
                        Icons.verified_user_outlined, 
                        'KYC Compliance Status', 
                        user?.kycStatus ?? 'PENDING',
                        trailingColor: user?.kycStatus == 'VERIFIED' ? AppTheme.accentEmerald : AppTheme.accentAmber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Anti-Cheat & Legal Policy Cards
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppTheme.accentCyan, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Anti-Cheat & Security Policy',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'We monitor device fingerprints, active VPNs, same-UPI wallets, and jailbreaks. Violating behavior will result in an immediate account ban and payout forfeiture.',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel_outlined, color: AppTheme.accentCyan, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Legal & Compliance Notice',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Real-money games are restricted for players residing in Assam, Odisha, Sikkim, Nagaland, Meghalaya, Andhra Pradesh, and Telangana. By playing on target99, you confirm that you are physically located in a permitted territory.',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Logout button
                ElevatedButton(
                  onPressed: () {
                    context.read<AppBloc>().add(LogoutEvent());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed.withOpacity(0.1),
                    foregroundColor: AppTheme.accentRed,
                    side: BorderSide(color: AppTheme.accentRed.withOpacity(0.3)),
                  ),
                  child: const Text('LOGOUT ACCOUNT'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileTile(IconData icon, String title, String val, {Color? trailingColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: trailingColor ?? Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
