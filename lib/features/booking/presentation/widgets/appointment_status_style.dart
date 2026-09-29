import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:flutter/material.dart';

Color appointmentStatusColor(AppointmentStatus status, BuildContext context) =>
    switch (status) {
      AppointmentStatus.confirmed => AppColors.green,
      AppointmentStatus.pending => AppColors.blue,
      AppointmentStatus.rejected ||
      AppointmentStatus.cancelled => AppColors.red,
      AppointmentStatus.noShow || AppointmentStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };

Color serviceProgressStatusColor(
  ServiceProgressStatus status,
  BuildContext context,
) => switch (status) {
  ServiceProgressStatus.completed => AppColors.green,
  ServiceProgressStatus.cancelled => AppColors.red,
  ServiceProgressStatus.inProgress => AppColors.blue,
  ServiceProgressStatus.postponed => AppColors.purple,
  ServiceProgressStatus.pending ||
  ServiceProgressStatus.scheduled ||
  ServiceProgressStatus.unknown => Theme.of(
    context,
  ).colorScheme.onSurfaceVariant,
};
