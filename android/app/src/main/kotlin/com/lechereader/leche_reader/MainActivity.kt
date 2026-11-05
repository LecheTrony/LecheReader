package com.lechereader.leche_reader

import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var immersive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.lechereader.leche_reader/immersive",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enter" -> {
                    immersive = true
                    hideSystemBars()
                    result.success(null)
                }

                "exit" -> {
                    immersive = false
                    showSystemBars()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Flutter restaura las barras al reanudar la actividad. Volvemos a ocultarlas
    // si el lector sigue abierto.
    override fun onPostResume() {
        super.onPostResume()
        if (immersive) hideSystemBars()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && immersive) hideSystemBars()
    }

    private fun hideSystemBars() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.systemBars())
    }

    private fun showSystemBars() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.show(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
    }
}
