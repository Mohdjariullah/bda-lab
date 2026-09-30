import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

# Generate dummy dataset
np.random.seed(42)
months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
sales = [12000, 15000, 18000, 14000, 22000, 25000]
df = pd.DataFrame({'Month': months, 'Sales': sales})

# Create a multi-panel plot layout
fig, axes = plt.subplots(2, 2, figsize=(12, 8))

# 1. Line Plot
axes[0, 0].plot(df['Month'], df['Sales'], marker='o', color='b', linewidth=2)
axes[0, 0].set_title('Monthly Sales Trend (Line Plot)')

# 2. Bar Chart
axes[0, 1].bar(df['Month'], df['Sales'], color='skyblue')
axes[0, 1].set_title('Monthly Revenue Comparison (Bar Chart)')

# 3. Histogram
data = np.random.normal(loc=100, scale=15, size=500)
axes[1, 0].hist(data, bins=20, color='lightgreen', edgecolor='black')
axes[1, 0].set_title('Distribution Analysis (Histogram)')

# 4. Scatter Plot
x = np.random.rand(50) * 100
y = x * 2 + np.random.randn(50) * 10
axes[1, 1].scatter(x, y, color='purple', alpha=0.7)
axes[1, 1].set_title('Scatter Relationship Plot')

plt.tight_layout()
plt.savefig('visualization_output.png')
print("Plot successfully saved as 'visualization_output.png'")
