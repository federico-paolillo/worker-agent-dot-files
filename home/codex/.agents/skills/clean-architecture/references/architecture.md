# Architecture Conventions

Use these conventions for medium-sized ASP.NET Core applications that adopt this
skill. Preserve an existing compatible convention rather than renaming it for
cosmetic consistency.

## Solution Shape

Create these projects as separate compilation boundaries:

```text
Acme.Domain
Acme.Commons
Acme.Application
Acme.Database
Acme.Api
Acme.Tests.Unit
Acme.Tests.Integration
```

Centralize common compiler settings in `Directory.Build.props`. Enable nullable
reference types and analyzers, treat warnings as errors, and use the solution's
selected SDK and language version rather than hard-coding a version in feature
projects.

### Dependency Rule

| Project           | Responsibility                                                     | May reference                                                  |
| ----------------- | ------------------------------------------------------------------ | -------------------------------------------------------------- |
| Domain            | Business models, value objects, invariants                         | BCL and narrowly justified domain-safe packages                |
| Commons           | Cross-project result and transaction primitives                    | BCL only                                                       |
| Application       | Use cases, persistence/external ports, application models          | Domain, Commons                                                |
| Database          | EF Core adapter, entities, mappings, queries, commands, migrations | Application, Domain, Commons                                   |
| Api               | HTTP boundary and composition root                                 | Application, Database; Domain/Commons where mapping needs them |
| Tests.Unit        | Pure domain and application behavior                               | Domain, Commons, Application                                   |
| Tests.Integration | Real DI, database, migration, serialization, and HTTP behavior     | Api, Database, required inner projects                         |

Do not create circular references. Domain and Application never reference API,
Database, ASP.NET Core, or EF Core. Database implements interfaces owned by
Application.

`Commons` is mandatory but narrow. It is not a dumping ground for unrelated
helpers, DTOs, constants, or extension methods. Its normal contents are
`Result<T>`, `Problem`, `Unit`, `IUnitOfWork`, and the shared transaction base.

## Organize by Feature Inside Layers

Use layer projects for dependency enforcement and feature folders for
navigation:

```text
Acme.Application/
|- Orders/
|  |- Data/
|  |- Extensions/
|  |- Handlers/
|  |  `- Defaults/
|  |- Models/
|  |  |- Input/
|  |  `- Output/
|  |- Problems/
|  |- Services/
|  |  `- Defaults/
|  `- Transactions/
|     `- Defaults/
`- Articles/
   `- ...

Acme.Database/
|- Commands/
|- Entities/
|- Extensions/
|- Mappers/
|- Migrations/
`- Queries/

Acme.Api/
|- Orders/
|  |- Endpoints.cs
|  |- Handlers.cs
|  `- Models/
|- Articles/
|  `- ...
|- Program.cs
`- Program.Declaration.cs
```

Omit empty feature subfolders. Add a folder when the first type of that role
exists. Namespace names follow project and folder names. Default implementations
of Application interfaces live in the role's `Defaults/` folder.

## Request and Data Flow

The normal write path is:

```text
HTTP DTO -> API mapping -> Application input -> Transaction
         -> Query/Command ports -> Database implementations -> EF entities
         <- Result<output> <- Domain/Application models <- mapping
