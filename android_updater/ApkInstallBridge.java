package com.pokeaether.game;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.IOException;
import org.json.JSONObject;

/** Verified APK installation and privacy-safe diagnostics for our own process. */
public final class ApkInstallBridge {
    private ApkInstallBridge() {}

    /** No descriptions, traces or other applications' process information. */
    public static String getPreviousProcessExit(Activity activity, int pid,
            long startedAtMillis, long currentSessionMillis) {
        if (activity == null || pid <= 0 || startedAtMillis <= 0
                || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return "{}";
        try {
            return ExitInfoApi30.read(activity, pid, startedAtMillis, currentSessionMillis);
        } catch (Exception error) {
            // Some devices do not retain this history. Keep the marker fallback.
            return "{}";
        }
    }

    private static final class ExitInfoApi30 {
        static String read(Activity activity, int pid, long startedAtMillis,
                long currentSessionMillis) throws Exception {
            ActivityManager manager = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
            if (manager == null) return "{}";
            String ownPackage = activity.getPackageName();
            for (ApplicationExitInfo exit : manager.getHistoricalProcessExitReasons(ownPackage, pid, 8)) {
                // PID reuse and worker processes must not describe this session.
                if (exit.getPid() != pid || !ownPackage.equals(exit.getProcessName())
                        || exit.getTimestamp() < startedAtMillis
                        || exit.getTimestamp() > currentSessionMillis) continue;
                JSONObject value = new JSONObject();
                value.put("reason", exit.getReason());
                value.put("status", exit.getStatus());
                value.put("importance", exit.getImportance());
                value.put("timestampUnixMs", exit.getTimestamp());
                value.put("pssKiB", exit.getPss());
                value.put("rssKiB", exit.getRss());
                return value.toString();
            }
            return "{}";
        }
    }

    // 0: installer opened; 1: install permission settings opened; negative: invalid file.
    public static int install(Activity activity, String apkPath) {
        if (activity == null || apkPath == null) return -1;
        try {
            File apk = new File(apkPath).getCanonicalFile();
            File files = activity.getFilesDir().getCanonicalFile();
            if (!apk.getPath().startsWith(files.getPath() + File.separator)
                    || !apk.isFile() || !apk.getName().endsWith(".apk")) return -1;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    && !activity.getPackageManager().canRequestPackageInstalls()) {
                Intent settings = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.getPackageName()));
                activity.runOnUiThread(() -> activity.startActivity(settings));
                return 1;
            }
            Uri uri = FileProvider.getUriForFile(activity,
                    activity.getPackageName() + ".fileprovider", apk);
            Intent install = new Intent(Intent.ACTION_INSTALL_PACKAGE);
            install.setData(uri);
            install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.runOnUiThread(() -> activity.startActivity(install));
            return 0;
        } catch (IOException | RuntimeException error) {
            return -1;
        }
    }
}
