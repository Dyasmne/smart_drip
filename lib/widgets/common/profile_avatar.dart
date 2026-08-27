import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only profile avatar: lets the user pick a photo from the camera
/// or gallery, saves a copy into the app's own documents folder, and
/// remembers the path in SharedPreferences so it survives app restarts.
///
/// Nothing is uploaded anywhere — this is device-local only, so a fresh
/// install or switching devices won't carry the photo over.
class ProfileAvatar extends StatefulWidget {
  final String initials;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.initials,
    this.radius = 26,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  static const _prefsKey = 'profile_avatar_path';

  File? _avatarFile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAvatar();
  }

  Future<void> _loadSavedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);

    if (path != null && await File(path).exists()) {
      if (!mounted) return;
      setState(() {
        _avatarFile = File(path);
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndSave(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );

      if (picked == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      // Fixed filename so re-picking overwrites the old one instead of
      // piling up files on disk.
      final savedPath = '${docsDir.path}/profile_avatar.jpg';
      final savedFile = await File(picked.path).copy(savedPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, savedFile.path);

      if (!mounted) return;
      setState(() => _avatarFile = savedFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't set photo: $e")),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);

    if (_avatarFile != null && await _avatarFile!.exists()) {
      await _avatarFile!.delete();
    }

    if (!mounted) return;
    setState(() => _avatarFile = null);
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                "Profile Photo",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("Take Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSave(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSave(ImageSource.gallery);
              },
            ),
            if (_avatarFile != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  "Remove Photo",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showPickerSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: const Color(0xff123524),
            backgroundImage:
                _avatarFile != null ? FileImage(_avatarFile!) : null,
            child: (_avatarFile == null && !_loading)
                ? Text(
                    widget.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.radius * 0.6,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xff123524),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}