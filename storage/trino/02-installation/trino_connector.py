#!/usr/bin/env python3
"""
Trino Python Client Examples
This script demonstrates different ways to use the Trino Python client
"""

import trino
import pandas as pd
import os
import sys

def basic_connection():
    """Basic connection example"""
    print("\n=== Basic Connection ===")
    # Connect to Trino
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='trino',
        catalog='mysql',
        schema='example',
    )
    
    # Create a cursor
    cur = conn.cursor()
    
    # Execute a simple query
    cur.execute('SHOW CATALOGS')
    
    # Fetch and print the results
    catalogs = cur.fetchall()
    print("Available catalogs:")
    for catalog in catalogs:
        print(f"  - {catalog[0]}")
    
    # Close the cursor and connection
    cur.close()
    conn.close()

def authentication_example():
    """Authentication example with password"""
    print("\n=== Authentication Example ===")
    # This example requires setting up authentication in Trino
    
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='admin',  # Use your authentication username
        catalog='mysql',
        schema='example',
        auth=trino.auth.BasicAuthentication("admin", "password")  # Use your password
    )
    
    cur = conn.cursor()
    cur.execute('SELECT current_user')
    print(f"Connected as user: {cur.fetchone()[0]}")
    cur.close()
    conn.close()

def query_with_parameters():
    """Demonstrating parameterized queries"""
    print("\n=== Parameterized Queries ===")
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='trino',
        catalog='mysql',
        schema='example',
    )
    
    cur = conn.cursor()
    
    # Execute a parameterized query
    # Note: Trino uses question marks for parameters
    customer_id = 1
    query = "SELECT * FROM customers WHERE id = ?"
    cur.execute(query, (customer_id,))
    
    # Fetch and print the results
    columns = [desc[0] for desc in cur.description]
    results = cur.fetchall()
    
    if results:
        print(f"Customer with ID {customer_id}:")
        for i, col in enumerate(columns):
            print(f"  {col}: {results[0][i]}")
    else:
        print(f"No customer found with ID {customer_id}")
    
    cur.close()
    conn.close()

def with_pandas_dataframe():
    """Working with pandas DataFrames"""
    print("\n=== Pandas DataFrame Integration ===")
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='trino',
        catalog='mysql',
        schema='example',
    )
    
    cur = conn.cursor()
    
    # Execute a query
    cur.execute('SELECT * FROM customers')
    
    # Convert to pandas DataFrame
    columns = [desc[0] for desc in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=columns)
    
    print("Customers DataFrame:")
    print(df)
    
    # Demonstrate some pandas operations
    print("\nDataFrame info:")
    print(df.info())
    
    print("\nSummary statistics:")
    print(df.describe(include='all'))
    
    cur.close()
    conn.close()

def cross_catalog_query():
    """Querying across different catalogs"""
    print("\n=== Cross-Catalog Query ===")
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='trino',
    )
    
    cur = conn.cursor()
    
    # Execute a cross-catalog query
    query = """
    SELECT 
        c.name AS customer, 
        p.name AS product
    FROM 
        mysql.example.customers c
    CROSS JOIN 
        postgresql.public.products p
    LIMIT 5
    """
    
    try:
        cur.execute(query)
        
        # Convert to pandas DataFrame
        columns = [desc[0] for desc in cur.description]
        df = pd.DataFrame(cur.fetchall(), columns=columns)
        
        print("Cross-catalog query results:")
        print(df)
    except Exception as e:
        print(f"Error executing cross-catalog query: {e}")
    
    cur.close()
    conn.close()

def session_properties():
    """Setting session properties"""
    print("\n=== Session Properties ===")
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='trino',
        catalog='mysql',
        schema='example',
        session_properties={
            'query_max_execution_time': '30m',
            'query_priority': '10'
        }
    )
    
    cur = conn.cursor()
    cur.execute('SHOW SESSION')
    
    print("Session properties:")
    for row in cur.fetchall():
        if row[0] in ['query_max_execution_time', 'query_priority']:
            print(f"  {row[0]} = {row[1]}")
    
    cur.close()
    conn.close()

def error_handling():
    """Demonstrating error handling"""
    print("\n=== Error Handling ===")
    conn = trino.dbapi.connect(
        host='localhost',
        port=8080,
        user='trino',
        catalog='mysql',
        schema='example',
    )
    
    cur = conn.cursor()
    
    # Intentionally cause an error with an invalid query
    try:
        cur.execute('SELECT * FROM non_existent_table')
        results = cur.fetchall()
        print(results)
    except Exception as e:
        print(f"Caught exception: {e}")
        print("This is expected - we're demonstrating error handling")
    
    # Show that the connection is still usable
    try:
        print("\nConnection is still usable:")
        cur.execute('SHOW CATALOGS')
        catalogs = cur.fetchall()
        print(f"Found {len(catalogs)} catalogs")
    except Exception as e:
        print(f"Connection failed after error: {e}")
    
    cur.close()
    conn.close()

def main():
    """Main function to run all examples"""
    print("Trino Python Client Examples")
    print("============================")
    
    # Test if Trino server is available
    try:
        test_conn = trino.dbapi.connect(
            host='localhost',
            port=8080,
            user='trino',
            catalog='system',
        )
        test_cur = test_conn.cursor()
        test_cur.execute('SELECT 1')
        test_cur.fetchall()
        test_cur.close()
        test_conn.close()
        print("Successfully connected to Trino server!")
    except Exception as e:
        print(f"Could not connect to Trino server: {e}")
        print("Make sure Trino is running at localhost:8080")
        print("You can still review the examples in this script.")
        if "--run-anyway" not in sys.argv:
            return
    
    try:
        # Run examples
        basic_connection()
        
        # Only run these examples if --all flag is provided
        if "--all" in sys.argv:
            authentication_example()
            query_with_parameters()
            cross_catalog_query()
            session_properties()
            error_handling()
        
        # Always run the pandas example if pandas is available
        if 'pandas' in sys.modules:
            with_pandas_dataframe()
        else:
            print("\n=== Pandas Integration ===")
            print("pandas module not available. Install with: pip install pandas")
    
    except Exception as e:
        print(f"Error during execution: {e}")
        print("Some examples may require a specific Trino setup with the appropriate catalogs and tables.")
        print("See the lab instructions for setting up the required environment.")

if __name__ == "__main__":
    main() 