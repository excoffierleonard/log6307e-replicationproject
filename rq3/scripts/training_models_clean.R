# rq3/scripts/training_models_clean.R
# Mirrors your workflow: log1p -> PCA -> 10x10 CV -> export metrics

suppressPackageStartupMessages({
  library(caret)
  library(pROC)
})

# ---- Inputs/outputs ----
datasets <- c(
  Mirantis  = "rq3/data/IST_MIR.csv",
  Mozilla   = "rq3/data/IST_MOZ.csv",
  OpenStack = "rq3/data/IST_OST.csv",
  Wikimedia = "rq3/data/IST_WIK.csv"
)

# Use the PCs you observed in your runs (~95% variance)
pc_keep <- c(
  Mirantis  = 7,
  Mozilla   = 9,
  OpenStack = 8,
  Wikimedia = 7
)

features <- c("URL","File","Require","Ensure","Include","Attribute",
              "Hard_coded_string","Command","File_mode","SSH_KEY",
              "Lines_of_code","Comment")

out_metrics <- "rq3/results/metrics_tables"
out_conf    <- "rq3/results/confusion_matrices"
out_figs    <- "rq3/results/figures"
dir.create(out_metrics, recursive = TRUE, showWarnings = FALSE)
dir.create(out_conf,    recursive = TRUE, showWarnings = FALSE)
dir.create(out_figs,    recursive = TRUE, showWarnings = FALSE)

# ---- Your custom summary (no MLmetrics needed) ----
mySummary <- function(data, lev = NULL, model = NULL) {
  positive <- "Yes"
  if (!positive %in% levels(data$obs)) positive <- tail(levels(data$obs), 1)
  tab <- table(data$obs, data$pred)
  TP <- ifelse(positive %in% rownames(tab) && positive %in% colnames(tab), tab[positive, positive], 0)
  FP <- ifelse(positive %in% colnames(tab), sum(tab[, positive, drop=FALSE]) - TP, 0)
  FN <- ifelse(positive %in% rownames(tab), sum(tab[positive, , drop=FALSE]) - TP, 0)
  TN <- sum(tab) - TP - FP - FN
  precision <- ifelse((TP+FP)>0, TP/(TP+FP), NA)
  recall    <- ifelse((TP+FN)>0, TP/(TP+FN), NA)
  f1        <- ifelse(!is.na(precision) && !is.na(recall) && (precision+recall)>0, 2*precision*recall/(precision+recall), NA)
  acc       <- ifelse(sum(tab)>0, (TP+TN)/sum(tab), NA)

  # ROC (prob column may be "Yes")
  roc_val <- NA
  if ("Yes" %in% colnames(data)) {
    try({
      roc_obj <- roc(response = data$obs, predictor = data$Yes, levels = rev(levels(data$obs)))
      roc_val <- as.numeric(auc(roc_obj))
    }, silent = TRUE)
  }
  c(Accuracy = acc, Precision = precision, Recall = recall, F1 = f1, ROC = roc_val)
}

# ---- Helpers ----
prepare_df <- function(path, kpcs) {
  dat <- read.csv(path, stringsAsFactors = FALSE)
  X <- dat[, features]
  y <- factor(dat$defect_status, levels = c(0,1), labels = c("No","Yes"))
  X_log <- log1p(X)
  pca   <- prcomp(X_log, scale. = TRUE)
  pcs   <- as.data.frame(pca$x[, 1:kpcs, drop = FALSE])
  pcs$y <- y
  pcs
}

save_one_model <- function(model, df, ds, model_name) {
  # best row (prefer ROC else Accuracy)
  res <- model$results
  best <- if ("ROC" %in% names(res)) res[which.max(res$ROC), , drop = FALSE] else res[which.max(res$Accuracy), , drop = FALSE]
  keep <- intersect(c("Accuracy","Precision","Recall","F1","ROC"), names(best))
  out  <- data.frame(best[, keep, drop = FALSE])
  out$Dataset <- ds; out$Model <- model_name

  # write metrics
  write.csv(out, file.path(out_metrics, sprintf("%s_%s_results.csv", tolower(ds), tolower(model_name))), row.names = FALSE)

  # confusion (in-sample)
  preds <- predict(model, df)
  cm <- confusionMatrix(preds, df$y)
  write.csv(as.data.frame(cm$table), file.path(out_conf, sprintf("%s_%s_confusion_matrix.csv", tolower(ds), tolower(model_name))), row.names = FALSE)

  # ROC curve (if probs available)
  has_prob <- TRUE
  probs <- tryCatch(predict(model, df, type = "prob"), error = function(e) { has_prob <<- FALSE; NULL })
  if (has_prob && !is.null(probs) && "Yes" %in% names(probs)) {
    roc_obj <- roc(df$y, probs$Yes, levels = rev(levels(df$y)))
    png(file.path(out_figs, sprintf("%s_%s_roc.png", tolower(ds), tolower(model_name))), width = 900, height = 600)
    plot(roc_obj, main = sprintf("ROC - %s (%s)", ds, model_name))
    dev.off()
  }
  out
}

# ---- Train (same CV you used) ----
set.seed(123)
ctrl <- trainControl(method = "repeatedcv",
                     number = 10,
                     repeats = 10,
                     classProbs = TRUE,
                     summaryFunction = mySummary,
                     savePredictions = "final")

all_best <- list()

for (ds in names(datasets)) {
  message("\n=== ", ds, " ===")
  k  <- pc_keep[[ds]]
  df <- prepare_df(datasets[[ds]], k)

  # Logistic Regression (your original code)
  mdl_lr <- train(y ~ ., data = df, method = "glm", family = "binomial", metric = "ROC", trControl = ctrl)
  b_lr   <- save_one_model(mdl_lr, df, ds, "LogReg")

  # CART (your original approach)
  mdl_cart <- train(y ~ ., data = df, method = "rpart", tuneLength = 5, metric = "ROC", trControl = ctrl)
  b_cart   <- save_one_model(mdl_cart, df, ds, "CART")

  # Random Forest
  mdl_rf <- train(y ~ ., data = df, method = "rf", tuneLength = 5, metric = "ROC", trControl = ctrl)
  b_rf   <- save_one_model(mdl_rf, df, ds, "RandomForest")

  # KNN
  mdl_knn <- train(y ~ ., data = df, method = "knn", tuneLength = 7, metric = "ROC", trControl = ctrl)
  b_knn   <- save_one_model(mdl_knn, df, ds, "KNN")

  # Naive Bayes (needs klaR installed)
  mdl_nb <- train(y ~ ., data = df, method = "nb", tuneLength = 5, metric = "ROC", trControl = ctrl)
  b_nb   <- save_one_model(mdl_nb, df, ds, "NaiveBayes")

  all_best[[ds]] <- rbind(b_lr, b_cart, b_rf, b_knn, b_nb)
}

final <- do.call(rbind, all_best)
final <- final[, intersect(c("Dataset","Model","Accuracy","Precision","Recall","F1","ROC"), names(final)), drop = FALSE]
write.csv(final, file.path(out_metrics, "all_models_best_results.csv"), row.names = FALSE)
message("\nSaved: rq3/results/metrics_tables/all_models_best_results.csv")
print(final)
