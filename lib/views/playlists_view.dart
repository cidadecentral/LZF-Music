import 'package:flutter/material.dart';
import '../widgets/show_aware_page.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  PlaylistsViewState createState() => PlaylistsViewState();
}

class PlaylistsViewState extends State<PlaylistsView> implements ShowAwarePage {
  @override
  void onPageShow() {
    print('PlaylistsView is now visible');
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('播放列表'));
  }
}