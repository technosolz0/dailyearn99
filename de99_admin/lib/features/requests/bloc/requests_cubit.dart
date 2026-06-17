import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/features/users/bloc/users_cubit.dart'; // To reuse AdminUser

class PendingRequest {
  final int id;
  final int userId;
  final String userName;
  final String userPhone;
  final String type;
  final double amount;
  final String status;
  final String? utr;
  final String? description;
  final DateTime createdAt;

  final String? bankAccount;
  final String? bankIfsc;
  final String? bankHolder;
  final String? bankName;

  PendingRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.type,
    required this.amount,
    required this.status,
    this.utr,
    this.description,
    required this.createdAt,
    this.bankAccount,
    this.bankIfsc,
    this.bankHolder,
    this.bankName,
  });

  factory PendingRequest.fromTransactionAndUser(Map<String, dynamic> txJson, AdminUser? user) {
    return PendingRequest(
      id: txJson['id'] ?? 0,
      userId: txJson['user_id'] ?? 0,
      userName: user?.name ?? 'Anonymous User',
      userPhone: user?.phone ?? 'Unknown Phone',
      type: txJson['type'] ?? 'DEPOSIT',
      amount: (txJson['amount'] ?? 0).toDouble(),
      status: txJson['status'] ?? 'PENDING',
      utr: txJson['utr'],
      description: txJson['description'],
      createdAt: DateTime.parse(txJson['created_at'] ?? DateTime.now().toIsoformatString()),
      bankAccount: user?.bankAccountNumber,
      bankIfsc: user?.bankIfscCode,
      bankHolder: user?.bankAccountHolderName,
      bankName: user?.bankName,
    );
  }
}

extension on DateTime {
  String toIsoformatString() => toIso8601String();
}

abstract class RequestsState {}

class RequestsInitial extends RequestsState {}
class RequestsLoading extends RequestsState {}
class RequestsLoaded extends RequestsState {
  final List<PendingRequest> pendingDeposits;
  final List<PendingRequest> pendingWithdrawals;
  RequestsLoaded(this.pendingDeposits, this.pendingWithdrawals);
}
class RequestsError extends RequestsState {
  final String message;
  RequestsError(this.message);
}

class RequestsCubit extends Cubit<RequestsState> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  RequestsCubit() : super(RequestsInitial());

  Future<void> fetchRequests() async {
    emit(RequestsLoading());
    try {
      // 1. Fetch Users
      final usersResponse = await _apiClient.dio.get('/admin/users');
      final users = (usersResponse.data as List)
          .map((x) => AdminUser.fromJson(x))
          .toList();
      final userMap = {for (var u in users) u.id: u};

      // 2. Fetch Transactions
      final txResponse = await _apiClient.dio.get('/admin/transactions');
      final txList = txResponse.data as List;

      // 3. Map & Filter pending deposits/withdrawals
      final pendingDeposits = <PendingRequest>[];
      final pendingWithdrawals = <PendingRequest>[];

      for (var tx in txList) {
        final status = tx['status'] as String;
        final type = tx['type'] as String;
        if (status == 'PENDING') {
          final userId = tx['user_id'] as int;
          final user = userMap[userId];
          final req = PendingRequest.fromTransactionAndUser(tx, user);
          
          if (type == 'DEPOSIT') {
            pendingDeposits.add(req);
          } else if (type == 'WITHDRAWAL') {
            pendingWithdrawals.add(req);
          }
        }
      }

      // Sort by newest first
      pendingDeposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      pendingWithdrawals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      emit(RequestsLoaded(pendingDeposits, pendingWithdrawals));
    } on DioException catch (e) {
      String errMsg = 'Failed to load requests';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(RequestsError(errMsg));
    } catch (e) {
      emit(RequestsError(e.toString()));
    }
  }

  Future<void> approveDeposit(int txId, bool approve) async {
    try {
      await _apiClient.dio.post('/admin/deposits/$txId/approve?approve=$approve');
      await fetchRequests(); // Reload
    } on DioException catch (e) {
      String errMsg = 'Failed to process deposit approval';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(RequestsError(errMsg));
    } catch (e) {
      emit(RequestsError(e.toString()));
    }
  }

  Future<void> approveWithdrawal(int txId, bool approve) async {
    try {
      await _apiClient.dio.post('/admin/withdrawals/$txId/approve?approve=$approve');
      await fetchRequests(); // Reload
    } on DioException catch (e) {
      String errMsg = 'Failed to process withdrawal approval';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(RequestsError(errMsg));
    } catch (e) {
      emit(RequestsError(e.toString()));
    }
  }
}
