sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Сүлжээний холболтоо шалгана уу.']);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure([super.message = 'Оруулсан мэдээллээ шалгана уу.']);
}

class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure([super.message = 'Нэвтрэх шаардлагатай.']);
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = 'Энэ үйлдлийг хийх боломжгүй байна.',
  ]);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Мэдээлэл олдсонгүй.']);
}

class ConflictFailure extends AppFailure {
  const ConflictFailure([super.message = 'Мэдээлэл давхардсан байна.']);
}

class RateLimitFailure extends AppFailure {
  const RateLimitFailure([super.message = 'Түр хүлээгээд дахин оролдоно уу.']);
}

class ExternalServiceFailure extends AppFailure {
  const ExternalServiceFailure([
    super.message = 'Гадаад үйлчилгээтэй холбогдож чадсангүй.',
  ]);
}

class ServerFailure extends AppFailure {
  const ServerFailure([super.message = 'Серверийн алдаа гарлаа.']);
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Тодорхойгүй алдаа гарлаа.']);
}
