// ignore_for_file: file_names

import 'dart:io';

import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> getPhotosDir() async {
  final appDir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${appDir.path}/photos');
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }
  return photosDir;
}

Future<String> getPhotoPath(int listItemId) async {
  final photosDir = await getPhotosDir();
  return '${photosDir.path}/$listItemId.jpg';
}

Future<bool> hasPhoto(int listItemId) async {
  final path = await getPhotoPath(listItemId);
  return File(path).exists();
}

Future<void> deletePhoto(int listItemId) async {
  final path = await getPhotoPath(listItemId);
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<bool> pickAndSavePhoto(int listItemId, ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source, imageQuality: 85);
  if (picked == null) return false;

  final path = await getPhotoPath(listItemId);
  await File(picked.path).copy(path);
  return true;
}

Future<bool> movePhotoToGallery(int listItemId) async {
  final path = await getPhotoPath(listItemId);
  final file = File(path);
  if (!await file.exists()) return false;

  try {
    // Save to gallery using Gal package
    await Gal.putImage(path);
    await file.delete();
    return true;
  } catch (e) {
    return false;
  }
}
