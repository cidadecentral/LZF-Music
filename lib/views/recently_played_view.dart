import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../database/database.dart';
import '../services/music_import_service.dart';
import '../services/player_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/toggleable_popup_menu.dart';
import '../widgets/show_aware_page.dart';
import '../widgets/compact_center_snack_bar.dart';

class RecentlyPlayedView extends StatefulWidget {
  const RecentlyPlayedView({super.key});

  @override
  State<RecentlyPlayedView> createState() => RecentlyPlayedViewState();
}

class RecentlyPlayedViewState extends State<RecentlyPlayedView>
    implements ShowAwarePage {
  int? _hoveredIndex;
  bool _isScrolling = false;
  Timer? _scrollTimer;
  final ScrollController _scrollController = ScrollController();
  late MusicDatabase database;
  late MusicImportService importService;
  List<Song> songs = [];
  String? orderField = null;
  String? orderDirection = null;
  String? searchKeyword = null;

  void onPageShow() {
    _loadSongs();
  }

  @override
  void initState() {
    super.initState();
    database = Provider.of<MusicDatabase>(context, listen: false);
    importService = MusicImportService(database);

    _scrollController.addListener(() {
      if (!_isScrolling &&
          _scrollController.position.pixels !=
              _scrollController.position.minScrollExtent) {
        setState(() {
          _isScrolling = true;
          _hoveredIndex = null;
        });
      }

      // 重置之前的定时器
      _scrollTimer?.cancel();

      // 设置新的定时器
      _scrollTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _isScrolling = false;
          });
        }
      });
    });
  }

  // 在你的 StatefulWidget 中更新这个方法
  Future<void> _loadSongs() async {
    try {
      List<Song> loadedSongs;
      loadedSongs = await database.smartSearch(null, isLastPlayed: true);
      setState(() {
        songs = loadedSongs;
      });
      print('加载了 ${loadedSongs.length} 首歌曲');
    } catch (e) {
      print('加载歌曲失败: $e');
      // 可以显示错误信息给用户
      setState(() {
        songs = [];
      });
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    database.close();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secondsStr = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$secondsStr";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0), // 左上右16，底部0
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LibraryHeader(
                songs: songs,
                onSearch: (keyword) async {
                  searchKeyword = keyword;
                  await _loadSongs();
                },
                onImportDirectory: () async {
                  await importService.importFromDirectory();
                  await _loadSongs();
                },
                onImportFiles: () async {
                  await importService.importFiles();
                  await _loadSongs();
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 60), // 封面图宽度 + 间距
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Text(
                                    '歌曲名称',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Text(
                                    '艺术家',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Text(
                                    '专辑',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: 70,
                              child: Text(
                                '采样率',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(
                              width: 80,
                              child: Text(
                                '比特率',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Row(
                                children: [
                                  Text(
                                    '时长',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 80,height: 40,), // 为更多按钮预留空间
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: songs.length,
                  itemExtent: 70,
                  itemBuilder: (context, index) {
                    final isHovered = !_isScrolling && _hoveredIndex == index;
                    final isSelected =
                        playerProvider.currentSong?.id == songs[index].id;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1)
                          : isHovered
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          // 主要内容区域 - 被MouseRegion包裹
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _hoveredIndex = index),
                              onExit: (_) =>
                                  setState(() => _hoveredIndex = null),
                              child: GestureDetector(
                                onDoubleTap: () {
                                  playerProvider.playSong(
                                    songs[index],
                                    playlist: songs,
                                    index: index,
                                  );
                                },
                                child: SizedBox(
                                  // 使用Container来扩展可点击区域，覆盖整个左侧
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: Stack(
                                    children: [
                                      // 透明的全覆盖层，确保整个区域都可以点击
                                      Positioned.fill(
                                        child: Container(color: Colors.transparent),
                                      ),
                                      // 实际内容
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Row(
                                          children: [
                                            // 封面图
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child:
                                                  songs[index].albumArtPath !=
                                                      null
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Image.file(
                                                        File(
                                                          songs[index]
                                                              .albumArtPath!,
                                                        ),
                                                        width: 50,
                                                        height: 50,
                                                        fit: BoxFit.cover,
                                                        cacheWidth: 150,
                                                        cacheHeight: 150,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.music_note_rounded,
                                                    ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 歌曲信息
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  // 歌曲名称
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      songs[index].title,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isSelected
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 艺术家
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      songs[index].artist ??
                                                          '未知艺术家',
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 专辑名
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      songs[index].album ??
                                                          '未知专辑',
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 采样率
                                                  SizedBox(
                                                    width: 70,
                                                    child: Text(
                                                      songs[index].sampleRate !=
                                                              null
                                                          ? '${(songs[index].sampleRate! / 1000).toStringAsFixed(1)} kHz'
                                                          : '',
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 比特率
                                                  SizedBox(
                                                    width: 80,
                                                    child: Text(
                                                      songs[index].bitrate !=
                                                              null
                                                          ? '${(songs[index].bitrate! / 1000).toStringAsFixed(0)} kbps'
                                                          : '',
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 时长
                                                  SizedBox(
                                                    width: 60,
                                                    child: Text(
                                                      _formatDuration(
                                                        songs[index].duration ??
                                                            0,
                                                      ),
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              database.updateSong(
                                songs[index].copyWith(
                                  isFavorite: !songs[index].isFavorite,
                                ),
                              );
                              CompactCenterSnackBar.show(
                                context,
                                songs[index].isFavorite
                                    ? '已取消收藏 ${songs[index].title} - ${songs[index].artist ?? '未知艺术家'}'
                                    : '已收藏 ${songs[index].title} - ${songs[index].artist ?? '未知艺术家'}',
                              );
                              setState(() {
                                songs[index] = songs[index].copyWith(
                                  isFavorite: !songs[index].isFavorite,
                                );
                              });
                            },
                            iconSize: 20,
                            icon: Icon(
                              songs[index].isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_outline_rounded,
                              color: songs[index].isFavorite
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            iconSize: 20,
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                            onSelected: (value) => {
                              if (value == 'delete')
                                {
                                  database.deleteSong(songs[index].id),
                                  CompactCenterSnackBar.show(
                                    context,
                                    "已删除 ${songs[index].title} - ${songs[index].artist ?? '未知艺术家'}",
                                  ),
                                  _loadSongs(),
                                },
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LibraryHeader extends StatefulWidget {
  final Future<void> Function(String? keyword) onSearch;
  final Future<void> Function() onImportDirectory;
  final Future<void> Function() onImportFiles;
  final List<Song> songs;

  const LibraryHeader({
    super.key,
    required this.onSearch,
    required this.onImportDirectory,
    required this.onImportFiles,
    required this.songs,
  });

  @override
  State<LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends State<LibraryHeader> {
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  void _onSubmitted(String? value) {
    widget.onSearch(value);
    // 收起搜索框
    setState(() {
      // _showSearch = false;
    });
    // _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '最近播放',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        Text('共${widget.songs.length}首最近播放音乐'),
        const Spacer(),
        if (_showSearch)
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '请输入搜索关键词',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), // 圆角半径16，可调
                ),
              ),
              onSubmitted: _onSubmitted,
            ),
          ),

        IconButton(
          icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
          onPressed: () {
            setState(() {
              if (_showSearch) {
                _searchController.clear();
              }
              if (_showSearch) {
                _showSearch = !_showSearch;
                _onSubmitted(null);
                return;
              }
              _showSearch = !_showSearch;
            });
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
