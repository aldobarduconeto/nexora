import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

enum P2PCallState {
  idle,
  outgoing,
  incoming,
  connecting,
  active,
}

/// Presets de qualidade de vídeo para chamadas e streaming de tela.
/// Permite resolução nativa até 4K (3840×2160) @ 60 FPS com bitrate de até 35 Mbps
/// para todos os usuários sem restrições ou paywall.
enum VideoStreamPreset {
  ultra4k60(
    id: '4k60',
    label: '4K Ultra HD • 60 FPS',
    shortLabel: '4K@60',
    badge: '💎 4K UHD 60fps',
    width: 3840,
    height: 2160,
    frameRate: 60,
    bitrateKbps: 35000,
    minBitrateKbps: 8000,
    startBitrateKbps: 18000,
  ),
  ultra4k30(
    id: '4k30',
    label: '4K Ultra HD • 30 FPS',
    shortLabel: '4K@30',
    badge: '💎 4K UHD 30fps',
    width: 3840,
    height: 2160,
    frameRate: 30,
    bitrateKbps: 22000,
    minBitrateKbps: 6000,
    startBitrateKbps: 14000,
  ),
  quad2k60(
    id: '2k60',
    label: '2K Quad HD • 60 FPS',
    shortLabel: '2K@60',
    badge: '⚡ 2K QHD 60fps',
    width: 2560,
    height: 1440,
    frameRate: 60,
    bitrateKbps: 16000,
    minBitrateKbps: 4000,
    startBitrateKbps: 10000,
  ),
  fullHd60(
    id: '1080p60',
    label: 'Full HD • 60 FPS',
    shortLabel: '1080p@60',
    badge: '🚀 1080p 60fps',
    width: 1920,
    height: 1080,
    frameRate: 60,
    bitrateKbps: 9000,
    minBitrateKbps: 3000,
    startBitrateKbps: 6000,
  ),
  fullHd30(
    id: '1080p30',
    label: 'Full HD • 30 FPS',
    shortLabel: '1080p@30',
    badge: 'HD 1080p',
    width: 1920,
    height: 1080,
    frameRate: 30,
    bitrateKbps: 5000,
    minBitrateKbps: 2000,
    startBitrateKbps: 3500,
  ),
  hd30(
    id: '720p30',
    label: 'HD • 30 FPS',
    shortLabel: '720p@30',
    badge: 'HD 720p',
    width: 1280,
    height: 720,
    frameRate: 30,
    bitrateKbps: 2500,
    minBitrateKbps: 1000,
    startBitrateKbps: 1800,
  ),
  economy(
    id: '480p24',
    label: 'Econômico • 24 FPS',
    shortLabel: '480p@24',
    badge: 'SD 480p',
    width: 854,
    height: 480,
    frameRate: 24,
    bitrateKbps: 1000,
    minBitrateKbps: 400,
    startBitrateKbps: 800,
  );

