import 'dart:convert';

/// 视频轨规格
class VideoTrackInfo {
  final String codec;
  final int width;
  final int height;
  final String resolutionLabel;
  final String hdrType; // Dolby Vision / HDR10+ / HDR10 / SDR
  final int bitDepth;
  final String bitRate;
  final String duration;

  VideoTrackInfo({
    this.codec = '',
    this.width = 0,
    this.height = 0,
    this.resolutionLabel = '',
    this.hdrType = 'SDR',
    this.bitDepth = 8,
    this.bitRate = '',
    this.duration = '',
  });

  bool get isDolbyVision => hdrType.toLowerCase().contains('dolby') || hdrType.toLowerCase().contains('dovi');
  bool get isHDR => hdrType.toUpperCase().contains('HDR') || isDolbyVision;

  factory VideoTrackInfo.fromMap(Map<String, dynamic> map) {
    return VideoTrackInfo(
      codec: map['codec'] ?? '',
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
      resolutionLabel: map['resolution_label'] ?? '',
      hdrType: map['hdr_type'] ?? 'SDR',
      bitDepth: map['bit_depth'] ?? 8,
      bitRate: map['bit_rate'] ?? '',
      duration: map['duration'] ?? '',
    );
  }
}

/// 音频轨规格（全音轨直出）
class AudioTrackInfo {
  final String codec;
  final int channels;
  final String channelLayout; // 7.1 / 5.1 / 2.0
  final String bitRate;
  final int bitDepth;
  final int samplingRate;
  final String language;
  final String title;
  final bool isAtmos;

  AudioTrackInfo({
    this.codec = '',
    this.channels = 2,
    this.channelLayout = '2.0',
    this.bitRate = '',
    this.bitDepth = 16,
    this.samplingRate = 48000,
    this.language = 'und',
    this.title = '',
    this.isAtmos = false,
  });

  factory AudioTrackInfo.fromMap(Map<String, dynamic> map) {
    return AudioTrackInfo(
      codec: map['codec'] ?? '',
      channels: map['channels'] ?? 2,
      channelLayout: map['channel_layout'] ?? '2.0',
      bitRate: map['bit_rate'] ?? '',
      bitDepth: map['bit_depth'] ?? 16,
      samplingRate: map['sampling_rate'] ?? 48000,
      language: map['language'] ?? 'und',
      title: map['title'] ?? '',
      isAtmos: map['is_atmos'] ?? false,
    );
  }
}

/// 字幕轨规格
class SubtitleTrackInfo {
  final String language;
  final String format; // PGS / ASS / SRT
  final String title;
  final bool isForced;

  SubtitleTrackInfo({
    this.language = 'chi',
    this.format = 'SRT',
    this.title = '',
    this.isForced = false,
  });

  factory SubtitleTrackInfo.fromMap(Map<String, dynamic> map) {
    return SubtitleTrackInfo(
      language: map['language'] ?? 'chi',
      format: map['format'] ?? 'SRT',
      title: map['title'] ?? '',
      isForced: map['is_forced'] ?? false,
    );
  }
}

/// 剧集分集模型 (Episode)
class EpisodeModel {
  final int id;
  final int mediaId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String overview;
  final String airDate;
  final String stillUrl;
  final int durationSec;
  final String strmPath;
  final bool matched;

  EpisodeModel({
    required this.id,
    required this.mediaId,
    this.seasonNumber = 1,
    this.episodeNumber = 1,
    this.title = '',
    this.overview = '',
    this.airDate = '',
    this.stillUrl = '',
    this.durationSec = 0,
    this.strmPath = '',
    this.matched = true,
  });

  String get episodeLabel {
    final s = seasonNumber.toString().padLeft(2, '0');
    final e = episodeNumber.toString().padLeft(2, '0');
    return "S${s}E$e";
  }

  factory EpisodeModel.fromMap(Map<String, dynamic> map) {
    return EpisodeModel(
      id: map['id'] ?? 0,
      mediaId: map['media_id'] ?? 0,
      seasonNumber: map['season_number'] ?? 1,
      episodeNumber: map['episode_number'] ?? 1,
      title: map['title'] ?? '',
      overview: map['overview'] ?? '',
      airDate: map['air_date'] ?? '',
      stillUrl: map['still_url'] ?? '',
      durationSec: map['duration_sec'] ?? 0,
      strmPath: map['strm_path'] ?? '',
      matched: map['matched'] ?? true,
    );
  }
}

/// 蓝光原盘母带规格胶囊 (BDInfoCapsule)
class BDInfoCapsule {
  final String sourceType; // UHD_BD / BD_ISO / BDMV / REMUX / WEB_DL
  final String discTitle;
  final String discLabel;
  final VideoTrackInfo? video;
  final List<AudioTrackInfo> audioTracks;
  final List<SubtitleTrackInfo> subtitleTracks;

