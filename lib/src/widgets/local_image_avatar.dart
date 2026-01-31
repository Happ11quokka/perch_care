import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/storage/local_image_storage_service.dart';

/// SQLite에서 이미지를 로드하여 원형으로 표시하는 재사용 위젯
class LocalImageAvatar extends StatefulWidget {
  final String ownerType;
  final String ownerId;
  final double size;
  final Widget placeholder;

  const LocalImageAvatar({
    super.key,
    required this.ownerType,
    required this.ownerId,
    this.size = 120,
    required this.placeholder,
  });

  @override
  State<LocalImageAvatar> createState() => _LocalImageAvatarState();
}

class _LocalImageAvatarState extends State<LocalImageAvatar> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(LocalImageAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.ownerType != widget.ownerType) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final bytes = await LocalImageStorageService.instance.getImage(
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
    );
    if (mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD9D9D9),
        image: _imageBytes != null
            ? DecorationImage(
                image: MemoryImage(_imageBytes!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _imageBytes == null ? widget.placeholder : null,
    );
  }
}
