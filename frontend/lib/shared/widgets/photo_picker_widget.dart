import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/app_theme.dart';

class PhotoPickerWidget extends StatefulWidget {
  /// Recibe `null` cuando el usuario elimina la foto.
  final ValueChanged<File?> onPhotoSelected;
  final String label;
  final bool circleShape;
  final File? initialPhoto;

  const PhotoPickerWidget({
    super.key,
    required this.onPhotoSelected,
    this.label = 'Agregar foto',
    this.circleShape = false,
    this.initialPhoto,
    this.hasError = false,
  });

  /// Pinta el borde con el color de error (validación del formulario).
  final bool hasError;

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

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedPhoto = File(pickedFile.path);
        });
        widget.onPhotoSelected(_selectedPhoto!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir la cámara o la galería. Revisa los permisos.',
              style: AppTheme.bodyMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.panicRed,
          ),
        );
      }
    }
  }

  // El sheet devuelve la opción elegida y se cierra ANTES de abrir la
  // cámara/galería (antes quedaba abierto detrás y, si el usuario cancelaba
  // el selector, seguía ahí).
  Future<void> _showPhotoOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: AppColors.trustBlue,
                ),
                title: Text('Tomar foto', style: AppTheme.bodyMd),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.trustBlue,
                ),
                title: Text('Elegir de galería', style: AppTheme.bodyMd),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (_selectedPhoto != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.panicRed),
                  title: Text('Eliminar foto', style: AppTheme.bodyMd),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'remove':
        setState(() => _selectedPhoto = null);
        // Antes no se avisaba al padre: el wizard seguía con la foto
        // "eliminada" y la enviaba igual al backend.
        widget.onPhotoSelected(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Contenedor de foto con diseño DESIGN.md
        Semantics(
          button: true,
          image: _selectedPhoto != null,
          label: _selectedPhoto != null
              ? '${widget.label}. Foto seleccionada'
              : '${widget.label}. Sin foto',
          hint: _selectedPhoto != null ? 'Cambiar o eliminar' : 'Agregar foto',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            shape: widget.circleShape
                ? const CircleBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _showPhotoOptions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: widget.circleShape
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: !widget.circleShape
                      ? BorderRadius.circular(12) // DESIGN.md: rounded.DEFAULT
                      : null,
                  border: Border.all(
                    color: widget.hasError && _selectedPhoto == null
                        ? Theme.of(context).colorScheme.error
                        : (_selectedPhoto == null
                              ? AppColors.outline.withValues(alpha: 0.3)
                              : AppColors.trustBlue),
                    width: 2,
                  ),
                  color: AppColors.inputFill,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _selectedPhoto != null
                      ? Stack(
                          key: const ValueKey('photo'),
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
                                decoration: const BoxDecoration(
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
                          key: const ValueKey('placeholder'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: AppColors.trustBlue.withValues(alpha: 0.6),
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