  BDInfoCapsule({
    this.sourceType = 'WEB_DL',
    this.discTitle = '',
    this.discLabel = '',
    this.video,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
  });

  factory BDInfoCapsule.fromMap(Map<String, dynamic> map) {
    var videoMap = map['video'];
    var audioList = (map['audio'] as List<dynamic>?) ?? [];
    var subList = (map['subtitles'] as List<dynamic>?) ?? [];

    return BDInfoCapsule(
      sourceType: map['source_type'] ?? 'WEB_DL',
      discTitle: map['disc_title'] ?? '',
      discLabel: map['disc_label'] ?? '',
      video: videoMap != null ? VideoTrackInfo.fromMap(videoMap) : null,
      audioTracks: audioList.map((e) => AudioTrackInfo.fromMap(e)).toList(),
      subtitleTracks: subList.map((e) => SubtitleTrackInfo.fromMap(e)).toList(),
    );
  }
}

/// 媒体库条目（海报墙与播放器核心实体）
class MediaItemModel {
  final int id;
  final String type; // movie / tv
  final String title;
  final String originalTitle;
  final int year;
  final int tmdbId;
  final String posterUrl;
  final String backdropUrl;
  final String overview;
  final double rating;
  final int runtime;
  final String collection;
  final List<String> genres;
  final String libraryPath;
  final String discType;   // UHD / BD / 3D / DVD
  final String resolution; // 4K / FHD / HD
  final String edition;    // Remux / MiniBD / Standard
  final BDInfoCapsule? bdinfo;
  final List<EpisodeModel> episodes;
  final int episodesCount;

  MediaItemModel({
    required this.id,
    this.type = 'movie',
    required this.title,
    this.originalTitle = '',
    this.year = 0,
    this.tmdbId = 0,
    this.posterUrl = '',
    this.backdropUrl = '',
    this.overview = '',
    this.rating = 0.0,
    this.runtime = 0,
    this.collection = '',
    this.genres = const [],
    this.libraryPath = '',
    this.discType = 'BD',
    this.resolution = '1080p',
    this.edition = 'Standard',
    this.bdinfo,
    this.episodes = const [],
    this.episodesCount = 0,
  });

  bool get isTV => type.toLowerCase() == 'tv' || episodes.isNotEmpty;
  bool get is4K => resolution.toUpperCase().contains('4K') || (bdinfo?.video?.width ?? 0) >= 3840;
  bool get isHDR => bdinfo?.video?.isHDR ?? (discType == 'UHD' || resolution.toUpperCase().contains('4K'));
  bool get hasDolbyVision => bdinfo?.video?.isDolbyVision ?? false;
  bool get hasAtmos => bdinfo?.audioTracks.any((a) => a.isAtmos || a.codec.contains('Atmos')) ?? false;

  /// 按季分组分集列表
  Map<int, List<EpisodeModel>> get seasonGroups {
    final Map<int, List<EpisodeModel>> map = {};
    for (var ep in episodes) {
      map.putIfAbsent(ep.seasonNumber, () => []).add(ep);
    }
    // 排序
    for (var key in map.keys) {
      map[key]!.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }
    return map;
  }

  factory MediaItemModel.fromMap(Map<String, dynamic> map) {
    var rawGenres = map['genres'];
    List<String> genreList = [];
    if (rawGenres is List) {
      genreList = rawGenres.map((e) => e.toString()).toList();
    } else if (rawGenres is String && rawGenres.isNotEmpty) {
      genreList = rawGenres.split(',').map((e) => e.trim()).toList();
    }

    var epList = (map['episodes'] as List<dynamic>?) ?? [];
    var episodes = epList.map((e) => EpisodeModel.fromMap(e)).toList();

    return MediaItemModel(
      id: map['id'] ?? 0,
      type: map['type'] ?? (episodes.isNotEmpty ? 'tv' : 'movie'),
      title: map['title'] ?? '未命名影片',
      originalTitle: map['original_title'] ?? '',
      year: map['year'] ?? 0,
      tmdbId: map['tmdb_id'] ?? 0,
      posterUrl: map['poster_url'] ?? '',
      backdropUrl: map['backdrop_url'] ?? '',
      overview: map['overview'] ?? '',
      rating: (map['rating'] is num) ? (map['rating'] as num).toDouble() : 0.0,
      runtime: map['runtime'] ?? 0,
      collection: map['collection'] ?? '',
      genres: genreList,
      libraryPath: map['library_path'] ?? '',
      discType: map['disc_type'] ?? 'BD',
      resolution: map['resolution'] ?? '1080p',
      edition: map['edition'] ?? 'Standard',
      bdinfo: map['bdinfo'] != null ? BDInfoCapsule.fromMap(map['bdinfo']) : null,
      episodes: episodes,
      episodesCount: map['episodes_count'] ?? episodes.length,
    );
  }
}
