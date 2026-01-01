import 'cave_repository.dart';
import 'local_cave_repository.dart';

/// Simple service locator for data access.
/// Provides a single instance of the cave repository.
class DataService {
  static final DataService _instance = DataService._internal();

  factory DataService() => _instance;

  DataService._internal();

  CaveRepository? _caveRepository;

  CaveRepository get caveRepository {
    _caveRepository ??= LocalCaveRepository();
    return _caveRepository!;
  }
}
