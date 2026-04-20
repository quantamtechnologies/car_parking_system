# Billing Engine

## Formula

```text
Total Fee = Base Fee + (Billable Hours x Hourly Rate) + Extra Charges + Penalties
```

## Rules

- Pricing is stored in `PricingPolicy`
- A session stores a pricing snapshot at entry time
- Historical sessions always use the snapshot saved with that session
- Admin can update pricing without changing code
- Cashiers can confirm payments, but they cannot edit pricing
- Exit is blocked until payment is confirmed unless an admin override is used

## Cash Shift

- Opening cash is recorded at shift start
- Closing cash compares actual versus expected
- Difference = Actual Cash - Expected Cash

## Accounting Safety

- Confirmed cash payments count as revenue
- Override closures are logged and excluded from cash revenue
- Every payment creates a receipt number

