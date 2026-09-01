package mn.carcare.carcare_customer_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mn.carcare.carcare_customer_mobile/map_configuration",
        ).setMethodCallHandler { call, result ->
            if (call.method != "isConfigured") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            @Suppress("DEPRECATION")
            val value = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            ).metaData
                ?.getString("com.google.android.geo.API_KEY")
                ?.trim()
            result.success(!value.isNullOrEmpty() && !value.contains("${'$'}{"))
        }
    }
}
