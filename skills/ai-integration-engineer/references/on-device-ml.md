# On-Device Machine Learning

## ML Kit

Google's ML Kit provides ready-to-use models that run on-device.

### Setup

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("com.google.mlkit:image-labeling:17.0.9")
    implementation("com.google.mlkit:translate:17.0.3")
    implementation("com.google.mlkit:smart-reply:17.0.4")
}
```

### Text Recognition (OCR)

```kotlin
class TextRecognitionHelper {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    suspend fun recognizeText(bitmap: Bitmap): String {
        val image = InputImage.fromBitmap(bitmap, 0)
        return suspendCoroutine { cont ->
            recognizer.process(image)
                .addOnSuccessListener { result -> cont.resume(result.text) }
                .addOnFailureListener { e -> cont.resumeWithException(e) }
        }
    }
}
```

### Barcode Scanning

```kotlin
val scanner = BarcodeScanning.getClient(
    BarcodeScannerOptions.Builder()
        .setBarcodeFormats(Barcode.FORMAT_QR_CODE, Barcode.FORMAT_EAN_13)
        .build()
)

suspend fun scanBarcode(image: InputImage): List<Barcode> =
    suspendCoroutine { cont ->
        scanner.process(image)
            .addOnSuccessListener { barcodes -> cont.resume(barcodes) }
            .addOnFailureListener { e -> cont.resumeWithException(e) }
    }
```

### Image Labeling

```kotlin
val labeler = ImageLabeling.getClient(
    ImageLabelerOptions.Builder().setConfidenceThreshold(0.7f).build()
)

suspend fun labelImage(bitmap: Bitmap): List<Pair<String, Float>> {
    val image = InputImage.fromBitmap(bitmap, 0)
    return suspendCoroutine { cont ->
        labeler.process(image)
            .addOnSuccessListener { labels ->
                cont.resume(labels.map { it.text to it.confidence })
            }
            .addOnFailureListener { e -> cont.resumeWithException(e) }
    }
}
```

### On-Device Translation

```kotlin
class TranslationHelper {
    suspend fun translate(text: String, source: String, target: String): String {
        val options = TranslatorOptions.Builder()
            .setSourceLanguage(source)
            .setTargetLanguage(target)
            .build()
        val translator = Translation.getClient(options)

        // Download model if needed
        translator.downloadModelIfNeeded().await()
        return translator.translate(text).await()
    }
}
```

## MediaPipe

Google's framework for building multimodal ML pipelines.

### Gesture Recognition

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.google.mediapipe:tasks-vision:0.20241104.1")
}
```

```kotlin
class GestureHelper(context: Context) {
    private val gestureRecognizer: GestureRecognizer

    init {
        val options = GestureRecognizer.GestureRecognizerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath("gesture_recognizer.task")
                    .build()
            )
            .setRunningMode(RunningMode.IMAGE)
            .build()
        gestureRecognizer = GestureRecognizer.createFromOptions(context, options)
    }

    fun recognize(bitmap: Bitmap): List<String> {
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = gestureRecognizer.recognize(mpImage)
        return result.gestures().flatMap { it.map { g -> g.categoryName() } }
    }
}
```

### Object Detection

```kotlin
val objectDetector = ObjectDetector.createFromOptions(
    context,
    ObjectDetector.ObjectDetectorOptions.builder()
        .setBaseOptions(
            BaseOptions.builder()
                .setModelAssetPath("efficientdet_lite0.tflite")
                .build()
        )
        .setMaxResults(5)
        .setScoreThreshold(0.5f)
        .build()
)
```

## TensorFlow Lite

### Custom Model Inference

```kotlin
// build.gradle.kts
dependencies {
    implementation("org.tensorflow:tensorflow-lite:2.17.0")
    implementation("org.tensorflow:tensorflow-lite-support:0.4.4")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.17.0")
}
```

```kotlin
class TFLiteClassifier(context: Context) {
    private val interpreter: Interpreter

    init {
        val model = FileUtil.loadMappedFile(context, "model.tflite")
        val options = Interpreter.Options().apply {
            setNumThreads(4)
            // Use GPU if available
            addDelegate(GpuDelegate())
        }
        interpreter = Interpreter(model, options)
    }

    fun classify(input: FloatArray): FloatArray {
        val output = Array(1) { FloatArray(NUM_CLASSES) }
        interpreter.run(arrayOf(input), output)
        return output[0]
    }

    fun close() {
        interpreter.close()
    }
}
```

## ONNX Runtime

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.19.0")
}
```

```kotlin
class OnnxInference(context: Context) {
    private val session: OrtSession

    init {
        val env = OrtEnvironment.getEnvironment()
        val modelBytes = context.assets.open("model.onnx").readBytes()
        session = env.createSession(modelBytes)
    }

    fun run(input: FloatArray, shape: LongArray): FloatArray {
        val env = OrtEnvironment.getEnvironment()
        val tensor = OnnxTensor.createTensor(env, FloatBuffer.wrap(input), shape)
        val results = session.run(mapOf("input" to tensor))
        val output = results[0].value as Array<FloatArray>
        return output[0]
    }
}
```

## Model Optimization

| Technique | Size Reduction | Speed Impact | Quality Impact |
|-----------|---------------|-------------|----------------|
| Float16 quantization | ~50% | Faster on GPU | Minimal |
| INT8 quantization | ~75% | Faster on CPU | Small |
| Dynamic quantization | ~75% | Variable | Small |
| Pruning | 50–90% | Faster | Moderate |
| Knowledge distillation | N/A | Much faster | Moderate |

## Performance Considerations

- **Model loading**: load in background thread, cache the interpreter
- **Inference**: run on background dispatcher, never on main thread
- **Memory**: release models when not in use, use GPU delegation when available
- **Battery**: batch inferences, avoid continuous camera processing when possible
- **Size**: bundle only needed models, download optional models on first use
