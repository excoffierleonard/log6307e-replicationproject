# RQ3 - Machine Learning Replication

This folder contains the code, data, and results for Research Question 3 of the IaC defect prediction replication study.

## Structure
- `data/` → CSV datasets (Mirantis, Mozilla, OpenStack, Wikimedia).
- `scripts/` → R scripts for PCA and model training.
- `results/` → exported CSV results (metrics, confusion matrices) and figures.
  
## Methodology
1. **Data preprocessing**
   - Applied log transformation (`log1p`) to normalize values.
   - Applied PCA to reduce dimensionality while preserving ~95% variance.
2. **Model training**
   - Models: Logistic Regression, CART, Random Forest, KNN, Naive Bayes.
   - Validation: 10x10 repeated cross-validation (caret package).
   - Metrics: Accuracy, Precision, Recall, F1-score, ROC AUC.
3. **Outputs**
   - CSV files of metrics per dataset/model.
   - Confusion matrices.
   - ROC curve plots.
   - Summary results table (`all_models_best_results.csv`).
   - Word report with discussion of results.

## How to run
1. Install the required R packages listed in `requirements_R.txt`.
2. Run `scripts/pca_analysis.R` to compute PCA for each dataset.
3. Run `scripts/training_models.R` to train the 5 models (LogReg, CART, RF, KNN, NB).
4. Results will be saved in the `results/` folder.
