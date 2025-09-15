# RQ-1 Replication

## Prerequisites

If using **uv**, then nothing.

If using **default python**:

```bash
pip install -r requirements.txt
```

## Running the analysis

With **uv**:

```bash
uv run main.py
```

With **default python** (you need to manually install the packages before):

```bash
python3 main.py
```

## Expected Results

| Property               | Mirantis p-value | Mirantis Cliff | Mozilla p-value | Mozilla Cliff | Openstack p-value | Openstack Cliff | Wikimedia p-value | Wikimedia Cliff |
|------------------------|------------------|----------------|-----------------|---------------|-------------------|-----------------|-------------------|-----------------|
| **Attribute**          | <0.001           | 0.47           | <0.001          | 0.41          | <0.001            | 0.35            | <0.001            | 0.47            |
| **Command**            | <0.001           | 0.24           | <0.001          | 0.18          | <0.001            | 0.07            | <0.001            | 0.18            |
| Comment                | <0.001           | 0.37           | 0.23            | 0.03          | 0.43              | 0.00            | <0.001            | 0.22            |
| **Ensure**             | <0.001           | 0.38           | 0.02            | 0.09          | <0.001            | 0.19            | <0.001            | 0.29            |
| **File**               | <0.001           | 0.36           | <0.001          | 0.18          | <0.001            | 0.09            | <0.001            | 0.31            |
| **File mode**          | <0.001           | 0.41           | <0.001          | 0.24          | <0.001            | 0.07            | <0.001            | 0.24            |
| **Hard-coded string**  | <0.001           | 0.55           | <0.001          | 0.41          | <0.001            | 0.37            | <0.001            | 0.55            |
| **Include**            | <0.001           | 0.33           | <0.001          | 0.31          | <0.001            | 0.22            | <0.001            | 0.37            |
| **Lines of code**      | <0.001           | 0.50           | <0.001          | 0.51          | <0.001            | 0.33            | <0.001            | 0.51            |
| **Require**            | <0.001           | 0.36           | <0.001          | 0.20          | <0.001            | 0.11            | <0.001            | 0.32            |
| **SSH_KEY**            | <0.001           | 0.39           | <0.001          | 0.24          | <0.001            | 0.07            | <0.001            | 0.24            |
| URL                    | <0.001           | 0.22           | 0.009           | 0.08          | 0.48              | 0.00            | <0.001            | 0.17            |
