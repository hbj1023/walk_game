import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:capstone_app/services/app_settings_service.dart';
import 'package:flutter/foundation.dart';

/// 게임 전역 배경음악과 짧은 효과음을 관리한다.
class GameAudioService {
  GameAudioService._();

  static final AudioPlayer _backgroundPlayer = AudioPlayer();
  static const double _backgroundBaseVolume = 0.22;
  static bool _backgroundStarted = false;
  static bool _backgroundStarting = false;
  static bool _initialized = false;
  static AppSettingsData _settings = const AppSettingsData.defaults();

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _settings = AppSettingsService.notifier.value;
    AppSettingsService.notifier.addListener(_onSettingsChanged);
  }

  static void _onSettingsChanged() {
    _settings = AppSettingsService.notifier.value;
    unawaited(_applyBackgroundSettings());
  }

  static void ensureBackgroundMusic() {
    initialize();
    if (!_canPlayBackground) return;
    if (_backgroundStarted) {
      unawaited(_applyBackgroundSettings());
      return;
    }
    if (_backgroundStarted || _backgroundStarting) return;
    _backgroundStarting = true;
    unawaited(_startBackgroundMusic());
  }

  static Future<void> _startBackgroundMusic() async {
    try {
      await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundPlayer.setVolume(_backgroundVolume);
      await _backgroundPlayer.play(AssetSource('audio/game_background.wav'));
      _backgroundStarted = true;
    } catch (error) {
      debugPrint('Background music playback failed: $error');
    } finally {
      _backgroundStarting = false;
    }
  }

  static Future<void> _applyBackgroundSettings() async {
    if (!_backgroundStarted) {
      if (_canPlayBackground) ensureBackgroundMusic();
      return;
    }
    try {
      if (!_canPlayBackground) {
        await _backgroundPlayer.pause();
        return;
      }
      await _backgroundPlayer.setVolume(_backgroundVolume);
      await _backgroundPlayer.resume();
    } catch (error) {
      debugPrint('Background music settings failed: $error');
    }
  }

  static bool get _canPlayBackground =>
      _settings.soundEnabled &&
      _settings.bgmEnabled &&
      _settings.masterVolume > 0;

  static bool get _canPlayEffects =>
      _settings.soundEnabled &&
      _settings.sfxEnabled &&
      _settings.masterVolume > 0;

  static double get _backgroundVolume =>
      (_backgroundBaseVolume * _settings.masterVolume)
          .clamp(0.0, 1.0)
          .toDouble();

  static void playWeaponSwing() => _playEffect('audio/weapon_swing.wav', 0.78);

  static void playStageEnter() => _playEffect('audio/stage_enter.wav', 0.72);

  static void playPotionPurchase() =>
      _playEffect('audio/potion_purchase.wav', 0.82);

  static void playPotionDrink() => _playEffect('audio/potion_drink.wav', 0.86);

  static void playChapterTurn() => _playEffect('audio/chapter_turn.wav', 0.85);

  static void playItemSell() => _playEffect('audio/item_sell.wav', 0.84);

  static void _playEffect(String assetPath, double volume) {
    initialize();
    if (!_canPlayEffects) return;
    unawaited(_playOneShot(assetPath, volume));
  }

  static Future<void> _playOneShot(String assetPath, double volume) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(
        (volume * _settings.masterVolume).clamp(0.0, 1.0).toDouble(),
      );
      await player.play(AssetSource(assetPath));
      await player.onPlayerComplete.first;
    } catch (error) {
      debugPrint('Sound effect playback failed ($assetPath): $error');
    } finally {
      await player.dispose();
    }
  }
}
