package com.example.leg.shared;

import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class RestExceptionHandler {
    @ExceptionHandler(ApiException.class)
    ResponseEntity<ErrorEnvelope> handleApi(ApiException exception) {
        return ResponseEntity.status(exception.status()).body(ErrorEnvelope.from(exception));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ErrorEnvelope> handleValidation(MethodArgumentNotValidException exception) {
        var field = exception.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(error -> error.getField())
                .orElse("request");
        var apiException = new ApiException(
                HttpStatus.UNPROCESSABLE_ENTITY,
                "validation.invalid_field",
                "Giá trị không hợp lệ.",
                Map.of("field", field));
        return handleApi(apiException);
    }

    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<ErrorEnvelope> handleDependency(DataAccessException exception) {
        var apiException = new ApiException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "dependency.unavailable",
                "Dịch vụ tạm thời không khả dụng.");
        return handleApi(apiException);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ErrorEnvelope> handleUnexpected(Exception exception) {
        var apiException = new ApiException(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "internal.unexpected",
                "Đã xảy ra lỗi không mong muốn.");
        return handleApi(apiException);
    }

    public record ErrorEnvelope(ErrorBody error) {
        static ErrorEnvelope from(ApiException exception) {
            return new ErrorEnvelope(new ErrorBody(
                    exception.code(),
                    exception.getMessage(),
                    exception.details(),
                    UUID.randomUUID()));
        }
    }

    public record ErrorBody(String code, String message, Object details, UUID requestId) {
    }
}
