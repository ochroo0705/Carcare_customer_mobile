import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/discovery/data/organization_dto.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';

/// Public organization catalog-ийн API adapter.
///
/// `/orgs` нь list-д зориулсан summary payload, `/orgs/[slug]` нь booking-д
/// хэрэгтэй detail payload буцаадаг тул хоёр response-ийг нэг DTO гэж үзэхгүй.
/// Detail-ийн memory cache нь нэг app session доторх давхар хүсэлтийг багасгана;
/// урт хугацааны offline cache-г [CachingOrganizationRepository] хариуцна.
class RemoteOrganizationRepository implements OrganizationRepository {
  RemoteOrganizationRepository(this._client);

  final ApiClient _client;
  final Map<String, OrganizationDetail> _detailCache = {};

  @override
  Future<List<Organization>> getOrganizations() async {
    final json = await _client.getJson('/orgs');
    final items = json['orgs'];
    if (items is! List) {
      throw const UnexpectedFailure('API жагсаалт буруу байна.');
    }
    return items
        .map((item) {
          if (item is! Map) {
            throw const UnexpectedFailure('API өгөгдөл буруу байна.');
          }
          return OrganizationSummaryDto.fromJson(
            Map<String, dynamic>.from(item),
          ).toDomain();
        })
        .toList(growable: false);
  }

  @override
  Future<OrganizationDetail> getOrganization(String slug) async {
    final cached = _detailCache[slug];
    if (cached != null) return cached;
    final json = await _client.getJson('/orgs/${Uri.encodeComponent(slug)}');
    final item = json['org'];
    if (item is! Map) throw const UnexpectedFailure('API өгөгдөл буруу байна.');
    final detail = OrganizationDetailDto.fromJson(
      Map<String, dynamic>.from(item),
    ).toDomain();
    _detailCache[slug] = detail;
    return detail;
  }
}
