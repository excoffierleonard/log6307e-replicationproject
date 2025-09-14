import pandas as pd
from scipy.stats import mannwhitneyu
from cliffs_delta import cliffs_delta
from typing import Dict, List, Tuple
import math

ALPHA = 0.05  # significance threshold


def format_p_value(p: float) -> str:
    """Render p-values per requirements."""
    if p < 0.001:
        return "<0.001"
    if p < 0.01:
        return f"{math.floor(p * 1000) / 1000:.3f}"
    return f"{math.floor(p * 100) / 100:.2f}"


def get_groups(df: pd.DataFrame, col: str) -> Tuple[pd.Series, pd.Series]:
    """Return defective and non-defective samples for a column."""
    def_group = df[df["defect_status"] == 1][col].dropna()
    nondef_group = df[df["defect_status"] == 0][col].dropna()
    return def_group, nondef_group


def compute_stats(
    def_group: pd.Series, nondef_group: pd.Series
) -> Tuple[str, str, bool]:
    """
    Compute Mann-Whitney U (greater) and Cliff's delta.
    Returns formatted p-value, formatted delta, and significance flag.
    """
    _, p = mannwhitneyu(def_group, nondef_group, alternative="greater")
    delta, _ = cliffs_delta(def_group, nondef_group)  # library returns (delta, effect)
    return format_p_value(p), f"{delta:.2f}", p < ALPHA


def build_tables(
    datasets_dfs: Dict[str, pd.DataFrame],
    properties: Dict[str, str],
) -> Tuple[Dict[str, Dict[str, str]], Dict[str, Dict[str, str]]]:
    """
    Build per-property tables for p-values and Cliff's delta.
    Bold the property name if significant across all datasets.
    """
    p_value_table: Dict[str, Dict[str, str]] = {}
    cliffs_table: Dict[str, Dict[str, str]] = {}

    for prop, rendered in properties.items():
        p_value_table[rendered] = {}
        cliffs_table[rendered] = {}

        all_significant = True
        for dname, df in datasets_dfs.items():
            def_g, nondef_g = get_groups(df, prop)
            p_str, d_str, significant = compute_stats(def_g, nondef_g)
            p_value_table[rendered][dname] = p_str
            cliffs_table[rendered][dname] = d_str
            if not significant:
                all_significant = False

        if all_significant:
            bold = f"**{rendered}**"
            p_value_table[bold] = p_value_table.pop(rendered)
            cliffs_table[bold] = cliffs_table.pop(rendered)

    return p_value_table, cliffs_table


def build_combined_dataframe(
    p_table: Dict[str, Dict[str, str]],
    c_table: Dict[str, Dict[str, str]],
    dataset_order: List[str],
) -> pd.DataFrame:
    """Create the alternating p-value/Cliff's delta table in the requested order."""
    combined: Dict[str, List[str]] = {"Property": list(p_table.keys())}
    for d in dataset_order:
        combined[f"{d} p-value"] = [p_table[prop][d] for prop in p_table.keys()]
        combined[f"{d} Cliff"] = [c_table[prop][d] for prop in c_table.keys()]

    df = pd.DataFrame(combined)

    # Enforce column order: Property, then for each dataset [p-value, Cliff]
    cols = ["Property"]
    for d in dataset_order:
        cols.extend([f"{d} p-value", f"{d} Cliff"])
    return df[cols]


def main() -> None:
    """Main execution function."""
    # Datasets
    datasets = {
        "Mirantis": "authors_data/IST_MIR.csv",
        "Mozilla": "authors_data/IST_MOZ.csv",
        "Openstack": "authors_data/IST_OST.csv",
        "Wikimedia": "authors_data/IST_WIK.csv",
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
        "URL": "URL",
    }

    # Preload datasets once
    datasets_dfs = {name: pd.read_csv(path) for name, path in datasets.items()}
    dataset_order = list(datasets_dfs.keys())

    p_table, c_table = build_tables(datasets_dfs, properties)
    combined_df = build_combined_dataframe(p_table, c_table, dataset_order)

    # Output
    print(combined_df)


if __name__ == "__main__":
    main()
