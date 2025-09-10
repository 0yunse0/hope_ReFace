import 'dart:core';

/// 로그 텍스트(여러 줄)에서 얼굴 랜드마크 좌표만 파싱
List<ParsedLandmark> parseLandmarksFromLog(String logText) {
  final reg = RegExp(
    r'LM\s+FaceLandmarkType\.(\w+):\s*raw=\(([-\d.]+),\s*([-\d.]+)\)\s*screen=\(([-\d.]+),\s*([-\d.]+)\)',
  );

  final results = <ParsedLandmark>[];
  for (final line in logText.split('\n')) {
    final m = reg.firstMatch(line);
    if (m == null) continue;

    final type = m.group(1)!;
    final rawX = double.tryParse(m.group(2)!) ?? 0;
    final rawY = double.tryParse(m.group(3)!) ?? 0;
    final screenX = double.tryParse(m.group(4)!) ?? 0;
    final screenY = double.tryParse(m.group(5)!) ?? 0;

    results.add(
      ParsedLandmark(
        type: type,
        rawX: rawX,
        rawY: rawY,
        screenX: screenX,
        screenY: screenY,
      ),
    );
  }
  return results;
}

class ParsedLandmark {
  final String type;
  final double rawX;
  final double rawY;
  final double screenX;
  final double screenY;

  ParsedLandmark({
    required this.type,
    required this.rawX,
    required this.rawY,
    required this.screenX,
    required this.screenY,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'raw': {'x': rawX, 'y': rawY},
        'screen': {'x': screenX, 'y': screenY},
      };
}
