import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../../core/app_theme.dart';
import '../widgets/progress_indicator.dart';

class Step3NoseScan extends StatefulWidget {
  final Function(File?) onComplete;
  final String petName;

  const Step3NoseScan({
    super.key,
    required this.onComplete,
    required this.petName,
  });

  @override
  State<Step3NoseScan> createState() => _Step3NoseScanState();
}

class _Step3NoseScanState extends State<Step3NoseScan> {
  late CameraController _cameraController;
  late Future<void> _initializeCamera;
  bool _isScanning = false;
  XFile? _capturedPhoto;

  @override
  void initState() {
    super.initState();
    _initializeCamera = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al acceder a la cámara',
              style: AppTheme.bodyMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.panicRed,
          ),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      setState(() => _isScanning = true);

      final photo = await _cameraController.takePicture();

      setState(() {
        _capturedPhoto = photo;
        _isScanning = false;
      });

      // Simulacion del escaneo
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        widget.onComplete(File(photo.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al capturar foto',
              style: AppTheme.bodyMd.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.panicRed,
          ),
        );
        setState(() => _isScanning = false);
      }
    }
  }

  void _showSkipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Estás seguro?', style: AppTheme.headlineMd),
        content: Text(
          'Sin el escaneo de trufa, no podremos identificar a ${widget.petName} '
          'si alguien lo encuentra. Puedes agregarlo después desde tu perfil.',
          style: AppTheme.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Volver', style: AppTheme.labelLg),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(null);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.outline,
            ),
            child: Text(
              'Continuar sin escaneo',
              style: AppTheme.labelLg.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeCamera,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_cameraController),
                _buildCameraOverlay(),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const ProgressIndicatorr(currentStep: 3),
                        GestureDetector(
                          onTap: _showSkipDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              'Saltar',
                              style: AppTheme.labelLg.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom controls
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.marginMobile),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Estado
                          if (_isScanning)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.esmeraldGreen,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ESCANEANDO...',
                                    style: AppTheme.labelLg.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.05 * 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_isScanning) const SizedBox(height: 40),

                          // Botón capturar
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isScanning ? null : _capturePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: Text(
                                'Capturar Huella',
                                style: AppTheme.labelLg.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  Widget _buildCameraOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Overlay circular con guía
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.esmeraldGreen,
                width: 3,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Instrucciones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  'Alinea la nariz',
                  style: AppTheme.headlineMd.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mantén el dispositivo firme dentro del círculo',
                  style: AppTheme.bodyMd.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}