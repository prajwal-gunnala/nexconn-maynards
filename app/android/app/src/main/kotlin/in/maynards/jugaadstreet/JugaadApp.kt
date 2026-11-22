package `in`.maynards.jugaadstreet

import ai.nexconn.call.api.NCCallEngine
import android.app.Application
import android.util.Log

/**
 * Installs the Nexconn Call SDK before the Flutter chat plugin initialises the IM engine, as the Call SDK
 * requires (`NCCallEngine.install()` -> Chat init/connect -> `NCCallEngine.initialize(...)`). The call event
 * handler is registered here too, so an incoming call that arrives right after the chat connects is not lost.
 */
class JugaadApp : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            NCCallEngine.install()
            CallBridge.installHandlers()
        } catch (t: Throwable) {
            Log.e(CallBridge.TAG, "Nexconn Call SDK install failed", t)
        }
    }
}
