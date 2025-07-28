package com.example.fingerprint_sensor;

import io.flutter.embedding.android.FlutterFragmentActivity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.content.SharedPreferences;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.widget.Toast;
import android.content.pm.PackageManager;
import androidx.annotation.NonNull;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import java.net.SocketTimeoutException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.util.concurrent.Executor;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.example.fingerprint_channel";
    private static final String TAG = "UDPJava";

    private MethodChannel methodChannel;
    private String currentToken = "";
    private int esp32Port = 4210; // default          // Default ESP32 listening port
    private Handler timeoutHandler;
    private Runnable timeoutRunnable;
    private String username = "";
    private String esp32Ip = "";

    private WifiManager.MulticastLock multicastLock;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);

        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "updateConfig": {
                    this.username = call.argument("username");
                    this.esp32Ip = call.argument("esp32_ip");
                    this.esp32Port = call.argument("esp32_port");

                    this.username = username;
                    this.esp32Ip = esp32Ip;
                    this.esp32Port = esp32Port;
                    SharedPreferences prefs = getSharedPreferences("app_config", MODE_PRIVATE);
                    SharedPreferences.Editor editor = prefs.edit();
                    editor.putString("username", username);
                    editor.putString("esp32_ip", esp32Ip);
                    editor.putInt("esp32_port", esp32Port);
                    editor.apply();
                    result.success(null);

                    break;
                }

                case "connect": {
                    String username = call.argument("username");
                    loadConfig();
                    Log.d(TAG, "Config loaded: " + username + ", " + esp32Ip + ":" + esp32Port);
                    sendUDP("CONNECT:" + username);
                    Log.d(TAG, "sent UDP and going to listen");

                    result.success(null);
                    Log.d(TAG, "listened and acknowledged");
                    break;
                }

                case "getUsername": {
                    SharedPreferences prefs = getSharedPreferences("app_config", MODE_PRIVATE);
                    String savedUsername = prefs.getString("username", "");
                    result.success(savedUsername);
                    break;
                }

                case "verify": {
                    authenticateFingerprint();
                    result.success(null);
                    break;
                }

                default:
                    result.notImplemented();
            }
        });
    }
    private void loadConfig() {
        SharedPreferences prefs = getSharedPreferences("app_config", MODE_PRIVATE);
        this.username = prefs.getString("username", "");
        this.esp32Ip = prefs.getString("esp32_ip", "");
        this.esp32Port = prefs.getInt("esp32_port", 4210);
    }
    private void acquireMulticastLock() {
        WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifiManager != null && multicastLock == null) {
            multicastLock = wifiManager.createMulticastLock("udp_lock");
            multicastLock.setReferenceCounted(true);
            multicastLock.acquire();
            Log.d(TAG, "MulticastLock acquired");
        }
    }

    private void releaseMulticastLock() {
        if (multicastLock != null && multicastLock.isHeld()) {
            multicastLock.release();
            Log.d(TAG, "MulticastLock released");
        }
    }

    private void sendUDP(String message) {
        new Thread(() -> {
            DatagramSocket socket = null;
            try {
                InetAddress esp32Address = InetAddress.getByName(esp32Ip);
                socket = new DatagramSocket(); // Use ephemeral port
                byte[] data = message.getBytes();
                DatagramPacket packet = new DatagramPacket(data, data.length, esp32Address, esp32Port);

                socket.send(packet); // Send CONNECT
                Log.d(TAG, "UDP request sent: " + message);

                // Start listener on same socket
                startUDPListener(socket);

            } catch (Exception e) {
                Log.e(TAG, "Failed to send UDP request: " + e.getMessage(), e);
            }
        }).start();
    }

    private void startUDPListener(final DatagramSocket socket) {
        new Thread(() -> {
            acquireMulticastLock(); // Acquire before using socket
            try {
                Log.d(TAG, "Listening for response on port: " + socket.getLocalPort());

                byte[] buffer = new byte[1024];
                DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                socket.setSoTimeout(10000); // Timeout after 10 seconds
                Log.d(TAG, "Waiting to receive packet...");
                socket.receive(packet); // Blocking call
                Log.d(TAG, "Packet received from: " + packet.getAddress() + ":" + packet.getPort());

                String response = new String(packet.getData(), 0, packet.getLength());
                Log.d(TAG, "UDP Received: " + response);

                if (methodChannel == null) {
                    Log.e(TAG, "MethodChannel is null, cannot send result");
                    return;
                }

                if (response.startsWith("ACK:CONNECT:")) {
                    currentToken = response.split(":")[2];
                    runOnUiThread(() -> methodChannel.invokeMethod("onConnectAck", currentToken));
                    startTimeoutCountdown();
                } else if (response.equals("ACK:UNLOCK")) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onUnlockAck", null));
                    stopTimeout();
                } else if (response.equals("TIMEOUT")) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onTimeout", null));
                    stopTimeout();
                }else if (response.equals("INVALID_USER")) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onInvalidUser", null));
                }

            } catch (SocketTimeoutException e) {
                Log.e(TAG, "UDP receive timeout", e);
                if (methodChannel != null) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onError", "UDP timeout: no packet received"));
                }
            } catch (Exception e) {
                Log.e(TAG, "UDP receive error: " + e.getMessage(), e);
                if (methodChannel != null) {
                    runOnUiThread(() -> methodChannel.invokeMethod("onError", "UDP receive failed: " + e.getMessage()));
                }
            } finally {
                if (socket != null && !socket.isClosed()) {
                    socket.close();
                }
                releaseMulticastLock();
            }
        }).start();
    }



    private void authenticateFingerprint() {
        Executor executor = ContextCompat.getMainExecutor(this);
        BiometricPrompt biometricPrompt = new BiometricPrompt(MainActivity.this, executor,
                new BiometricPrompt.AuthenticationCallback() {
                    @Override
                    public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                        sendUDP("UNLOCK:" + currentToken);
//                        startUDPListener(); // Listen for ACK:UNLOCK
                    }

                    @Override
                    public void onAuthenticationFailed() {
                        runOnUiThread(() -> methodChannel.invokeMethod("onAuthFailed", null));
                    }

                    @Override
                    public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
                        runOnUiThread(() -> methodChannel.invokeMethod("onError", errString.toString()));
                    }
                });

        BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
                .setTitle("Fingerprint Verification")
                .setSubtitle("Scan your fingerprint to unlock")
                .setNegativeButtonText("Cancel")
                .build();

        biometricPrompt.authenticate(promptInfo);
    }

    private void startTimeoutCountdown() {
        timeoutHandler = new Handler(Looper.getMainLooper());
        timeoutRunnable = () -> runOnUiThread(() -> methodChannel.invokeMethod("onTimeout", null));
        timeoutHandler.postDelayed(timeoutRunnable, 15000);  // 15s
    }

    private void stopTimeout() {
        if (timeoutHandler != null) {
            timeoutHandler.removeCallbacks(timeoutRunnable);
        }
    }
}
