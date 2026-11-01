package com.brivio.center

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatActivity
import com.airbnb.lottie.LottieAnimationView

@SuppressLint("CustomSplashScreen")
class SplashActivity : AppCompatActivity() {

    private var hasNavigated = false
    private val handler = Handler(Looper.getMainLooper())
    private val safetyTimeoutRunnable = Runnable {
        navigateToMain()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)

        val lottieView = findViewById<LottieAnimationView>(R.id.lottieAnimationView)

        // Safety timeout in case animation fails to trigger onAnimationEnd
        handler.postDelayed(safetyTimeoutRunnable, 5000)

        lottieView.addAnimatorListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                navigateToMain()
            }
        })

        // Allow instant skip on tap
        lottieView.setOnClickListener {
            navigateToMain()
        }
    }

    private fun navigateToMain() {
        if (hasNavigated || isFinishing || isDestroyed) return
        hasNavigated = true
        handler.removeCallbacks(safetyTimeoutRunnable)

        val intent = Intent(this, MainActivity::class.java)
        if (getIntent().extras != null) {
            intent.putExtras(getIntent().extras!!)
        }
        if (getIntent().data != null) {
            intent.data = getIntent().data
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)

        startActivity(intent)
        finish()
        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
    }

    override fun onDestroy() {
        handler.removeCallbacks(safetyTimeoutRunnable)
        super.onDestroy()
    }
}
