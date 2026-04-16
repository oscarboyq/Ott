import 'package:get_it/get_it.dart';
import 'package:video/features/admin/data/repositories/mock_admin_video_repository.dart';
import 'package:video/features/admin/domain/repositories/admin_video_repository.dart';
import 'package:video/features/admin/domain/usecases/create_video.dart';
import 'package:video/features/admin/domain/usecases/get_admin_catalog.dart';
import 'package:video/features/admin/domain/usecases/update_featured_status.dart';
import 'package:video/features/admin/domain/usecases/update_publish_status.dart';
import 'package:video/features/admin/presentation/controllers/admin_catalog_controller.dart';
import 'package:video/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:video/features/auth/domain/repositories/auth_repository.dart';
import 'package:video/features/auth/domain/usecases/sign_in_demo_user.dart';
import 'package:video/features/auth/domain/usecases/sign_out.dart';
import 'package:video/features/auth/domain/usecases/update_premium_access.dart';
import 'package:video/features/auth/domain/usecases/watch_session.dart';
import 'package:video/features/auth/presentation/controllers/session_controller.dart';
import 'package:video/features/catalog/data/datasources/mock_video_remote_data_source.dart';
import 'package:video/features/catalog/data/datasources/video_data_source.dart';
import 'package:video/features/catalog/data/repositories/mock_video_repository.dart';
import 'package:video/features/catalog/domain/repositories/video_repository.dart';
import 'package:video/features/catalog/domain/usecases/get_catalog.dart';
import 'package:video/features/catalog/domain/usecases/resolve_video_access.dart';
import 'package:video/features/catalog/presentation/controllers/catalog_controller.dart';

final GetIt sl = GetIt.instance;

void setupDependencies() {
  if (sl.isRegistered<CatalogController>()) {
    return;
  }

  sl
    ..registerLazySingleton(MockVideoRemoteDataSource.new)
    ..registerLazySingleton<VideoDataSource>(
      () => sl<MockVideoRemoteDataSource>(),
    )
    ..registerLazySingleton<VideoRepository>(() => MockVideoRepository(sl()))
    ..registerLazySingleton<AdminVideoRepository>(
      () => MockAdminVideoRepository(sl()),
    )
    ..registerLazySingleton<AuthRepository>(MockAuthRepository.new)
    ..registerLazySingleton(() => GetCatalogUseCase(sl()))
    ..registerLazySingleton(() => GetAdminCatalogUseCase(sl()))
    ..registerLazySingleton(() => CreateVideoUseCase(sl()))
    ..registerLazySingleton(() => UpdatePublishStatusUseCase(sl()))
    ..registerLazySingleton(() => UpdateFeaturedStatusUseCase(sl()))
    ..registerLazySingleton(() => WatchSessionUseCase(sl()))
    ..registerLazySingleton(() => SignInDemoUserUseCase(sl()))
    ..registerLazySingleton(() => SignOutUseCase(sl()))
    ..registerLazySingleton(() => UpdatePremiumAccessUseCase(sl()))
    ..registerFactory(ResolveVideoAccessUseCase.new)
    ..registerLazySingleton(
      () => SessionController(
        authRepository: sl(),
        watchSessionUseCase: sl(),
        signInDemoUserUseCase: sl(),
        signOutUseCase: sl(),
        updatePremiumAccessUseCase: sl(),
      ),
    )
    ..registerLazySingleton(() => CatalogController(getCatalogUseCase: sl()))
    ..registerLazySingleton(
      () => AdminCatalogController(
        getAdminCatalogUseCase: sl(),
        createVideoUseCase: sl(),
        updatePublishStatusUseCase: sl(),
        updateFeaturedStatusUseCase: sl(),
      ),
    );
}
