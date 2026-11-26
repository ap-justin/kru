# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## A fake that can't drift

Where a real test database is cheap, use it (above). Where the real dependency is slow, needs credentials or can't be reset per test, a hand-written fake beats a mock at a boundary your code owns the interface of (a repository, the app's own `Payments` or `Mailer` interface):

- **It implements the interface.** `class FakeOrders implements Orders`, kept next to the real one and shared by every test that needs it. Its rows sit in public arrays or maps the test reads. A vendor's fake implements the app's own interface for that vendor.
- **It passes the real one's tests.** Run the repository's own round-trip suite against both the real repository and the fake. A guarantee the fake gives that no shared test covers (a uniqueness check, a lock) is one it can drop silently: add the shared test.
- **Assert state, not calls.** Read what the fake now holds (the row written), compared whole. A port with no state to read (mail, payments) gets a fake that records what it was asked to send; read that list, compared whole.
- **Time and IDs are constructor arguments.** `now: () => Date` and the ID source come in through the constructor, and the test fixes both and writes out the values they produce, so it needs no fake timers. Where the code reads the clock itself, fake timers are the fallback (`vitest` → `reference/mocks.md`).

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
