import 'dart:io';

import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/downloads/background_download_engine.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:path_provider/path_provider.dart';

/// The real downloads. Android: files in the app's own external files folder (`Android/data/<id>/files/Downloads`, no permission
/// needed). Windows: the user's Downloads folder, in an IPTVMac folder of its own, so the files are easy to find and keep. The list is
/// in [support]/downloads.json. Anything else, or any failure, gives the disabled model.
Future<DownloadsModel> openDownloads(LibraryModel library, Directory support) async {
  if (!Platform.isAndroid && !Platform.isWindows) return DownloadsModel.disabled();
  try {
    final String dir;
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external == null) return DownloadsModel.disabled();
      dir = '${external.path}/Downloads';
    } else {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) return DownloadsModel.disabled();
      dir = '${downloads.path}${Platform.pathSeparator}IPTVMac';
    }
    final model = DownloadsModel(
      engine: BackgroundDownloadEngine(partialDir: '$dir/.partial'),
      store: File('${support.path}/downloads.json'),
      dir: dir,
      resolveUrl: library.downloadUrl,
    );
    await model.load();
    return model;
  } catch (_) {
    return DownloadsModel.disabled();
  }
}
