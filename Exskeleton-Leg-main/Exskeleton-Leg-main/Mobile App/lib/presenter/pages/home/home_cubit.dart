import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/core/exception.dart';
import 'package:flutter_starter/data/entities/patient_home.dart';
import 'package:flutter_starter/data/repositories/home_repository/home_repository.dart';

enum HomeStatus { initial, loading, content, failure }

class HomeState {
  final HomeStatus status;
  final PatientHome? home;
  final BaseException? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.home,
    this.error,
  });

  HomeState copyWith({
    HomeStatus? status,
    PatientHome? home,
    BaseException? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      home: home ?? this.home,
      error: error,
    );
  }
}

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _repository;

  HomeCubit({required HomeRepository repository})
      : _repository = repository,
        super(const HomeState());

  Future<void> load(String? patientId) async {
    if (patientId == null || patientId.isEmpty) {
      emit(HomeState(
        status: HomeStatus.failure,
        error: UnknownException('Missing patient id'),
      ));
      return;
    }

    emit(state.copyWith(status: HomeStatus.loading, error: null));
    try {
      final home = await _repository.getPatientHome(patientId);
      emit(HomeState(status: HomeStatus.content, home: home));
    } catch (error) {
      emit(HomeState(
        status: HomeStatus.failure,
        error: BaseException.from(error),
      ));
    }
  }
}
