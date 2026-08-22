# qpmR quickstart: the canonical small-open-economy QPM end to end
library(qpmR)

# 1. The model ---------------------------------------------------------------
m <- qpm_template("bkl")
print(m)
summary(m)

# 2. Solve: QZ + Blanchard-Kahn ---------------------------------------------
sol <- qpm_solve(m)
print(sol)
head(eigen_table(sol), 8)

# 3. Monetary transmission ---------------------------------------------------
ir <- irf(sol, shock = "eps_i", horizon = 16)
print(ir)
plot(ir, vars = c("i", "r", "pi", "y_gap", "q", "pi4"))

# 4. A depreciation shock -----------------------------------------------------
plot(irf(sol, shock = "eps_q", horizon = 16),
     vars = c("q", "pi", "i", "y_gap"))

# 5. History + forecast with fan bands ---------------------------------------
histq <- simulate(sol, nsim = 48, seed = 7, burn = 20)
fc <- qpm_forecast(sol, from = histq, horizon = 12)
print(fc)
plot(fc, vars = c("pi", "i", "y_gap", "q"))

# 6. Calibration experiment: stronger FX pass-through -------------------------
m2 <- qpm_calibrate(m, b3 = 0.2)
sol2 <- qpm_solve(m2)
ir1 <- irf(sol, shock = "eps_q", horizon = 16)
ir2 <- irf(sol2, shock = "eps_q", horizon = 16)

# 7. Specification checks ------------------------------------------------------
qpm_lint(m)

# 8. What a broken model reports ----------------------------------------------
try(qpm_solve(qpm_calibrate(m, c2 = -0.5)))   # Taylor principle violated
