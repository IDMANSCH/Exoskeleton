import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/core/exception.dart';
import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';

enum RegisterStatus { initial, submitting, success, failure }

class RegisterState {
  final RegisterStatus status;
  final Account? account;
  final BaseException? error;

  const RegisterState({
    this.status = RegisterStatus.initial,
    this.account,
    this.error,
  });
}

class RegisterCubit extends Cubit<RegisterState> {
  final AuthRepository _authRepository;

  RegisterCubit(this._authRepository) : super(const RegisterState());

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    required bool acceptedTerms,
    String role = 'patient',
  }) async {
    if (state.status == RegisterStatus.submitting) return;
    emit(const RegisterState(status: RegisterStatus.submitting));
    try {
      final account = await _authRepository.register(
        email: email,
        password: password,
        displayName: displayName,
        acceptedTerms: acceptedTerms,
        role: role,
      );
      emit(RegisterState(status: RegisterStatus.success, account: account));
    } catch (error) {
      emit(
        RegisterState(
          status: RegisterStatus.failure,
          error: BaseException.from(error),
        ),
      );
    }
  }
}
