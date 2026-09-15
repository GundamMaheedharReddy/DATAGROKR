"""
OOP Bank Account System with Transaction History
--------------------------------------------------
Demonstrates core OOP concepts: encapsulation, inheritance, polymorphism.
Every deposit/withdrawal/transfer is logged as a Transaction object,
and the full history can be exported to a CSV for later analysis with pandas.
"""

from __future__ import annotations
import csv
from datetime import datetime
from dataclasses import dataclass, field
from typing import List


# ---------------------------------------------------------------------------
# Transaction: an immutable record of a single event on an account
# ---------------------------------------------------------------------------
@dataclass
class Transaction:
    account_id: str
    txn_type: str          # "DEPOSIT", "WITHDRAWAL", "TRANSFER_IN", "TRANSFER_OUT"
    amount: float
    balance_after: float
    timestamp: str = field(default_factory=lambda: datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "account_id": self.account_id,
            "type": self.txn_type,
            "amount": self.amount,
            "balance_after": self.balance_after,
        }

    def __str__(self):
        return f"[{self.timestamp}] {self.account_id} | {self.txn_type:<13} | Amt: {self.amount:>10.2f} | Bal: {self.balance_after:>10.2f}"


# ---------------------------------------------------------------------------
# Base Account class
# ---------------------------------------------------------------------------
class BankAccount:
    """Base class for all account types."""

    _id_counter = 1000  # class-level counter to auto-generate account IDs

    def __init__(self, owner: str, balance: float = 0.0):
        BankAccount._id_counter += 1
        self.account_id: str = f"ACC{BankAccount._id_counter}"
        self.owner: str = owner
        self._balance: float = balance
        self.history: List[Transaction] = []

        if balance > 0:
            self._log_transaction("DEPOSIT", balance)

    # ---- properties (encapsulation) ----
    @property
    def balance(self) -> float:
        return self._balance

    # ---- core operations ----
    def deposit(self, amount: float) -> None:
        if amount <= 0:
            raise ValueError("Deposit amount must be positive.")
        self._balance += amount
        self._log_transaction("DEPOSIT", amount)

    def withdraw(self, amount: float) -> None:
        if amount <= 0:
            raise ValueError("Withdrawal amount must be positive.")
        if amount > self._balance:
            raise ValueError(f"Insufficient funds in {self.account_id}. Balance: {self._balance:.2f}")
        self._balance -= amount
        self._log_transaction("WITHDRAWAL", amount)

    def transfer(self, other: "BankAccount", amount: float) -> None:
        self.withdraw(amount)
        other._balance += amount
        other._log_transaction("TRANSFER_IN", amount)
        self.history[-1] = Transaction(  # relabel the last log as a transfer-out
            self.account_id, "TRANSFER_OUT", amount, self._balance
        )

    def _log_transaction(self, txn_type: str, amount: float) -> None:
        self.history.append(Transaction(self.account_id, txn_type, amount, self._balance))

    def print_statement(self) -> None:
        print(f"\n--- Statement for {self.account_id} ({self.owner}) ---")
        for txn in self.history:
            print(txn)
        print(f"Current Balance: {self._balance:.2f}\n")

    def __str__(self):
        return f"{self.__class__.__name__}[{self.account_id}] Owner: {self.owner}, Balance: {self._balance:.2f}"


# ---------------------------------------------------------------------------
# Derived account types (inheritance + polymorphism)
# ---------------------------------------------------------------------------
class SavingsAccount(BankAccount):
    """Earns interest, restricts withdrawals below a minimum balance."""

    def __init__(self, owner: str, balance: float = 0.0, interest_rate: float = 0.04, min_balance: float = 500.0):
        super().__init__(owner, balance)
        self.interest_rate = interest_rate
        self.min_balance = min_balance

    def withdraw(self, amount: float) -> None:
        if self._balance - amount < self.min_balance:
            raise ValueError(
                f"Cannot withdraw: {self.account_id} must maintain a minimum balance of {self.min_balance:.2f}"
            )
        super().withdraw(amount)

    def apply_interest(self) -> None:
        interest = self._balance * self.interest_rate
        self.deposit(round(interest, 2))


class CurrentAccount(BankAccount):
    """Allows overdraft up to a limit."""

    def __init__(self, owner: str, balance: float = 0.0, overdraft_limit: float = 1000.0):
        super().__init__(owner, balance)
        self.overdraft_limit = overdraft_limit

    def withdraw(self, amount: float) -> None:
        if amount <= 0:
            raise ValueError("Withdrawal amount must be positive.")
        if self._balance - amount < -self.overdraft_limit:
            raise ValueError(f"Overdraft limit exceeded for {self.account_id}.")
        self._balance -= amount
        self._log_transaction("WITHDRAWAL", amount)


# ---------------------------------------------------------------------------
# Bank: manages multiple accounts, aggregates all transaction history
# ---------------------------------------------------------------------------
class Bank:
    def __init__(self, name: str):
        self.name = name
        self.accounts: dict[str, BankAccount] = {}

    def open_account(self, account: BankAccount) -> str:
        self.accounts[account.account_id] = account
        return account.account_id

    def get_account(self, account_id: str) -> BankAccount:
        if account_id not in self.accounts:
            raise KeyError(f"No such account: {account_id}")
        return self.accounts[account_id]

    def all_transactions(self) -> List[Transaction]:
        txns = []
        for acc in self.accounts.values():
            txns.extend(acc.history)
        return sorted(txns, key=lambda t: t.timestamp)

    def export_history_csv(self, filepath: str) -> None:
        txns = self.all_transactions()
        with open(filepath, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["timestamp", "account_id", "type", "amount", "balance_after"])
            writer.writeheader()
            for txn in txns:
                writer.writerow(txn.to_dict())
        print(f"Exported {len(txns)} transactions to {filepath}")

    def print_all_balances(self) -> None:
        print(f"\n=== {self.name}: Account Balances ===")
        for acc in self.accounts.values():
            print(acc)


# ---------------------------------------------------------------------------
# Demo / driver code
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    bank = Bank("PyBank")

    alice = SavingsAccount("Alice", balance=5000, interest_rate=0.05)
    bob = CurrentAccount("Bob", balance=1000, overdraft_limit=500)
    carol = SavingsAccount("Carol", balance=2000)

    bank.open_account(alice)
    bank.open_account(bob)
    bank.open_account(carol)

    # Perform a series of operations
    alice.deposit(1500)
    alice.withdraw(800)
    bob.withdraw(1300)          # dips into overdraft
    carol.deposit(300)
    alice.transfer(bob, 1000)
    carol.apply_interest()
    bob.deposit(200)

    try:
        carol.withdraw(5000)    # should fail: below min balance
    except ValueError as e:
        print(f"Transaction blocked: {e}")

    for acc in (alice, bob, carol):
        acc.print_statement()

    bank.print_all_balances()
    bank.export_history_csv("transactions.csv")
