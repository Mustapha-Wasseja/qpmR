# Build the `czechia` dataset shipped with qpmR.
#
# Sources (all public, no API key):
#   FRED (fred.stlouisfed.org/graph/fredgraph.csv):
#     CLVMNACSCAB1GQCZ  CZ real GDP, chain-linked, SA+calendar adj., quarterly (Eurostat)
#     CZECPIALLMINMEI   CZ CPI all items, monthly index, 2015=100, NSA (OECD MEI)
#     IR3TIB01CZM156N   CZ 3-month interbank rate (PRIBOR), monthly, % p.a. (OECD MEI)
#     IR3TIB01EZM156N   Euro area 3-month interbank rate (EURIBOR), monthly (OECD MEI)
#     CP0000EZ19M086NEST EA19 HICP all items, monthly index, 2015=100, NSA (Eurostat)
#   ECB data portal (data-api.ecb.europa.eu):
#     EXR/Q.CZK.EUR.SP00.A  CZK per EUR, reference rate, quarterly average
#
# Run from the package root:  Rscript data-raw/czechia.R

fred <- function(id) {
  d <- utils::read.csv(sprintf("https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s", id))
  names(d) <- c("date", "value")
  d$date <- as.Date(d$date)
  d$value <- suppressWarnings(as.numeric(d$value))
  d[!is.na(d$value), ]
}

ecb <- function(key) {
  d <- utils::read.csv(sprintf(
    "https://data-api.ecb.europa.eu/service/data/%s?format=csvdata", key))
  data.frame(period = d$TIME_PERIOD, value = as.numeric(d$OBS_VALUE))
}

# monthly data frame -> quarterly mean (only quarters with all 3 months)
to_q <- function(d) {
  yr <- as.integer(format(d$date, "%Y"))
  qt <- (as.integer(format(d$date, "%m")) - 1L) %/% 3L + 1L
  key <- sprintf("%d-Q%d", yr, qt)
  n <- tapply(d$value, key, length)
  m <- tapply(d$value, key, mean)
  data.frame(period = names(m)[n == 3], value = as.numeric(m[n == 3]))
}

qnum <- function(p) {  # "1996-Q1"/"1996Q1" -> 1996.00, 1996.25, ...
  yr <- as.numeric(substr(p, 1, 4))
  qt <- as.numeric(substr(p, nchar(p), nchar(p)))
  yr + (qt - 1) / 4
}

gdp_raw <- fred("CLVMNACSCAB1GQCZ")
gdp <- data.frame(period = sprintf("%s-Q%d", format(gdp_raw$date, "%Y"),
                                   (as.integer(format(gdp_raw$date, "%m")) - 1L) %/% 3L + 1L),
                  gdp = gdp_raw$value)
cpi   <- to_q(fred("CZECPIALLMINMEI"));    names(cpi)[2] <- "cpi"
prib  <- to_q(fred("IR3TIB01CZM156N"));    names(prib)[2] <- "i"
eurib <- to_q(fred("IR3TIB01EZM156N"));    names(eurib)[2] <- "istar"
hicp  <- to_q(fred("CP0000EZ19M086NEST")); names(hicp)[2] <- "hicp"
fx    <- ecb("EXR/Q.CZK.EUR.SP00.A");      names(fx)[2] <- "fx"

grid <- data.frame(qn = seq(1996, max(qnum(gdp$period)), by = 0.25))
grid$period <- sprintf("%d-Q%d", floor(grid$qn), round((grid$qn %% 1) * 4) + 1L)
add <- function(g, d) { d$qn <- qnum(d$period); merge(g, d[, c("qn", setdiff(names(d), c("period", "qn")))], by = "qn", all.x = TRUE) }
g <- Reduce(add, list(gdp, cpi, prib, eurib, hicp, fx), accumulate = FALSE, init = grid)
g <- g[order(g$qn), ]

lag4 <- function(x, k = 4) c(rep(NA, k), utils::head(x, -k))
dlog <- function(x) c(NA, 400 * diff(log(x)))

# quarterly CPI inflation: seasonally adjust the quarterly log index with STL
lcpi <- log(g$cpi)
ok <- !is.na(lcpi)
lcpi_ts <- stats::ts(lcpi[ok], frequency = 4)
sa <- lcpi
sa[ok] <- as.numeric(lcpi_ts - stats::stl(lcpi_ts, s.window = "periodic", robust = TRUE)$time.series[, "seasonal"])

czechia <- data.frame(
  period = g$period,
  pi     = c(NA, 400 * diff(sa)),                       # QoQ annualised, STL-SA
  pi4    = 100 * (log(g$cpi) - lag4(log(g$cpi))),       # YoY, no SA needed
  i      = g$i,                                          # 3M PRIBOR (policy proxy)
  q      = 100 * (log(g$fx) + log(g$hicp) - log(g$cpi)), # real CZK/EUR, + = depreciation
  dy_obs = dlog(g$gdp),                                  # QoQ annualised GDP growth
  istar  = g$istar,                                      # 3M EURIBOR
  pistar = 100 * (log(g$hicp) - lag4(log(g$hicp)))       # EA HICP YoY
)
# normalize the real exchange rate: 2015 average = 0
base <- mean(czechia$q[substr(czechia$period, 1, 4) == "2015"], na.rm = TRUE)
czechia$q <- czechia$q - base
num <- vapply(czechia, is.numeric, TRUE)
czechia[num] <- lapply(czechia[num], round, digits = 4)

stopifnot(nrow(czechia) > 100, !all(is.na(czechia$q)), !all(is.na(czechia$pi4)))
cat("rows:", nrow(czechia), " span:", czechia$period[1], "-",
    czechia$period[nrow(czechia)], "\n")
print(summary(czechia[, -1]))

save(czechia, file = file.path("data", "czechia.rda"), compress = "xz")
cat("written data/czechia.rda\n")
