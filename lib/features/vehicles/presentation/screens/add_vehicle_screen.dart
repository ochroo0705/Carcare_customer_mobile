import 'dart:async';

import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _platePattern = RegExp(r'^\d{4}[А-ЯЁӨҮ]{3}$');

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({
    required this.repository,
    required this.onBack,
    required this.onAdded,
    super.key,
  });

  final VehicleRepository repository;
  final VoidCallback onBack;
  final ValueChanged<Vehicle> onAdded;

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _vinController = TextEditingController();
  Timer? _lookupTimer;
  String? _lastLookedUpPlate;

  bool _lookingUp = false;
  bool _isPlateValid = false;
  bool _submitting = false;
  String? _lookupMessage;
  String? _error;

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Машин нэмэх'),
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('vehicle-plate'),
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                    inputFormatters: const [_MongolianPlateInputFormatter()],
                    onChanged: _scheduleLookup,
                    decoration: InputDecoration(
                      labelText: 'Улсын дугаар',
                      hintText: '1234УБА',
                      counterText: '',
                      helperText: _lookingUp
                          ? 'ХУР-аас хайж байна…'
                          : '4 цифр + 3 кирилл үсэг',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    key: const ValueKey('vehicle-lookup'),
                    onPressed: _lookingUp || !_isPlateValid ? null : _lookup,
                    child: _lookingUp
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ХУР-аас хайх'),
                  ),
                ),
              ],
            ),
            if (_lookupMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _lookupMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('vehicle-make'),
              controller: _makeController,
              decoration: const InputDecoration(labelText: 'Марк'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('vehicle-model'),
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Загвар'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('vehicle-year'),
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Оны загвар (заавал биш)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('vehicle-vin'),
              controller: _vinController,
              decoration: const InputDecoration(labelText: 'VIN (заавал биш)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('vehicle-submit'),
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.directions_car_outlined),
              label: Text(_submitting ? 'Хадгалж байна…' : 'Нэмэх'),
            ),
          ],
        ),
      ),
    ),
  );

  void _scheduleLookup(String value) {
    setState(() => _isPlateValid = _isValidPlate(value));
    _lookupTimer?.cancel();
    final plate = value.trim();
    if (!_isValidPlate(plate) || plate == _lastLookedUpPlate) return;
    _lookupTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted &&
          !_lookingUp &&
          plate == _plateController.text.trim() &&
          plate != _lastLookedUpPlate) {
        _lookup();
      }
    });
  }

  Future<void> _lookup() async {
    final plate = _plateController.text.trim();
    if (!_isValidPlate(plate)) {
      setState(() => _error = 'Дугаараа 4 цифр, 3 кирилл үсгээр оруулна уу.');
      return;
    }
    _lastLookedUpPlate = plate;
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
      _error = null;
    });
    try {
      final result = await widget.repository.lookupByPlate(plate);
      if (!mounted) return;
      setState(() {
        _makeController.text = result.make;
        _modelController.text = result.model;
        _yearController.text = result.year?.toString() ?? '';
        _vinController.text = result.vin ?? '';
        _lookupMessage = result.source == VehicleLookupSource.hur
            ? 'ХУР-аас олдлоо. Мэдээллээ шалгаад засварлаж болно.'
            : 'Системээс олдлоо. Мэдээллээ шалгаад засварлаж болно.';
      });
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Тодорхойгүй алдаа гарлаа.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _submit() async {
    final plate = _plateController.text.trim();
    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    if (!_isValidPlate(plate) || make.isEmpty || model.isEmpty) {
      setState(() => _error = 'Дугаар, марк, загвараа зөв оруулна уу.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final vehicle = await widget.repository.addVehicle(
        plate: plate,
        make: make,
        model: model,
        year: int.tryParse(_yearController.text.trim()),
        vin: _vinController.text.trim().isEmpty
            ? null
            : _vinController.text.trim(),
      );
      if (mounted) widget.onAdded(vehicle);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Тодорхойгүй алдаа гарлаа.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

bool _isValidPlate(String value) => _platePattern.hasMatch(value.trim());

class _MongolianPlateInputFormatter extends TextInputFormatter {
  const _MongolianPlateInputFormatter();

  static const _latinToCyrillic = {
    'A': 'А',
    'B': 'В',
    'C': 'С',
    'E': 'Е',
    'H': 'Н',
    'K': 'К',
    'M': 'М',
    'O': 'О',
    'P': 'Р',
    'T': 'Т',
    'X': 'Х',
    'Y': 'У',
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = StringBuffer();
    for (final rune in newValue.text.toUpperCase().runes) {
      final character = String.fromCharCode(rune);
      if (!RegExp(r'[0-9A-ZА-ЯЁӨҮ]').hasMatch(character)) continue;
      normalized.write(_latinToCyrillic[character] ?? character);
      if (normalized.length == 7) break;
    }
    final value = normalized.toString();
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
