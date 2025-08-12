// domain/usecases/check_credentials.dart
import 'package:load_balance/domain/entities/lb_device_credentials.dart';
import 'package:load_balance/domain/entities/router_interface.dart'; // این import را اضافه کنید
import 'package:load_balance/domain/repositories/router_repository.dart';

class CheckCredentials {
  final RouterRepository repository;

  CheckCredentials(this.repository);

  // ***تغییر اصلی***
  // نوع خروجی متد call آپدیت می‌شود
  Future<List<RouterInterface>> call(LBDeviceCredentials credentials) async {
    return await repository.checkCredentials(credentials);
  }
}