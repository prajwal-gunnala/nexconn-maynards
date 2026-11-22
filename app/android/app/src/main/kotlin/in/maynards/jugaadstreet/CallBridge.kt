package `in`.maynards.jugaadstreet

import ai.nexconn.call.api.NCCallEngine
import ai.nexconn.call.api.handler.NCCallAPIResultHandler
import ai.nexconn.call.api.handler.NCCallEventHandler
import ai.nexconn.call.api.handler.event.NCCallConnectedEvent
import ai.nexconn.call.api.handler.event.NCCallEndedEvent
import ai.nexconn.call.api.handler.event.NCCallLocalCallLogReceivedEvent
import ai.nexconn.call.api.handler.event.NCCallMediaTypeChangeRequestReceivedEvent
import ai.nexconn.call.api.handler.event.NCCallMediaTypeChangeResultReceivedEvent
import ai.nexconn.call.api.handler.event.NCCallReceivedEvent
import ai.nexconn.call.api.handler.event.NCCallRemoteCameraStateChangedEvent
import ai.nexconn.call.api.handler.event.NCCallRemoteMicrophoneStateChangedEvent
import ai.nexconn.call.api.handler.event.NCCallRemoteUserInvitedEvent
import ai.nexconn.call.api.handler.event.NCCallRemoteUserStateChangedEvent
import ai.nexconn.call.api.handler.event.NCCallServerCallLogReceivedEvent
import ai.nexconn.call.api.handler.event.NCCallStartTimeReceivedEvent
import ai.nexconn.call.api.handler.event.NCCallTypeChangedEvent
import ai.nexconn.call.api.handler.result.NCCallAcceptCallResult
import ai.nexconn.call.api.handler.result.NCCallEnableCameraResult
import ai.nexconn.call.api.handler.result.NCCallEndCallResult
import ai.nexconn.call.api.handler.result.NCCallStartCallResult
import ai.nexconn.call.api.model.NCCallCode
import ai.nexconn.call.api.model.NCCallMediaType
import ai.nexconn.call.api.model.NCCallRenderMode
import ai.nexconn.call.api.model.NCCallSession
import ai.nexconn.call.api.model.NCCallType
import ai.nexconn.call.api.params.NCCallAcceptCallParams
import ai.nexconn.call.api.params.NCCallEndCallParams
import ai.nexconn.call.api.params.NCCallInitParams
import ai.nexconn.call.api.params.NCCallReplyChangeMediaTypeParams
import ai.nexconn.call.api.params.NCCallStartCallParams
import ai.nexconn.call.api.view.NCCallLocalVideoTextureView
import ai.nexconn.call.api.view.NCCallRemoteVideoTextureView
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Flutter <-> Nexconn Call SDK for Android.
 *
 * - MethodChannel `jugaad/call`: init, startCall, startGroupCall, accept, hangup, mute, speaker, camera,
 *   switchCamera, permissions, current.
 * - EventChannel `jugaad/call/events`: every SDK event and API result as a map with a `type` key.
 * - Platform view `jugaad/call-video`: local (no userId) or remote (userId) video, rendered by the SDK's
 *   TextureView renderers.
 *
 * The Call SDK rides on the IM connection the Flutter chat plugin made in this process (same RongCoreClient).
 */
object CallBridge {
    const val TAG = "JugaadCall"
    private const val METHODS = "jugaad/call"
    private const val EVENTS = "jugaad/call/events"
    private const val VIDEO_VIEW = "jugaad/call-video"

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var initializedFor: String? = null
    private var appContext: Context? = null

    /** The last incoming call, kept until Flutter listens (cold start straight into a ringing call). */
    private var pendingIncoming: Map<String, Any?>? = null

    private val engine: NCCallEngine get() = NCCallEngine.getInstance()

    fun installHandlers() {
        engine.setCallEventHandler(eventHandler)
    }

