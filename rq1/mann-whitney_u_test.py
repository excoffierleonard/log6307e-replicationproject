import pandas as pd
from scipy.stats import mannwhitneyu

# Load dataset
df = pd.read_csv('authors_data/IST_MIR.csv')

# Split into two groups based on defect status
defective = df[df['defect_status'] == 1]['Lines_of_code']
non_defective = df[df['defect_status'] == 0]['Lines_of_code']

# Perform one-sided Mann-Whitney U test (are defective > non-defective?)
stat, p = mannwhitneyu(defective, non_defective, alternative='greater')

print(f'Mann-Whitney U statistic: {stat}')
print(f'p-value: {p}')
