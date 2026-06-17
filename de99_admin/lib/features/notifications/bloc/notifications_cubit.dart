import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';

abstract class NotificationsState {}

class NotificationsInitial extends NotificationsState {}
class NotificationsSending extends NotificationsState {}
class NotificationsSuccess extends NotificationsState {
  final String message;
  NotificationsSuccess(this.message);
}
class NotificationsError extends NotificationsState {
  final String message;
  NotificationsError(this.message);
}

class NotificationsCubit extends Cubit<NotificationsState> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  NotificationsCubit() : super(NotificationsInitial());

  Future<void> sendBroadcast({required String title, required String body}) async {
    emit(NotificationsSending());
    try {
      final response = await _apiClient.dio.post(
        '/admin/notifications/send-all',
        data: {
          'title': title,
          'body': body,
        },
      );
      emit(NotificationsSuccess(response.data['message'] ?? 'Broadcast sent successfully.'));
    } on DioException catch (e) {
      String errMsg = 'Failed to broadcast notification';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(NotificationsError(errMsg));
    } catch (e) {
      emit(NotificationsError(e.toString()));
    }
  }

  Future<void> sendDirect({required int userId, required String title, required String body}) async {
    emit(NotificationsSending());
    try {
      final response = await _apiClient.dio.post(
        '/admin/notifications/send-user',
        data: {
          'user_id': userId,
          'title': title,
          'body': body,
        },
      );
      emit(NotificationsSuccess(response.data['message'] ?? 'Notification sent successfully.'));
    } on DioException catch (e) {
      String errMsg = 'Failed to send notification';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(NotificationsError(errMsg));
    } catch (e) {
      emit(NotificationsError(e.toString()));
    }
  }

  void reset() {
    emit(NotificationsInitial());
  }
}
