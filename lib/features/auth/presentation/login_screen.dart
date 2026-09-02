import 'dart:async';

import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Phone + OTP login, mirroring the web customer login page's copy and
/// step structure (static title/subtitle over a card whose form content
/// swaps between the phone step and the code step).
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.controller,
    required this.onAuthenticated,
    required this.onBack,
    super.key,
  });

  final AuthController controller;
  final VoidCallback onAuthenticated;
  final VoidCallback onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _resendCooldownSeconds = 60;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const CarCareBrand(compact: true),
      centerTitle: false,
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) => GlassSurface(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Нэвтрэх / Бүртгүүлэх',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.controller.step == AuthStep.phone
                            ? 'Утасны дугаараа оруулаад, ирэх 6 оронтой кодоор нэвтэрнэ.'
                            : '${widget.controller.phone} дугаарт ирсэн 6 оронтой кодоо оруулна уу.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.controller.step == AuthStep.phone)
                        TextField(
                          key: const ValueKey('login-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Утасны дугаар',
                            prefixText: '+976 ',
                            hintText: '99112233',
                          ),
                        )
                      else
                        TextField(
                          key: const ValueKey('login-otp'),
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: const TextStyle(
                            fontSize: 20,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Баталгаажуулах код',
                            hintText: '000000',
                          ),
                        ),
                      if (widget.controller.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.controller.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.controller.isBusy ? null : _submit,
                          child: widget.controller.isBusy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.controller.step == AuthStep.phone
                                      ? 'Код авах →'
                                      : 'Нэвтрэх →',
                                ),
                        ),
                      ),
                      if (widget.controller.step == AuthStep.otp) ...[
                        Center(
                          child: TextButton(
                            onPressed:
                                widget.controller.isBusy ||
                                    _resendSecondsRemaining > 0
                                ? null
                                : _resendOtp,
                            child: Text(_resendButtonLabel),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: widget.controller.isBusy
                                ? null
                                : _editPhone,
                            child: const Text('← Өөр дугаар оруулах'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final success = widget.controller.step == AuthStep.phone
        ? await widget.controller.requestOtp(_phoneController.text)
        : await widget.controller.verifyOtp(_codeController.text);
    if (success &&
        widget.controller.step == AuthStep.otp &&
        !widget.controller.isAuthenticated &&
        mounted) {
      _startResendCooldown();
    }
    if (success && widget.controller.isAuthenticated && mounted) {
      widget.onAuthenticated();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSecondsRemaining > 0 || widget.controller.isBusy) return;
    final success = await widget.controller.requestOtp(widget.controller.phone);
    if (success && mounted) _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSecondsRemaining--;
        if (_resendSecondsRemaining <= 0) {
          _resendSecondsRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  void _editPhone() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 0);
    widget.controller.editPhone();
  }

  String get _resendButtonLabel {
    if (_resendSecondsRemaining <= 0) return 'Код дахин авах';
    final minutes = _resendSecondsRemaining ~/ 60;
    final seconds = (_resendSecondsRemaining % 60).toString().padLeft(2, '0');
    return 'Код дахин авах ($minutes:$seconds)';
  }
}
