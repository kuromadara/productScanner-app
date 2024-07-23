import 'product_types.dart';

class TextProcessor {
  static ProcessResult processText(List<String> lines, ProductType type) {
    switch (type) {
      case ProductType.teaTypeOne:
        return _processTeaTypeOne(lines);
      case ProductType.teaTypeTwo:
        return _processTeaTypeTwo(lines);
      case ProductType.biscuit:
        return _processBiscuit(lines);
    }
  }

  static ProcessResult _processTeaTypeOne(List<String> lines) {
    if (lines.isEmpty) {
      return ProcessResult(false, 'Error: No text detected for Tea Type One');
    }

    String firstLine = lines[0].trim().replaceAll(' ', '');
    if (firstLine.length == 12 || firstLine.length == 10) {
      return ProcessResult(true, firstLine, lines.take(4).toList());
    } else {
      return ProcessResult(false,
          'Error: $firstLine is not a valid batch number for Tea Type One');
    }
  }

  static ProcessResult _processTeaTypeTwo(List<String> lines) {
    if (lines.length < 2) {
      return ProcessResult(
          false, 'Error: Not enough lines detected for Tea Type Two');
    }

    String secondLine = lines[1].trim().replaceAll(' ', '');
    if (secondLine.length == 10) {
      return ProcessResult(true, secondLine, lines.take(4).toList());
    } else {
      return ProcessResult(false,
          'Error: $secondLine is not a valid Batch No. for Tea Type Two');
    }
  }

  static ProcessResult _processBiscuit(List<String> lines) {
    if (lines.length < 3) {
      return ProcessResult(
          false, 'Error: Not enough lines detected for Biscuit');
    }

    String thirdLine = lines[2].trim();
    if (thirdLine.contains('gl24/tpa')) {
      return ProcessResult(true, thirdLine, lines.take(3).toList());
    } else {
      return ProcessResult(
          false, 'Error: Third line does not contain gl24/tpa for Biscuit');
    }
  }
}

class ProcessResult {
  final bool isValid;
  final String message;
  final List<String>? scannedLines;

  ProcessResult(this.isValid, this.message, [this.scannedLines]);
}
