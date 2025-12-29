package com.livekitCalling.livekit_calling_app

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.util.Log

class RingtoneManager(private val context: Context) {
    companion object {
        private const val TAG = "RingtoneManager"
    }

    private var ringtone: Ringtone? = null

    fun playRingtone() {
        try {
            Log.d(TAG, "playRingtone called")
            stopRingtone()

            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            Log.d(TAG, "Ringtone URI: $ringtoneUri")

            ringtone = RingtoneManager.getRingtone(context, ringtoneUri)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_REQUEST)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            }

            ringtone?.play()
            Log.d(TAG, "Ringtone play invoked")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing ringtone: ${e.message}", e)
        }
    }

    fun stopRingtone() {
        try {
            Log.d(TAG, "stopRingtone called")
            if (ringtone?.isPlaying == true) {
                ringtone?.stop()
                Log.d(TAG, "Ringtone stopped")
            }
            ringtone = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping ringtone: ${e.message}", e)
        }
    }
}

