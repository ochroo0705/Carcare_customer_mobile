import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/booking_form_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_calendar.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_form_sections.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_header.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_locked_notices.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_vehicle_picker.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    required this.organization,
    this.initialBranchId,
    required this.repository,
    required this.onAddVehicle,
    required this.onBack,
    required this.onCompleted,
    required this.onUnauthenticated,
    this.initialCategoryIds,
    this.lockCategories = false,
    this.lockBranch = false,
    super.key,
  });

  final OrganizationDetail organization;
  final String? initialBranchId;
  final AppointmentRepository repository;
  final VoidCallback onAddVehicle;
  final VoidCallback onBack;
  final ValueChanged<CreatedAppointment> onCompleted;
  final VoidCallback onUnauthenticated;

  /// Cross-org "юу хийлгэх гэж байна?" пикерээс (Booking tab) аль хэдийн
  /// сонгогдсон ангилалуудын id — зөвхөн [lockCategories] үнэн үед хэрэглэгдэнэ.
  final List<String>? initialCategoryIds;

  /// Ангилалыг Booking tab-ийн пикер дээр аль хэдийн сонгосон тул энд дахин
  /// сонгуулахгүй (зөвхөн товч тоймоор харуулна), мөн [initialBranchId]-аас
  /// өөр салбар руу сольж болохгүй (тухайн салбар л сонгосон бүх ажлыг санал
  /// болгодог гэдгийг үр дүнгийн жагсаалт дээр аль хэдийн баталгаажуулсан).
  final bool lockCategories;

  /// Discover-ийн салбарын дэлгэрэнгүйгээс тодорхой салбар сонгож ирсэн бол
  /// (харах: [initialBranchId]) байгууллага/салбарын сонголтыг ТҮГЖИНЭ —
  /// хэрэглэгч зөвхөн ангилал, огноо/цагаа сонгоно. [lockCategories]-ийн
  /// эсрэг тэнхлэг: тэнд ангилал түгжигдэж салбар (тохирох хүрээнд) чөлөөтэй,
  /// энд салбар түгжигдэж ангилал чөлөөтэй. Хоёул `false`-той адилтгах
  /// боломжгүй (харилцан үл шүтэлцээтэй урсгалууд).
  final bool lockBranch;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen>
    with WidgetsBindingObserver {
  final _noteController = TextEditingController();
  late final BookingFormController _form;

  @override
  void initState() {
    super.initState();
    _form = BookingFormController(
      organization: widget.organization,
      repository: widget.repository,
      vehiclesController: context.read<VehiclesController>(),
      initialBranchId: widget.initialBranchId,
      initialCategoryIds: widget.initialCategoryIds,
      lockCategories: widget.lockCategories,
      lockBranch: widget.lockBranch,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  /// Апп background-оос буцаж ирэхэд сонгосон огноо/цаг хугацаандаа хоцорсон
  /// эсвэл дүүрсэн байж болзошгүй — controller дахин ачаалж шинэчилнэ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _form.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _form.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await _form.submit(_noteController.text);
    if (!mounted) return;
    switch (outcome.status) {
      case BookingSubmitStatus.completed:
        widget.onCompleted(outcome.created!);
      case BookingSubmitStatus.unauthenticated:
        widget.onUnauthenticated();
      case BookingSubmitStatus.ignored:
      case BookingSubmitStatus.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Цаг хүсэх'),
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _form,
          builder: (context, _) => _form.lockedFlowBlocked
              ? LockedFlowUnavailable(
                  branchMissing: _form.lockedBranchMissing,
                  onBack: widget.onBack,
                )
              : _buildForm(context),
        ),
      ),
    ),
  );

  Widget _buildForm(BuildContext context) {
    final form = _form;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BookingHeader(
          organization: widget.organization,
          selectedBranch: form.selectedBranch,
          categoryCount: form.allCategories.length,
        ),
        BookingCategorySection(form: form),
        BookingBranchSection(form: form),
        if (form.selectedBranch != null) ...[
          const SizedBox(height: 16),
          GlassSurface(
            child: BookingCalendar(
              month: form.displayedMonth,
              selectedDate: form.selectedDate,
              branch: form.selectedBranch,
              onMonthChanged: form.setDisplayedMonth,
              onDateSelected: form.selectDate,
            ),
          ),
        ],
        if (form.selectedBranch != null && form.selectedDate != null) ...[
          const SizedBox(height: 12),
          BookingSlotSection(form: form),
        ],
        const SizedBox(height: 12),
        VehiclePicker(
          controller: form.vehiclesController,
          selectedVehicleId: form.selectedVehicleId,
          onChanged: form.selectVehicle,
          onAddVehicle: widget.onAddVehicle,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Тэмдэглэл (заавал биш)',
            alignLabelWithHint: true,
          ),
        ),
        Text(
          'Энэ нь хүсэлт илгээх үйлдэл. Сервис баталгаажуулсны дараа цаг баталгаажна.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (form.error != null) ...[
          const SizedBox(height: 12),
          Text(
            form.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('submit-booking'),
          onPressed: form.submitting ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(form.submitting ? 'Илгээж байна…' : 'Хүсэлт илгээх'),
        ),
      ],
    );
  }
}