  const VideoStreamPreset({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.badge,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrateKbps,
    required this.minBitrateKbps,
    required this.startBitrateKbps,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String badge;
  final int width;
  final int height;
  final int frameRate;
  final int bitrateKbps;
  final int minBitrateKbps;
  final int startBitrateKbps;

  static VideoStreamPreset fromId(String id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return VideoStreamPreset.ultra4k60;
  }
}

/// Manages P2P Voice, Video, and Screen-Streaming media tracks and signaling.
/// Allows the user to independently toggle microphone, camera, and screen sharing
/// (including turning all media off) at any time without disconnecting the call.
class P2PMediaSession {
  P2PMediaSession({
    required this.onStateChanged,
    required this.sendSignal,
    required this.transformSdp,
  });

  final VoidCallback onStateChanged;
  final Future<void> Function(Map<String, dynamic> payload) sendSignal;
  final String Function(String sdp) transformSdp;

  static const _uuid = Uuid();
  static const Map<String, dynamic> _audioConstraints = {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
  };

  P2PCallState _state = P2PCallState.idle;
  String? _callId;
  String? _pendingOfferSdp;
  bool _isVideoCall = false;
  bool _isAudioMuted = false;
  bool _isVideoEnabled = false;
  bool _isScreenSharing = false;
  bool _isRemoteVideoEnabled = false;
  bool _isRemoteAudioMuted = false;
  bool _isRemoteScreenSharing = false;
  bool _isSpeakerphoneOn = true;
  DateTime? _connectedAt;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  MediaStream? _remoteStream;
  final List<RTCRtpSender> _senders = [];
  RTCRtpSender? _audioSender;
  RTCRtpSender? _videoSender;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  VideoStreamPreset _currentPreset = VideoStreamPreset.ultra4k60;
  VideoStreamPreset _remotePreset = VideoStreamPreset.ultra4k60;

  P2PCallState get state => _state;
  String? get callId => _callId;
  bool get isInCall => _state != P2PCallState.idle;
  bool get isVideoCall => _isVideoCall;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isScreenSharing => _isScreenSharing;
  bool get isRemoteVideoEnabled => _isRemoteVideoEnabled;
  bool get isRemoteAudioMuted => _isRemoteAudioMuted;
  bool get isRemoteScreenSharing => _isRemoteScreenSharing;
  bool get isSpeakerphoneOn => _isSpeakerphoneOn;
  DateTime? get connectedAt => _connectedAt;
  MediaStream? get localStream => _screenStream ?? _localStream;
  MediaStream? get remoteStream => _remoteStream;
  VideoStreamPreset get currentPreset => _currentPreset;
  VideoStreamPreset get remotePreset => _remotePreset;

  void setInitialPreset(VideoStreamPreset preset) {
    _currentPreset = preset;
  }

  static bool get isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Lists available desktop screens and windows on Windows, macOS, and Linux.
  static Future<List<DesktopCapturerSource>> getDesktopSources() async {
    if (!isDesktopPlatform) return const [];
    try {
      return await desktopCapturer.getSources(
        types: [SourceType.Screen, SourceType.Window],
      );
    } catch (_) {
      return const [];
    }
  }

  void handleRemoteTrack(RTCTrackEvent event) {
    if (event.streams.isNotEmpty) {
      _remoteStream = event.streams.first;
    }
    onStateChanged();
  }

  void handleRemoteStreamAdded(MediaStream stream) {
    _remoteStream = stream;
    onStateChanged();
  }

  void handleRemoteStreamRemoved(MediaStream stream) {
    if (_remoteStream?.id == stream.id) {
      _remoteStream = null;
      onStateChanged();
    }
  }

  String _prepareSdp(String rawSdp) {
    final optimized = optimizeSdpForStreaming(rawSdp, _currentPreset);
    return transformSdp(optimized);
  }

  /// Otimiza o SDP do WebRTC para alocar até 35-40 Mbps de largura de banda para 4K@60fps
  /// e ajustar os limites dos codecs H264/VP8/VP9/AV1.
  static String optimizeSdpForStreaming(String sdp, VideoStreamPreset preset) {
    final lines = sdp.split('\r\n');
    final result = <String>[];
    bool inVideo = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('m=audio')) {
        inVideo = false;
      } else if (line.startsWith('m=video')) {
        inVideo = true;
        result.add(line);
        // Injeta limites de bandwidth logo abaixo da declaração m=video
        result.add('b=AS:${preset.bitrateKbps}');
        result.add('b=TIAS:${preset.bitrateKbps * 1000}');
        continue;
      }

      if (inVideo && (line.startsWith('b=AS:') || line.startsWith('b=TIAS:'))) {
        continue;
      }

      if (inVideo && line.startsWith('a=fmtp:')) {
        final maxMbps = (preset.width * preset.height * preset.frameRate) ~/ 256;
        final maxFs = (preset.width * preset.height) ~/ 256;
        var modifiedFmtp = line;
        if (!modifiedFmtp.contains('x-google-min-bitrate')) {
          modifiedFmtp += ';x-google-min-bitrate=${preset.minBitrateKbps}';
        }
        if (!modifiedFmtp.contains('x-google-start-bitrate')) {
          modifiedFmtp += ';x-google-start-bitrate=${preset.startBitrateKbps}';
        }
        if (!modifiedFmtp.contains('x-google-max-bitrate')) {
          modifiedFmtp += ';x-google-max-bitrate=${preset.bitrateKbps}';
        }
        if (!modifiedFmtp.contains('max-fps')) {
          modifiedFmtp += ';max-fps=${preset.frameRate}';
        }
        if (!modifiedFmtp.contains('max-fs')) {
          modifiedFmtp += ';max-fs=$maxFs';
        }
        if (!modifiedFmtp.contains('max-mbps')) {
          modifiedFmtp += ';max-mbps=$maxMbps';
        }
        result.add(modifiedFmtp);
        continue;
      }

      result.add(line);
    }

    return result.join('\r\n');
  }

