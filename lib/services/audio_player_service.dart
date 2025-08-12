import 'package:media_kit/media_kit.dart';
import '../database/database.dart';
import 'package:drift/drift.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();

  final Player player = Player();
  late MusicDatabase _database; // 延迟初始化
  Song? _currentSong;

  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal();

  void setDatabase(MusicDatabase database) {
    _database = database;
  }

  Future<void> playSong(Song song) async {
    try {
      print('Playing song: ${song.filePath}');
      if (_currentSong != null && _currentSong!.id == song.id) {
        return;
      }
      _database.updateSong(
        song.copyWith(
          lastPlayedTime: DateTime.now(),
          playedCount: song.playedCount + 1,
        ),
      );
      _currentSong = song;
      await player.open(Media(song.filePath));
      await player.play();
    } catch (e) {
      print('Error playing song: $e');
    }
  }

  Future<void> pause() async => await player.pause();
  Future<void> resume() async => await player.play();
  Future<void> stop() async {
    await player.stop();
    _currentSong = null;
  }

  Future<void> seek(Duration position) async => await player.seek(position);

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;

  void dispose() => player.dispose();
}
