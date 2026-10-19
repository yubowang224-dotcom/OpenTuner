package org.opentune.tuner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioRecordingConfiguration
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

/** Only controls/snapshots cross this channel; no PCM or callback-thread JNI. */
class MainActivity : FlutterActivity() {
    companion object {
        private const val REQUEST_MIC = 4091
        // Process-wide serialization survives Activity recreation; stale owners
        // can only stop their own native session.
        private val control = Executors.newSingleThreadExecutor()
        private val preferencesControl = Executors.newSingleThreadExecutor()
        private val sessions = AtomicLong(0)
        init { System.loadLibrary("opentune_audio") }
    }
    private external fun nativeStart(session: Long, unprocessed: Boolean, referenceHz: Double, piano: Boolean): String
    private external fun nativePartialStart(session: Long, unprocessed: Boolean, referenceHz: Double, midi: Int, associationHz: Double): String
    private external fun nativeStop(session: Long)
    private external fun nativeSnapshot(details: Boolean): DoubleArray
    private external fun nativeToneStart(session: Long, hz: Double, voice: Int, gain: Double): String
    private external fun nativeToneStop(session: Long)
    private external fun nativeToneStatus(session: Long): DoubleArray
    private external fun nativeMetroStart(session: Long, word: Int, gain: Int): String
    private external fun nativeMetroUpdate(session: Long, word: Int, gain: Int)
    private external fun nativeMetroPause(session: Long, paused: Boolean)
    private external fun nativeMetroStatus(session: Long): DoubleArray
    private var outputKind = "idle"
    private var outputRequest = 0L
    private var outputState = "idle"
    private var toneOwner = 0L
    private var tonePending: MethodChannel.Result? = null
    private var focusRequest: AudioFocusRequest? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change <= AudioManager.AUDIOFOCUS_LOSS) stopTone("interrupted")
    }
    private val main = Handler(Looper.getMainLooper())
    private lateinit var channel: MethodChannel
    private var preferencesChannel: MethodChannel? = null
    private lateinit var audio: AudioManager
    private var foreground = false
    private var generation = 0L
    private var activeSession = 0L
    private var pending: MethodChannel.Result? = null
    private var state = "idle"
    private var silenced = false
    private var inputRequest: InputRequest? = null
    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(devices: Array<out AudioDeviceInfo>) {
            // Initial inventory is delivered at registration; activeSession==0.
            if (activeSession != 0L && devices.any { it.isSource }) stop("device_changed")
            if (toneOwner != 0L && devices.any { it.isSink }) stopTone("device_changed")
        }
        override fun onAudioDevicesRemoved(devices: Array<out AudioDeviceInfo>) {
            if (activeSession != 0L && devices.any { it.isSource }) stop("device_changed")
            if (toneOwner != 0L && devices.any { it.isSink }) stopTone("device_changed")
        }
    }
    private val recordingCallback = object : AudioManager.AudioRecordingCallback() {
        override fun onRecordingConfigChanged(configs: List<AudioRecordingConfiguration>) {
            if (Build.VERSION.SDK_INT >= 29) {
                silenced = configs.any { it.clientAudioSessionId == audioSessionId && it.isClientSilenced }
                if (silenced && activeSession != 0L) stop("silenced")
            }
        }
    }
    private var audioSessionId = -1 // filled from native stream, -1 if unavailable

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audio = getSystemService(AUDIO_SERVICE) as AudioManager
        val preferences = getSharedPreferences("org.opentune.tuner.ui", MODE_PRIVATE)
        preferencesChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.opentune/preferences").also { prefsChannel ->
            prefsChannel.setMethodCallHandler { call, result ->
                if (call.method == "profileDirectory") { preferencesControl.execute { main.post { result.success(java.io.File(filesDir,"pianos").absolutePath) } }; return@setMethodCallHandler }
                if (call.method !in listOf("read", "write")) { result.notImplemented(); return@setMethodCallHandler }
                val values = call.arguments as? Map<*, *>
                if (call.method == "write" && (values == null || values["version"] != 2 || values["theme"] !in listOf("system", "light", "dark") || values["minimal"] !is Boolean || (values["referenceHz"] as? Number)?.toDouble()?.let { !it.isFinite() || it !in 400.0..480.0 } != false)) {
                    result.error("invalid_preferences", "Invalid appearance preferences", null); return@setMethodCallHandler
                }
                preferencesControl.execute {
                    try {
                        if (call.method == "read") {
                            val data = mapOf("version" to preferences.getInt("version", 1), "theme" to preferences.getString("theme", "system"), "minimal" to preferences.getBoolean("minimal", false), "referenceHz" to (preferences.getString("referenceHz", "440")?.toDoubleOrNull() ?: Double.NaN))
                            main.post { result.success(data) }
                        } else {
                            val ok = preferences.edit().putInt("version", 2).putString("theme", values!!["theme"] as String).putBoolean("minimal", values["minimal"] as Boolean).putString("referenceHz", (values["referenceHz"] as Number).toDouble().toString()).commit()
                            main.post { if (ok) result.success(null) else result.error("preferences_io", "Preference write failed", null) }
                        }
                    } catch (_: Exception) { main.post { result.error("preferences_io", "Preference access failed", null) } }
                }
            }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.opentune/audio")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    stopTone()
                    val reference = call.argument<Double>("referenceHz")
                    val mode = call.argument<String>("mode") ?: "general"
                    val midi = call.argument<Number>("midi")?.toDouble() ?: -1.0
                    val association = call.argument<Number>("targetHz")?.toDouble() ?: 0.0
                    if (reference == null || !reference.isFinite() || reference !in 400.0..480.0 || mode !in listOf("general", "piano", "partial") || mode == "partial" && (!midi.isFinite() || midi !in 21.0..108.0 || midi != midi.toInt().toDouble())) result.success(mapOf("status" to "error"))
                    else start(result, reference, mode != "general", if(mode == "partial") midi.toInt() else -1,association)
                }
                "toneStart" -> {
                    val hz = call.argument<Double>("hz")
                    val voice = call.argument<Number>("voice")?.toDouble() ?: 0.0
                    val gain = call.argument<Number>("gain")?.toDouble() ?: 1.0
                    if (hz == null || !hz.isFinite() || hz !in 20.0..5000.0 || voice !in listOf(0.0, 1.0) || !gain.isFinite() || gain !in 0.0..1.0) result.success(mapOf("status" to "error"))
                    else startTone(hz, voice.toInt(), gain, result)
                }
                "toneStop" -> { if (outputKind == "tone") stopTone(); control.execute { main.post { result.success(null) } } }
                "toneStatus" -> toneStatus(result)
                "metroStart", "metroUpdate" -> {
                    val word = metroWord(call.arguments as? Map<*, *>)
                    val request = call.argument<Number>("request")?.toLong() ?: 0L
                    val level = call.argument<Number>("gain")?.toDouble() ?: 100.0
                    if (word == null || request <= 0L || !level.isFinite() || level !in 0.0..100.0 || level != level.toInt().toDouble()) result.success(mapOf("status" to "error"))
                    else if (call.method == "metroStart") startPlayback(0.0, word, request, result, metroGain = level.toInt())
                    else {
                        val owner = toneOwner
                        if (outputKind != "metronome" || request != outputRequest || owner == 0L) result.success(mapOf("status" to "replaced"))
                        else control.execute { nativeMetroUpdate(owner, word, level.toInt()); main.post { result.success(mapOf("status" to "accepted")) } }
                    }
                }
                "metroPause" -> {
                    val request = call.argument<Number>("request")?.toLong() ?: 0L
                    val paused = call.argument<Any>("paused") as? Boolean
                    val owner = toneOwner
                    if (!foreground || paused == null || request <= 0 || request != outputRequest || outputKind != "metronome" || owner == 0L) result.success(mapOf("status" to "replaced"))
                    else control.execute {
                        nativeMetroPause(owner, paused)
                        main.post { result.success(mapOf("status" to if(owner == toneOwner && request == outputRequest && foreground) "accepted" else "replaced")) }
                    }
                }
                "metroStop" -> {
                    if (outputKind == "metronome" && call.argument<Number>("request")?.toLong() == outputRequest) stopTone()
                    control.execute { main.post { result.success(null) } }
                }
                "metroStatus" -> metroStatus(call.argument<Number>("request")?.toLong() ?: 0L, result)
                "stop" -> { stop("idle"); control.execute { main.post { result.success(null) } } }
                "snapshot" -> snapshot(call.argument<Boolean>("details") == true, result)
                "settings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        audio.registerAudioDeviceCallback(deviceCallback, main)
        audio.registerAudioRecordingCallback(recordingCallback, main)
    }
    override fun onStart() { super.onStart(); foreground = true }
    // Permission dialog can pause the activity. Stop on onStop, not onPause;
    // Dart likewise ignores inactive but cancels on paused/hidden/detached.
    override fun onStop() { foreground = false; stop("background"); stopTone("background"); super.onStop() }
    override fun onResume() {
        super.onResume()
        if (activeSession != 0L && checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) stop("permission_revoked")
    }
    override fun onDestroy() {
        preferencesChannel?.setMethodCallHandler(null)
        if (::channel.isInitialized) channel.setMethodCallHandler(null)
        if (::audio.isInitialized) {
            audio.unregisterAudioDeviceCallback(deviceCallback)
            audio.unregisterAudioRecordingCallback(recordingCallback)
        }
        stop("idle"); stopTone()
        super.onDestroy()
    }
    private fun start(result: MethodChannel.Result, reference: Double, piano: Boolean, partialMidi: Int = -1, association: Double = 0.0) {
        if (!foreground) { result.success(mapOf("status" to "background")); return }
        val busy = pending != null || activeSession != 0L
        val accepted = try { if(partialMidi>=21) InputRequest.admitPartial(busy,reference,partialMidi,association) else InputRequest.admit(busy, reference, piano) } catch (_: IllegalArgumentException) { result.success(mapOf("status" to "error")); return }
        if (accepted == null) { result.success(mapOf("status" to "busy")); return }
        inputRequest = accepted
        generation = sessions.incrementAndGet()
        pending = result
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) open(generation)
        else {
            val prefs = getPreferences(MODE_PRIVATE)
            if (prefs.getBoolean("blockedMic", false) && !shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)) {
                pending = null
                result.success(mapOf("status" to "permission_settings"))
            } else {
                requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_MIC)
            }
        }
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, permissions, grants)
        if (code != REQUEST_MIC || pending == null) return
        if (grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED && foreground) {
            getPreferences(MODE_PRIVATE).edit().putBoolean("blockedMic", false).apply()
            open(generation)
        }
        else {
            val reply = pending; pending = null
            state = if (!foreground) "background" else if (shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)) "permission_denied" else "permission_settings"
            if (foreground && grants.isNotEmpty()) getPreferences(MODE_PRIVATE).edit().putBoolean("blockedMic", state == "permission_settings").apply()
            reply?.success(mapOf("status" to state))
        }
    }
    private fun open(token: Long) {
        val unprocessed = audio.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"
        val config = inputRequest ?: return
        val reference = config.referenceHz
        val piano = config.piano
        val partialMidi = config.partialMidi
        val associationHz = config.associationHz
        control.execute {
            val error = if(partialMidi>=21) nativePartialStart(token,unprocessed,reference,partialMidi,associationHz) else nativeStart(token, unprocessed, reference, piano)
            main.post {
                if (token != generation || !foreground) return@post // stop already queued
                val reply = pending; pending = null
                state = if (error.isEmpty()) "running" else "error"
                activeSession = if (error.isEmpty()) token else 0L
                reply?.success(mapOf("status" to state, "session" to token, "error" to error))
            }
        }
    }
    private fun stop(reason: String) {
        val owner = generation
        generation = sessions.incrementAndGet(); activeSession = 0L; state = reason; silenced = false
        pending?.success(mapOf("status" to reason)); pending = null
        control.execute { nativeStop(owner) }
    }
    @Suppress("DEPRECATION")
    private fun startTone(hz: Double, voice: Int, gain: Double, result: MethodChannel.Result) = startPlayback(hz, null, 0L, result, voice, gain)
    @Suppress("DEPRECATION")
    private fun startPlayback(hz: Double, word: Int?, requestId: Long, result: MethodChannel.Result, voice: Int = 0, gain: Double = 1.0, metroGain: Int = 100) {
        if (!foreground) { result.success(mapOf("status" to "background")); return }
        stop("reference"); stopTone()
        val focus = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setOnAudioFocusChangeListener(focusListener, main).build()
            focusRequest = request; audio.requestAudioFocus(request)
        } else audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        if (focus != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { stopTone(); result.success(mapOf("status" to "focus_denied")); return }
        val token = sessions.incrementAndGet(); toneOwner = token; tonePending = result
        outputKind = if (word == null) "tone" else "metronome"
        outputRequest = requestId; outputState = "playing"
        control.execute {
            val error = if (word == null) nativeToneStart(token, hz, voice, gain) else nativeMetroStart(token, word, metroGain)
            val status = if (word == null) nativeToneStatus(token) else nativeMetroStatus(token)
            main.post {
                if (token != toneOwner || !foreground) return@post
                tonePending = null
                if (error.isNotEmpty()) stopTone()
                val rate = if (word == null) status.getOrNull(1) else status.getOrNull(3)
                result.success(mapOf("status" to if(error.isEmpty()) "playing" else "error", "rate" to (rate?.toInt() ?: 0), "session" to token, "error" to error))
            }
        }
    }
    @Suppress("DEPRECATION")
    private fun stopTone(reason: String = "idle") {
        val owner = toneOwner; toneOwner = 0L
        outputState = reason
        tonePending?.success(mapOf("status" to "cancelled")); tonePending = null
        if (owner != 0L) control.execute { nativeToneStop(owner) }
        if (::audio.isInitialized) {
            if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audio.abandonAudioFocusRequest(it) }
            else audio.abandonAudioFocus(focusListener)
        }
        focusRequest = null
    }
    private fun toneStatus(result: MethodChannel.Result) {
        val owner = toneOwner
        if (owner == 0L || outputKind != "tone") { result.success(mapOf("status" to "idle")); return }
        control.execute {
            val data = nativeToneStatus(owner)
            main.post {
                if (owner != toneOwner) { result.success(mapOf("status" to "idle")); return@post }
                val playing = data[0] == 1.0
                if (!playing) stopTone()
                result.success(mapOf("status" to if(playing) "playing" else if(data[2] != 0.0) "error" else "idle", "rate" to data[1].toInt()))
            }
        }
    }
    private fun metroWord(args: Map<*, *>?): Int? {
        fun integer(key: String): Int? {
            val value = (args?.get(key) as? Number)?.toDouble() ?: return null
            return if (value.isFinite() && value == value.toInt().toDouble()) value.toInt() else null
        }
        val bpm = integer("bpm") ?: return null
        val beats = integer("beats") ?: return null
        val denominator = integer("denominator") ?: return null
        val divisions = integer("divisions") ?: return null
        val accent = args?.get("accent") as? Boolean ?: return null
        if (bpm !in 20..300 || beats !in 1..12 || denominator !in listOf(4,8) || divisions !in 1..4) return null
        return (bpm-20) or ((beats-1) shl 9) or ((if(denominator==8) 1 else 0) shl 13) or ((divisions-1) shl 14) or ((if(accent) 1 else 0) shl 16)
    }
    private fun metroStatus(requestId: Long, result: MethodChannel.Result) {
        val owner = toneOwner
        if (requestId != outputRequest || outputKind != "metronome") { result.success(mapOf("status" to "replaced")); return }
        if (owner == 0L) { result.success(mapOf("status" to outputState)); return }
        control.execute {
            val data = nativeMetroStatus(owner)
            main.post {
                if (owner != toneOwner) { result.success(mapOf("status" to "replaced")); return@post }
                val playing = MetronomeStatus.validRunning(data, owner)
                if (!playing) stopTone("interrupted")
                result.success(mapOf("status" to if(playing) "playing" else "interrupted", "data" to data.toList()))
            }
        }
    }
    private fun snapshot(details: Boolean, result: MethodChannel.Result) {
        if (activeSession == 0L) { result.success(mapOf("status" to state)); return }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            stop("permission_revoked"); result.success(mapOf("status" to state)); return
        }
        if (audio.isMicrophoneMute || silenced) {
            stop("silenced"); result.success(mapOf("status" to state)); return
        }
        val token = generation
        control.execute {
            val data = nativeSnapshot(details)
            main.post {
                if (token != generation) { result.success(mapOf("status" to state)); return@post }
                if (data.size >= 30) audioSessionId = data[29].toInt()
                if (Build.VERSION.SDK_INT >= 29 && audioSessionId > 0 && audio.activeRecordingConfigurations.any { it.clientAudioSessionId == audioSessionId && it.isClientSilenced }) stop("silenced")
                if (data.size >= 30 && data[23] != 0.0) stop("interrupted")
                result.success(mapOf("status" to state, "data" to data.toList(), "processing" to "unknown"))
            }
        }
    }
}
