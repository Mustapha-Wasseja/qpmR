// Compiled Kalman filter for qpmR.
//
// This is the estimation hot path: every posterior draw solves the model
// and then runs this filter over the whole sample, so the cost of a
// Bayesian estimate is dominated by it. The algorithm is a
// line-for-line match of the reference implementation in R
// (kalman_loglik_r), including the Cholesky factorisation of the
// innovation covariance and the Joseph-form covariance update, so the
// two agree to machine precision rather than merely closely.
//
// Errors are not thrown from C++: a singular innovation covariance is
// reported back through `fail` so that R can raise the typed
// qpm_singular_F condition the rest of the package expects.

// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

// Discrete Lyapunov equation  V = T V T' + W  by squaring.
//
// The obvious solution vectorises to (I - T (x) T) vec(V) = vec(W), which
// means forming and factorising an N^2 x N^2 matrix: O(N^6), and hopeless
// beyond a handful of states. Squaring accumulates
//   V_k = sum_{j < 2^k} T^j W (T^j)'
// in O(N^3) per iteration and converges quadratically, so ~20 iterations
// suffice even for the near-unit roots used in diffuse initialisation.
//
// [[Rcpp::export]]
Rcpp::List lyapunov_cpp(const arma::mat& Tm, const arma::mat& W,
                        int max_iter = 60, double tol = 1e-14) {
  arma::mat V = W;
  arma::mat A = Tm;
  const double scale = std::max(arma::norm(W, "fro"), 1e-300);
  int iter = 0;
  bool converged = false;

  for (iter = 1; iter <= max_iter; ++iter) {
    arma::mat AVA = A * V * A.t();
    V += AVA;
    V = 0.5 * (V + V.t());
    if (arma::norm(AVA, "fro") <= tol * scale) { converged = true; break; }
    A = A * A;
    if (!V.is_finite() || !A.is_finite()) break;
  }
  return Rcpp::List::create(Rcpp::Named("V") = V,
                            Rcpp::Named("iter") = iter,
                            Rcpp::Named("converged") = converged);
}

// [[Rcpp::export]]
Rcpp::List kalman_loglik_cpp(const arma::mat& Tt, const arma::mat& RQR,
                             const arma::mat& Z, const arma::vec& d,
                             const arma::mat& H, const arma::mat& P1,
                             const arma::mat& Y) {
  const arma::uword n = Y.n_rows;
  const arma::uword N = Tt.n_rows;
  const double LOG2PI = std::log(2.0 * M_PI);

  arma::vec a = arma::zeros<arma::vec>(N);
  arma::mat P = P1;
  const arma::mat I = arma::eye<arma::mat>(N, N);
  double loglik = 0.0;

  for (arma::uword t = 0; t < n; ++t) {
    // prediction
    arma::vec ap = Tt * a;
    arma::mat Pp = Tt * P * Tt.t() + RQR;
    Pp = 0.5 * (Pp + Pp.t());

    arma::rowvec yrow = Y.row(t);
    arma::uvec idx = arma::find_finite(yrow);

    if (idx.n_elem == 0) {           // nothing observed this period
      a = ap;
      P = Pp;
      continue;
    }

    arma::mat Zt = Z.rows(idx);
    arma::mat Ht = H.submat(idx, idx);
    arma::vec yt = yrow.t();
    arma::vec v = yt.elem(idx) - Zt * ap - d.elem(idx);

    arma::mat F = Zt * Pp * Zt.t() + Ht;
    F = 0.5 * (F + F.t());

    arma::mat ch;
    if (!arma::chol(ch, F)) {                       // F not positive definite
      return Rcpp::List::create(Rcpp::Named("loglik") = R_NaReal,
                                Rcpp::Named("fail") = (int)(t + 1));
    }
    arma::vec dg = ch.diag();
    if (dg.min() < 1e-8 * dg.max()) {               // numerically singular
      return Rcpp::List::create(Rcpp::Named("loglik") = R_NaReal,
                                Rcpp::Named("fail") = (int)(t + 1));
    }

    // F^-1 v and F^-1 via the Cholesky factor, as the R version does
    arma::vec Finv_v = arma::solve(arma::trimatu(ch),
                        arma::solve(arma::trimatl(ch.t()), v));
    arma::mat Finv = arma::solve(arma::trimatu(ch),
                       arma::solve(arma::trimatl(ch.t()),
                         arma::eye<arma::mat>(idx.n_elem, idx.n_elem)));

    arma::mat K = Pp * Zt.t() * Finv;
    a = ap + K * v;

    arma::mat IKZ = I - K * Zt;                     // Joseph form
    P = IKZ * Pp * IKZ.t() + K * Ht * K.t();
    P = 0.5 * (P + P.t());

    loglik -= 0.5 * ((double)idx.n_elem * LOG2PI
                       + 2.0 * arma::sum(arma::log(dg))
                       + arma::dot(v, Finv_v));
  }

  return Rcpp::List::create(Rcpp::Named("loglik") = loglik,
                            Rcpp::Named("fail") = 0);
}
