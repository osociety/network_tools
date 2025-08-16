// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:network_tools/network_tools.dart' as _i916;
import 'package:network_tools/src/database/database_service.dart' as _i45;
import 'package:network_tools/src/database/drfit_database_service.dart'
    as _i827;
import 'package:network_tools/src/database/drift_database.dart' as _i1025;
import 'package:network_tools/src/services/impls/arp_repository_impl.dart'
    as _i364;
import 'package:network_tools/src/services/impls/vendor_repository_impl.dart'
    as _i315;
import 'package:network_tools/src/services/repository.dart' as _i960;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.factory<_i45.DatabaseService<_i1025.AppDatabase>>(
      () => _i827.DriftDatabaseService(),
    );
    gh.factory<_i960.Repository<_i916.Vendor>>(
      () => _i315.VendorRepository(
        gh<_i45.DatabaseService<_i1025.AppDatabase>>(),
      ),
    );
    gh.factory<_i960.Repository<_i916.ARPData>>(
      () => _i364.ARPRepository(gh<_i45.DatabaseService<_i1025.AppDatabase>>()),
    );
    return this;
  }
}
