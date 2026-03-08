# Microsoft To Do Export Feasibility

Last reviewed: March 8, 2026

## Summary

It is feasible to export generated shopping ingredients into Microsoft To Do.

- Microsoft To Do is available through Microsoft Graph To Do endpoints (task lists, tasks, checklist items).
- Ingredient export can be modeled as:
  - one task per ingredient, or
  - one "shopping trip" task with ingredient checklist items.

## Important Constraint

Current Microsoft Graph To Do task endpoints are primarily delegated-user flows for create/update/delete operations. In practice, this means:

- The safe implementation assumption is signed-in user consent (`Tasks.ReadWrite` delegated).
- A pure app-only background sync should be treated as unsupported/risky for task mutation.

## Integration Options

1. Graph API (custom integration)
- Best when we need full control over mapping, idempotency, and UX.
- Requires auth flow and token handling.

2. Power Automate / Logic Apps (no-code/low-code)
- Official Microsoft To Do connectors exist for both Business and Consumer variants.
- Good for faster initial rollout with lower engineering effort.

## Recommended Direction

Start with delegated user-auth export flow (or Power Automate for MVP), then evolve to a richer Graph integration if the product workflow needs tighter control.

## Sources

- https://learn.microsoft.com/en-us/graph/todo-concept-overview
- https://learn.microsoft.com/en-us/graph/api/todo-list-lists?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/todotasklist-post-tasks?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/todotask-update?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/todotask-delete?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/todotask-post-checklistitems?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/permissions-reference
- https://learn.microsoft.com/en-us/graph/api/subscription-post-subscriptions?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/connectors/todo/
- https://learn.microsoft.com/en-us/connectors/todoconsumer/