HTTP result <- API response DTO
```

The normal read path is:

```text
HTTP parameters -> API mapping -> Handler -> Query port
HTTP DTO <- API mapping <- Application projection <- Database SELECT
```

A trivial read may skip the Application Handler and invoke its narrow
Application query port from the API handler. It must still return a Domain model
or Application projection, never an EF entity. Cross-use-case orchestration
belongs in a named Application Handler; do not add another architectural layer.

## Application Roles

### Transactions

A `*Transaction` is a write use case, not an EF transaction object. It:

- Accepts one Application input model, or a domain value object when that is the
  complete input.
- Loads state through query ports.
- Applies business behavior through domain models or services.
- Stages persistence through command ports.
- Owns the unit-of-work boundary.
- Calls `SaveChangesAsync` once, and only after a successful result.
- Returns `Result<TOutput>` or `Result<Unit>` for expected outcomes.

Application commands never call `SaveChangesAsync`; otherwise the Transaction
cannot control atomicity. Do not nest Transactions. Complete expected validation
before mutating tracked state where practical.

EF Core already treats a scoped `DbContext` as a unit of work, and a single
`SaveChangesAsync` call is atomic. Use an explicit database transaction only
when one use case requires multiple saves or mixes EF operations with other
operations on the same database transaction. Keep provider-specific transaction
APIs in Database.

### Handlers

A `*Handler` is a non-committing application use case. Use one to:

- Compose multiple queries.
- Enrich or transform a projection.
- Generate a file or stream.
- Coordinate a call to an external system.
- Coordinate a workflow whose persistence steps remain explicit Transactions.

Handlers do not depend on HTTP types and do not call `SaveChangesAsync`. If a
handler only forwards one query without adding behavior, remove it and let the
API use the query port directly.

### Services

A `*Service` contains reusable or substantial business/application behavior used
by a Handler or Transaction. Do not extract a service merely to shorten a
method. Prefer a concrete class for a private pure helper; introduce an
interface when it is a use-case contract, an external boundary, has multiple
implementations, or meaningful substitution is required in tests.

### Queries and Commands

Declare persistence ports under the owning Application feature's `Data/` folder:

- Name queries after the exact read: `IFetchOrderQuery`,
  `IFetchOrdersPageQuery`.
- Name commands after the exact mutation: `ISaveOrderCommand`,
  `IDecrementAvailabilityCommand`.
- Expose domain models or Application output projections.
- Accept domain value objects or Application input types rather than raw storage
  identifiers when useful.
- Include and propagate `CancellationToken` on asynchronous I/O.
- Never expose `DbSet`, EF entities, provider exceptions, expressions, or
  `IQueryable`.

Do not use a generic repository. A broad repository hides which interactions a
use case performs and produces a larger mocking surface than narrow
task-oriented ports.

## Domain Model

Use lightweight domain modeling:

- Choose names from the business language.
- Use value objects for concepts with validation, formatting, equality, or unit
  semantics.
- Validate invariants at construction or factory methods so invalid instances
  cannot be created.
- Put behavior on the domain type when it naturally belongs to that concept.
- Expose collections as immutable or read-only when consumers must not mutate
  state.
- Keep infrastructure and serialization attributes out of Domain.
- Do not assume one domain type per table or one table per domain type.

Do not introduce aggregate-root frameworks, domain-event infrastructure, event
sourcing, specifications, or base entity hierarchies without a concrete
requirement. Plain sealed classes and records are the default.

## Failures and Validation

Use three distinct failure categories:

1. **Invalid transport input:** reject at the API boundary with typed `400` or
   validation-problem results.
2. **Expected business/application outcome:** return `Result<T>` with a
   feature-specific `Problem`, such as missing data or a conflict.
3. **Unexpected or infrastructure failure:** throw; centralized ASP.NET Core
   exception handling logs it and produces the configured Problem Details
   response.

Do not catch every exception inside `Result<T>`. That obscures defects and
infrastructure outages. Catch only when translating a known exception into a
meaningful expected problem or adding context before rethrowing.

Keep `Problem` values independent of HTTP. The API maps each known problem to a
status code using an explicit switch and uses a safe generic response for
unexpected failures.

## EF Core Database Adapter

EF Core with migrations is the default for relational persistence. The
Application ports keep another adapter possible when the actual system requires
one.

- Keep `DbContext`, EF entities, type configurations, interceptors, and
  migrations in Database.
- Use persistence-shaped entity types. Do not force Domain types to satisfy EF
  mapping concerns.
- Map entities to Domain models for behavioral writes and entity-style reads.
- Project directly to Application output models for query-specific reads.
- Use `AsNoTracking()` for read-only entity queries. Tracking is appropriate for
  entities a command will mutate.
- Execute database I/O asynchronously and pass the caller's cancellation token.
- Avoid materializing full graphs when a projection can select the required
  columns.
- Keep query filters, provider configuration, connection strings, and
  provider-specific tuning inside Database.
- Add a migration for every schema change; do not create migrations for
  model-only refactors.
- Do not use the EF InMemory provider to prove relational query behavior.

CQRS here means separate read and write types over the same database. It does
not imply separate stores, events, or eventual consistency.

Register the same scoped `DbContext` instance as the Database context
abstraction and `IUnitOfWork`. Register queries, commands, and other
EF-dependent services as scoped. Use singleton only for immutable, stateless,
thread-safe services.

## Minimal API Boundary

Each feature owns:

```text
<Feature>/Endpoints.cs
<Feature>/Handlers.cs
<Feature>/Models/*.cs
```

`Endpoints.cs` exposes a `Map<Feature>(this WebApplication app)` extension,
creates one route group, maps methods, and gives every endpoint a stable
`.WithName(...)`. Apply shared authorization, filters, or metadata to the group
when the whole feature shares them.

`Handlers.cs` is an internal static class of route-handler methods. Each method:

- Receives dependencies through Minimal API parameter injection.
- Binds route, query, body, authenticated-user, and cancellation data.
- Validates transport-level rules.
- Maps DTOs and ambient request context to Application inputs.
- Calls one Application use case or one narrow query port.
- Maps outputs and known Problems to HTTP DTOs and typed results.

Use `TypedResults` and `Results<T1, ...>` unions for multiple outcomes. Use
`Created` with a location generated from a named retrieval endpoint. Prefer
framework-inferred OpenAPI metadata; add explicit metadata only when inference
cannot describe the contract.

API DTOs remain in Api and use transport-oriented primitive fields. Application
input/output types remain in Application and may use domain value objects. Never
serialize a Domain or EF entity merely because its current shape resembles the
public contract.

Configure `AddProblemDetails` and centralized exception handling in the
composition root. Keep transport-independent error details in Problems and avoid
exposing exception messages or storage details to clients.

With top-level statements, expose `Program` for `WebApplicationFactory<Program>`
in `Program.Declaration.cs`:

```csharp
namespace Acme.Api;

public partial class Program
{
}
```

## Dependency Injection and Configuration

Each Application feature exposes one registration extension such as
`AddOrders()`. Database exposes one adapter registration extension such as
`AddAcmeDatabase(configuration)`. These extensions own their registrations;
`Program.cs` composes them and maps endpoint groups.

Validate required configuration during startup. Use the options pattern for
grouped settings. Do not use a service locator in application code or build
nested service providers during registration.

## Testing Strategy

### Unit Tests

Use `Tests.Unit` for value objects, domain behavior, pure services, mappers
without I/O, and algorithms. Tests should not start the web host or database.
Prefer real values and small hand-written substitutes over mocking frameworks
when the substitute is trivial.

### Integration Tests

Use `Tests.Integration` when behavior depends on:

- EF Core translation, tracking, constraints, or transactions.
- Migrations and the production database provider.
- Dependency injection registrations and lifetimes.
- JSON binding and serialization.
- Route templates, status codes, headers, or Problem mapping.

Build the real application with `WebApplicationFactory<Program>`, supply
isolated configuration, apply migrations, and create a fresh database per test
or test collection. Replace only true external boundaries. API tests use public
request/response DTOs and typed HTTP JSON helpers unless deliberately testing
malformed payloads.

For each changed behavior, cover the main success path and the meaningful
expected failure path. For Transactions, verify both persisted success and no
persisted changes after failure. For queries, exercise the real provider. For
endpoints, assert status, response shape, and important headers such as
`Location`.

## Adapting an Existing Application

Do not perform a solution-wide migration as a side effect of one feature.
Preserve correct existing boundaries and move only code required by the
requested change. When a dependency currently points outward, place the new
interface at the inward layer and implement it in the adapter; propose unrelated
migrations separately.

When another established project convention conflicts with this skill, surface
the conflict. Follow explicit repository or user instructions; otherwise use
this architecture for the changed slice.
