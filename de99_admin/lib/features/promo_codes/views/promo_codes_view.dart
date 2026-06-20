import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class PromoCode {
  final int id;
  final String code;
  final double bonusAmount;
  final String description;

  PromoCode({
    required this.id,
    required this.code,
    required this.bonusAmount,
    required this.description,
  });

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    return PromoCode(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      bonusAmount: (json['bonus_amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class PromoCodesView extends StatefulWidget {
  const PromoCodesView({super.key});

  @override
  State<PromoCodesView> createState() => _PromoCodesViewState();
}

class _PromoCodesViewState extends State<PromoCodesView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  bool _isLoading = false;
  String? _error;

  List<PromoCode> _codes = [];

  // Form parameters
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _bonusController = TextEditingController(text: '25');
  final _descController = TextEditingController();
  PromoCode? _editingCode;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bonusController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiClient.dio.get('/admin/promo-codes');
      setState(() {
        _codes = (res.data as List).map((x) => PromoCode.fromJson(x)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Failed to load Promo Codes';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _startEdit(PromoCode p) {
    setState(() {
      _editingCode = p;
      _codeController.text = p.code;
      _bonusController.text = p.bonusAmount.toString();
      _descController.text = p.description;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCode = null;
      _codeController.clear();
      _bonusController.text = '25';
      _descController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final codeStr = _codeController.text.trim().toUpperCase();
    final bonus = double.tryParse(_bonusController.text) ?? 25.0;
    final desc = _descController.text.trim();

    setState(() {
      _isLoading = true;
    });

    final payload = {
      'code': codeStr,
      'bonus_amount': bonus,
      'description': desc,
    };

    try {
      if (_editingCode != null) {
        // Edit mode
        await _apiClient.dio.put('/admin/promo-codes/${_editingCode!.id}', data: payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promo Referral Code updated successfully!'), backgroundColor: AdminTheme.success),
        );
      } else {
        // Create mode
        await _apiClient.dio.post('/admin/promo-codes', data: payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promo Referral Code created successfully!'), backgroundColor: AdminTheme.success),
        );
      }
      _cancelEdit();
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to save promo code'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCode(PromoCode p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete promo code "${p.code}"?'),
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
      await _apiClient.dio.delete('/admin/promo-codes/${p.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo Referral Code deleted successfully.'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to delete promo code'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _codes.isEmpty) {
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Form builder
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingCode != null ? 'Edit Promo Referral Code' : 'Create Promo Referral Code',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _codeController,
                                decoration: const InputDecoration(labelText: 'Promo Code name (e.g. WELCOME100)', prefixIcon: Icon(Icons.label)),
                                validator: (val) => val == null || val.isEmpty ? 'Code required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _bonusController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Bonus Coins (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                                validator: (val) => val == null || val.isEmpty ? 'Bonus required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(labelText: 'Description / Purpose of Code', prefixIcon: Icon(Icons.description)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_editingCode != null) ...[
                              TextButton(onPressed: _cancelEdit, child: const Text('CANCEL')),
                              const SizedBox(width: 12),
                            ],
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.primary,
                                foregroundColor: AdminTheme.background,
                              ),
                              onPressed: _submit,
                              child: Text(_editingCode != null ? 'SAVE CHANGES' : 'CREATE CODE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Configured Promo Referral codes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
              ),
              const SizedBox(height: 12),

              if (_codes.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No promo codes configured yet.', style: TextStyle(color: AdminTheme.textMuted)),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _codes.length,
                  itemBuilder: (context, index) {
                    final p = _codes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(p.code, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primary)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Bonus amount: ₹${p.bonusAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            if (p.description.isNotEmpty)
                              Text(p.description, style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AdminTheme.primary),
                              onPressed: () => _startEdit(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                              onPressed: () => _deleteCode(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
