import pandas as pd
from scipy.stats import mannwhitneyu
from cliffs_delta import cliffs_delta

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

# Storage for tables
p_value_table = {}
cliffs_delta_table = {}

# Iterate over each property to test
for prop, rendered_name in properties.items():
    # Initialize dictionaries for each property
    p_value_table[rendered_name] = {}
    cliffs_delta_table[rendered_name] = {}
    
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
        
        # Calculate Cliff's Delta
        # Calculate Cliff's Delta
        delta_tuple = cliffs_delta(def_group, nondef_group)
        delta = delta_tuple[0]
        
        # Render p-values: <0.001 as "<0.001", 0.001-0.01 with 3 decimals, else with 2 decimals, always round down
        if p < 0.001:
            p_value = "<0.001"
        elif p < 0.01:
            p_value = f"{(int(p * 1000) / 1000):.3f}"
        else:
            p_value = f"{(int(p * 100) / 100):.2f}"
        
        # Format Cliff's Delta (2 decimal places)
        delta_value = f"{delta:.2f}"
        
        # Store values in results tables
        p_value_table[rendered_name][dataset_name] = p_value
        cliffs_delta_table[rendered_name][dataset_name] = delta_value
        # Check significance
        if not (p < 0.05):
            all_significant = False
    
    # Bold property name if all p-values < 0.05
    if all_significant:
        bold_name = f"**{rendered_name}**"
        p_value_table[bold_name] = p_value_table.pop(rendered_name)
        cliffs_delta_table[bold_name] = cliffs_delta_table.pop(rendered_name)

# Alternative: Create combined table with alternating columns
combined_data = {}
combined_data['Property'] = list(p_value_table.keys())

for dataset in datasets.keys():
    combined_data[f'{dataset} p-value'] = [p_value_table[prop][dataset] for prop in p_value_table.keys()]
    combined_data[f'{dataset} Cliff'] = [cliffs_delta_table[prop][dataset] for prop in cliffs_delta_table.keys()]

combined_df = pd.DataFrame(combined_data)

# Reorder columns to match your expected format
column_order = ['Property']
for dataset in datasets.keys():
    column_order.extend([f'{dataset} p-value', f'{dataset} Cliff'])
combined_df = combined_df[column_order]

# Print results
print(combined_df)
