import pandas as pd
from scipy.stats import mannwhitneyu

# Load dataset
df = pd.read_csv('authors_data/IST_MIR.csv')

# Columns to test (the properties from the study)
properties = [
    "Lines_of_code",
    "Hard_coded_string",
    "Attribute",
    "Ensure",
    "File",
    "File_mode",
    "Include",
    "Require",
    "SSH_KEY",
    "URL",
    "Command",
    "Comment"
]

# Split groups by defect_status
def_group = df[df['defect_status'] == 1]
nondef_group = df[df['defect_status'] == 0]

results = []

for prop in properties:
    defective = def_group[prop].dropna()
    non_defective = nondef_group[prop].dropna()
    
    # Mann-Whitney U test (alternative = greater, same as the paper)
    stat, p = mannwhitneyu(defective, non_defective, alternative="greater")
    
    results.append({
        "Property": prop,
        "Median_def": defective.median(),
        "Median_nondef": non_defective.median(),
        "U_stat": stat,
        "p_value": p
    })

# Put results into a DataFrame
results_df = pd.DataFrame(results)
print(results_df)

# Save to CSV
results_df.to_csv("mann_whitney_results.csv", index=False)