    fun register(flutterEngine: FlutterEngine, context: Context, permissions: (Boolean, MethodChannel.Result) -> Unit) {
        appContext = context
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        methods = MethodChannel(messenger, METHODS).also { ch ->
            ch.setMethodCallHandler { call, result -> handle(call, result, permissions) }
        }
        events = EventChannel(messenger, EVENTS).also { ch ->
            ch.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    pendingIncoming?.let { emit(it) }
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            })
        }
        flutterEngine.platformViewsController.registry.registerViewFactory(VIDEO_VIEW, VideoViewFactory)
    }

    fun unregister() {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        sink = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result, permissions: (Boolean, MethodChannel.Result) -> Unit) {
        try {
            when (call.method) {
                "init" -> result.success(init(call.argument<String>("userId")))
                "permissions" -> permissions(call.argument<Boolean>("video") == true, result)
                "startCall" -> {
                    val target = call.argument<String>("targetUserId")
                    if (target.isNullOrEmpty()) return result.error("80010", "USER_ID_INVALID", null)
                    val params = NCCallStartCallParams(listOf(target), NCCallType.SINGLE, media(call))
                    call.argument<String>("extra")?.let { params.extra = it }
                    pendingIncoming = null
                    engine.startCall(params)
                    result.success(true)
                }
                "startGroupCall" -> {
                    val ids = call.argument<List<String>>("userIds").orEmpty().filter { it.isNotEmpty() }.distinct()
                    if (ids.isEmpty()) return result.error("80007", "USER_LIST_INVALID", null)
                    val params = NCCallStartCallParams(ids, NCCallType.MULTI, media(call))
                    call.argument<String>("groupId")?.let { params.targetId = it }
                    call.argument<String>("extra")?.let { params.extra = it }
                    pendingIncoming = null
                    engine.startCall(params)
                    result.success(true)
                }
                "accept" -> {
                    val id = call.argument<String>("callId") ?: engine.currentCallSession?.callId
                    if (id.isNullOrEmpty()) return result.error("80008", "CALL_ID_INVALID", null)
                    pendingIncoming = null
                    engine.acceptCall(NCCallAcceptCallParams(id))
                    result.success(true)
                }
                "hangup" -> {
                    val id = call.argument<String>("callId") ?: engine.currentCallSession?.callId
                    pendingIncoming = null
                    if (id.isNullOrEmpty()) return result.success(false)
                    engine.endCall(NCCallEndCallParams(id))
                    result.success(true)
                }
                "mute" -> {
                    engine.enableMicrophone(call.argument<Boolean>("muted") != true)
                    result.success(!engine.isMicrophoneEnabled)
                }
                "speaker" -> {
                    engine.enableSpeaker(call.argument<Boolean>("on") == true)
                    result.success(engine.isSpeakerphoneEnabled)
                }
                "camera" -> {
                    engine.enableCamera(call.argument<Boolean>("on") == true)
                    result.success(true)
                }
                "switchCamera" -> {
                    engine.switchCamera()
                    result.success(true)
                }
                "current" -> result.success(engine.currentCallSession?.let { session(it) })
                "version" -> result.success(NCCallEngine.getVersion())
                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            Log.e(TAG, "call ${call.method} failed", t)
            result.error("native", t.message ?: t.javaClass.simpleName, null)
        }
    }

    /**
     * Initialises the Call SDK once the chat is connected. The Flutter chat plugin connects through the IM core
     * directly, so the Nexconn Chat (Android) layer the Call SDK reads its current user id from never saw a
     * connect; we hand it the connected user id first.
     */
    private fun init(userId: String?): Map<String, Any?> {
        val ctx = appContext ?: return mapOf("ok" to false, "error" to "no context")
        if (!userId.isNullOrEmpty()) {
            try {
                val f = Class.forName("c.H0").getField("a")
                if (f.get(null) != userId) f.set(null, userId)
            } catch (t: Throwable) {
                Log.w(TAG, "could not seed Nexconn chat user id", t)
            }
        }
        if (initializedFor == null) {
            val params = NCCallInitParams(ctx)
            params.pubLowResolutionStream(true)
            NCCallEngine.initialize(params)
            engine.setCallEventHandler(eventHandler)
            engine.setAPIResultHandler(resultHandler)
        }
        initializedFor = userId
        Log.i(TAG, "Nexconn Call SDK ${NCCallEngine.getVersion()} initialised for $userId")
        return mapOf("ok" to true, "version" to NCCallEngine.getVersion())
    }

    private fun media(call: MethodCall) =
        if (call.argument<Boolean>("video") == true) NCCallMediaType.AUDIO_VIDEO else NCCallMediaType.AUDIO

    private fun session(s: NCCallSession): Map<String, Any?> = mapOf(
        "callId" to s.callId,
        "state" to s.callState?.name,
        "callType" to s.callType?.name,
        "video" to (s.mediaType == NCCallMediaType.AUDIO_VIDEO),
        "callerUserId" to s.callerUserId,
        "inviterUserId" to s.inviterUserId,
        "participants" to s.remoteParticipants.orEmpty().map {
            mapOf(
                "userId" to it.userId,
                "state" to it.userState?.name,
                "camera" to it.isCameraEnabled,
                "mic" to it.isMicrophoneEnabled,
            )
        },
    )

    private fun code(c: NCCallCode?): Map<String, Any?> = mapOf("code" to (c?.value ?: -1), "codeName" to c?.name)

    private fun emit(event: Map<String, Any?>) {
        main.post {
            Log.i(TAG, "event $event")
            sink?.success(event)
        }
    }

    private val eventHandler = object : NCCallEventHandler {
        override fun onCallReceived(event: NCCallReceivedEvent) {
            val e = mapOf("type" to "incoming", "extra" to event.extra) + session(event.callSession)
            pendingIncoming = e
            emit(e)
        }

        override fun onCallConnected(event: NCCallConnectedEvent) {
            pendingIncoming = null
            emit(mapOf("type" to "connected") + session(event.callSession))
        }

        override fun onRemoteUserInvited(event: NCCallRemoteUserInvitedEvent) {
            emit(mapOf("type" to "invited", "callId" to event.callId, "userIds" to event.inviteeUserList))
        }

        override fun onRemoteUserStateChanged(event: NCCallRemoteUserStateChangedEvent) {
            emit(
                mapOf(
                    "type" to "remoteState", "callId" to event.callId, "userId" to event.userId,
                    "state" to event.userState?.name, "reason" to event.reason?.name,
                )
            )
        }

        override fun onCallEnded(event: NCCallEndedEvent) {
            pendingIncoming = null
            emit(mapOf("type" to "ended", "reason" to event.reason?.name) + (event.session?.let { session(it) } ?: emptyMap()))
        }

        override fun onServerCallLogReceived(event: NCCallServerCallLogReceivedEvent) {}

        override fun onRemoteMicrophoneStateChanged(event: NCCallRemoteMicrophoneStateChangedEvent) {}

        override fun onRemoteCameraStateChanged(event: NCCallRemoteCameraStateChangedEvent) {
            emit(mapOf("type" to "remoteCamera"))
        }

        override fun onMediaTypeChangeRequestReceived(event: NCCallMediaTypeChangeRequestReceivedEvent) {
            engine.replyChangeMediaType(NCCallReplyChangeMediaTypeParams(event.transactionId, true))
        }

        override fun onMediaTypeChangeResultReceived(event: NCCallMediaTypeChangeResultReceivedEvent) {}

        override fun onCallTypeChanged(event: NCCallTypeChangedEvent) {}

        override fun onLocalCallLogReceived(event: NCCallLocalCallLogReceivedEvent) {}

        override fun onStartTimeReceived(event: NCCallStartTimeReceivedEvent) {
            emit(mapOf("type" to "startTime", "startTime" to event.startTime))
        }
    }

    private val resultHandler = object : NCCallAPIResultHandler {
        override fun onStartCall(result: NCCallStartCallResult) {
            emit(
                mapOf(
                    "type" to "startResult", "callId" to result.callId,
                    "busy" to result.busyLineUserList.orEmpty().map { it.userId },
                ) + code(result.code)
            )
        }

        override fun onAcceptCall(result: NCCallAcceptCallResult) {
            emit(mapOf("type" to "acceptResult", "callId" to result.callId) + code(result.code))
        }

        override fun onEndCall(result: NCCallEndCallResult) {
            emit(mapOf("type" to "endResult") + code(result.code))
        }

        override fun onEnableCamera(result: NCCallEnableCameraResult) {
            emit(mapOf("type" to "cameraResult") + code(result.code))
        }
    }

    /** `jugaad/call-video`: creationParams {userId: String?} - null/empty = local preview. */
    private object VideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val userId = (args as? Map<*, *>)?.get("userId") as? String
            return VideoView(context, userId)
        }
    }

    private class VideoView(context: Context, userId: String?) : PlatformView {
        private val root = FrameLayout(context)

        init {
            try {
                if (userId.isNullOrEmpty()) {
                    val v = NCCallLocalVideoTextureView(context)
                    v.setRenderMode(NCCallRenderMode.FILL)
                    root.addView(v, FrameLayout.LayoutParams(-1, -1))
                    NCCallEngine.getInstance().setLocalVideoView(v)
                } else {
                    val v = NCCallRemoteVideoTextureView(context, userId, false)
                    v.setRenderMode(NCCallRenderMode.FILL)
                    root.addView(v, FrameLayout.LayoutParams(-1, -1))
                    NCCallEngine.getInstance().setRemoteVideoView(listOf(v))
                }
            } catch (t: Throwable) {
                Log.e(TAG, "video view for ${userId ?: "local"} failed", t)
            }
        }

        override fun getView(): View = root

        override fun dispose() {}
    }
}
