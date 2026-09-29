/// Path builders for the customer app's go_router migration — the only
/// place a route path is spelled out. See `plan-context.md`'s route table
/// for the contract these mirror.
abstract final class CustomerRoutes {
  static const shell = '/';

  static String organization(String slug, {String? branchId}) => Uri(
    path: '/organizations/$slug',
    queryParameters: {'branch': ?branchId},
  ).toString();

  static String booking(
    String slug, {
    String? branchId,
    List<String> serviceKeyIds = const [],
    bool lockBranch = false,
  }) => Uri(
    path: '/organizations/$slug/book',
    queryParameters: {
      'branch': ?branchId,
      if (serviceKeyIds.isNotEmpty) 'keys': serviceKeyIds.join(','),
      if (lockBranch) 'lock': '1',
    },
  ).toString();

  static String login({String? from}) => Uri(
    path: '/login',
    queryParameters: {'from': ?from},
  ).toString();

  static const addVehicle = '/vehicles/add';
  static String vehicle(String id) => '/vehicles/$id';
  static String appointment(String id) => '/appointments/$id';
  static String payment(String appointmentId) =>
      '/appointments/$appointmentId/pay';
  static String walkInOrder(String id) => '/walk-in-orders/$id';
  static String order(String id) => '/orders/$id';
  static String diagnostic(String id) => '/diagnostics/$id';
  static const notifications = '/notifications';
  static const accountClosure = '/account/close';
}
