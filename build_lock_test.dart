import 'dart:io';

void main() {
  final path = r'F:\flutter_windows_3.44.1-stable\flutter\bin\cache\lockfile';
  stdout.writeln('open: $path');
  final f = File(path);
  final raf = f.openSync(mode: FileMode.write);
  stdout.writeln('opened, locking...');
  raf.lockSync(FileLock.exclusive);
  stdout.writeln('LOCKED OK');
  raf.unlockSync();
  raf.closeSync();
  stdout.writeln('UNLOCKED OK');

  final snap = File(r'F:\flutter_windows_3.44.1-stable\flutter\bin\cache\flutter_tools.snapshot');
  stdout.writeln('snapshot exists=${snap.existsSync()} size=${snap.existsSync() ? snap.lengthSync() : -1}');
}
