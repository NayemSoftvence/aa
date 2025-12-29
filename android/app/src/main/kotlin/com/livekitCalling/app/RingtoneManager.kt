package com.livekitCalling.app

import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Handler
import android.os.Looper

class RingtoneManager(private val context: Context) {
    private var ringtone: android.media.Ringtone? = null
    private val handler = Handler(Looper.getMainLooper())

    fun playRingtone() {
        try {
            stopRingtone() // Stop any existing ringtone
            
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(context, ringtoneUri)
            
            // Set audio attributes for incoming call
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_REQUEST)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            }
            
            ringtone?.play()
            android.util.Log.d("RingtoneManager", "Ringtone started")
        } catch (e: Exception) {
            android.util.Log.e("RingtoneManager", "Error playing ringtone: ${e.message}")
        }
    }

    fun stopRingtone() {
        try {
            if (ringtone?.isPlaying == true) {
                ringtone?.stop()
                android.util.Log.d("RingtoneManager", "Ringtone stopped")
            }
            ringtone = null
        } catch (e: Exception) {
            android.util.Log.e("RingtoneManager", "Error stopping ringtone: ${e.message}")
        }
    }
}
