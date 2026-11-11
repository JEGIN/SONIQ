package com.soniq.soniq.dsp

import android.app.UiModeManager
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.hardware.usb.UsbManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaCodecList
import android.media.audiofx.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.hypot
import kotlin.math.log10

class NativeAudioDspEngine(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    private val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soniq.soniq/dsp")
    private val visualizerEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soniq.soniq/visualizer")
    private val deviceEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soniq.soniq/device_route")

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var visualizerEventSink: EventChannel.EventSink? = null
    private var deviceEventSink: EventChannel.EventSink? = null

    // Native Audio Effects
    private var currentSessionId: Int = 0
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var visualizer: Visualizer? = null

    // State cache
    private var isEqEnabled = true
    private var isBassBoostEnabled = true
    private var isVirtualizerEnabled = true
    private var isLoudnessEnabled = true
    private var isVisualizerEnabled = true

    private var currentPreampDb: Double = 0.0
    private var currentBassStrength: Int = 0 // 0..1000
    private var currentTrebleDb: Double = 0.0 // -12..+12
    private var currentVirtualizerStrength: Int = 0 // 0..1000
    private var currentStereoWidthPercent: Int = 100 // 0..150
    private var currentVirtualizerMode: String = "auto" // binaural / transaural / auto
    private var currentBalance: Double = 0.0 // -1.0..+1.0

    // Standard 10-band target frequencies in Hz
    private val target10BandFreqs = listOf(31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)
    private val bandGains = DoubleArray(10) { 0.0 } // in dB (-12.0 to +12.0)

    fun setup() {
        methodChannel.setMethodCallHandler(this)

        visualizerEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                visualizerEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                visualizerEventSink = null
            }
        })

        deviceEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                deviceEventSink = events
                // Emit initial device
                emitCurrentDevice()
            }

            override fun onCancel(arguments: Any?) {
                deviceEventSink = null
            }
        })

        registerDeviceCallback()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attachSession" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                attachSession(sessionId)
                result.success(getDspCapabilities())
            }
            "setEqualizerEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                isEqEnabled = enabled
                try {
                    equalizer?.enabled = enabled
                } catch (_: Exception) {}
                result.success(true)
            }
            "set10BandGains" -> {
                val gains = call.argument<List<Double>>("gains")
                if (gains != null && gains.size == 10) {
                    for (i in 0 until 10) {
                        bandGains[i] = gains[i]
                    }
                    applyBandGainsToNative()
                }
                result.success(true)
            }
            "setBandGain" -> {
                val bandIndex = call.argument<Int>("band") ?: 0
                val gainDb = call.argument<Double>("gain") ?: 0.0
                if (bandIndex in 0..9) {
                    bandGains[bandIndex] = gainDb
                    applyBandGainsToNative()
                }
                result.success(true)
            }
            "setPreamp" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                currentPreampDb = gainDb
                applyPreamp()
                result.success(true)
            }
            "setBassBoost" -> {
                val strength = call.argument<Int>("strength") ?: 0 // 0..1000
                currentBassStrength = strength.coerceIn(0, 1000)
                try {
                    bassBoost?.setStrength(currentBassStrength.toShort())
                } catch (_: Exception) {}
                result.success(true)
            }
            "setTrebleBoost" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                currentTrebleDb = gainDb
                // Treble boost affects high bands (8kHz and 16kHz)
                bandGains[8] = gainDb
                bandGains[9] = gainDb
                applyBandGainsToNative()
                result.success(true)
            }
            "setVirtualizerStrength" -> {
                val strength = call.argument<Int>("strength") ?: 0 // 0..1000
                currentVirtualizerStrength = strength.coerceIn(0, 1000)
                try {
                    virtualizer?.setStrength(currentVirtualizerStrength.toShort())
                } catch (_: Exception) {}
                result.success(true)
            }
            "setVirtualizerMode" -> {
                val mode = call.argument<String>("mode") ?: "auto"
                currentVirtualizerMode = mode
                applyVirtualizerMode()
                result.success(true)
            }
            "setStereoWidth" -> {
                val width = call.argument<Int>("width") ?: 100 // 0..150%
                currentStereoWidthPercent = width.coerceIn(0, 150)
                if (currentStereoWidthPercent == 0) {
                    // Mono downmix
                    try {
                        virtualizer?.enabled = false
                    } catch (_: Exception) {}
                } else {
                    try {
                        virtualizer?.enabled = isVirtualizerEnabled
                        val strength = ((currentStereoWidthPercent - 50) * 10).coerceIn(0, 1000)
                        virtualizer?.setStrength(strength.toShort())
                    } catch (_: Exception) {}
                }
                result.success(true)
            }
            "setChannelBalance" -> {
                val balance = call.argument<Double>("balance") ?: 0.0 // -1.0 to +1.0
                currentBalance = balance.coerceIn(-1.0, 1.0)
                // Returns left and right volume multipliers to Flutter audio player
                val left = if (currentBalance > 0) 1.0 - currentBalance else 1.0
                val right = if (currentBalance < 0) 1.0 + currentBalance else 1.0
                result.success(mapOf("left" to left, "right" to right))
            }
            "setLimiterEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                // In native LoudnessEnhancer or dynamic limiter
                result.success(true)
            }
            "setVisualizerEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                isVisualizerEnabled = enabled
                try {
                    visualizer?.enabled = enabled
                } catch (_: Exception) {}
                result.success(true)
            }
            "getConnectedOutputDevice" -> {
                result.success(getCurrentDeviceType())
            }
            "getDeviceCapabilities" -> {
                result.success(getDeviceCapabilitiesSnapshot())
            }
            "setHighRefreshRate" -> {
                result.success(setHighRefreshRate(call.argument<Boolean>("enabled") ?: false))
            }
            "isCarConnected" -> {
                result.success(isCarModeActive())
            }
            "getAudioFileSpecs" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(getAudioFileSpecs(path))
            }
            else -> result.notImplemented()
        }
    }

    @Synchronized
    fun attachSession(sessionId: Int) {
        if (sessionId <= 0 || sessionId == currentSessionId && equalizer != null) return
        releaseEffects()
        currentSessionId = sessionId

        try {
            // 1. Equalizer (Priority 1000)
            equalizer = Equalizer(1000, sessionId).apply {
                enabled = isEqEnabled
            }
            applyBandGainsToNative()
        } catch (e: Exception) {
            android.util.Log.e("SONIQ_DSP", "Equalizer attach error: $e")
        }

        try {
            // 2. BassBoost
            bassBoost = BassBoost(1000, sessionId).apply {
                enabled = isBassBoostEnabled
                if (strengthSupported) {
                    setStrength(currentBassStrength.toShort())
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("SONIQ_DSP", "BassBoost attach error: $e")
        }

        try {
            // 3. Virtualizer (Surround / Stereo Widening)
            virtualizer = Virtualizer(1000, sessionId).apply {
                enabled = isVirtualizerEnabled
                if (strengthSupported) {
                    setStrength(currentVirtualizerStrength.toShort())
                }
            }
            applyVirtualizerMode()
        } catch (e: Exception) {
            android.util.Log.e("SONIQ_DSP", "Virtualizer attach error: $e")
        }

        try {
            // 4. LoudnessEnhancer (Preamp & Dynamic Range)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                loudnessEnhancer = LoudnessEnhancer(sessionId).apply {
                    enabled = isLoudnessEnabled
                }
                applyPreamp()
            }
        } catch (e: Exception) {
            android.util.Log.e("SONIQ_DSP", "LoudnessEnhancer attach error: $e")
        }

        try {
            // 5. Visualizer (Spectrum analyzer & FFT)
            setupVisualizer(sessionId)
        } catch (e: Exception) {
            android.util.Log.e("SONIQ_DSP", "Visualizer attach error: $e")
        }
    }

    private fun setupVisualizer(sessionId: Int) {
        try {
            visualizer?.release()
            visualizer = Visualizer(sessionId).apply {
                captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(256)
                setDataCaptureListener(
                    object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(viz: Visualizer?, waveform: ByteArray?, samplingRate: Int) {}

                        override fun onFftDataCapture(viz: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                            if (fft != null && visualizerEventSink != null) {
                                processFftAndEmit(fft)
                            }
                        }
                    },
                    Visualizer.getMaxCaptureRate() / 2,
                    false,
                    true
                )
                enabled = isVisualizerEnabled
            }
        } catch (e: Exception) {
            android.util.Log.e("SONIQ_DSP", "Visualizer setup failed: $e")
        }
    }

    private fun processFftAndEmit(fft: ByteArray) {
        val numBars = 16
        val magnitudes = DoubleArray(numBars)
        val n = fft.size / 2
        val step = (n / numBars).coerceAtLeast(1)

        for (i in 0 until numBars) {
            var sum = 0.0
            val start = i * step
            val end = ((i + 1) * step).coerceAtMost(n)

            for (j in start until end) {
                val realIndex = 2 * j
                val imagIndex = 2 * j + 1
                if (imagIndex < fft.size) {
                    val r = fft[realIndex].toDouble()
                    val im = fft[imagIndex].toDouble()
                    sum += hypot(r, im)
                }
            }

            val avg = sum / (end - start).coerceAtLeast(1)
            // Logarithmic normalization
            val db = if (avg > 0) 20 * log10(avg / 128.0) + 60 else 0.0
            magnitudes[i] = (db / 60.0).coerceIn(0.0, 1.0)
        }

        mainHandler.post {
            visualizerEventSink?.success(magnitudes.toList())
        }
    }

    private fun applyBandGainsToNative() {
        val eq = equalizer ?: return
        val numNativeBands = eq.numberOfBands.toInt()
        val range = eq.bandLevelRange // [min, max] in millibels (e.g. -1500 to +1500)
        val minMb = range[0].toInt()
        val maxMb = range[1].toInt()

        for (nativeIdx in 0 until numNativeBands) {
            val centerFreqHz = eq.getCenterFreq(nativeIdx.toShort()) / 1000 // Convert mHz to Hz

            val targetGainDb: Double
            if (numNativeBands == 10 && nativeIdx in 0..9) {
                targetGainDb = bandGains[nativeIdx]
            } else {
                // Logarithmic continuous piecewise interpolation across ISO 10 octave bands
                val freqLog = log10(centerFreqHz.toDouble().coerceAtLeast(20.0))
                val firstLog = log10(target10BandFreqs.first().toDouble())
                val lastLog = log10(target10BandFreqs.last().toDouble())

                if (freqLog <= firstLog) {
                    targetGainDb = bandGains[0]
                } else if (freqLog >= lastLog) {
                    targetGainDb = bandGains[9]
                } else {
                    var interpolated = 0.0
                    for (i in 0 until target10BandFreqs.size - 1) {
                        val f1Log = log10(target10BandFreqs[i].toDouble())
                        val f2Log = log10(target10BandFreqs[i + 1].toDouble())
                        if (freqLog >= f1Log && freqLog <= f2Log) {
                            val alpha = (freqLog - f1Log) / (f2Log - f1Log)
                            interpolated = (1.0 - alpha) * bandGains[i] + alpha * bandGains[i + 1]
                            break
                        }
                    }
                    targetGainDb = interpolated
                }
            }

            // Convert dB to millibels (1 dB = 100 mB) with clipping safety
            val levelMb = (targetGainDb * 100).toInt().coerceIn(minMb, maxMb)
            try {
                eq.setBandLevel(nativeIdx.toShort(), levelMb.toShort())
            } catch (_: Exception) {}
        }
    }

    private fun getAudioFileSpecs(filePath: String): Map<String, Any?> {
        val retriever = android.media.MediaMetadataRetriever()
        return try {
            retriever.setDataSource(filePath)
            val bitrateStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val sampleRateStr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_SAMPLERATE)
            } else null
            val mimeType = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
            val durationStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)

            val bitrateBps = bitrateStr?.toLongOrNull() ?: 0L
            val sampleRateHz = sampleRateStr?.toIntOrNull() ?: 44100
            val durationMs = durationStr?.toLongOrNull() ?: 0L

            mapOf(
                "bitrateBps" to bitrateBps,
                "sampleRateHz" to sampleRateHz,
                "mimeType" to (mimeType ?: "audio/mpeg"),
                "durationMs" to durationMs,
                "nativeBandsCount" to (equalizer?.numberOfBands?.toInt() ?: 10),
                "activeSessionId" to currentSessionId,
                "isEqActive" to isEqEnabled,
                "isBassActive" to isBassBoostEnabled,
                "isVirtualizerActive" to isVirtualizerEnabled,
                "isLoudnessActive" to isLoudnessEnabled,
                "outputDevice" to getCurrentDeviceType()
            )
        } catch (e: Exception) {
            mapOf(
                "error" to (e.localizedMessage ?: "File read error"),
                "sampleRateHz" to 44100,
                "bitrateBps" to 320000L,
                "mimeType" to "audio/mpeg",
                "outputDevice" to getCurrentDeviceType()
            )
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }

    private fun applyPreamp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val enhancer = loudnessEnhancer ?: return
            try {
                // Preamp from -6 dB to +6 dB converted to mB (e.g. 0 to 600 mB target gain)
                val targetMb = ((currentPreampDb.coerceAtLeast(0.0)) * 100).toInt().coerceIn(0, 1000)
                enhancer.setTargetGain(targetMb)
            } catch (_: Exception) {}
        }
    }

    private fun applyVirtualizerMode() {
        val virt = virtualizer ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                when (currentVirtualizerMode) {
                    "binaural" -> virt.forceVirtualizationMode(Virtualizer.VIRTUALIZATION_MODE_BINAURAL)
                    "transaural" -> virt.forceVirtualizationMode(Virtualizer.VIRTUALIZATION_MODE_TRANSAURAL)
                    else -> virt.forceVirtualizationMode(Virtualizer.VIRTUALIZATION_MODE_AUTO)
                }
            } catch (_: Exception) {}
        }
    }

    private fun getDspCapabilities(): Map<String, Any> {
        val eq = equalizer
        val numBands = eq?.numberOfBands?.toInt() ?: 10
        val range = eq?.bandLevelRange ?: shortArrayOf(-1500, 1500)
        val centerFreqs = mutableListOf<Int>()

        if (eq != null) {
            for (i in 0 until numBands) {
                centerFreqs.add(eq.getCenterFreq(i.toShort()) / 1000)
            }
        } else {
            centerFreqs.addAll(target10BandFreqs)
        }

        return mapOf(
            "numBands" to numBands,
            "minLevelMb" to range[0].toInt(),
            "maxLevelMb" to range[1].toInt(),
            "centerFreqsHz" to centerFreqs,
            "hasBassBoost" to (bassBoost != null),
            "hasVirtualizer" to (virtualizer != null),
            "hasLoudness" to (loudnessEnhancer != null),
            "outputDevice" to getCurrentDeviceType()
        )
    }

    private var isCarReceiverRegistered = false
    private val carModeReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            emitCurrentDevice()
        }
    }

    private fun registerDeviceCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.registerAudioDeviceCallback(object : android.media.AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                    emitCurrentDevice()
                }

                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                    emitCurrentDevice()
                }
            }, mainHandler)
        }

        try {
            val filter = IntentFilter().apply {
                addAction(UiModeManager.ACTION_ENTER_CAR_MODE)
                addAction(UiModeManager.ACTION_EXIT_CAR_MODE)
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            }
            context.registerReceiver(carModeReceiver, filter)
            isCarReceiverRegistered = true
        } catch (_: Exception) {}
    }

    private fun isCarModeActive(): Boolean {
        try {
            val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            if (uiModeManager != null && uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_CAR) {
                return true
            }
        } catch (_: Exception) {}

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in devices) {
                val productName = device.productName?.toString()?.lowercase() ?: ""
                if (device.type == AudioDeviceInfo.TYPE_USB_DEVICE || device.type == AudioDeviceInfo.TYPE_USB_HEADSET) {
                    if (productName.contains("car") || productName.contains("auto") || productName.contains("renault") || productName.contains("triber") || productName.contains("medianav")) {
                        return true
                    }
                }
                if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP) {
                    if (productName.contains("car") || productName.contains("renault") || productName.contains("triber") || productName.contains("medianav")) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private fun getCurrentDeviceType(): String {
        if (isCarModeActive()) {
            return "car"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in devices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_REMOTE_SUBMIX,
                    AudioDeviceInfo.TYPE_HDMI,
                    AudioDeviceInfo.TYPE_HDMI_ARC,
                    AudioDeviceInfo.TYPE_HDMI_EARC,
                    AudioDeviceInfo.TYPE_DOCK -> return "cast"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> return "bluetooth"
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> return "wired_headphones"
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> return "usb"
                }
            }
        }
        return "speaker"
    }

    private fun getDeviceCapabilitiesSnapshot(): Map<String, Any> {
        val outputDevices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .map { device ->
                    val productName = device.productName?.toString()?.takeIf { it.isNotBlank() }
                    productName ?: outputTypeName(device.type)
                }
                .distinct()
        } else {
            listOf("Device speaker")
        }

        val codecs = try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
                .filter { codec -> !codec.isEncoder }
                .flatMap { codec -> codec.supportedTypes.toList() }
                .distinct()
        } catch (_: Exception) {
            emptyList()
        }
        val decoderNames = try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
                .filter { codec -> !codec.isEncoder }
                .map { codec -> codec.name }
                .distinct()
        } catch (_: Exception) {
            emptyList()
        }

        val display = (context as? Activity)?.window?.decorView?.display
        val maxRefresh = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            display?.supportedModes?.maxByOrNull { mode -> mode.refreshRate }?.refreshRate
        } else {
            display?.refreshRate
        }

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "platform" to "Android ${Build.VERSION.RELEASE}",
            "apiLevel" to Build.VERSION.SDK_INT,
            "currentOutput" to getCurrentDeviceType(),
            "outputs" to outputDevices,
            "decoderMimeTypes" to codecs,
            "decoderNames" to decoderNames,
            "refreshRate" to (display?.refreshRate ?: 0f),
            "maxRefreshRate" to (maxRefresh ?: 0f)
        )
    }

    private fun outputTypeName(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth audio"
        AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired headphones"
        AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "USB audio"
        AudioDeviceInfo.TYPE_REMOTE_SUBMIX,
        AudioDeviceInfo.TYPE_HDMI,
        AudioDeviceInfo.TYPE_HDMI_ARC,
        AudioDeviceInfo.TYPE_HDMI_EARC,
        AudioDeviceInfo.TYPE_DOCK -> "Cast / HDMI audio"
        else -> "Device speaker"
    }

    private fun setHighRefreshRate(enabled: Boolean): Boolean {
        val activity = context as? Activity ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            val window = activity.window
            val display = window.decorView.display
            val preferredRate = if (enabled) {
                display?.supportedModes?.maxByOrNull { mode -> mode.refreshRate }?.refreshRate ?: 0f
            } else {
                0f
            }
            val attributes = window.attributes
            attributes.preferredRefreshRate = preferredRate
            window.attributes = attributes
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun emitCurrentDevice() {
        val deviceType = getCurrentDeviceType()
        mainHandler.post {
            deviceEventSink?.success(deviceType)
        }
    }

    fun release() {
        if (isCarReceiverRegistered) {
            try {
                context.unregisterReceiver(carModeReceiver)
                isCarReceiverRegistered = false
            } catch (_: Exception) {}
        }
        releaseEffects()
        methodChannel.setMethodCallHandler(null)
    }

    private fun releaseEffects() {
        try {
            visualizer?.apply {
                enabled = false
                release()
            }
            visualizer = null
        } catch (_: Exception) {}

        try {
            equalizer?.apply {
                enabled = false
                release()
            }
            equalizer = null
        } catch (_: Exception) {}

        try {
            bassBoost?.apply {
                enabled = false
                release()
            }
            bassBoost = null
        } catch (_: Exception) {}

        try {
            virtualizer?.apply {
                enabled = false
                release()
            }
            virtualizer = null
        } catch (_: Exception) {}

        try {
            loudnessEnhancer?.apply {
                enabled = false
                release()
            }
            loudnessEnhancer = null
        } catch (_: Exception) {}
    }
}
