# rq3/scripts/pca_exploratory.R
# Purpose: DESCRIPTIVE PCA ONLY (NOT USED FOR TRAINING).
# Computes PCs needed to reach ≥95% variance per dataset and makes scree plots.
# Do NOT feed these PCs into model training; training uses fold-internal PCA.

datasets <- c(
  Mirantis   = "rq3/data/IST_MIR.csv",
  Mozilla    = "rq3/data/IST_MOZ.csv",
  OpenStack  = "rq3/data/IST_OST.csv",
  Wikimedia  = "rq3/data/IST_WIK.csv"
)

features <- c("URL","File","Require","Ensure","Include","Attribute",
              "Hard_coded_string","Command","File_mode","SSH_KEY",
              "Lines_of_code","Comment")

out_summary <- "rq3/results/pca/pca_summary.csv"
out_fig_dir <- "rq3/results/pca/figures"

dir.create("rq3/results/pca/figures", recursive = TRUE, showWarnings = FALSE)

pc95 <- function(pca_obj, threshold = 0.95) {
  cumvar <- cumsum(pca_obj$sdev^2 / sum(pca_obj$sdev^2))
  which(cumvar >= threshold)[1]
}

summary_rows <- list()

for (ds in names(datasets)) {
  cat("\n=== ", ds, " ===\n", sep = "")
  dat <- read.csv(datasets[[ds]], stringsAsFactors = FALSE)

  # Coerce features safely to numeric (guards against accidental factors/strings)
  X <- dat[, features]
  X[] <- lapply(X, function(x) suppressWarnings(as.numeric(x)))

  X_log <- log1p(X)  # safe log
  pca <- prcomp(X_log, scale. = TRUE)

  k <- pc95(pca, 0.95)
  cumvar <- cumsum(pca$sdev^2 / sum(pca$sdev^2))

  cat("PCs needed for ~95% variance: ", k, "\n", sep = "")
  cat("Cumulative variance at PC", k, ": ", round(cumvar[k], 4), "\n", sep = "")

  png(file.path(out_fig_dir, paste0("pca_scree_", tolower(ds), ".png")),
      width = 900, height = 600)
  par(mfrow = c(1,2))
  barplot(pca$sdev^2 / sum(pca$sdev^2),
          main = paste("Scree Plot -", ds),
          xlab = "Principal Component", ylab = "Proportion of Variance")
  plot(cumvar, type = "b", pch = 19,
       main = paste("Cumulative Variance -", ds),
       xlab = "Principal Component", ylab = "Cumulative Proportion")
  abline(h = 0.95, col = "red", lty = 2)
  abline(v = k, col = "blue", lty = 3)
  dev.off()

  summary_rows[[ds]] <- data.frame(
    Dataset = ds,
    PCs_95  = k,
    CumVar_at_PC = round(cumvar[k], 4),
    stringsAsFactors = FALSE
  )
}

pca_summary <- do.call(rbind, summary_rows)
dir.create(dirname(out_summary), recursive = TRUE, showWarnings = FALSE)
write.csv(pca_summary, out_summary, row.names = FALSE)

cat("\nSaved PCA summary to: ", out_summary, "\n", sep = "")
cat("Saved scree plots to: ", out_fig_dir, "\n", sep = "")
print(pca_summary)
