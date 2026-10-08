package com.example.leg.notifications;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;

/** HTTP v1 fallback for malformed gzip responses from the Admin SDK transport. */
final class FcmHttpSender {
    private static final String MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
    private final GoogleCredentials credentials;
    private final URI endpoint;
    private final ObjectMapper mapper;
    private final HttpClient client;

    FcmHttpSender(FirebaseApp app, GoogleCredentials source, ObjectMapper mapper) {
        var options = app.getOptions();
        var projectId = options.getProjectId();
        if ((projectId == null || projectId.isBlank()) && source instanceof ServiceAccountCredentials account) {
            projectId = account.getProjectId();
        }
        if (projectId == null || !projectId.matches("[a-zA-Z0-9-]+")) {
            throw new IllegalStateException("Firebase project ID is missing or invalid");
        }
        this.credentials = source.createScoped(MESSAGING_SCOPE);
        this.endpoint = URI.create("https://fcm.googleapis.com/v1/projects/" + projectId + "/messages:send");
        this.mapper = mapper;
        this.client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    }

    void send(String token, String title, String body, Map<String, String> data) throws IOException, InterruptedException {
        credentials.refreshIfExpired();
        var accessToken = credentials.getAccessToken();
        if (accessToken == null) throw new IOException("Firebase OAuth token is unavailable");
        var payload = Map.of("message", Map.of(
                "token", token,
                "notification", Map.of("title", title, "body", body),
                "data", data));
        var request = HttpRequest.newBuilder(endpoint)
                .timeout(Duration.ofSeconds(15))
                .header("Authorization", "Bearer " + accessToken.getTokenValue())
                .header("Content-Type", "application/json; charset=UTF-8")
                .header("Accept-Encoding", "identity")
                .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload)))
                .build();
        var response = client.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            // Never include the registration token or OAuth credential in logs.
            var error = response.body().length() > 600 ? response.body().substring(0, 600) : response.body();
            throw new IOException("FCM HTTP v1 returned " + response.statusCode() + ": " + error);
        }
    }
}
