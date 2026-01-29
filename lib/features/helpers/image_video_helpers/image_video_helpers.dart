import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/env.dart';


class ImageVideoHelpers {

  static String mediaServerBaseUrlHelper(){
    final base = Env.apiBaseUrl;
    if (base.isEmpty) return base;
    return base.endsWith('/') ? base : '$base/';
  }

  static String _fullUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = mediaServerBaseUrlHelper();
    if (base.isEmpty) return url;
    final clean = url.startsWith('/') ? url.substring(1) : url;
    return '$base$clean';
  }

  static bool isImage(String url) {
    return url.contains('.jpg') || url.contains('.jpeg') || url.contains('.png');
  }

  static bool isVideo(String url) {
    return url.contains('.mp4') || url.contains('.mov') || url.contains('.avi');
  }

  static Widget getThumbnail(String url) {
    if (isImage(url)) {
      return Image.network(
        _fullUrl(url),
        fit: BoxFit.cover,
      );
    } else if (isVideo(url)) {
      try{
        return Image.network(
          '${mediaServerBaseUrlHelper()}getVideoThumbnail?videoPath=$url',
          fit: BoxFit.cover,
        );
      } catch (e) {
        log('ERROR: getThumbnail - $e');
        return const SizedBox();
      }
    } else {
      return const SizedBox();
    }
  }

  static getFullUrl(String url) {
    return _fullUrl(url);
  }

  static getVideo(String url) async {
    String videoUrl = '${mediaServerBaseUrlHelper()}getAsset?assetPath=$url';

    var request = http.Request('GET', Uri.parse(videoUrl));

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      var videoBytes = await response.stream.toBytes();

      // Create a temporary file and write the video bytes to it
      Directory tempDir = await getTemporaryDirectory();
      File tempFile = File('${tempDir.path}/temp_video.mp4');
      await tempFile.writeAsBytes(videoBytes);

      // Return the file path
      return tempFile.path;
    }
    else {
      log(response.reasonPhrase ?? 'ERROR: getVideoUrl');
      return null;
    }
  }

  static Future<String?> pickFile( List<String>? allowedExtensions ) async {
    String? filePath;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        filePath = file.path;
      }
    } catch (e) {
      log('ERROR: pickFile - $e');
    }

    return filePath;
  }

}
