package com.moon.nexora

import android.graphics.Rect
import android.os.Build
import android.view.Window
import android.view.WindowInsets
import android.view.WindowInsetsController
import kotlin.math.roundToInt

internal class DesktopCaption(private val window: Window) {
    fun update(
        enabled: Boolean,
        dark: Boolean,
        flutterTopInset: Double,
        minimumWidth: Int,
    ): Map<String, Double>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return null

        val decor = window.decorView
        val density = decor.resources.displayMetrics.density
        val bounds = if (enabled) {
            availableBounds(decor.rootWindowInsets, decor.width, density, minimumWidth)
                ?.takeIf { kotlin.math.abs(it.height() / density - flutterTopInset) < 1 }
        } else {
            null
        }
        val transparent = WindowInsetsController.APPEARANCE_TRANSPARENT_CAPTION_BAR_BACKGROUND
        val light = WindowInsetsController.APPEARANCE_LIGHT_CAPTION_BARS
        val appearance = when {
            bounds == null -> 0
            dark -> transparent
            else -> transparent or light
        }
        window.insetsController?.setSystemBarsAppearance(appearance, transparent or light)
        decor.systemGestureExclusionRects = listOfNotNull(bounds)

        return bounds?.let {
            mapOf(
                "width" to decor.width.toDouble() / density,
                "height" to it.height().toDouble() / density,
                "left" to it.left.toDouble() / density,
                "right" to (decor.width - it.right).toDouble() / density,
            )
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.VANILLA_ICE_CREAM)
    private fun availableBounds(
        insets: WindowInsets?,
        width: Int,
        density: Float,
        minimumWidth: Int,
    ): Rect? {
        val caption = WindowInsets.Type.captionBar()
        if (insets == null || !insets.isVisible(caption)) return null
        val height = insets.getInsets(caption).top
        val topInset = insets.getInsets(
            WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
        ).top
        if (height <= 0 || topInset != height) return null

        val occupied = insets.getBoundingRects(caption)
            .filter { it.top < height && it.bottom > 0 && it.right > 0 && it.left < width }
            .sortedBy { it.left }
        // Keep the regular header if the window manager doesn't report its controls.
        if (occupied.isEmpty()) return null

        var start = 0
        var best = Rect()
        for (rect in occupied + Rect(width, 0, width, height)) {
            val end = rect.left.coerceIn(0, width)
            if (end - start > best.width()) best = Rect(start, 0, end, height)
            start = maxOf(start, rect.right.coerceIn(0, width))
        }
        // Leave part of the system caption available for dragging the window.
        best.right -= (48 * density).roundToInt()
        return best.takeIf { it.width() >= (minimumWidth * density).roundToInt() }
    }
}
