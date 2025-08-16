import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';
import '../database/database.dart';
import 'audio_player_service.dart';

class PlayerProvider with ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();

  Song? _currentSong;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;

  double _volume = 1.0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PlayMode _playMode = PlayMode.sequence;

  List<Song> _playlist = [];
  int _currentIndex = -1;

  // 流订阅
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;

  // 防重复调用标志
  bool _isHandlingComplete = false;
  Timer? _completeDebounceTimer;

  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayMode get playMode => _playMode;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Player get player => _audioService.player;
  double get volume => _volume;

  bool get hasPrevious =>
      playMode == PlayMode.shuffle ? true : _currentIndex > 0;
  bool get hasNext => playMode == PlayMode.shuffle
      ? true
      : _currentIndex < _playlist.length - 1;

  PlayerProvider() {
    _initializeListeners();
    setPlayMode(PlayMode.loop);
  }

  void _initializeListeners() {
    // 播放状态
    _playingSub = player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _isLoading = false;
      notifyListeners();
    });

    // 播放进度
    _positionSub = player.stream.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    // 总时长
    _durationSub = player.stream.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    // 播放完成 - 使用防抖机制
    _completedSub = player.stream.completed.listen((completed) {
      if (completed) {
        _handleSongCompleteWithDebounce();
      }
    });
  }

  void _handleSongCompleteWithDebounce() {
    // 取消之前的定时器
    _completeDebounceTimer?.cancel();

    // 设置新的定时器，延迟执行
    _completeDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_isHandlingComplete) {
        _onSongComplete();
      }
    });
  }

  void setDatabase(MusicDatabase database) {
    _audioService.setDatabase(database);
  }

  Future<void> playSong(Song song, {List<Song>? playlist, int? index}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _isHandlingComplete = false; // 重置完成处理标志
      notifyListeners();

      if (playlist != null) {
        _playlist = List.from(playlist);
        _currentIndex = index ?? 0;
      } else if (_playlist.isEmpty || !_playlist.contains(song)) {
        _playlist = [song];
        _currentIndex = 0;
      } else {
        _currentIndex = _playlist.indexOf(song);
      }

      _currentSong = song;
      await _audioService.playSong(song);
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      _errorMessage = '播放失败: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (_currentSong == null) return;

    try {
      if (_isPlaying) {
        await _audioService.pause();
      } else {
        await _audioService.resume();
      }
    } catch (e) {
      _errorMessage = '操作失败: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      _isHandlingComplete = true; // 防止stop时触发complete回调
      await _audioService.stop();
      _currentSong = null;
      _isPlaying = false;
      _position = Duration.zero;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = '停止失败: ${e.toString()}';
      notifyListeners();
    } finally {
      Timer(const Duration(milliseconds: 200), () {
        _isHandlingComplete = false;
      });
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (_playMode == PlayMode.shuffle) {
      final randomIndex =
          DateTime.now().millisecondsSinceEpoch % _playlist.length;
      _currentIndex = randomIndex;
      await playSong(_playlist[_currentIndex]);
      return;
    }
    if (!hasPrevious && _playMode != PlayMode.loop&& _playMode != PlayMode.singleLoop) return;
    if ((_playMode == PlayMode.loop||_playMode == PlayMode.singleLoop) && !hasPrevious) {
      _currentIndex = _playlist.length-1;
    } else {
      _currentIndex--;
    }
    await playSong(_playlist[_currentIndex]);
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_playMode == PlayMode.shuffle) {
      final randomIndex =
          DateTime.now().millisecondsSinceEpoch % _playlist.length;
      _currentIndex = randomIndex;
      await playSong(_playlist[_currentIndex]);
      return;
    }

    if (!hasNext && _playMode != PlayMode.loop&& _playMode != PlayMode.singleLoop) return;
    if ((_playMode == PlayMode.loop||_playMode == PlayMode.singleLoop) && !hasNext) {
      _currentIndex = 0;
    } else {
      _currentIndex++;
    }
    await playSong(_playlist[_currentIndex]);
  }

  Future<void> seekTo(Duration position) async {
    try {
      await player.seek(position);
    } catch (e) {
      _errorMessage = '跳转失败: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await player.setVolume(_volume * 100);
      notifyListeners();
    } catch (e) {
      _errorMessage = '设置音量失败: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    if (_volume > 0) {
      await setVolume(0);
    } else {
      await setVolume(1.0);
    }
  }

  void setPlayMode(PlayMode mode) {
    if (_playMode != mode) {
      _playMode = mode;
      notifyListeners();
    }
  }

  void setPlaylist(List<Song> songs, {int currentIndex = 0}) {
    _playlist = List.from(songs);
    _currentIndex = currentIndex.clamp(0, songs.length - 1);
    if (songs.isNotEmpty) {
      _currentSong = songs[_currentIndex];
    }
    notifyListeners();
  }

  void addToPlaylist(Song song) {
    _playlist.add(song);
    notifyListeners();
  }

  void removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      if (_playlist.isEmpty) {
        stop();
      } else {
        _currentSong = _playlist[_currentIndex];
      }
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _onSongComplete() {
    // 防止重复处理
    if (_isHandlingComplete) return;
    _isHandlingComplete = true;

    try {
      switch (_playMode) {
        case PlayMode.single:
          _isPlaying = false;
          _position = Duration.zero;
          break;
        case PlayMode.singleLoop:
          if (_currentSong != null) {
            Future.microtask(() => {
              seekTo(Duration.zero),
              _audioService.resume()
            });
          }
          break;
        case PlayMode.sequence:
          if (hasNext) {
            Future.microtask(() => next());
          } else {
            _isPlaying = false;
            _position = Duration.zero;
          }
          break;
        case PlayMode.loop:
          Future.microtask(() => next());
          break;
        case PlayMode.shuffle:
          if (_playlist.isNotEmpty) {
            final random =
                DateTime.now().millisecondsSinceEpoch % _playlist.length;
            _currentIndex = random;
            Future.microtask(() => playSong(_playlist[_currentIndex]));
          }
          break;
      }
      notifyListeners();
    } finally {
      // 延迟重置标志
      Timer(const Duration(milliseconds: 500), () {
        _isHandlingComplete = false;
      });
    }
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _completeDebounceTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}

enum PlayMode { single, singleLoop, sequence, loop, shuffle }
