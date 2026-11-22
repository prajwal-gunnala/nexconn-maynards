package `in`.maynards.jugaadstreet

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CallBridge.register(flutterEngine, applicationContext) { video, result -> requestCallPermissions(video, result) }
    }

    override fun onDestroy() {
        CallBridge.unregister()
        super.onDestroy()
    }

    /** RECORD_AUDIO (+ CAMERA for video) at call time, as the Call SDK docs ask. */
    private fun requestCallPermissions(video: Boolean, result: MethodChannel.Result) {
        val wanted = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (video) wanted += Manifest.permission.CAMERA
        val missing = wanted.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(missing.toTypedArray(), REQ_CALL)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_CALL) return
        val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermission?.success(ok)
        pendingPermission = null
    }

    private companion object {
        const val REQ_CALL = 4711
    }
}
