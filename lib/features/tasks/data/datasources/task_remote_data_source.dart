import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/task_model.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> getPendingTasks();
  Future<List<TaskModel>> getCompletedTasks();
  Future<TaskModel> getTaskDetails(String taskId);
  Future<TaskModel> updateTaskStatus(
    String taskId,
    String status, {
    String? completedDate,
  });
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final DioClient dioClient;

  TaskRemoteDataSourceImpl({required this.dioClient});

  Map<String, dynamic> _getBasePayload() {
    final now = DateTime.now();
    return {
      'toDayDate': DateFormat('yyyy-MM-dd').format(now),
      'currentTime': DateFormat('HH:mm:ss').format(now),
    };
  }

  @override
  Future<List<TaskModel>> getPendingTasks() async {
    final payload = _getBasePayload();
    final response = await dioClient.post(
      ApiEndpoints.taskList,
      data: payload,
    );

    return _parseTaskList(response.data);
  }

  @override
  Future<List<TaskModel>> getCompletedTasks() async {
    final payload = _getBasePayload();
    final response = await dioClient.post(
      ApiEndpoints.completedTaskList,
      data: payload,
    );

    return _parseTaskList(response.data);
  }

  @override
  Future<TaskModel> getTaskDetails(String taskId) async {
    final payload = _getBasePayload()..['taskId'] = taskId;
    final response = await dioClient.post(
      ApiEndpoints.taskDetails,
      data: payload,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return TaskModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      if (data['task'] is Map<String, dynamic>) {
        return TaskModel.fromJson(data['task'] as Map<String, dynamic>);
      }
      return TaskModel.fromJson(data);
    }
    return TaskModel(id: taskId, title: 'Task Details', description: '');
  }

  @override
  Future<TaskModel> updateTaskStatus(
    String taskId,
    String status, {
    String? completedDate,
  }) async {
    final payload = _getBasePayload()
      ..addAll({
        'taskId': taskId,
        'task_id': taskId,
        'status': status,
        if (completedDate != null && completedDate.isNotEmpty) ...{
          'completedDate': completedDate,
          'completed_date': completedDate,
        },
      });

    final response = await dioClient.post(
      ApiEndpoints.taskStatusUpdate,
      data: payload,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return TaskModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      if (data['task'] is Map<String, dynamic>) {
        return TaskModel.fromJson(data['task'] as Map<String, dynamic>);
      }
    }
    return TaskModel(
      id: taskId,
      title: '',
      description: '',
      status: status,
      completedDate: completedDate,
    );
  }

  List<TaskModel> _parseTaskList(dynamic responseData) {
    if (responseData == null) return [];

    List<dynamic> items = [];
    if (responseData is List) {
      items = responseData;
    } else if (responseData is Map<String, dynamic>) {
      if (responseData['data'] is List) {
        items = responseData['data'] as List;
      } else if (responseData['data'] is Map<String, dynamic>) {
        final dataMap = responseData['data'] as Map<String, dynamic>;
        if (dataMap['taskList'] is List) {
          items = dataMap['taskList'] as List;
        } else if (dataMap['tasks'] is List) {
          items = dataMap['tasks'] as List;
        } else if (dataMap['completedTaskList'] is List) {
          items = dataMap['completedTaskList'] as List;
        } else if (dataMap['completedTasks'] is List) {
          items = dataMap['completedTasks'] as List;
        } else if (dataMap['items'] is List) {
          items = dataMap['items'] as List;
        }
      } else if (responseData['tasks'] is List) {
        items = responseData['tasks'] as List;
      } else if (responseData['taskList'] is List) {
        items = responseData['taskList'] as List;
      } else if (responseData['completedTaskList'] is List) {
        items = responseData['completedTaskList'] as List;
      } else if (responseData['completedTasks'] is List) {
        items = responseData['completedTasks'] as List;
      } else if (responseData['items'] is List) {
        items = responseData['items'] as List;
      }
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => TaskModel.fromJson(json))
        .toList();
  }
}

final taskRemoteDataSourceProvider = Provider<TaskRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return TaskRemoteDataSourceImpl(dioClient: dioClient);
});
