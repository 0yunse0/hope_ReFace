// functions/utils/landmarkMetrics.js

// typedef: { x:number, y:number, z?:number, visibility?:number }

/** @param {{x?:number,y?:number,z?:number}} p @param {{x?:number,y?:number,z?:number}} q */
function computeEuclidean(p, q) {
  const px = (p && typeof p.x === "number") ? p.x : 0;
  const py = (p && typeof p.y === "number") ? p.y : 0;
  const pz = (p && typeof p.z === "number") ? p.z : 0;
  const qx = (q && typeof q.x === "number") ? q.x : 0;
  const qy = (q && typeof q.y === "number") ? q.y : 0;
  const qz = (q && typeof q.z === "number") ? q.z : 0;
  return Math.hypot(px - qx, py - qy, pz - qz);
}

function landmarkProgress(baseline, ref, curr, eps) {
  const epsilon = (typeof eps === "number" && eps > 0) ? eps : 1e-3;
  const numer = computeEuclidean(curr, baseline);
  const denom = Math.max(epsilon, computeEuclidean(ref, baseline));
  const raw = numer / denom;
  return Math.max(0, Math.min(1, raw));
}

function aggregateProgress(scores, weights) {
  if (!scores || !scores.length) return 0;
  if (!weights || weights.length !== scores.length) {
    let s = 0;
    for (let i = 0; i < scores.length; i++) s += scores[i];
    return s / scores.length;
  }
  let wsum = 0; let acc = 0;
  for (let j = 0; j < scores.length; j++) {
    let w = weights[j]; if (!(w > 0)) w = 0;
    wsum += w; acc += w * scores[j];
  }
  return wsum > 0 ? (acc / wsum) : 0;
}

function symmetry(leftScore, rightScore) {
  let L = leftScore; if (!(L >= 0 && L <= 1)) L = (L > 1 ? 1 : (L < 0 ? 0 : (typeof L === "number" ? L : 0)));
  let R = rightScore; if (!(R >= 0 && R <= 1)) R = (R > 1 ? 1 : (R < 0 ? 0 : (typeof R === "number" ? R : 0)));
  const absDiff = Math.abs(L - R);
  const ratio = (Math.max(L, R) > 0) ? (Math.min(L, R) / Math.max(L, R)) : 1;
  return { absDiff: absDiff, ratio: ratio };
}

function outlierFilter(framesOrSeries, options) {
  const opts = options || {};
  const visibilityKey = (typeof opts.visibilityKey === "string") ? opts.visibilityKey : "visibility";
  const visibilityMin = (typeof opts.visibilityMin === "number") ? opts.visibilityMin : 0.6;
  const maxJumpPx = (typeof opts.maxJumpPx === "number") ? opts.maxJumpPx : 20;
  const mode = Array.isArray(framesOrSeries) ? "frames" : "series";

  if (mode === "frames") {
    const frames = framesOrSeries.map(function(f) {
      return Object.assign({}, f);
    });
    for (let t = 0; t < frames.length; t++) {
      const f = frames[t];
      for (const k in f) {
        const p = f[k];
        if (p && typeof p[visibilityKey] === "number" && p[visibilityKey] < visibilityMin) {
          f[k] = null;
        }
      }
    }
    for (let t = 1; t < frames.length; t++) {
      const prev = frames[t - 1];
      const curr = frames[t];
      for (const k in curr) {
        const c = curr[k];
        const p = prev ? prev[k] : null;
        if (c && p) {
          const jump = computeEuclidean(c, p);
          if (jump > maxJumpPx) curr[k] = null;
        }
      }
    }
    return frames;
  } else {
    const series = {};
    for (const k in framesOrSeries) {
      const srcArr = framesOrSeries[k] || [];
      const arr = srcArr.map(function(pt) {
        return pt ? Object.assign({}, pt) : pt;
      });

      for (let i = 0; i < arr.length; i++) {
        const pt = arr[i];
        if (pt && typeof pt[visibilityKey] === "number" && pt[visibilityKey] < visibilityMin) {
          arr[i] = null;
        }
      }
      for (let i = 1; i < arr.length; i++) {
        const c = arr[i];
        const p = arr[i - 1];
        if (c && p) {
          const jump = computeEuclidean(c, p);
          if (jump > maxJumpPx) arr[i] = null;
        }
      }
      series[k] = arr;
    }
    return series;
  }
}

module.exports = {
  computeEuclidean,
  landmarkProgress,
  aggregateProgress,
  symmetry,
  outlierFilter,
};
