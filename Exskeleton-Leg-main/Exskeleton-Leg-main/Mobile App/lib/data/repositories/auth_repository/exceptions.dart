import 'package:flutter_starter/core/exception.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';

abstract class AuthException extends BaseException {
  AuthException({String? message, super.code, super.data})
      : super(message ?? LocaleKeys.Errors_AnUnknownErrorOccurred);
}

class UnauthorizedException extends AuthException {
  UnauthorizedException({super.data});
}

class LoginInvalidEmailPasswordException extends AuthException {
  LoginInvalidEmailPasswordException()
      : super(message: LocaleKeys.Errors_InvalidUsernameOrPassword);
}

class EmailAlreadyExistsException extends AuthException {
  EmailAlreadyExistsException() : super(message: 'Errors.EmailAlreadyExists');
}

class TermsNotAcceptedException extends AuthException {
  TermsNotAcceptedException() : super(message: 'Errors.TermsNotAccepted');
}
