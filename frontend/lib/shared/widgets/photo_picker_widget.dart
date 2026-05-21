import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/app_theme.dart';

class PhotoPickerWidget extends StatefulWidget {
  final Function(File) onPhotoSelected;
  final String label;
  final bool circleShape;
  final File? initialPhoto;

  const PhotoPickerWidget({
    super.key,
    required this.onPhotoSelected,
    this.label = 'Agregar foto',
    this.circleShape = false,
    this.initialPhoto,
  });

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  late File? _selectedPhoto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedPhoto = widget.initialPhoto;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedPhoto = File(pickedFile.path);
        });
        widget.onPhotoSelected(_selectedPhoto!);
        
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al seleccionar foto',
              style: AppTheme.bodyMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.panicRed,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.trustBlue),
              title: Text('Tomar foto', style: AppTheme.bodyMd),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.trustBlue),
              title: Text('Elegir de galería', style: AppTheme.bodyMd),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            if (_selectedPhoto != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.panicRed),
                title: Text('Eliminar foto', style: AppTheme.bodyMd),
                onTap: () {
                  setState(() => _selectedPhoto = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Contenedor de foto con diseño DESIGN.md
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: widget.circleShape ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: !widget.circleShape
                  ? BorderRadius.circular(12)  // DESIGN.md: rounded.DEFAULT
                  : null,
              border: Border.all(
                color: _selectedPhoto == null
                    ? AppColors.outline.withOpacity(0.3)
                    : AppColors.trustBlue,
                width: 2,
                style: _selectedPhoto == null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
              color: AppColors.inputFill,
            ),
            child: _selectedPhoto != null
                ? Stack(
                    children: [
                      // Imagen seleccionada
                      ClipRRect(
                        borderRadius: widget.circleShape
                            ? BorderRadius.circular(140)
                            : BorderRadius.circular(10),
                        child: Image.file(
                          _selectedPhoto!,
                          width: 136,
                          height: 136,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Overlay de edición
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.trustBlue,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: AppColors.trustBlue.withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agregar foto',
                        style: AppTheme.labelSm.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Label
        Text(
          widget.label,
          style: AppTheme.labelSm.copyWith(color: AppColors.outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}