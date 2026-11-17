#include <Rcpp.h>
#include <cmath>
using namespace Rcpp;
// Per-link sums over ordered pairs (s, t) of weight * f(D[l,s] - D[l,t]),
// f = square and abs, for two weightings. D is links x nodes, column-major.
// [[Rcpp::export]]
NumericMatrix pair_sums(NumericMatrix D, IntegerVector s, IntegerVector t,
                        NumericVector a1, NumericVector a2) {
  int L = D.nrow(); NumericMatrix out(L, 4);   // sq1, abs1, sq2, abs2
  double *o = &out[0];
  for (R_xlen_t p = 0; p < s.size(); p++) {
    const double *ds = &D[(R_xlen_t)(s[p] - 1) * L], *dt = &D[(R_xlen_t)(t[p] - 1) * L];
    double w1 = a1[p], w2 = a2[p];
    for (int l = 0; l < L; l++) {
      double x = ds[l] - dt[l], x2 = x * x, ax = std::fabs(x);
      o[l] += w1 * x2; o[L + l] += w1 * ax; o[2 * L + l] += w2 * x2; o[3 * L + l] += w2 * ax;
    }
  }
  return out;
}

// As pair_sums (one weighting), split by whether the link midpoint lies within
// R of the pair's target: columns sq_in, abs_in, sq_out, abs_out.
// [[Rcpp::export]]
NumericMatrix pair_split(NumericMatrix D, IntegerVector s, IntegerVector t, NumericVector a,
                         NumericVector mr, NumericVector mc, NumericVector tr, NumericVector tc, double R) {
  int L = D.nrow(); NumericMatrix out(L, 4); double *o = &out[0]; double R2 = R * R;
  for (R_xlen_t p = 0; p < s.size(); p++) {
    const double *ds = &D[(R_xlen_t)(s[p] - 1) * L], *dt = &D[(R_xlen_t)(t[p] - 1) * L];
    int ti = t[p] - 1;
    for (int l = 0; l < L; l++) {
      double x = ds[l] - dt[l]; double dr = mr[l] - tr[ti], dc = mc[l] - tc[ti];
      int k = (dr * dr + dc * dc <= R2) ? 0 : 2;
      o[k * L + l] += a[p] * x * x; o[(k + 1) * L + l] += a[p] * std::fabs(x);
    }
  }
  return out;
}
