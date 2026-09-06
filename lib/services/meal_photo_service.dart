import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MealPhotoService {
  static final MealPhotoService _instance = MealPhotoService._internal();
  factory MealPhotoService() => _instance;
  MealPhotoService._internal();

  static const String bucketName = 'meal_photos';

  /// Compresses and uploads a meal image to Supabase Storage in the 'meal_photos' bucket.
  /// Returns the persistent public URL or null if upload fails.
  static Future<String?> uploadMealPhoto({
    required XFile image,
    required String slotId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      final userId = currentUser?.id ?? 'guest';

      debugPrint('[MealPhotoService] Initiating upload for slot "$slotId". Auth userId: $userId (authenticated: ${currentUser != null})');

      if (currentUser == null) {
        debugPrint('[MealPhotoService WARNING] User is not authenticated. If RLS requires authenticated role, upload might fail with 403 / 400.');
      }

      Uint8List bytes = await image.readAsBytes();
      debugPrint('[MealPhotoService] Read source image: ${bytes.lengthInBytes} bytes');

      // Compress/resize locally before upload (max ~1024px, quality ~80)
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          bytes = Uint8List.fromList(compressed);
          debugPrint('[MealPhotoService] Compressed image size: ${bytes.lengthInBytes} bytes');
        }
      } catch (compressErr) {
        debugPrint('[MealPhotoService] Compression fallback (using raw bytes): $compressErr');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedSlotId = slotId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath = '$userId/${sanitizedSlotId}_$timestamp.jpg';

      debugPrint('[MealPhotoService] Uploading binary to bucket "$bucketName" at path: "$filePath"...');

      final uploadResponse = await client.storage.from(bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      debugPrint('[MealPhotoService] UploadBinary response path: $uploadResponse');

      final publicUrl = client.storage.from(bucketName).getPublicUrl(filePath);
      debugPrint('[MealPhotoService SUCCESS] Uploaded photo public URL: $publicUrl');
      return publicUrl;
    } on StorageException catch (se) {
      debugPrint('[MealPhotoService ERROR - StorageException] statusCode: ${se.statusCode}, error: ${se.error}, message: ${se.message}');
      if (se.statusCode == '403' || se.statusCode == '401') {
        debugPrint('[MealPhotoService HINT] 403 Forbidden: Ensure the user is logged in and RLS policy "Authenticated users can upload meal photos" is created on storage.objects for bucket "$bucketName".');
      } else if (se.statusCode == '404') {
        debugPrint('[MealPhotoService HINT] 404 Not Found: Ensure the bucket "$bucketName" is created in Supabase Storage.');
      }
      return null;
    } catch (e, stack) {
      debugPrint('[MealPhotoService ERROR] Unexpected failure uploading meal photo: $e\n$stack');
      return null;
    }
  }

  /// Builds a safe image widget that handles both network URLs (http/https)
  /// and local fallback file paths.
  static Widget buildMealImage({
    required String photoUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final isNetwork = photoUrl.startsWith('http://') || photoUrl.startsWith('https://');

    if (isNetwork) {
      return Image.network(
        photoUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFF94A3B8)),
              ),
            ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: const Color(0xFF0F172A),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              );
        },
      );
    } else {
      // Local file path
      try {
        final file = File(photoUrl);
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ??
              Container(
                width: width,
                height: height,
                color: const Color(0xFF0F172A),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
        );
      } catch (_) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFF94A3B8)),
              ),
            );
      }
    }
  }
}
