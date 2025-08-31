const KEYS = [
  'bottomMouth','rightMouth','leftMouth',
  'leftEye','rightEye','rightCheek','leftCheek','noseBase'
];

exports.validateLandmarks = (landmarks) => {
  if (!landmarks || typeof landmarks !== 'object') return 'landmarks must be object';
  for (const k of KEYS) {
    const p = landmarks[k];
    if (!p || typeof p.x !== 'number' || typeof p.y !== 'number') {
      return `Invalid point for ${k} (need {x:number,y:number})`;
    }
  }
  return null;
};

exports.EXPRESSIONS = new Set(['smile','angry','sad','neutral']);