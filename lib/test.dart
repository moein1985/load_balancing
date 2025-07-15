// import 'dart:convert';
// import 'package:dartssh2/dartssh2.dart';

// void main() async {
//   final socket = await SSHSocket.connect('192.168.85.91', 22);
//   final client = SSHClient(
//     socket,
//     username: 'cisco',
//     onPasswordRequest: () => 'cisco',
//   );
//   final result = await client.run('show ip interface brief');
//   print(utf8.decode(result));
//   client.close();
// }
