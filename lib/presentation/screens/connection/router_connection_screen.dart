// presentation/screens/connection/router_connection_screen.dart
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:load_balance/presentation/bloc/router_connection/router_connection_bloc.dart';
import 'package:load_balance/presentation/bloc/router_connection/router_connection_event.dart';
import 'package:load_balance/presentation/bloc/router_connection/router_connection_state.dart';

enum ConnectionType { ssh, telnet }

class RouterConnectionScreen extends StatefulWidget {
  const RouterConnectionScreen({super.key});
  @override
  State<RouterConnectionScreen> createState() => _RouterConnectionScreenState();
}

class _RouterConnectionScreenState extends State<RouterConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _enablePasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isEnablePasswordVisible = false;
  ConnectionType _selectedType = ConnectionType.ssh;

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _enablePasswordController.dispose();
    super.dispose();
  }

  void _checkCredentials() {
    if (_formKey.currentState!.validate()) {
      context.read<RouterConnectionBloc>().add(
            CheckCredentialsRequested(
              ip: _ipController.text,
              username: _usernameController.text,
              password: _passwordController.text,
              enablePassword: _enablePasswordController.text,
              type: _selectedType,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Router Connection'),
      ),
      body: BlocListener<RouterConnectionBloc, RouterConnectionState>(
        listener: (context, state) {
          if (state is ConnectionSuccess) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Connection Successful!'),
                  backgroundColor: Colors.green,
                ),
              );

            // ***تغییر اصلی***
            // به جای ارسال یک آبجکت، یک Map شامل تمام داده‌های لازم را ارسال می‌کنیم
            context.go('/config', extra: {
              'credentials': state.credentials,
              'interfaces': state.interfaces,
            });

          } else if (state is ConnectionFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.error}'),
                  backgroundColor: Colors.red,
                ),
              );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter Router Credentials',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      prefixIcon: Icon(Icons.router),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an IP address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _enablePasswordController,
                    obscureText: !_isEnablePasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Enable Password (optional)',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_isEnablePasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() =>
                            _isEnablePasswordVisible =
                                !_isEnablePasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<ConnectionType>(
                    segments: const <ButtonSegment<ConnectionType>>[
                      ButtonSegment<ConnectionType>(
                          value: ConnectionType.ssh,
                          label: Text('SSHv2'),
                          icon: Icon(Icons.security)),
                      ButtonSegment<ConnectionType>(
                          value: ConnectionType.telnet,
                          label: Text('Telnet'),
                          icon: Icon(Icons.lan)),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<ConnectionType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<RouterConnectionBloc, RouterConnectionState>(
                    builder: (context, state) {
                      if (state is ConnectionLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Check Credentials'),
                        onPressed: _checkCredentials,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}