/// Stub implementation for saving or downloading CSV files.
Future<void> saveOrShareCsv({
  required String csvContent,
  required String filename,
}) async {
  throw UnsupportedError('Cannot save CSV on this platform.');
}

/// Direct download helper.
Future<void> downloadCsv(String csvContent, String filename) =>
    saveOrShareCsv(csvContent: csvContent, filename: filename);
