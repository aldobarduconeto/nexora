enum ContentWarning {
  spoiler('Spoiler'),
  nsfw('NSFW');

  const ContentWarning(this.label);
  final String label;
}

enum ProtectedContentKind {
  text('Texto'),
  photo('Foto'),
  video('Vídeo'),
  audio('Áudio'),
  file('Arquivo');

  const ProtectedContentKind(this.label);
  final String label;

  bool get isMedia => this == photo || this == video || this == audio;

  static ProtectedContentKind forExtension(String? extension) =>
      switch (extension?.toLowerCase()) {
        'jpg' ||
        'jpeg' ||
        'png' ||
        'gif' ||
        'webp' ||
        'bmp' ||
        'heic' ||
        'heif' ||
        'avif' => photo,
        'mp4' ||
        'mov' ||
        'webm' ||
        'mkv' ||
        'avi' ||
        'm4v' ||
        '3gp' ||
        'mpeg' ||
        'mpg' => video,
        'mp3' ||
        'wav' ||
        'm4a' ||
        'aac' ||
        'ogg' ||
        'opus' ||
        'flac' ||
        'wma' ||
        'aiff' ||
        'amr' => audio,
        _ => file,
      };
}
