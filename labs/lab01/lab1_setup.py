import numpy as np
import pandas as pd

# NumPy Verification
arr = np.array([10, 20, 30, 40, 50])
print(f"NumPy Mean: {np.mean(arr)}")

# Pandas Verification
df = pd.DataFrame({
    'ID': [101, 102, 103],
    'Name': ['Alice', 'Bob', 'Charlie'],
    'Score': [85, 92, 78]
})
print("\nPandas DataFrame:")
print(df)
