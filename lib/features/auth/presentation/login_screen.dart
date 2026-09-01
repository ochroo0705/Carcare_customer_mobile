import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Нэвтрэх'),
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.controller.step == AuthStep.phone
                    ? 'Утасны дугаараа оруулна уу'
                    : '${widget.controller.phone} дугаарт ирсэн код',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Зөвхөн цаг захиалахад нэвтрэх шаардлагатай.',
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
                  ),
                )
              else
                TextField(
                  key: const ValueKey('login-otp'),
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: '6 оронтой код'),
                ),
              if (widget.controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.controller.isBusy ? null : _submit,
                child: widget.controller.isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.controller.step == AuthStep.phone
                            ? 'Код авах'
                            : 'Баталгаажуулах',
                      ),
              ),
              if (widget.controller.step == AuthStep.otp)
                TextButton(
                  onPressed: widget.controller.editPhone,
                  child: const Text('Дугаар солих'),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final success = widget.controller.step == AuthStep.phone
        ? await widget.controller.requestOtp(_phoneController.text)
        : await widget.controller.verifyOtp(_codeController.text);
    if (success && widget.controller.isAuthenticated && mounted) {
      widget.onAuthenticated();
    }
  }
}