  Future<void> _applyPresetToSender(
    RTCRtpSender? sender,
    VideoStreamPreset preset,
  ) async {
    if (sender == null) return;
    try {
      final parameters = sender.parameters;
      final encodings = parameters.encodings;
      if (encodings != null && encodings.isNotEmpty) {
        for (final enc in encodings) {
          enc.maxBitrate = preset.bitrateKbps * 1000;
          enc.maxFramerate = preset.frameRate;
          enc.scaleResolutionDownBy = 1.0;
        }
        await sender.setParameters(parameters);
      }
    } catch (_) {}
  }

  /// Acquires requested local audio and/or video tracks gracefully.
  /// If hardware/permission is unavailable or user chose muted/off, returns null or partial stream
  /// without failing the call connection.
  Future<MediaStream?> _acquireLocalMedia({
    required bool audio,
    required bool video,
    VideoStreamPreset? preset,
  }) async {
    if (!audio && !video) {
      _isAudioMuted = true;
      _isVideoEnabled = false;
      return null;
    }
    final targetPreset = preset ?? _currentPreset;
    if (video) {
      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': audio ? _audioConstraints : false,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': targetPreset.width},
            'height': {'ideal': targetPreset.height},
            'frameRate': {'ideal': targetPreset.frameRate},
          },
        });
        _isVideoEnabled = stream.getVideoTracks().isNotEmpty;
        _isAudioMuted = !audio || stream.getAudioTracks().isEmpty;
        return stream;
      } catch (_) {
        // Fallback progressivo se a câmera não aceitar a resolução máxima
        try {
          final stream = await navigator.mediaDevices.getUserMedia({
            'audio': audio ? _audioConstraints : false,
            'video': {
              'facingMode': 'user',
              'width': {'ideal': 1920},
              'height': {'ideal': 1080},
              'frameRate': {'ideal': 30},
            },
          });
          _isVideoEnabled = stream.getVideoTracks().isNotEmpty;
          _isAudioMuted = !audio || stream.getAudioTracks().isEmpty;
          return stream;
        } catch (_) {}
      }
    }
    if (audio) {
      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': _audioConstraints,
          'video': false,
        });
        _isVideoEnabled = false;
        _isAudioMuted = stream.getAudioTracks().isEmpty;
        return stream;
      } catch (_) {
        // Fallback to listener-only if microphone is unavailable
      }
    }
    _isVideoEnabled = false;
    _isAudioMuted = true;
    return null;
  }

  Future<MediaStream> _acquireDisplayStream({
    DesktopCapturerSource? source,
    bool includeMic = true,
    VideoStreamPreset? preset,
  }) async {
    final targetPreset = preset ?? _currentPreset;
    MediaStream displayStream;
    try {
      displayStream = await navigator.mediaDevices.getDisplayMedia({
        'video': source != null
            ? {
                'deviceId': {'exact': source.id},
                'mandatory': {
                  'frameRate': targetPreset.frameRate,
                  'maxWidth': targetPreset.width,
                  'maxHeight': targetPreset.height,
                },
              }
            : {
                'frameRate': {
                  'ideal': targetPreset.frameRate,
                  'max': targetPreset.frameRate,
                },
                'width': {
                  'ideal': targetPreset.width,
                  'max': targetPreset.width,
                },
                'height': {
                  'ideal': targetPreset.height,
                  'max': targetPreset.height,
                },
              },
        'audio': false,
      });
    } catch (_) {
      try {
        displayStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {
            'frameRate': {'ideal': 30},
            'width': {'ideal': 1920},
            'height': {'ideal': 1080},
          },
          'audio': false,
        });
      } catch (_) {
        displayStream = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': false,
        });
      }
    }

    if (displayStream.getVideoTracks().isEmpty) {
      throw StateError('Nenhuma trilha de vídeo de tela foi capturada.');
    }

    for (final track in displayStream.getVideoTracks()) {
      track.onEnded = () {
        if (_isScreenSharing) {
          unawaited(stopScreenShare());
        }
      };
    }

    if (includeMic) {
      try {
        final micStream = await navigator.mediaDevices.getUserMedia({
          'audio': _audioConstraints,
          'video': false,
        });
        for (final audioTrack in micStream.getAudioTracks()) {
          await displayStream.addTrack(audioTrack);
        }
        _isAudioMuted = displayStream.getAudioTracks().isEmpty;
      } catch (_) {
        _isAudioMuted = true;
      }
    } else {
      _isAudioMuted = true;
    }

    return displayStream;
  }

  Future<void> _attachStreamTracks(
    RTCPeerConnection pc,
    MediaStream? stream,
  ) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      final sender = await pc.addTrack(track, stream);
      _senders.add(sender);
      if (track.kind == 'audio') {
        _audioSender = sender;
      } else if (track.kind == 'video') {
        _videoSender = sender;
        await _applyPresetToSender(sender, _currentPreset);
      }
    }
  }

  Future<void> startCall(
    RTCPeerConnection pc, {
    bool audio = true,
    required bool video,
    bool screenShare = false,
    DesktopCapturerSource? screenSource,
    VideoStreamPreset? preset,
  }) async {
    if (_state != P2PCallState.idle) {
      throw StateError('Já existe uma chamada ou transmissão em andamento.');
    }
    await cleanup(pc);
    if (preset != null) {
      _currentPreset = preset;
    }
    final callId = _uuid.v4();
    _callId = callId;
    _isVideoCall = video || screenShare;
    _isScreenSharing = screenShare;
    _isAudioMuted = !audio;
    _isRemoteAudioMuted = false;
    _isRemoteVideoEnabled = false;
    _isRemoteScreenSharing = false;
    _remoteDescriptionSet = false;
    _state = P2PCallState.outgoing;
    onStateChanged();

    try {
      if (screenShare) {
        final stream = await _acquireDisplayStream(
          source: screenSource,
          includeMic: audio,
          preset: _currentPreset,
        );
        _screenStream = stream;
        _localStream = stream;
        _isVideoEnabled = true;
        await _attachStreamTracks(pc, stream);
      } else {
        final stream = await _acquireLocalMedia(
          audio: audio,
          video: video,
          preset: _currentPreset,
        );
        _localStream = stream;
        await _attachStreamTracks(pc, stream);
      }

      final offer = await pc.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await pc.setLocalDescription(offer);
      final localDesc = await pc.getLocalDescription() ?? offer;
      if (localDesc.sdp == null || localDesc.sdp!.isEmpty) {
        throw StateError('Não foi possível preparar a sessão de mídia P2P.');
      }
      await sendSignal({
        'type': 'offer',
        'callId': callId,
        'video': _isVideoCall,
        'audioMuted': _isAudioMuted,
        'videoEnabled': _isVideoEnabled,
        'screenSharing': _isScreenSharing,
        'preset': _currentPreset.id,
        'sdp': _prepareSdp(localDesc.sdp!),
      });
      onStateChanged();
    } catch (_) {
      await cleanup(pc);
      rethrow;
    }
  }

  Future<void> acceptCall(
    RTCPeerConnection pc, {
    bool withAudio = true,
    bool? withVideo,
    VideoStreamPreset? preset,
  }) async {
    final offerSdp = _pendingOfferSdp;
    final callId = _callId;
    if (_state != P2PCallState.incoming || offerSdp == null || callId == null) {
      throw StateError('Não há chamada pendente para aceitar.');
    }
    if (preset != null) {
      _currentPreset = preset;
    }
    final wantVideo = withVideo ?? (_isVideoCall && !_isRemoteScreenSharing);
    _state = P2PCallState.connecting;
    onStateChanged();

    try {
      final stream = await _acquireLocalMedia(
        audio: withAudio,
        video: wantVideo,
        preset: _currentPreset,
      );
      _localStream = stream;
      if (wantVideo && _isVideoEnabled) _isVideoCall = true;

      await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
      _remoteDescriptionSet = true;
      await _flushCandidates(pc);

      await _attachStreamTracks(pc, stream);

      final answer = await pc.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await pc.setLocalDescription(answer);
      final localDesc = await pc.getLocalDescription() ?? answer;
      if (localDesc.sdp == null || localDesc.sdp!.isEmpty) {
        throw StateError('Não foi possível responder à chamada.');
      }
      await sendSignal({
        'type': 'answer',
        'callId': callId,
        'video': _isVideoCall,
        'audioMuted': _isAudioMuted,
        'videoEnabled': _isVideoEnabled,
        'screenSharing': _isScreenSharing,
        'preset': _currentPreset.id,
        'sdp': _prepareSdp(localDesc.sdp!),
      });
      _pendingOfferSdp = null;
      _connectedAt = DateTime.now();
      _state = P2PCallState.active;
      onStateChanged();
    } catch (_) {
      await sendSignal({'type': 'hangup', 'callId': callId});
      await cleanup(pc);
      rethrow;
    }
  }

  Future<void> rejectCall(RTCPeerConnection? pc) async {
    final callId = _callId;
    if (callId != null) {
      await sendSignal({'type': 'reject', 'callId': callId});
    }
    await cleanup(pc);
  }

  Future<void> endCall(RTCPeerConnection? pc) async {
    final callId = _callId;
    if (callId != null) {
      await sendSignal({'type': 'hangup', 'callId': callId});
    }
    await cleanup(pc);
  }

  /// Toggles microphone audio on/off without disconnecting the call.
  /// If the user joined without a microphone track, acquires it on demand.
  Future<void> toggleMute(RTCPeerConnection pc) async {
    final stream = _localStream;
    final audioTracks = stream?.getAudioTracks() ?? const [];
    if (audioTracks.isNotEmpty) {
      _isAudioMuted = !_isAudioMuted;
      for (final track in audioTracks) {
        track.enabled = !_isAudioMuted;
      }
      onStateChanged();
      await _broadcastMediaState();
      return;
    }

    // Acquire microphone on demand if call started without audio track
    if (!_isAudioMuted) {
      _isAudioMuted = true;
      onStateChanged();
      await _broadcastMediaState();
      return;
    }

    try {
      final micStream = await navigator.mediaDevices.getUserMedia({
        'audio': _audioConstraints,
        'video': false,
      });
      final newAudioTracks = micStream.getAudioTracks();
      if (newAudioTracks.isEmpty) return;
      final audioTrack = newAudioTracks.first;

      if (_localStream != null) {
        await _localStream!.addTrack(audioTrack);
      } else {
        _localStream = micStream;
      }

      if (_audioSender != null) {
        await _audioSender!.replaceTrack(audioTrack);
      } else {
        final sender = await pc.addTrack(audioTrack, _localStream!);
        _senders.add(sender);
        _audioSender = sender;
        if (_state == P2PCallState.active) {
          await _renegotiate(pc);
        }
      }
      _isAudioMuted = false;
      onStateChanged();
      await _broadcastMediaState();
    } catch (_) {}
  }

  /// Toggles camera video on/off without disconnecting the call.
  /// Turning off the camera stops the camera capture track while keeping the call alive.
  Future<void> toggleVideo(RTCPeerConnection pc) async {
    // If camera is currently enabled (and not screen sharing), turn camera OFF
    if (_isVideoEnabled && !_isScreenSharing) {
      final stream = _localStream;
      if (stream != null) {
        final camTracks = List<MediaStreamTrack>.from(stream.getVideoTracks());
        for (final track in camTracks) {
          try {
            await stream.removeTrack(track);
          } catch (_) {}
          try {
            await track.stop();
          } catch (_) {}
        }
      }
      try {
        await _videoSender?.replaceTrack(null);
      } catch (_) {}
      _isVideoEnabled = false;
      onStateChanged();
      await _broadcastMediaState();
      return;
    }

    // If screen sharing is active and user clicks camera, switch from screen to camera
    if (_isScreenSharing) {
      await _disposeScreenStreamOnly();
    }

    // Turn camera ON
    try {
      final camStream = await _acquireLocalMedia(
        audio: false,
        video: true,
        preset: _currentPreset,
      );
      if (camStream == null) return;
      final newVideoTracks = camStream.getVideoTracks();
      if (newVideoTracks.isEmpty) return;
      final track = newVideoTracks.first;

      if (_localStream != null) {
        for (final old in List<MediaStreamTrack>.from(
          _localStream!.getVideoTracks(),
        )) {
          try {
            await _localStream!.removeTrack(old);
            await old.stop();
          } catch (_) {}
        }
        await _localStream!.addTrack(track);
      } else {
        _localStream = camStream;
      }

      _isVideoEnabled = true;
      _isVideoCall = true;

      if (_videoSender != null) {
        await _videoSender!.replaceTrack(track);
        await _applyPresetToSender(_videoSender, _currentPreset);
        await _broadcastMediaState();
      } else {
        final sender = await pc.addTrack(track, _localStream!);
        _senders.add(sender);
        _videoSender = sender;
        await _applyPresetToSender(sender, _currentPreset);
        if (_state == P2PCallState.active) {
          await _renegotiate(pc);
        }
      }
      onStateChanged();
    } catch (_) {}
  }

  /// Starts or stops P2P screen streaming during an active call without disconnecting.
  Future<void> toggleScreenShare(
    RTCPeerConnection pc, {
    DesktopCapturerSource? source,
  }) async {
    if (_isScreenSharing) {
      await stopScreenShare();
      return;
    }
    if (_state != P2PCallState.active || _callId == null) return;

    final displayStream = await _acquireDisplayStream(
      source: source,
      includeMic: false,
      preset: _currentPreset,
    );
    final screenTrack = displayStream.getVideoTracks().first;

    // Stop camera tracks while screen streaming is active
    final local = _localStream;
    if (local != null) {
      for (final camTrack in List<MediaStreamTrack>.from(
        local.getVideoTracks(),
      )) {
        try {
          await local.removeTrack(camTrack);
          await camTrack.stop();
        } catch (_) {}
      }
    }

    _screenStream = displayStream;
    _isScreenSharing = true;
    _isVideoEnabled = true;
    _isVideoCall = true;

    if (_videoSender != null) {
      await _videoSender!.replaceTrack(screenTrack);
      await _applyPresetToSender(_videoSender, _currentPreset);
      await _broadcastMediaState();
    } else {
      final sender = await pc.addTrack(screenTrack, displayStream);
      _senders.add(sender);
      _videoSender = sender;
      await _applyPresetToSender(sender, _currentPreset);
      await _renegotiate(pc);
    }
    onStateChanged();
  }

  Future<void> _disposeScreenStreamOnly() async {
    final screen = _screenStream;
    _screenStream = null;
    _isScreenSharing = false;
    if (screen != null) {
      for (final track in List<MediaStreamTrack>.from(
        screen.getVideoTracks(),
      )) {
        track.onEnded = null;
        try {
          await track.stop();
        } catch (_) {}
      }
      if (screen != _localStream) {
        try {
          await screen.dispose();
        } catch (_) {}
      }
    }
  }

  /// Stops screen sharing while keeping the call connected (audio continues or stays muted).
  Future<void> stopScreenShare() async {
    if (!_isScreenSharing) return;
    await _disposeScreenStreamOnly();
    _isVideoEnabled = false;
    try {
      await _videoSender?.replaceTrack(null);
    } catch (_) {}
    onStateChanged();
    await _broadcastMediaState();
  }

  Future<void> _renegotiate(RTCPeerConnection pc) async {
    final offer = await pc.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await pc.setLocalDescription(offer);
    final localDesc = await pc.getLocalDescription() ?? offer;
    if (localDesc.sdp != null && localDesc.sdp!.isNotEmpty) {
      await sendSignal({
        'type': 'renegotiate_offer',
        'callId': _callId,
        'audioMuted': _isAudioMuted,
        'videoEnabled': _isVideoEnabled,
        'screenSharing': _isScreenSharing,
        'preset': _currentPreset.id,
        'sdp': _prepareSdp(localDesc.sdp!),
      });
    }
  }

  /// Altera a qualidade do vídeo/streaming em tempo real durante a chamada ativa (até 4K@60fps).
  Future<void> setVideoQuality(
    VideoStreamPreset preset,
    RTCPeerConnection pc,
  ) async {
    _currentPreset = preset;

    // 1. Reajusta parâmetros de encoder no RTP sender ativo
    if (_videoSender != null) {
      await _applyPresetToSender(_videoSender, preset);
    }

    // 2. Se estiver transmitindo câmera, readquire a câmera com a nova resolução e substitui a track
    if (_isVideoEnabled && !_isScreenSharing && _localStream != null) {
      try {
        final newCamStream = await _acquireLocalMedia(
          audio: !_isAudioMuted,
          video: true,
          preset: preset,
        );
        if (newCamStream != null && newCamStream.getVideoTracks().isNotEmpty) {
          final newTrack = newCamStream.getVideoTracks().first;
          final oldTracks = List<MediaStreamTrack>.from(
            _localStream!.getVideoTracks(),
          );
          for (final t in oldTracks) {
            try {
              await _localStream!.removeTrack(t);
              await t.stop();
            } catch (_) {}
          }
          await _localStream!.addTrack(newTrack);
          if (_videoSender != null) {
            await _videoSender!.replaceTrack(newTrack);
            await _applyPresetToSender(_videoSender, preset);
          }
        }
      } catch (_) {}
    }

    // 3. Sinaliza ao contato a nova qualidade e renegocia SDP para novos limites de banda
    if (_callId != null) {
      await sendSignal({
        'type': 'video_quality',
        'callId': _callId,
        'preset': preset.id,
      });
      if (_state == P2PCallState.active) {
        await _renegotiate(pc);
      }
    }
    onStateChanged();
  }

  Future<void> _broadcastMediaState() async {
    if (_callId == null) return;
    await sendSignal({
      'type': 'media_state',
      'callId': _callId,
      'audioMuted': _isAudioMuted,
      'videoEnabled': _isVideoEnabled,
      'screenSharing': _isScreenSharing,
    });
  }

  Future<void> switchCamera() async {
    if (_isScreenSharing) return;
    final stream = _localStream;
    if (stream == null) return;
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) return;
    try {
      await Helper.switchCamera(videoTracks.first);
      onStateChanged();
    } catch (_) {}
  }

  Future<void> toggleSpeakerphone() async {
    _isSpeakerphoneOn = !_isSpeakerphoneOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerphoneOn);
    } catch (_) {}
    onStateChanged();
  }

  Future<void> handleSignal(
    RTCPeerConnection pc,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] as String?;
    final callId = data['callId'] as String?;
    if (type == null || callId == null) return;

    switch (type) {
      case 'offer':
        if (_state != P2PCallState.idle) {
          await sendSignal({'type': 'busy', 'callId': callId});
          return;
        }
        final sdp = data['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        _callId = callId;
        _pendingOfferSdp = sdp;
        _isVideoCall = data['video'] == true;
        _isRemoteVideoEnabled = data['videoEnabled'] == true;
        _isRemoteScreenSharing = data['screenSharing'] == true;
        _isRemoteAudioMuted = data['audioMuted'] == true;
        final remotePresetId = data['preset'] as String?;
        if (remotePresetId != null) {
          _remotePreset = VideoStreamPreset.fromId(remotePresetId);
        }
        _remoteDescriptionSet = false;
        _state = P2PCallState.incoming;
        onStateChanged();

      case 'answer':
        if (_state != P2PCallState.outgoing || callId != _callId) return;
        final sdp = data['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        _isRemoteVideoEnabled = data['videoEnabled'] == true;
        _isRemoteScreenSharing = data['screenSharing'] == true;
        _isRemoteAudioMuted = data['audioMuted'] == true;
        final remotePresetId = data['preset'] as String?;
        if (remotePresetId != null) {
          _remotePreset = VideoStreamPreset.fromId(remotePresetId);
        }
        if (data['video'] == true || _isRemoteScreenSharing) {
          _isVideoCall = true;
        }
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        _remoteDescriptionSet = true;
        await _flushCandidates(pc);
        _connectedAt = DateTime.now();
        _state = P2PCallState.active;
        onStateChanged();

      case 'renegotiate_offer':
        if (_state != P2PCallState.active || callId != _callId) return;
        final sdp = data['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        _isRemoteVideoEnabled = data['videoEnabled'] == true;
        _isRemoteScreenSharing = data['screenSharing'] == true;
        final remotePresetId = data['preset'] as String?;
        if (remotePresetId != null) {
          _remotePreset = VideoStreamPreset.fromId(remotePresetId);
        }
        if (data['audioMuted'] is bool) {
          _isRemoteAudioMuted = data['audioMuted'] as bool;
        }
        if (_isRemoteVideoEnabled || _isRemoteScreenSharing) {
          _isVideoCall = true;
        }
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        final answer = await pc.createAnswer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 1,
        });
        await pc.setLocalDescription(answer);
        final localDesc = await pc.getLocalDescription() ?? answer;
        if (localDesc.sdp != null && localDesc.sdp!.isNotEmpty) {
          await sendSignal({
            'type': 'renegotiate_answer',
            'callId': callId,
            'audioMuted': _isAudioMuted,
            'videoEnabled': _isVideoEnabled,
            'screenSharing': _isScreenSharing,
            'preset': _currentPreset.id,
            'sdp': _prepareSdp(localDesc.sdp!),
          });
        }
        onStateChanged();

      case 'renegotiate_answer':
        if (_state != P2PCallState.active || callId != _callId) return;
        final sdp = data['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        _isRemoteVideoEnabled = data['videoEnabled'] == true;
        _isRemoteScreenSharing = data['screenSharing'] == true;
        final remotePresetId = data['preset'] as String?;
        if (remotePresetId != null) {
          _remotePreset = VideoStreamPreset.fromId(remotePresetId);
        }
        if (data['audioMuted'] is bool) {
          _isRemoteAudioMuted = data['audioMuted'] as bool;
        }
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        onStateChanged();

      case 'video_quality':
        if (callId != _callId) return;
        final presetId = data['preset'] as String?;
        if (presetId != null) {
          _remotePreset = VideoStreamPreset.fromId(presetId);
          onStateChanged();
        }

      case 'ice':
        if (callId != _callId) return;
        final cand = data['candidate'] as String?;
        if (cand == null || cand.isEmpty) return;
        final candidate = RTCIceCandidate(
          cand,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        if (_remoteDescriptionSet) {
          await pc.addCandidate(candidate);
        } else {
          _pendingCandidates.add(candidate);
        }

      case 'media_state':
        if (callId != _callId) return;
        if (data['audioMuted'] is bool) {
          _isRemoteAudioMuted = data['audioMuted'] as bool;
        }
        if (data['videoEnabled'] is bool) {
          _isRemoteVideoEnabled = data['videoEnabled'] as bool;
          if (_isRemoteVideoEnabled) _isVideoCall = true;
        }
        if (data['screenSharing'] is bool) {
          _isRemoteScreenSharing = data['screenSharing'] as bool;
          if (_isRemoteScreenSharing) {
            _isRemoteVideoEnabled = true;
            _isVideoCall = true;
          }
        }
        onStateChanged();

      case 'reject':
      case 'hangup':
      case 'busy':
        if (callId != _callId) return;
        await cleanup(pc);
    }
  }

  Future<void> _flushCandidates(RTCPeerConnection pc) async {
    final pending = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in pending) {
      try {
        await pc.addCandidate(candidate);
      } catch (_) {}
    }
  }

  Future<void> cleanup(RTCPeerConnection? pc) async {
    if (pc != null && _senders.isNotEmpty) {
      for (final sender in List<RTCRtpSender>.from(_senders)) {
        try {
          await pc.removeTrack(sender);
        } catch (_) {}
      }
    }
    _senders.clear();
    _audioSender = null;
    _videoSender = null;
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _pendingOfferSdp = null;
    _callId = null;
    _connectedAt = null;
    _isAudioMuted = false;
    _isVideoEnabled = false;
    _isScreenSharing = false;
    _isRemoteVideoEnabled = false;
    _isRemoteAudioMuted = false;
    _isRemoteScreenSharing = false;
    _isVideoCall = false;
    _remotePreset = VideoStreamPreset.ultra4k60;

    final screen = _screenStream;
    _screenStream = null;
    if (screen != null) {
      for (final track in screen.getTracks()) {
        track.onEnded = null;
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await screen.dispose();
      } catch (_) {}
    }

    final local = _localStream;
    _localStream = null;
    if (local != null && local != screen) {
      for (final track in local.getTracks()) {
        track.onEnded = null;
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await local.dispose();
      } catch (_) {}
    }

    _remoteStream = null;
    final wasInCall = _state != P2PCallState.idle;
    _state = P2PCallState.idle;
    if (wasInCall) {
      onStateChanged();
    }
  }
}
