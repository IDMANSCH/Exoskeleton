import 'package:flutter_starter/data/entities/patient_home.dart';

abstract class HomeRepository {
  const HomeRepository();

  Future<PatientHome> getPatientHome(String patientId);
}
