import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../utils/format.dart';

String errorText(Object e) => e is ApiException ? e.friendly : e.toString();

void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Coloured pill for vehicle status (available/pending/sold) and transaction
/// status (pending/completed/cancelled).
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final MaterialColor color;
    switch (status) {
      case 'available':
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default: // sold
        color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        capitalize(status),
        style: TextStyle(color: color.shade900, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Network image with a car placeholder for null/failed URLs.
class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double iconSize;

  const NetImage({super.key, this.url, this.fit = BoxFit.cover, this.iconSize = 40});

  Widget _placeholder({bool broken = false}) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          broken ? Icons.broken_image_outlined : Icons.directions_car,
          size: iconSize,
          color: broken ? Colors.red.shade300 : Colors.grey.shade500,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return _placeholder();
    return Image.network(
      u,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, error, __) {
        // A broken-image icon (not the car) means the URL exists but could not
        // be loaded. The URL is printed so it can be opened in a browser.
        debugPrint('Image failed to load: $u -> $error');
        return _placeholder(broken: true);
      },
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final ImagePicker _picker = ImagePicker();

class _ShrinkJob {
  final Uint8List bytes;
  final int maxSide;
  const _ShrinkJob(this.bytes, this.maxSide);
}

/// Decodes, fixes orientation, scales down and re-encodes as JPEG.
/// Runs in an isolate via compute(). Returns null if the image can't be decoded.
Uint8List? _shrinkJpeg(_ShrinkJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;
  var out = img.bakeOrientation(decoded);
  if (out.width > job.maxSide || out.height > job.maxSide) {
    out = out.width >= out.height
        ? img.copyResize(out, width: job.maxSide)
        : img.copyResize(out, height: job.maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 85));
}

String _asJpgName(String name) {
  final dot = name.lastIndexOf('.');
  return '${dot > 0 ? name.substring(0, dot) : (name.isEmpty ? 'photo' : name)}.jpg';
}

/// Picks JPEG/PNG/WebP images from the gallery and shrinks large ones
/// (longest side [maxSide], JPEG) so uploads stay small and fast, then enforces
/// the API limits (5 MB per vehicle photo, 2 MB per avatar, max 10 photos).
Future<List<PickedImage>> pickImages(
  BuildContext context, {
  int maxCount = 10,
  int maxBytes = 5 * 1024 * 1024,
  int maxSide = 1600,
  bool multiple = true,
}) async {
  if (maxCount <= 0) {
    showSnack(context, 'Maximum number of photos reached', error: true);
    return [];
  }
  List<XFile> files;
  if (multiple) {
    files = await _picker.pickMultiImage();
  } else {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    files = f == null ? <XFile>[] : <XFile>[f];
  }

  final out = <PickedImage>[];
  final problems = <String>[];
  for (final f in files) {
    if (out.length >= maxCount) {
      problems.add('Only $maxCount photo(s) can be added');
      break;
    }
    final bytes = await f.readAsBytes();
    if (sniffImageMime(bytes) == null) {
      problems.add('${f.name}: only JPEG, PNG or WebP are allowed');
      continue;
    }
    if (bytes.length > 25 * 1024 * 1024) {
      problems.add('${f.name}: file is too large');
      continue;
    }
    var data = bytes;
    var name = f.name;
    if (bytes.length > 700 * 1024) {
      final shrunk = await compute(_shrinkJpeg, _ShrinkJob(bytes, maxSide));
      if (shrunk != null && shrunk.length < bytes.length) {
        data = shrunk;
        name = _asJpgName(name);
      }
    }
    if (data.length > maxBytes) {
      problems.add('${f.name}: still larger than ${maxBytes ~/ (1024 * 1024)} MB after resizing');
      continue;
    }
    out.add(PickedImage(name, data));
  }
  if (problems.isNotEmpty && context.mounted) {
    showSnack(context, problems.join('\n'), error: true);
  }
  return out;
}
