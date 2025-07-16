// lib/data/datasources/restapi_client_handler.dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:load_balance/core/error/failure.dart';
import 'package:load_balance/domain/entities/device_credentials.dart';

class RestApiClientHandler {
  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[REST API] $message');
    }
  }

  Future<void> checkCredentials(DeviceCredentials credentials) async {
    _logDebug('بررسی اعتبار REST API');
    
    final dio = Dio();
    final String basicAuth = 'Basic ${base64Encode(
        utf8.encode('${credentials.username}:${credentials.password}'))}';
    
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        _logDebug('هشدار: گواهی SSL تایید نشده برای $host:$port');
        return true;
      };
      return client;
    };

    try {
      final response = await dio.get(
        'https://${credentials.ip}/restconf/data/Cisco-IOS-XE-native:native',
        options: Options(
          headers: {
            'Authorization': basicAuth,
            'Accept': 'application/yang-data+json'
          },
          receiveTimeout: Duration(seconds: 10),
          sendTimeout: Duration(seconds: 10),
        ),
      );
      
      _logDebug('REST API اتصال موفق - کد پاسخ: ${response.statusCode}');
    } on DioException catch (e) {
      _logDebug('خطا در REST API: ${e.type} - ${e.message}');
      
      if (e.response?.statusCode == 401) {
        throw const ServerFailure(
            'احراز هویت ناموفق. نام کاربری و رمز عبور را بررسی کنید.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const ServerFailure(
            'زمان اتصال به پایان رسید. IP را بررسی کنید و مطمئن شوید RESTCONF فعال است.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw const ServerFailure(
            'خطا در اتصال. IP و دسترسی شبکه را بررسی کنید.');
      } else {
        throw ServerFailure(
            'خطای RESTCONF: ${e.message ?? 'خطای ناشناخته Dio'}');
      }
    } catch (e) {
      _logDebug('خطای ناشناخته REST API: $e');
      throw ServerFailure('خطای ناشناخته: ${e.toString()}');
    }
  }
}
