import 'package:fluffychat/utils/extension/web_url_creation_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/download_file_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:matrix/matrix.dart';

mixin HandleVideoDownloadMixin {
  String? lastSelectedVideoEventId;

  Future<String> handleDownloadVideoEvent({
    required Event event,
    void Function(String uriOrFilePath)? playVideoAction,
  }) async {
    lastSelectedVideoEventId = event.eventId;
    if (PlatformInfos.isWeb) {
      final videoBytes = await event.downloadAndDecryptAttachment();
      final url = videoBytes.bytes?.toWebUrl();
      if (url == null) {
        throw Exception('$videoBytes is null');
      }
      if (lastSelectedVideoEventId == event.eventId &&
          playVideoAction != null) {
        playVideoAction(url);
      }
      return url;
    } else {
      final videoFile = await event.getFileInfo();
      if (lastSelectedVideoEventId == event.eventId &&
          playVideoAction != null &&
          videoFile?.filePath != null) {
        playVideoAction(videoFile!.filePath);
      }
      return videoFile?.filePath ?? '';
    }
  }
}
