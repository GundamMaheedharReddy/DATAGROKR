"""
CSV Dataset Analysis using pandas
-----------------------------------
Loads the transaction history exported by bank_account.py (transactions.csv)
and runs summary analysis: totals by type, per-account activity,
largest transactions, and a running balance timeline.

Run bank_account.py first to generate transactions.csv, then run this file.
"""

import pandas as pd

CSV_PATH = "transactions.csv"


def load_data(path: str = CSV_PATH) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["timestamp"])
    df.sort_values("timestamp", inplace=True)
    return df


def summary_by_type(df: pd.DataFrame) -> pd.DataFrame:
    return df.groupby("type")["amount"].agg(["count", "sum", "mean"]).round(2)


def summary_by_account(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df.groupby("account_id")
        .agg(
            total_transactions=("amount", "count"),
            total_deposited=("amount", lambda x: x[df.loc[x.index, "type"].isin(["DEPOSIT", "TRANSFER_IN"])].sum()),
            total_withdrawn=("amount", lambda x: x[df.loc[x.index, "type"].isin(["WITHDRAWAL", "TRANSFER_OUT"])].sum()),
            final_balance=("balance_after", "last"),
        )
        .round(2)
    )


def largest_transactions(df: pd.DataFrame, n: int = 5) -> pd.DataFrame:
    return df.nlargest(n, "amount")[["timestamp", "account_id", "type", "amount"]]


def net_flow(df: pd.DataFrame) -> float:
    inflow = df.loc[df["type"].isin(["DEPOSIT", "TRANSFER_IN"]), "amount"].sum()
    outflow = df.loc[df["type"].isin(["WITHDRAWAL", "TRANSFER_OUT"]), "amount"].sum()
    return round(inflow - outflow, 2)


if __name__ == "__main__":
    df = load_data()

    print("=== Raw Transaction Data ===")
    print(df, "\n")

    print("=== Summary by Transaction Type ===")
    print(summary_by_type(df), "\n")

    print("=== Summary by Account ===")
    print(summary_by_account(df), "\n")

    print("=== Top 5 Largest Transactions ===")
    print(largest_transactions(df), "\n")

    print(f"Net cash flow across the bank: {net_flow(df):.2f}\n")

    # Example export of a derived report
    summary_by_account(df).to_csv("account_summary.csv")
    print("Saved per-account summary to account_summary.csv")
