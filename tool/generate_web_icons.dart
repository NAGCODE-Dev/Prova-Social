import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final sourceFile = File('assets/branding/app_icon.png');
  if (!sourceFile.existsSync()) {
    stderr.writeln('Logo não encontrada em ${sourceFile.path}.');
    exitCode = 1;
    return;
  }

  final source = img.decodeImage(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Não foi possível ler a logo do Prova Social.');
    exitCode = 1;
    return;
  }

  Directory('web/icons').createSync(recursive: true);
  _write(source, 48, 'web/favicon.png');
  _write(source, 192, 'web/icons/Icon-192.png');
  _write(source, 512, 'web/icons/Icon-512.png');
  _write(source, 192, 'web/icons/Icon-maskable-192.png');
  _write(source, 512, 'web/icons/Icon-maskable-512.png');

  stdout.writeln('Ícones web do Prova Social aplicados.');
}

void _write(img.Image source, int size, String path) {
  final resized = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  File(path).writeAsBytesSync(img.encodePng(resized));
}
