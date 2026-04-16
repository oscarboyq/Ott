import 'package:video/features/catalog/data/datasources/video_data_source.dart';
import 'package:video/features/catalog/data/models/video_model.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

class MockVideoRemoteDataSource implements VideoDataSource {
  final List<VideoModel> _videos = <VideoModel>[
    const VideoModel(
      id: 'coastline-notes',
      title: 'Coastline Notes',
      tagline: 'A slow-travel story filmed across hidden harbors.',
      description:
          'A free editorial travel episode designed to show the public catalog experience. In the real backend this record would come from your database and hold a secure playback reference.',
      category: 'Travel',
      durationLabel: '14 min',
      releaseLabel: 'New release',
      accentHex: '#0D6A73',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      accessLevel: VideoAccessLevel.free,
      isFeatured: true,
    ),
    const VideoModel(
      id: 'midnight-terminal',
      title: 'Midnight Terminal',
      tagline: 'A neon crime series set between rail yards and safe houses.',
      description:
          'A serialized thriller built to feel like a marquee OTT release. This mock item helps the home page look and behave like a content-first streaming catalog.',
      category: 'Series',
      durationLabel: '6 episodes',
      releaseLabel: 'Top series',
      accentHex: '#7A2638',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      accessLevel: VideoAccessLevel.premium,
      isFeatured: true,
    ),
    const VideoModel(
      id: 'after-hours-city',
      title: 'After Hours City',
      tagline: 'A premium urban portrait with a cinematic night look.',
      description:
          'This sample represents a locked premium title. In production, your app would check authentication and membership before loading the playback URL.',
      category: 'Documentary',
      durationLabel: '22 min',
      releaseLabel: 'Premium',
      accentHex: '#A64B2A',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      accessLevel: VideoAccessLevel.premium,
    ),
    const VideoModel(
      id: 'quiet-kitchen',
      title: 'Quiet Kitchen',
      tagline: 'A calm food story built around texture, sound, and ritual.',
      description:
          'Free content like this is useful for discovery, search ranking, and user onboarding before they decide to pay for a subscription.',
      category: 'Food',
      durationLabel: '11 min',
      releaseLabel: 'Free',
      accentHex: '#4D7C59',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      accessLevel: VideoAccessLevel.free,
    ),
    const VideoModel(
      id: 'wild-atlas',
      title: 'Wild Atlas',
      tagline:
          'Natural history travel episodes shot in wide-format landscapes.',
      description:
          'A bright discovery title that gives the catalog more visual range and helps model a nature documentary lane.',
      category: 'Nature',
      durationLabel: '48 min',
      releaseLabel: 'Trending',
      accentHex: '#15615F',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      accessLevel: VideoAccessLevel.free,
    ),
    const VideoModel(
      id: 'founders-room',
      title: 'Founders Room',
      tagline: 'Interviews and strategy breakdowns for premium viewers.',
      description:
          'This premium title models member-only content. Later we will connect this screen to a real backend so only entitled users receive the playable source.',
      category: 'Business',
      durationLabel: '28 min',
      releaseLabel: 'Members',
      accentHex: '#384F7A',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      accessLevel: VideoAccessLevel.premium,
      isFeatured: true,
    ),
    const VideoModel(
      id: 'velvet-circuit',
      title: 'Velvet Circuit',
      tagline: 'A sleek sci-fi thriller crafted for premium-night viewing.',
      description:
          'Premium-only catalog entries like this help us test the subscription gate and make the homepage feel closer to a streaming service lineup.',
      category: 'Sci-Fi',
      durationLabel: '1h 54m',
      releaseLabel: 'Premium',
      accentHex: '#3D3FA6',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
      accessLevel: VideoAccessLevel.premium,
    ),
    const VideoModel(
      id: 'morning-letters',
      title: 'Morning Letters',
      tagline: 'Short-form reflective storytelling for open viewers.',
      description:
          'Short free episodes can work well as teasers that gently push viewers toward account creation and premium conversion.',
      category: 'Lifestyle',
      durationLabel: '9 min',
      releaseLabel: 'Free',
      accentHex: '#7C5B9A',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      accessLevel: VideoAccessLevel.free,
    ),
    const VideoModel(
      id: 'stadium-red',
      title: 'Stadium Red',
      tagline:
          'A sports docuseries mixing personal stories with match-day heat.',
      description:
          'This mock series gives us another rail candidate and broadens the look of the catalog.',
      category: 'Sports',
      durationLabel: '8 episodes',
      releaseLabel: 'Most watched',
      accentHex: '#8D2B24',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
      accessLevel: VideoAccessLevel.free,
    ),
    const VideoModel(
      id: 'marble-sky',
      title: 'Marble Sky',
      tagline:
          'A premium romance drama designed as a flagship streaming original.',
      description:
          'Mock flagship content helps us stage a front page that feels more like a commercial OTT platform than a simple file browser.',
      category: 'Drama',
      durationLabel: '1h 42m',
      releaseLabel: 'Original',
      accentHex: '#8F5277',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
      accessLevel: VideoAccessLevel.premium,
    ),
    const VideoModel(
      id: 'signal-house',
      title: 'Signal House',
      tagline: 'A compact mystery series with a strong free-entry hook.',
      description:
          'Free titles like this can help conversion by letting viewers sample the tone and quality of the platform before upgrading.',
      category: 'Mystery',
      durationLabel: '4 episodes',
      releaseLabel: 'Free',
      accentHex: '#4C6A8C',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      accessLevel: VideoAccessLevel.free,
    ),
    const VideoModel(
      id: 'embers-of-rain',
      title: 'Embers of Rain',
      tagline: 'An upcoming premium drama still waiting for admin publish.',
      description:
          'This draft title is visible only in the admin panel so you can immediately see publish and feature controls in action.',
      category: 'Upcoming',
      durationLabel: '1h 37m',
      releaseLabel: 'Draft',
      accentHex: '#734B3F',
      videoUrl:
          'https://storage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
      accessLevel: VideoAccessLevel.premium,
      isPublished: false,
    ),
  ];

  @override
  Future<List<VideoModel>> getCatalog() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _videos
        .where((VideoModel video) => video.isPublished)
        .toList(growable: false);
  }

  @override
  Future<List<VideoModel>> getAdminCatalog() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return List<VideoModel>.from(_videos);
  }

  @override
  Future<void> createVideo(VideoModel video) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _videos.insert(0, video);
  }

  @override
  Future<void> updateFeaturedStatus({
    required String videoId,
    required bool isFeatured,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _replaceVideo(
      videoId: videoId,
      transform: (VideoModel current) =>
          current.copyWith(isFeatured: isFeatured),
    );
  }

  @override
  Future<void> updatePublishStatus({
    required String videoId,
    required bool isPublished,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _replaceVideo(
      videoId: videoId,
      transform: (VideoModel current) =>
          current.copyWith(isPublished: isPublished),
    );
  }

  void _replaceVideo({
    required String videoId,
    required VideoModel Function(VideoModel current) transform,
  }) {
    final int index = _videos.indexWhere(
      (VideoModel video) => video.id == videoId,
    );

    if (index == -1) {
      return;
    }

    _videos[index] = transform(_videos[index]);
  }
}
