// ============================================================================
//  example/lib/screens/upload_screen.dart
//
//  Demonstrates:
//    • ApiExecutor.uploadStream() with real-time progress
//    • UploadState — idle / uploading(progress) / processing / success / failed
//    • UploadState.when() for exhaustive pattern matching
//    • FormData and MultipartFile construction
//
//  The key pattern: wire the onSendProgress callback that uploadStream()
//  passes to your request closure directly into Dio's onSendProgress.
//  This is the ONLY change needed vs a normal dio.post() call.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:keystone_network/config/keystone_network.dart';
import 'package:keystone_network/keystone_network.dart';

import '../data/models.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  // UploadState tracks the full lifecycle: idle → uploading → processing → done
  UploadState<Photo, ApiError> _state = const UploadState.idle();

  // Simulate picking a file path (in a real app: use image_picker)
  final String _fakeFilePath = '/tmp/photo.jpg';

  Future<void> _startUpload() async {
    // ── Build FormData ──────────────────────────────────────────────────────
    //
    // MultipartFile.fromFile() reads the file from disk.
    // In a real app the path comes from image_picker or file_picker.
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        _fakeFilePath,
        filename: 'photo.jpg',
        // contentType: MediaType('image', 'jpeg'),  // optional explicit type
      ),
      'gallery_id': '42',
    });

    // ── uploadStream ────────────────────────────────────────────────────────
    //
    // Note the request parameter signature:
    //   (void Function(int sent, int total) onSendProgress) → Future<Response>
    //
    // You MUST pass onSendProgress into dio.post(onSendProgress: ...).
    // If you omit it, progress events are never emitted and the state
    // jumps straight from uploading(0.0) to processing.

    ApiExecutor.uploadStream<Photo, ApiError>(
      request: (onSendProgress) => KeystoneNetwork.dio.post(
        '/photos',
        data: formData,
        onSendProgress: onSendProgress,   // ← wire here
      ),
      parser: Photo.fromJson,
    ).listen(
      (state) => setState(() => _state = state),
      onError: (_) => setState(() => _state = const UploadState.networkError()),
    );
  }

  void _reset() => setState(() => _state = const UploadState.idle());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Photo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _state.when(

          // ── Idle: show pick + upload button ──────────────────────────────
          idle: () => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 96, color: Colors.grey),
              const SizedBox(height: 24),
              const Text('Select a photo and tap Upload',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Upload Photo'),
                onPressed: _startUpload,
              ),
            ],
          ),

          // ── Uploading: show progress bar ──────────────────────────────────
          //
          // progress is 0.0 – 1.0.
          // Show percentage and a LinearProgressIndicator.
          uploading: (progress) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              Text('Uploading… ${(progress * 100).round()}%',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text('${(progress * 100).round()} / 100',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),

          // ── Processing: spinner while server processes ─────────────────────
          //
          // All bytes have been sent. Server is processing (resizing, storing…).
          processing: () => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Processing on server…', style: TextStyle(fontSize: 18)),
            ],
          ),

          // ── Success ───────────────────────────────────────────────────────
          success: (photo) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 96, color: Colors.green),
              const SizedBox(height: 24),
              Text('Uploaded: ${photo.filename}',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Photo ID: ${photo.id}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: _reset,
                child: const Text('Upload Another'),
              ),
            ],
          ),

          // ── Failed: show error message with retry ─────────────────────────
          failed: (error) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 96, color: Colors.red),
              const SizedBox(height: 24),
              Text(error.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
              FilledButton(onPressed: _startUpload, child: const Text('Retry')),
              const SizedBox(height: 12),
              TextButton(onPressed: _reset, child: const Text('Cancel')),
            ],
          ),

          // ── Network error ─────────────────────────────────────────────────
          networkError: () => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 96, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('No internet connection',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 32),
              FilledButton(onPressed: _startUpload, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
