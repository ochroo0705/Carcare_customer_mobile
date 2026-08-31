sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Сүлжээний холболтоо шалгана уу.']);
}

class ServerFailure extends AppFailure {
  const ServerFailure([super.message = 'Серверийн алдаа гарлаа.']);
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Тодорхойгүй алдаа гарлаа.']);
}
