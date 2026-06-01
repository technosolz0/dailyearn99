import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';

class TermsDialog extends StatelessWidget {
  const TermsDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TermsDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
          decoration: BoxDecoration(
            color: AppTheme.cardBg.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.accentCyan.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentCyan.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Dialog Header ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentCyan.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: AppTheme.accentCyan,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Terms & Conditions',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'User Agreement & Disclaimers',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Content ────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Starting Benefits
                        _buildSectionHeader(
                          '1. Welcome & Membership Benefits',
                          Icons.star_border_rounded,
                        ),
                        _buildBenefitItem(
                          'Play & Earn Real Cash',
                          'Test your mental agility and puzzles skills to win exciting cash rewards directly deposited to your wallet.',
                          Icons.currency_rupee_rounded,
                        ),
                        _buildBenefitItem(
                          'Lightning-Fast Secure Withdrawals',
                          'Direct bank or UPI cash outs with secure encrypted payment systems.',
                          Icons.bolt_rounded,
                        ),
                        _buildBenefitItem(
                          'Certified Fair & Anti-Cheat Play',
                          '100% fair matches. No bots, no hacks. Only true skill-based real player contests.',
                          Icons.verified_user_rounded,
                        ),

                        const SizedBox(height: 24),

                        // Section 2: Restrictions & Underage (Middle)
                        _buildSectionHeader(
                          '2. Key Restrictions',
                          Icons.warning_amber_rounded,
                        ),
                        _buildWarningItem(
                          'Strictly 18+ Years Age Limit',
                          'You must be 18 years of age or older to play real cash tournaments. Minors are strictly prohibited from participating.',
                          Icons.eighteen_up_rating_rounded,
                        ),
                        _buildWarningItem(
                          'Geographical Restrictions',
                          'Residents of Assam, Odisha, Sikkim, and Nagaland are strictly prohibited from participating in real cash contests due to state laws.',
                          Icons.location_off_rounded,
                        ),

                        const SizedBox(height: 24),

                        // Section 3: Waiver & Agreement (Legal Actions Barred)
                        _buildSectionHeader(
                          '3. Absolute Legal Waiver',
                          Icons.gavel_rounded,
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accentRed.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    color: AppTheme.accentRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'NO LEGAL ACTION ALLOWED',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accentRed,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'By accepting these terms, you unconditionally agree that you shall NOT, under any circumstances, initiate, join, support or participate in any lawsuit, class-action lawsuit, arbitration, or legal claims against this application, its developer, or parent operator in any jurisdiction. All gameplay is provided "as is", and you accept all outcomes, risks, and possible financial losses associated with playing.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section 4: Final Consent & Benefits (End)
                        _buildSectionHeader(
                          '4. Safe & Audited Play Benefits',
                          Icons.check_circle_outline_rounded,
                        ),
                        _buildBenefitItem(
                          'Responsible Gaming Features',
                          'Control your game limits and play within your means. We support clean, ethical, and safe gaming.',
                          Icons.health_and_safety_rounded,
                        ),
                        _buildBenefitItem(
                          '24/7 Dedicated Support',
                          'Fast resolutions for wallet transactions, matches, or account security queries.',
                          Icons.support_agent_rounded,
                        ),

                        const SizedBox(height: 16),
                        Divider(color: Colors.white.withOpacity(0.06)),
                        const SizedBox(height: 12),

                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              height: 1.5,
                            ),
                            children: const [
                              TextSpan(text: 'By clicking '),
                              TextSpan(
                                text: 'Agree & Accept',
                                style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ', you legally acknowledge that you have read, understood, and bound yourself to all terms, age/state restrictions, and the absolute waiver of legal actions.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Footer Buttons ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'DECLINE',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomButton(
                          text: 'AGREE & ACCEPT',
                          height: 46,
                          borderRadius: 12,
                          onPressed: () => Navigator.pop(context, true),
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
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accentCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentCyan,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentEmerald.withOpacity(0.1),
            ),
            child: Icon(icon, color: AppTheme.accentEmerald, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentAmber.withOpacity(0.1),
            ),
            child: Icon(icon, color: AppTheme.accentAmber, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
