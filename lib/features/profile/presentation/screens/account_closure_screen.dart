import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Self-service account closure: deactivate (reversible by logging back in)
/// or delete forever (anonymize, irreversible). Both require an OTP sent to
/// the account's own phone (see `AuthController.requestClosureOtp` /
/// `closeAccount`, added in Task 6).
class AccountClosureScreen extends StatefulWidget {
  const AccountClosureScreen({this.onClosed, super.key});

  /// Called after a successful deactivate/delete. The router delegate uses it
  /// to drop this page from its stack; when null (isolated tests) the screen
  /// pops back to the first route itself.
  final VoidCallback? onClosed;

  @override
  State<AccountClosureScreen> createState() => _AccountClosureScreenState();
}

enum _ClosureKind { deactivate, delete }

class _AccountClosureScreenState extends State<AccountClosureScreen> {
  _ClosureKind? _selected;
  String? _maskedPhone;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _selected == null ? null : _reset),
        title: const Text('Бүртгэл хаах'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _selected == null
                ? _OptionList(onSelected: _select)
                : _ClosureStep(
                    kind: _selected!,
                    maskedPhone: _maskedPhone,
                    codeController: _codeController,
                    isBusy: controller.isBusy,
                    errorMessage: controller.errorMessage,
                    onRequestOtp: () => _requestOtp(controller),
                    onConfirm: () => _confirm(controller),
                  ),
          ),
        ),
      ),
    );
  }

  void _select(_ClosureKind kind) {
    setState(() {
      _selected = kind;
      _maskedPhone = null;
      _codeController.clear();
    });
  }

  void _reset() {
    setState(() {
      _selected = null;
      _maskedPhone = null;
      _codeController.clear();
    });
  }

  Future<void> _requestOtp(AuthController controller) async {
    final masked = await controller.requestClosureOtp();
    if (!mounted || masked == null) return;
    setState(() => _maskedPhone = masked);
  }

  Future<void> _confirm(AuthController controller) async {
    final kind = _selected;
    if (kind == null) return;
    final code = _codeController.text.trim();
    if (kind == _ClosureKind.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Бүрмөсөн устгах уу?'),
          content: const Text(
            'Энэ үйлдлийг буцаах боломжгүй. Бүртгэл бүрмөсөн устана.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Үгүй'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Тийм, устгах'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final success = await controller.closeAccount(
      deleteForever: kind == _ClosureKind.delete,
      code: code,
    );
    // On failure controller.errorMessage is already set and the code stays
    // entered — nothing further to do here, the widget rebuilds via watch().
    if (success && mounted) {
      final onClosed = widget.onClosed;
      if (onClosed != null) {
        onClosed();
      } else {
        // Only reached when embedded without a router callback (tests).
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.onSelected});

  final ValueChanged<_ClosureKind> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _OptionCard(
        title: 'Идэвхгүй болгох',
        description: 'Бүртгэл нуугдаж, мэдэгдэл ирэхгүй. Хүссэн үедээ дахин нэвтэрч сэргээнэ.',
        destructive: false,
        onTap: () => onSelected(_ClosureKind.deactivate),
      ),
      const SizedBox(height: 12),
      _OptionCard(
        title: 'Бүрмөсөн устгах',
        description:
            'Нэр, утас, машин, мэдэгдэл устана. Үйлчилгээний түүх гаражид '
            'нэргүйгээр үлдэнэ. Энэ үйлдлийг буцаах боломжгүй.',
        destructive: true,
        onTap: () => onSelected(_ClosureKind.delete),
      ),
    ],
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.description,
    required this.destructive,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: destructive ? scheme.error : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ClosureStep extends StatelessWidget {
  const _ClosureStep({
    required this.kind,
    required this.maskedPhone,
    required this.codeController,
    required this.isBusy,
    required this.errorMessage,
    required this.onRequestOtp,
    required this.onConfirm,
  });

  final _ClosureKind kind;
  final String? maskedPhone;
  final TextEditingController codeController;
  final bool isBusy;
  final String? errorMessage;
  final Future<void> Function() onRequestOtp;
  final Future<void> Function() onConfirm;

  bool get _delete => kind == _ClosureKind.delete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _delete ? 'Бүрмөсөн устгах' : 'Идэвхгүй болгох',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: _delete ? scheme.error : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _delete
                ? 'Нэр, утас, машин, мэдэгдэл устана. Үйлчилгээний түүх '
                      'гаражид нэргүйгээр үлдэнэ. Энэ үйлдлийг буцаах '
                      'боломжгүй.'
                : 'Бүртгэл нуугдаж, мэдэгдэл ирэхгүй. Хүссэн үедээ дахин '
                      'нэвтэрч сэргээнэ.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // Код авах алхамд гарсан алдаа (429 throttle, сүлжээ г.м.) — доорх
          // код оруулах хэсэг хараахан харагдаагүй тул энд харуулна.
          if (maskedPhone == null && errorMessage != null) ...[
            Text(
              errorMessage!,
              key: const ValueKey('account_closure_request_error'),
              style: TextStyle(color: scheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (maskedPhone == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: _delete
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: isBusy ? null : onRequestOtp,
                child: isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Код авах'),
              ),
            )
          else ...[
            Text('$maskedPhone руу код илгээлээ'),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
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
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: _delete
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: isBusy ? null : onConfirm,
                child: isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_delete ? 'Устгах' : 'Идэвхгүй болгох'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
