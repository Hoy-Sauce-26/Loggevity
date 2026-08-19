/// Piecewise linear interpolation over a monotonically increasing `x` grid.
///
/// Out-of-range inputs are **clamped** to the terminal `y` values. The source
/// spreadsheet used `FORECAST.LINEAR`, which extrapolates off the final
/// segment instead; that produces unbounded penalties (300 min of resistance
/// training would score -25.25 rather than -9.0), so the curves are treated as
/// undefined beyond their last anchor and held flat.
double interpolate(double val, List<double> xs, List<double> ys) {
  assert(xs.length == ys.length, 'curve grids must be the same length');
  assert(xs.length >= 2, 'a curve needs at least two anchors');
  if (val <= xs.first) return ys.first;
  if (val >= xs.last) return ys.last;
  for (var i = 0; i < xs.length - 1; i++) {
    if (val >= xs[i] && val <= xs[i + 1]) {
      final t = (val - xs[i]) / (xs[i + 1] - xs[i]);
      return ys[i] + t * (ys[i + 1] - ys[i]);
    }
  }
  return ys.last;
}
