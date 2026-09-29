package dev.nagcode.paddleocr

import android.content.Context
import com.paddle.ocr.EngineConfig
import com.paddle.ocr.PaddleOCR
import com.paddle.ocr.PaddleOCRConfig
import com.paddle.ocr.util.OpenCVUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class PaddleOcrPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var applicationContext: Context
    private var channel: MethodChannel? = null
    private var ocr: PaddleOCR? = null
    private val mutex = Mutex()
    private var scope = createScope()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        scope = createScope()
        channel = MethodChannel(
            binding.binaryMessenger,
            "dev.nagcode.prova_social/paddle_ocr",
        ).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recognize" -> recognize(call, result)
            else -> result.notImplemented()
        }
    }

    private fun recognize(call: MethodCall, result: MethodChannel.Result) {
        val imageBytes = call.argument<ByteArray>("image")
        if (imageBytes == null || imageBytes.isEmpty() || imageBytes.size > MAX_IMAGE_BYTES) {
            result.error("invalid_image", "A imagem da página é inválida.", null)
            return
        }

        scope.launch {
            try {
                val run = mutex.withLock {
                    val engine = ocr ?: createEngine().also { ocr = it }
                    engine.recognize(imageBytes)
                }
                result.success(
                    mapOf(
                        "lines" to run.results.map { line ->
                            mapOf(
                                "text" to line.text,
                                "confidence" to line.confidence.toDouble(),
                                "points" to line.box.points.map { point ->
                                    listOf(point.x.toDouble(), point.y.toDouble())
                                },
                            )
                        },
                        "elapsedMs" to run.totalTimeMs,
                    ),
                )
            } catch (_: Exception) {
                result.error(
                    "paddle_ocr_failed",
                    "Não foi possível executar PaddleOCR nesta página.",
                    null,
                )
            }
        }
    }

    private suspend fun createEngine(): PaddleOCR {
        check(OpenCVUtils.init(applicationContext)) { "OpenCV indisponível" }
        return PaddleOCR.create(
            context = applicationContext,
            config = PaddleOCRConfig(recBatchSize = 1),
            engineConfig = EngineConfig(numThreads = 2),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        scope.launch {
            try {
                mutex.withLock {
                    ocr?.release()
                    ocr = null
                }
            } finally {
                scope.cancel()
            }
        }
    }

    private fun createScope() = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private companion object {
        const val MAX_IMAGE_BYTES = 20 * 1024 * 1024
    }
}
