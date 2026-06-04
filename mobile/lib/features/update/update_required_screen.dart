import 'package:flutter/material.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';

class UpdateRequiredScreen extends StatefulWidget {
  final String updateUrl;
  final String currentVersion;
  final String requiredVersion;
  final bool isMandatory;

  const UpdateRequiredScreen({
    super.key,
    required this.updateUrl,
    required this.currentVersion,
    required this.requiredVersion,
    required this.isMandatory,
  });

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isRedirecting = true;
    });

    // Simulate opening the store URL
    print(
      "Redirecting user to Play Store/App Store update URL: ${widget.updateUrl}",
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isRedirecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Navigating to update link:\n${widget.updateUrl}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.accentCyan,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isMandatory,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.darkBg, Color(0xFF0F1426)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing icon indicator
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: widget.isMandatory
                              ? [AppTheme.accentRed, AppTheme.accentPurple]
                              : [AppTheme.accentCyan, AppTheme.accentPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (widget.isMandatory
                                        ? AppTheme.accentRed
                                        : AppTheme.accentCyan)
                                    .withOpacity(0.35),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    widget.isMandatory ? 'UPDATE REQUIRED' : 'UPDATE AVAILABLE',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: widget.isMandatory
                          ? AppTheme.accentRed
                          : Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Description card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderCol),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.isMandatory
                              ? 'A critical update is required to continue playing on Dailyearn99. This version contains essential security modifications, brand new lobbies, and performance improvements.'
                              : 'A brand new version of Dailyearn99 is available! Enjoy exciting new real-money gaming features, improved game transitions, and wallet synchronization enhancements.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _versionInfo('Your Version', widget.currentVersion),
                            Container(
                              height: 24,
                              width: 1,
                              color: AppTheme.borderCol,
                            ),
                            _versionInfo('New Version', widget.requiredVersion),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Action CTA Button
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withOpacity(0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isRedirecting ? null : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isRedirecting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'UPDATE NOW',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cancel option (if not mandatory)
                  if (!widget.isMandatory)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'LATER',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _versionInfo(String label, String version) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v$version',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
