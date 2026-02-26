package com.quicksave.quicksave_app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.quicksave.quicksave_app/muxer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "muxVideoAudio" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")

                    if (videoPath == null || audioPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val success = muxVideoAudio(videoPath, audioPath, outputPath)
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("MUX_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractAudioOnly" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val success = extractAudioOnly(inputPath, outputPath)
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "nativeDownload" -> {
                    val url = call.argument<String>("url")
                    val outputPath = call.argument<String>("outputPath")

                    if (url == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val bytesDownloaded = nativeDownload(url, outputPath)
                            runOnUiThread { result.success(bytesDownloaded) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DOWNLOAD_ERROR", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun muxVideoAudio(videoPath: String, audioPath: String, outputPath: String): Boolean {
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        // Extract video track
        val videoExtractor = MediaExtractor()
        videoExtractor.setDataSource(videoPath)
        var videoTrackIndex = -1
        for (i in 0 until videoExtractor.trackCount) {
            val format = videoExtractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("video/")) {
                videoTrackIndex = i
                break
            }
        }

        // Extract audio track
        val audioExtractor = MediaExtractor()
        audioExtractor.setDataSource(audioPath)
        var audioTrackIndex = -1
        for (i in 0 until audioExtractor.trackCount) {
            val format = audioExtractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                break
            }
        }

        if (videoTrackIndex == -1 || audioTrackIndex == -1) {
            videoExtractor.release()
            audioExtractor.release()
            muxer.release()
            return false
        }

        // Add tracks to muxer
        videoExtractor.selectTrack(videoTrackIndex)
        val videoFormat = videoExtractor.getTrackFormat(videoTrackIndex)
        val muxerVideoTrack = muxer.addTrack(videoFormat)

        audioExtractor.selectTrack(audioTrackIndex)
        val audioFormat = audioExtractor.getTrackFormat(audioTrackIndex)
        val muxerAudioTrack = muxer.addTrack(audioFormat)

        muxer.start()

        val buffer = ByteBuffer.allocate(1024 * 1024) // 1MB buffer
        val bufferInfo = MediaCodec.BufferInfo()

        // Copy video samples
        while (true) {
            val sampleSize = videoExtractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = videoExtractor.sampleTime
            bufferInfo.flags = videoExtractor.sampleFlags
            muxer.writeSampleData(muxerVideoTrack, buffer, bufferInfo)
            videoExtractor.advance()
        }

        // Copy audio samples
        while (true) {
            val sampleSize = audioExtractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = audioExtractor.sampleTime
            bufferInfo.flags = audioExtractor.sampleFlags
            muxer.writeSampleData(muxerAudioTrack, buffer, bufferInfo)
            audioExtractor.advance()
        }

        muxer.stop()
        muxer.release()
        videoExtractor.release()
        audioExtractor.release()

        return true
    }

    private fun nativeDownload(urlString: String, outputPath: String): Long {
        val url = URL(urlString)
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 15; Pixel 8 Pro Build/AP4A.250205.002) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.6943.137 Mobile Safari/537.36")
        connection.setRequestProperty("Accept", "*/*")
        connection.setRequestProperty("Accept-Language", "en-US,en;q=0.9")
        connection.setRequestProperty("Accept-Encoding", "identity")
        connection.setRequestProperty("Connection", "keep-alive")
        connection.connectTimeout = 30000
        connection.readTimeout = 300000 // 5 min for large files
        connection.instanceFollowRedirects = true

        val responseCode = connection.responseCode
        if (responseCode != HttpURLConnection.HTTP_OK) {
            connection.disconnect()
            throw Exception("HTTP $responseCode: ${connection.responseMessage}")
        }

        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()

        var totalBytes: Long = 0
        connection.inputStream.use { input ->
            FileOutputStream(outputFile).use { output ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalBytes += bytesRead
                }
            }
        }

        connection.disconnect()
        return totalBytes
    }

    private fun extractAudioOnly(inputPath: String, outputPath: String): Boolean {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // Find audio track
        var audioTrackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                break
            }
        }

        if (audioTrackIndex == -1) {
            extractor.release()
            return false
        }

        extractor.selectTrack(audioTrackIndex)
        val audioFormat = extractor.getTrackFormat(audioTrackIndex)

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val muxerTrack = muxer.addTrack(audioFormat)
        muxer.start()

        val buffer = ByteBuffer.allocate(1024 * 1024)
        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = extractor.sampleTime
            bufferInfo.flags = extractor.sampleFlags
            muxer.writeSampleData(muxerTrack, buffer, bufferInfo)
            extractor.advance()
        }

        muxer.stop()
        muxer.release()
        extractor.release()

        return true
    }
}
