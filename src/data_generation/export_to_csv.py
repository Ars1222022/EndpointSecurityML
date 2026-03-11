import pandas as pd
import pyodbc
from datetime import datetime
import os

print("Ansluter till SQL Server...")
conn_str = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=EndpointSecurityML;Trusted_Connection=yes;"
conn = pyodbc.connect(conn_str)

print("Hämtar data...")
df = pd.read_sql("SELECT * FROM EndpointActivities", conn)

os.makedirs("data/raw", exist_ok=True)
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
csv_path = f"data/raw/endpoint_data_{timestamp}.csv"
df.to_csv(csv_path, index=False)
print(f"Sparade {len(df)} rader till {csv_path}")
conn.close()
