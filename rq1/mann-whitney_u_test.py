import pandas as pd
from scipy.stats import mannwhitneyu

# Datasets
datasets = {
    "Mirantis": "authors_data/IST_MIR.csv",
    "Mozilla": "authors_data/IST_MOZ.csv",
    "Openstack": "authors_data/IST_OST.csv",
    "Wikimedia": "authors_data/IST_WIK.csv"
}

# Mapping of dataset column names to rendered names (preserving order)
properties = {
    "Attribute": "Attribute",
    "Command": "Command",
    "Comment": "Comment",
    "Ensure": "Ensure",
    "File": "File",
    "File_mode": "File mode",
    "Hard_coded_string": "Hard-coded string",
    "Include": "Include",
    "Lines_of_code": "Lines of code",
    "Require": "Require",
    "SSH_KEY": "SSH_KEY",
    "URL": "URL"
}

# Storage for table (keys = property rendered names, values = dict of dataset:pval)
table = {}

# Iterate over each property to test
for prop, rendered_name in properties.items():
    # Initialize dictionary for each property
    table[rendered_name] = {}

    # Track if all p-values < 0.05 for this property
    all_significant = True

    # Iterate over each dataset
    for dataset_name, file_path in datasets.items():
        # Load dataset
        df = pd.read_csv(file_path)

        # Select values for defective and non-defective groups
        def_group = df[df['defect_status'] == 1][prop].dropna()
        nondef_group = df[df['defect_status'] == 0][prop].dropna()

        # Perform Mann-Whitney U test (alternative: greater)
        stat, p = mannwhitneyu(def_group, nondef_group, alternative="greater")

        # Render p-values: <0.001 as "<0.001", 0.001-0.01 with 3 decimals, else with 2 decimals, always round down
        if p < 0.001:
            p_value = "<0.001"
        elif p < 0.01:
            p_value = f"{(int(p * 1000) / 1000):.3f}"
        else:
            p_value = f"{(int(p * 100) / 100):.2f}"

        # Store p-value in results table
        table[rendered_name][dataset_name] = p_value

        # Check significance
        # For "<0.001", treat as significant
        if not (p < 0.05):
            all_significant = False

    # Bold property name if all p-values < 0.05
    if all_significant:
        # Markdown bold
        bold_name = f"**{rendered_name}**"
        table[bold_name] = table.pop(rendered_name)

# Build DataFrame
results_df = pd.DataFrame.from_dict(table, orient='index')
results_df.reset_index(inplace=True)
results_df.rename(columns={'index': 'Property'}, inplace=True)

# Show results
print(results_df)
