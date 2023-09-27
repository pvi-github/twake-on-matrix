import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fluffychat/data/network/media/media_api.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/presentation/fake_sending_file_info.dart';
import 'package:fluffychat/presentation/model/file/file_asset_entity.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:image/image.dart' as img;
import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

typedef TransactionId = String;

typedef MessageType = String;

typedef FakeImageEvent = SyncUpdate;

extension SendFileExtension on Room {
  Future<String?> sendFileEvent(
    FileInfo fileInfo, {
    String msgType = MessageTypes.Image,
    SyncUpdate? fakeImageEvent,
    String? txid,
    Event? inReplyTo,
    String? editEventId,
    int? shrinkImageMaxDimension,
    ImageFileInfo? thumbnail,
    Map<String, dynamic>? extraContent,
  }) async {
    FileInfo tempfileInfo = fileInfo;
    txid ??= client.generateUniqueTransactionId();
    fakeImageEvent ??= await sendFakeImagePickerFileEvent(
      fileInfo,
      txid: txid,
      messageType: msgType,
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      shrinkImageMaxDimension: shrinkImageMaxDimension,
      extraContent: extraContent,
    );
    // Check media config of the server before sending the file. Stop if the
    // Media config is unreachable or the file is bigger than the given maxsize.
    try {
      final mediaConfig = await client.getConfig();
      final maxMediaSize = mediaConfig.mUploadSize;
      Logs().d(
        'SendImage::sendFileEvent(): FileSized ${fileInfo.fileSize} || maxMediaSize $maxMediaSize',
      );
      if (maxMediaSize != null && maxMediaSize < fileInfo.fileSize) {
        throw FileTooBigMatrixException(fileInfo.fileSize, maxMediaSize);
      }
    } catch (e) {
      Logs().d('Config error while sending file', e);
      await _updateFakeSync(
        fakeImageEvent,
        messageSendingStatusKey,
        EventStatus.error.intValue,
      );
      rethrow;
    }

    final encryptedService = EncryptedService();
    final tempDir = await getTemporaryDirectory();
    final formattedDateTime = DateTime.now().getFormattedCurrentDateTime();
    final tempEncryptedFile =
        await File('${tempDir.path}/$formattedDateTime${fileInfo.fileName}')
            .create();
    final tempThumbnailFile = await File(
      '${tempDir.path}/$formattedDateTime${fileInfo.fileName}_thumbnail.jpg',
    ).create();
    final tempEncryptedThumbnailFile = await File(
      '${tempDir.path}/$formattedDateTime${fileInfo.fileName}_encrypted_thumbnail',
    ).create();

    // computing the thumbnail in case we can
    if (fileInfo is ImageFileInfo &&
        (thumbnail == null || shrinkImageMaxDimension != null)) {
      await _updateFakeSync(
        fakeImageEvent,
        fileSendingStatusKey,
        FileSendingStatus.generatingThumbnail.name,
      );
      thumbnail ??= await _generateThumbnail(
        fileInfo,
        targetPath: tempThumbnailFile.path,
      );

      if (thumbnail != null && fileInfo.fileSize < thumbnail.fileSize) {
        thumbnail = null; // in this case, the thumbnail is not usefull
      }
    } else if (fileInfo is VideoFileInfo) {
      await _updateFakeSync(
        fakeImageEvent,
        fileSendingStatusKey,
        FileSendingStatus.generatingThumbnail.name,
      );
      thumbnail ??= await _getThumbnailVideo(tempThumbnailFile, fileInfo);
    }

    EncryptedFileInfo? encryptedFileInfo;
    EncryptedFileInfo? encryptedThumbnail;
    if (encrypted && client.fileEncryptionEnabled) {
      await _updateFakeSync(
        fakeImageEvent,
        fileSendingStatusKey,
        FileSendingStatus.encrypting.name,
      );

      encryptedFileInfo = await encryptedService.encryptFile(
        fileInfo: fileInfo,
        outputFile: tempEncryptedFile,
      );
      tempfileInfo = FileInfo(
        fileInfo.fileName,
        tempEncryptedFile.path,
        fileInfo.fileSize,
      );
      if (thumbnail != null) {
        encryptedThumbnail = await encryptedService.encryptFile(
          fileInfo: thumbnail,
          outputFile: tempEncryptedThumbnailFile,
        );
      }
    }
    Uri? uploadResp, thumbnailUploadResp;

    await _updateFakeSync(
      fakeImageEvent,
      fileSendingStatusKey,
      FileSendingStatus.uploading.name,
    );
    while (uploadResp == null ||
        (encryptedThumbnail != null && thumbnailUploadResp == null)) {
      try {
        final mediaApi = getIt.get<MediaAPI>();
        final response = await mediaApi.uploadFile(fileInfo: tempfileInfo);
        if (response.contentUri != null) {
          uploadResp = Uri.parse(response.contentUri!);
        }
        if (uploadResp != null &&
            encryptedThumbnail != null &&
            thumbnail != null) {
          final thumbnailResponse = await mediaApi.uploadFile(
            fileInfo: FileInfo(
              thumbnail.fileName,
              tempEncryptedThumbnailFile.path,
              thumbnail.fileSize,
            ),
          );
          thumbnailUploadResp =
              Uri.tryParse(thumbnailResponse.contentUri ?? "");
        }
      } on MatrixException catch (e) {
        await _updateFakeSync(
          fakeImageEvent,
          messageSendingStatusKey,
          EventStatus.error.name,
        );
        Logs().e('Error: $e');
        rethrow;
      } catch (e) {
        await _updateFakeSync(
          fakeImageEvent,
          messageSendingStatusKey,
          EventStatus.error.intValue,
        );
        Logs().e('Error: $e');
        Logs().e('Send File into room failed. Try again...');
        return null;
      }
    }

    if (encryptedFileInfo != null) {
      encryptedFileInfo = EncryptedFileInfo(
        key: encryptedFileInfo.key,
        version: encryptedFileInfo.version,
        initialVector: encryptedFileInfo.initialVector,
        hashes: encryptedFileInfo.hashes,
        url: uploadResp.toString(),
      );
      Logs().d('RoomExtension::EncryptedFileInfo: $encryptedFileInfo');
    }

    if (encryptedThumbnail != null) {
      encryptedThumbnail = EncryptedFileInfo(
        key: encryptedThumbnail.key,
        version: encryptedThumbnail.version,
        initialVector: encryptedThumbnail.initialVector,
        hashes: encryptedThumbnail.hashes,
        url: thumbnailUploadResp.toString(),
      );
      Logs().d('RoomExtension::EncryptedThumbnail: $encryptedThumbnail');
    }

    final blurHash = thumbnail?.filePath != null
        ? await runBenchmarked(
            '_generateBlurHash',
            () => _generateBlurHash(thumbnail!.filePath),
          )
        : null;
    // Send event
    final content = <String, dynamic>{
      'msgtype': msgType,
      'body': fileInfo.fileName,
      'filename': fileInfo.fileName,
      'url': uploadResp.toString(),
      if (encryptedFileInfo != null) 'file': encryptedFileInfo.toJson(),
      'info': {
        ...fileInfo.metadata,
        if (thumbnail != null && encryptedThumbnail == null)
          'thumbnail_url': thumbnailUploadResp.toString(),
        if (thumbnail != null && encryptedThumbnail != null)
          'thumbnail_file': encryptedThumbnail.toJson(),
        if (thumbnail != null) 'thumbnail_info': thumbnail.metadata,
        if (blurHash != null) 'xyz.amorgan.blurhash': blurHash,
      },
      if (extraContent != null) ...extraContent,
    };
    final eventId = await sendEvent(
      content,
      txid: txid,
      inReplyTo: inReplyTo,
      editEventId: editEventId,
    );
    await Future.wait([
      tempEncryptedFile.delete(),
      tempThumbnailFile.delete(),
      tempEncryptedThumbnailFile.delete()
    ]);
    return eventId;
  }

