import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class PortfolioConfig {
  String contactEmail;
  String contactPhone;
  String contactAddress;
  String officeHours;
  String apkLink;
  String telegramLink;
  String instagramLink;
  String referralCode;
  String addAmountMethod; // 'UPI' or 'BANK' or 'NONE'
  String adminUpiId;
  String adminBankHolder;
  String adminBankName;
  String adminBankAccount;
  String adminBankIfsc;

  PortfolioConfig({
    required this.contactEmail,
    required this.contactPhone,
    required this.contactAddress,
    required this.officeHours,
    required this.apkLink,
    required this.telegramLink,
    required this.instagramLink,
    required this.referralCode,
    required this.addAmountMethod,
    required this.adminUpiId,
    required this.adminBankHolder,
    required this.adminBankName,
    required this.adminBankAccount,
    required this.adminBankIfsc,
  });

  factory PortfolioConfig.fromJson(Map<String, dynamic> json) {
    return PortfolioConfig(
      contactEmail: json['contact_email'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      contactAddress: json['contact_address'] ?? '',
      officeHours: json['office_hours'] ?? '',
      apkLink: json['apk_link'] ?? '',
      telegramLink: json['telegram_link'] ?? '',
      instagramLink: json['instagram_link'] ?? '',
      referralCode: json['referral_code'] ?? '',
      addAmountMethod: json['add_amount_method'] ?? 'UPI',
      adminUpiId: json['admin_upi_id'] ?? '',
      adminBankHolder: json['admin_bank_holder'] ?? '',
      adminBankName: json['admin_bank_name'] ?? '',
      adminBankAccount: json['admin_bank_account'] ?? '',
      adminBankIfsc: json['admin_bank_ifsc'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'contact_address': contactAddress,
        'office_hours': officeHours,
        'apk_link': apkLink,
        'telegram_link': telegramLink,
        'instagram_link': instagramLink,
        'referral_code': referralCode,
        'add_amount_method': addAmountMethod,
        'admin_upi_id': adminUpiId,
        'admin_bank_holder': adminBankHolder,
        'admin_bank_name': adminBankName,
        'admin_bank_account': adminBankAccount,
        'admin_bank_ifsc': adminBankIfsc,
      };
}

class ContactInquiry {
  final int id;
  final String name;
  final String email;
  final String subject;
  final String message;
  final DateTime createdAt;

  ContactInquiry({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.createdAt,
  });

  factory ContactInquiry.fromJson(Map<String, dynamic> json) {
    return ContactInquiry(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      subject: json['subject'] ?? '',
      message: json['message'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class PortfolioManagerView extends StatefulWidget {
  const PortfolioManagerView({super.key});

  @override
  State<PortfolioManagerView> createState() => _PortfolioManagerViewState();
}

class _PortfolioManagerViewState extends State<PortfolioManagerView> with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  late TabController _tabController;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  PortfolioConfig? _config;
  List<ContactInquiry> _inquiries = [];

  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  final _apkController = TextEditingController();
  final _tgController = TextEditingController();
  final _igController = TextEditingController();
  final _refController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccController = TextEditingController();
  final _bankIfscController = TextEditingController();

  String _addAmountMethod = 'UPI';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    _apkController.dispose();
    _tgController.dispose();
    _igController.dispose();
    _refController.dispose();
    _upiController.dispose();
    _bankHolderController.dispose();
    _bankNameController.dispose();
    _bankAccController.dispose();
    _bankIfscController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final configRes = await _apiClient.dio.get('/portfolio/config');
      final inquiriesRes = await _apiClient.dio.get('/admin/portfolio/contacts');

      final config = PortfolioConfig.fromJson(configRes.data);
      final inquiries = (inquiriesRes.data as List).map((x) => ContactInquiry.fromJson(x)).toList();

      setState(() {
        _config = config;
        _inquiries = inquiries;
        _isLoading = false;

        // Populate controllers
        _emailController.text = config.contactEmail;
        _phoneController.text = config.contactPhone;
        _addressController.text = config.contactAddress;
        _hoursController.text = config.officeHours;
        _apkController.text = config.apkLink;
        _tgController.text = config.telegramLink;
        _igController.text = config.instagramLink;
        _refController.text = config.referralCode;
        _upiController.text = config.adminUpiId;
        _bankHolderController.text = config.adminBankHolder;
        _bankNameController.text = config.adminBankName;
        _bankAccController.text = config.adminBankAccount;
        _bankIfscController.text = config.adminBankIfsc;
        _addAmountMethod = config.addAmountMethod;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Failed to load portfolio configurations';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final updated = PortfolioConfig(
      contactEmail: _emailController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactAddress: _addressController.text.trim(),
      officeHours: _hoursController.text.trim(),
      apkLink: _apkController.text.trim(),
      telegramLink: _tgController.text.trim(),
      instagramLink: _igController.text.trim(),
      referralCode: _refController.text.trim().toUpperCase(),
      addAmountMethod: _addAmountMethod,
      adminUpiId: _upiController.text.trim(),
      adminBankHolder: _bankHolderController.text.trim(),
      adminBankName: _bankNameController.text.trim(),
      adminBankAccount: _bankAccController.text.trim(),
      adminBankIfsc: _bankIfscController.text.trim().toUpperCase(),
    );

    try {
      await _apiClient.dio.put('/admin/portfolio/config', data: updated.toJson());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portfolio configurations saved successfully!'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
      setState(() {
        _isSaving = false;
      });
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to save config'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteInquiry(ContactInquiry q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete inquiry from "${q.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagContext, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(diagContext, true),
            child: const Text('DELETE', style: TextStyle(color: AdminTheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.delete('/admin/portfolio/contacts/${q.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inquiry ticket deleted.'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to delete inquiry'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Platform & Contact Info', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primary, fontSize: 14)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Contact Email', prefixIcon: Icon(Icons.email)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Contact Phone', prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Contact Office Address', prefixIcon: Icon(Icons.location_on)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Office Timings / Hours', prefixIcon: Icon(Icons.access_time)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apkController,
              decoration: const InputDecoration(labelText: 'Client Application APK Link', prefixIcon: Icon(Icons.android)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tgController,
                    decoration: const InputDecoration(labelText: 'Telegram Channel', prefixIcon: Icon(Icons.send)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _igController,
                    decoration: const InputDecoration(labelText: 'Instagram Handle', prefixIcon: Icon(Icons.camera_alt)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _refController,
              decoration: const InputDecoration(labelText: 'Default Referral Code', prefixIcon: Icon(Icons.card_giftcard)),
            ),
            const Divider(color: AdminTheme.borderColor, height: 32),
            
            const Text('Payment Deposit Config', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primary, fontSize: 14)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _addAmountMethod,
              decoration: const InputDecoration(labelText: 'Add Amount Instruction Gateway'),
              items: const [
                DropdownMenuItem(value: 'UPI', child: Text('UPI Address (Instant)')),
                DropdownMenuItem(value: 'BANK', child: Text('Manual Bank Transfer Details')),
                DropdownMenuItem(value: 'NONE', child: Text('Disable Payment Gateway Instructions')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _addAmountMethod = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            
            // Conditional UPI forms
            if (_addAmountMethod == 'UPI') ...[
              TextFormField(
                controller: _upiController,
                decoration: const InputDecoration(labelText: 'Admin UPI Address ID', hintText: 'e.g. merchant@upi'),
              ),
              const SizedBox(height: 12),
            ],

            // Conditional Bank forms
            if (_addAmountMethod == 'BANK') ...[
              TextFormField(
                controller: _bankHolderController,
                decoration: const InputDecoration(labelText: 'Account Holder Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bankAccController,
                      decoration: const InputDecoration(labelText: 'Bank Account Number'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _bankIfscController,
                      decoration: const InputDecoration(labelText: 'IFSC Code'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 16),
            if (_isSaving)
              const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  foregroundColor: AdminTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saveConfig,
                child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiriesTab() {
    if (_inquiries.isEmpty) {
      return const Center(child: Text('No inquiries received yet.', style: TextStyle(color: AdminTheme.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inquiries.length,
      itemBuilder: (context, index) {
        final q = _inquiries[index];
        final timeStr = DateFormat.yMMMd().add_jm().format(q.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.textMain)),
                          Text(q.email, style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                        ],
                      ),
                    ),
                    Text(timeStr, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                  ],
                ),
                const Divider(color: AdminTheme.borderColor, height: 20),
                Text('Subject: ${q.subject}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: Text(q.message, style: const TextStyle(fontSize: 12, color: AdminTheme.textMain)),
                ),
                const Divider(color: AdminTheme.borderColor, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                      onPressed: () => _deleteInquiry(q),
                    ),
                    const Spacer(),
                    // Emulates direct email action
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.primary,
                        foregroundColor: AdminTheme.background,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        // Normally launches email client, we show success callback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Replying to: ${q.email}')),
                        );
                      },
                      icon: const Icon(Icons.reply, size: 14),
                      label: const Text('REPLY EMAIL', style: TextStyle(fontSize: 11)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _config == null) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: AdminTheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: AdminTheme.surfaceDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AdminTheme.primary,
            labelColor: AdminTheme.primary,
            unselectedLabelColor: AdminTheme.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.settings), text: 'Portal settings'),
              Tab(icon: Icon(Icons.question_answer), text: 'User inquiries'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfigTab(),
          RefreshIndicator(
            onRefresh: _loadData,
            child: _buildInquiriesTab(),
          ),
        ],
      ),
    );
  }
}
