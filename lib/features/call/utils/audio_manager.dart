import 'dart:developer';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter/material.dart';

enum AudioOutput {
  earpiece,
  speaker,
  bluetooth;

  String get displayName {
    switch (this) {
      case AudioOutput.earpiece:
        return 'Phone';
      case AudioOutput.speaker:
        return 'Speaker';
      case AudioOutput.bluetooth:
        return 'Bluetooth';
    }
  }

  IconData get icon {
    switch (this) {
      case AudioOutput.earpiece:
        return Icons.hearing;
      case AudioOutput.speaker:
        return Icons.volume_up;
      case AudioOutput.bluetooth:
        return Icons.bluetooth_audio;
    }
  }
}

class AudioManager {
  static AudioOutput _currentOutput = AudioOutput.earpiece;

  static AudioOutput get currentOutput => _currentOutput;

  /// Set audio output to speaker
  static Future<void> setSpeakerOn(bool on) async {
    try {
      await Hardware.instance.setSpeakerphoneOn(on);
      _currentOutput = on ? AudioOutput.speaker : AudioOutput.earpiece;
      log('[AudioManager] Speaker: $on');
    } catch (e) {
      log('[AudioManager] setSpeakerOn error: $e');
    }
  }

  /// Toggle speaker
  static Future<void> toggleSpeaker() async {
    await setSpeakerOn(_currentOutput != AudioOutput.speaker);
  }

  /// Set audio output
  static Future<void> setOutput(AudioOutput output) async {
    try {
      switch (output) {
        case AudioOutput.earpiece:
          await Hardware.instance.setSpeakerphoneOn(false);
          break;
        case AudioOutput.speaker:
          await Hardware.instance.setSpeakerphoneOn(true);
          break;
        case AudioOutput.bluetooth:
          // Bluetooth routing is typically automatic
          // when a Bluetooth audio device is connected
          break;
      }
      _currentOutput = output;
      log('[AudioManager] Output set to: ${output.displayName}');
    } catch (e) {
      log('[AudioManager] setOutput error: $e');
    }
  }

  /// Show audio output picker
  static Future<AudioOutput?> showOutputPicker(BuildContext context) async {
    return showModalBottomSheet<AudioOutput>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Audio Output',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...AudioOutput.values.map((output) => ListTile(
                  leading: Icon(output.icon),
                  title: Text(output.displayName),
                  trailing: _currentOutput == output
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setOutput(output);
                    Navigator.pop(ctx, output);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