  Future<SyncUpdate> sendFakeImagePickerFileEvent(
    FileInfo fileInfo, {
    String messageType = MessageTypes.Image,
    required String txid,
    Event? inReplyTo,
    String? editEventId,
    int? shrinkImageMaxDimension,
    Map<String, dynamic>? extraContent,
  }) async {
    // Create a fake Event object as a placeholder for the uploading file:
    final fakeImageEvent = SyncUpdate(
      nextBatch: '',
      rooms: RoomsUpdate(
        join: {
          id: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [
                MatrixEvent(
                  content: {
                    'msgtype': messageType,
                    'body': fileInfo.fileName,
                    'filename': fileInfo.fileName,
                  },
                  type: EventTypes.Message,
                  eventId: txid,
                  senderId: client.userID!,
                  originServerTs: DateTime.now(),
                  unsigned: {
                    messageSendingStatusKey: EventStatus.sending.intValue,
                    'transaction_id': txid,
                    if (inReplyTo?.eventId != null)
                      'in_reply_to': inReplyTo?.eventId,
                    if (editEventId != null) 'edit_event_id': editEventId,
                    if (shrinkImageMaxDimension != null)
                      'shrink_image_max_dimension': shrinkImageMaxDimension,
                    if (extraContent != null) 'extra_content': extraContent,
                  },
                ),
              ],
            ),
          ),
        },
      ),
    );
    await handleImageFakeSync(fakeImageEvent);
    return fakeImageEvent;
  }

  Future<void> handleImageFakeSync(
    SyncUpdate fakeImageEvent, {
    Direction? direction,
  }) async {
    if (client.database != null) {
      await client.database?.transaction(() async {
        await client.handleSync(fakeImageEvent, direction: direction);
      });
    } else {
      await client.handleSync(fakeImageEvent, direction: direction);
    }
  }

  Future<void> _storePlaceholderFile({
    required String txid,
    required FileAssetEntity assetEntity,
  }) async {
    // in order to have placeholder, this line must have,
    // otherwise the sending event will be removed from timeline
    final matrixFile = await assetEntity.toMatrixFile();
    if (matrixFile != null) {
      sendingFilePlaceholders[txid] = matrixFile;
    }
  }

  Future<Map<TransactionId, FakeSendingFileInfo>>
      sendPlaceholdersForImagePickerFiles({
    required List<FileAssetEntity> entities,
  }) async {
    final txIdMapToImageFile = <TransactionId, FakeSendingFileInfo>{};
    for (final entity in entities) {
      final fileInfo = await entity.toFileInfo();
      if (fileInfo != null) {
        final txid = client.generateUniqueTransactionId();

        await _storePlaceholderFile(
          txid: txid,
          assetEntity: entity,
        );

        final fakeImageEvent = await sendFakeImagePickerFileEvent(
          fileInfo,
          txid: txid,
          messageType: entity.messageType,
        );
        txIdMapToImageFile[txid] = FakeSendingFileInfo(
          fileInfo: fileInfo,
          fakeImageEvent: fakeImageEvent,
          messageType: entity.messageType,
        );
      }
    }
    return txIdMapToImageFile;
  }

  User? getUser(mxId) {
    return getParticipants().firstWhereOrNull((user) => user.id == mxId);
  }

  Future<ImageFileInfo?> _generateThumbnail(
    ImageFileInfo originalFile, {
    required String targetPath,
  }) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.filePath,
        targetPath,
        quality: AppConfig.thumbnailQuality,
      );
      if (result == null) return null;
      final size = await result.length();
      return ImageFileInfo(
        result.name,
        result.path,
        size,
        width: originalFile.width,
        height: originalFile.height,
      );
    } catch (e) {
      Logs().e('Error while generating thumbnail', e);
      return null;
    }
  }

  Future<String?> _generateBlurHash(String filePath) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        minHeight: AppConfig.blurHashSize,
        minWidth: AppConfig.blurHashSize,
      );
      final blurHash = await compute(
        (imageData) {
          final image = img.decodeJpg(imageData);
          return BlurHash.encode(image!);
        },
        result!,
      );
      return blurHash.hash;
    } catch (e) {
      Logs().e('_generateBlurHash::error', e);
      return null;
    }
  }

  Future<ImageFileInfo> _getThumbnailVideo(
    File tempThumbnailFile,
    VideoFileInfo fileInfo,
  ) async {
    await tempThumbnailFile.writeAsBytes(fileInfo.imagePlaceholderBytes);
    Logs().d('Video thumbnail generated', tempThumbnailFile.path);
    final newThumbnail = ImageFileInfo(
      tempThumbnailFile.path.split("/").last,
      tempThumbnailFile.path,
      fileInfo.imagePlaceholderBytes.lengthInBytes,
    );
    return newThumbnail;
  }

  Future<void> _updateFakeSync(
    SyncUpdate fakeImageEvent,
    String key,
    Object? value,
  ) async {
    fakeImageEvent.rooms!.join!.values.first.timeline!.events!.first
        .unsigned![key] = value;
    await handleImageFakeSync(fakeImageEvent);
  }
}
