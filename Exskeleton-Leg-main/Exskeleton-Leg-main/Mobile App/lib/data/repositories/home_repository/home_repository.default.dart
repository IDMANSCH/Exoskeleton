import 'package:flutter_starter/data/entities/patient_home.dart';
import 'package:flutter_starter/data/repositories/home_repository/home_repository.dart';
import 'package:flutter_starter/data/sources/network/network.dart';

class DefaultHomeRepository extends HomeRepository {
  final NetworkDataSource _networkDataSource;

  const DefaultHomeRepository({
    required NetworkDataSource networkDataSource,
  }) : _networkDataSource = networkDataSource;

  @override
  Future<PatientHome> getPatientHome(String patientId) {
    return _networkDataSource.getPatientHome(patientId);
  }
}
