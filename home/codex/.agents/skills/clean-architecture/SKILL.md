---
name: clean-architecture
description: Design, adapt, implement, or review medium-sized .NET web applications using explicit Clean Architecture project boundaries and vertical feature slices. Invoke explicitly when this architecture is wanted; do not apply it automatically to ordinary .NET work or to Go projects.
---

# .NET Clean Architecture

Use a light Clean Architecture: strict project boundaries, vertical slices
inside the API and Application projects, lightweight domain modeling, narrow
persistence ports, and EF Core as the default relational adapter.

## Start With the Existing System

Before proposing structure or writing code:

1. Read repository instructions, solution files, central build properties,
   project references, composition roots, and the complete feature being
   changed.
2. Reuse established names and shared primitives when they already express this
   architecture.
3. Do not reorganize unrelated code. For an existing system, adopt the
   conventions in the changed slice and propose broader migration separately.
4. Use the repository's configured .NET and C# versions. Keep nullable reference
   types, analyzers, formatting, and warnings-as-errors aligned with its build
   configuration.

For architecture design, project creation, dependency changes, persistence work,
or a feature spanning layers, read
[references/architecture.md](references/architecture.md). For concrete code
shapes or scaffolding, also read
[references/examples.md](references/examples.md).

## Required Project Boundaries

When adopting this architecture, use separate projects:

```text
<App>.Domain
<App>.Commons
<App>.Application
<App>.Database
<App>.Api
<App>.Tests.Unit
<App>.Tests.Integration
```

Dependencies point inward:

```text
Domain       -> no application projects
Commons      -> no application projects
Application  -> Domain, Commons
Database     -> Application, Domain, Commons
Api          -> Application, Database; Domain/Commons only for boundary mapping
Tests.Unit   -> Domain, Commons, Application
Tests.Integration -> Api, Database and required inner projects
```

Never reference API or Database from Domain or Application. `Api` is the
composition root and may reference concrete adapters solely to register and
start them.

## Choose the Smallest Correct Use-Case Type

| Need                                                                | Application type | Rule                                                                                   |
| ------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------- |
| Persist state                                                       | `*Transaction`   | Own one unit-of-work boundary and save once on success.                                |
| Compose reads, transform output, export, or call an external system | `*Handler`       | Coordinate application behavior without owning a database commit.                      |
| Reusable non-trivial behavior                                       | `*Service`       | Extract only when multiple use cases need it or the behavior deserves focused testing. |
| One specific read from persistence                                  | `*Query` port    | Declare the narrow interface in Application; implement it in Database.                 |
| One specific persistence mutation                                   | `*Command` port  | Declare the narrow interface in Application; implement it in Database.                 |

A trivial API read may call an Application query port directly. Writes and
non-trivial reads go through a named Application use case. Do not create generic
repositories, mediator pipelines, factories, or interfaces for private one-off
helpers.

## Non-Negotiable Behavior

- API DTOs are transport contracts. Map them to Application input models and map
  Domain/Application output to response DTOs.
- EF Core entities, `DbContext`, provider types, and `IQueryable` stay in
  Database.
- Expected business failures return `Result<T>` with typed `Problem` values.
  Unexpected failures throw and are handled centrally at the API boundary.
- Domain models use business names and enforce invariants. They do not mirror
  database tables by default.
- Every Minimal API endpoint belongs to a feature route group, delegates to a
  static method in `Handlers.cs`, has `.WithName(...)`, and returns
  `TypedResults` with `Results<...>` when it has multiple outcomes.
- Propagate `CancellationToken` through every asynchronous boundary that
  supports it.
- Register services through feature-specific `IServiceCollection` extensions.
  Keep `Program.cs` focused on composition and startup.
- Add tests with behavior changes. Use unit tests for pure behavior and
  integration tests when DI, EF Core, migrations, serialization, or HTTP
  semantics matter.

## Completion Check

Verify project references, API-to-Application mapping, transaction ownership,
persistence encapsulation, expected-problem mapping, cancellation propagation,
DI registration, migrations when the schema changed, and the relevant
unit/integration tests. Run the repository's formatting, build, and test
commands.
