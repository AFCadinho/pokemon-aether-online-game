package com.pokeaether.game;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.IOException;

/** Opens Android's installer for an APK already verified by the game. */
public final class ApkInstallBridge {
    private ApkInstallBridge() {}

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
