# Leakage-free RQ3 pipeline; reports MEDIAN AUC across 10x10 CV.

suppressPackageStartupMessages({
  library(caret)
  library(recipes)
  library(pROC)
  library(dplyr)
  library(ggplot2)
})

set.seed(123)

# ---- paths ----
DATA_DIR <- "data"  # IST_*.csv live here (under rq3/)
FIG_DIR  <- "results/figures"
CM_DIR   <- "results/confusion_matrices"
MT_DIR   <- "results/metrics_tables"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(CM_DIR,  recursive = TRUE, showWarnings = FALSE)
dir.create(MT_DIR,  recursive = TRUE, showWarnings = FALSE)

# ---- features & datasets ----
X_COLS <- c("URL","File","Require","Ensure","Include","Attribute",
            "Hard_coded_string","Command","File_mode","SSH_KEY",
            "Lines_of_code","Comment")

DATASETS <- list(
  mirantis  = "IST_MIR.csv",
  mozilla   = "IST_MOZ.csv",
  openstack = "IST_OST.csv",
  wikimedia = "IST_WIK.csv"
)

# pick a NB backend caret supports on your machine
safe_nb <- if ("naive_bayes" %in% caret::modelLookup()$model) "naive_bayes" else "nb"

MODELS <- list(
  cart = "rpart",
  knn  = "knn",
  lr   = "glm",
  nb   = safe_nb,
  rf   = "rf"
)

# 10x10 CV with OUT-OF-FOLD predictions saved
ctrl <- trainControl(
  method = "repeatedcv",
  number = 10,
  repeats = 10,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,  # gives ROC per resample
  savePredictions = "final"
)

# helpers ----------------------------------------------------------
to_yes_no <- function(v) factor(ifelse(as.numeric(v) == 1, "Yes", "No"),
                                levels = c("No","Yes"))

filter_best <- function(df, best) {
  if (is.null(best) || ncol(best) == 0) df else dplyr::semi_join(df, best, by = names(best))
}

# main -------------------------------------------------------------
run_one <- function(ds_name, filename) {
  message("=== ", ds_name, " ===")
  df_raw <- read.csv(file.path(DATA_DIR, filename), check.names = FALSE)

  X <- df_raw[, X_COLS]
  X[] <- lapply(X, function(x) suppressWarnings(as.numeric(x)))
  y <- to_yes_no(df_raw$defect_status)
  df <- data.frame(X, y = y)

  # preprocessing learned INSIDE each CV split
  rec <- recipe(y ~ ., data = df) %>%
    step_log(all_predictors(), offset = 1) %>%
    step_normalize(all_predictors()) %>%
    step_pca(all_predictors(), threshold = 0.95)

  rows <- list()

  for (m in names(MODELS)) {
    fit <- caret::train(
      rec, data = df,
      method = MODELS[[m]],
      metric = "ROC",
      trControl = ctrl,
      tuneLength = 5
    )

    # write caret’s tuning table (averaged across resamples)
    write.csv(fit$results,
              file.path(MT_DIR, sprintf("%s_%s_results.csv", ds_name, m)),
              row.names = FALSE)

    # --- NEW: MEDIAN AUC across the 100 resamples (best-tuned model only) ---
    best     <- fit$bestTune
    res_best <- filter_best(fit$resample, best)
    AUC_med  <- suppressWarnings(median(res_best$ROC, na.rm = TRUE))

    # out-of-fold predictions (best tune) for CM + ROC plot
    preds <- filter_best(fit$pred, best)

    cm <- caret::confusionMatrix(preds$pred, preds$obs, positive = "Yes")
    write.csv(as.data.frame(cm$table),
              file.path(CM_DIR, sprintf("%s_%s_confusion_matrix.csv", ds_name, m)),
              row.names = FALSE)

    png(file.path(FIG_DIR, sprintf("roc_%s_%s.png", ds_name, m)), width = 1000, height = 800)
    plot(pROC::roc(preds$obs, preds$Yes, levels = c("No","Yes"), quiet = TRUE),
         main = sprintf("ROC — %s %s (10×10 CV, OOF)", toupper(ds_name), toupper(m)))
    dev.off()

    # compact summary row (AUC = MEDIAN across resamples)
    acc <- mean(preds$pred == preds$obs)
    tp <- sum(preds$pred == "Yes" & preds$obs == "Yes")
    fp <- sum(preds$pred == "Yes" & preds$obs == "No")
    fn <- sum(preds$pred == "No"  & preds$obs == "Yes")
    precision <- ifelse(tp + fp > 0, tp/(tp + fp), NA_real_)
    recall    <- ifelse(tp + fn > 0, tp/(tp + fn), NA_real_)

    rows[[m]] <- data.frame(
      dataset   = ds_name,
      model     = m,
      AUC_med   = round(AUC_med, 3),
      Accuracy  = round(acc, 3),
      Precision = round(precision, 3),
      Recall    = round(recall, 3),
      stringsAsFactors = FALSE
    )
  }

  bind_rows(rows)
}

summary_all <- bind_rows(Map(run_one, names(DATASETS), DATASETS))
write.csv(summary_all, file.path("results", "summaries_all_models.csv"), row.names = FALSE)

# simple comparison plot using the MEDIAN AUC
gg <- ggplot(summary_all, aes(x = dataset, y = AUC_med, fill = model)) +
  geom_col(position = position_dodge()) +
  labs(title = "ROC AUC by model (10×10 CV, median across resamples)",
       y = "AUC (median of 100 folds)", x = "Dataset") +
  theme_minimal()
ggsave(file.path(FIG_DIR, "comparison_graph.png"), gg, width = 10, height = 7)