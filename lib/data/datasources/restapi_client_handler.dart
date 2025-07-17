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
    _logDebug('Checking REST API credentials');
    
    final dio = Dio();
    final String basicAuth = 'Basic ${base64Encode(
        utf8.encode('${credentials.username}:${credentials.password}'))}';
    
    // Allow self-signed certificates for lab environments
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        _logDebug('Warning: Untrusted SSL certificate for $host:$port');
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
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      _logDebug('REST API connection successful - Response code: ${response.statusCode}');
    } on DioException catch (e) {
      _logDebug('REST API Error: ${e.type} - ${e.message}');
      if (e.response?.statusCode == 401) {
        throw const ServerFailure(
            'Authentication failed. Check your username and password.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const ServerFailure(
            'Connection timed out. Check the IP and ensure RESTCONF is enabled.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw const ServerFailure(
            'Connection error. Check the IP and network accessibility.');
      } else {
        throw ServerFailure(
            'RESTCONF Error: ${e.message ?? 'Unknown Dio error'}');
      }
    } catch (e) {
      _logDebug('Unknown REST API error: $e');
      throw ServerFailure('An unknown error occurred: ${e.toString()}');
    }
  }
}