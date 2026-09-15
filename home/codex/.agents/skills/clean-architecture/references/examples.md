# Vertical-Slice Example

This example shows the shape of an `Orders` feature. Adapt names and business
rules; do not copy types that the target project already provides. Imports and
routine configuration are omitted where they do not clarify a boundary.

## Result and Transaction Primitives

Keep these in `Acme.Commons`:

```csharp
public abstract record Problem;

public readonly record struct Unit;

public sealed class Result<T>
{
    private Result(T value) => Value = value;

    private Result(Problem error) => Error = error;

    public T? Value { get; }

    public Problem? Error { get; }

    [MemberNotNullWhen(true, nameof(Value))]
    [MemberNotNullWhen(false, nameof(Error))]
    public bool Ok => Error is null;

    public static Result<T> Success(T value) => new(value);

    public static Result<T> Failure(Problem problem) => new(problem);
}

public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}

public abstract class Transaction<TInput, TOutput>(IUnitOfWork unitOfWork)
{
    public async Task<Result<TOutput>> ExecuteAsync(
        TInput input,
        CancellationToken cancellationToken = default
    )
    {
        var result = await ExecuteCoreAsync(input, cancellationToken);

        if (result.Ok)
        {
            await unitOfWork.SaveChangesAsync(cancellationToken);
        }

        return result;
    }

    protected abstract Task<Result<TOutput>> ExecuteCoreAsync(
        TInput input,
        CancellationToken cancellationToken
    );
}
```

The base class deliberately does not catch unexpected exceptions. A failed
expected result is not committed. Commands stage changes; only the Transaction
saves them.

## Domain

Keep business concepts and invariants in `Acme.Domain`:

```csharp
public sealed record OrderId(Guid Value)
{
    public static OrderId New() => new(Guid.NewGuid());
}

public sealed record Money(long Cents)
{
    public static Money FromCents(long cents)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(cents);
        return new Money(cents);
    }
}

public sealed record OrderItem(string ArticleId, string Description, Money Price, uint Quantity);

public sealed record Article(string Id, string Description, Money Price);

public sealed class Order
{
    public required OrderId Id { get; init; }

    public required ImmutableArray<OrderItem> Items { get; init; }

    public Money Total() => Money.FromCents(Items.Sum(x => x.Price.Cents * x.Quantity));
}
```

These types describe the business. They contain no EF Core or HTTP attributes.

## Application Write Use Case

Place feature-local input, output, problems, and persistence ports under
`Acme.Application/Orders`:

```csharp
// Models/Input/PlaceOrderRequest.cs
public sealed record PlaceOrderRequest(ImmutableArray<PlaceOrderItemRequest> Items);

public sealed record PlaceOrderItemRequest(string ArticleId, uint Quantity);

// Problems/ArticlesMissingProblem.cs
public sealed record ArticlesMissingProblem(ImmutableArray<string> ArticleIds) : Problem;

// Data/IFetchArticlesQuery.cs
public interface IFetchArticlesQuery
{
    Task<ImmutableArray<Article>> FetchAsync(
        IReadOnlyCollection<string> articleIds,
        CancellationToken cancellationToken = default
    );
}

// Data/ISaveOrderCommand.cs
public interface ISaveOrderCommand
{
    Task SaveAsync(Order order, CancellationToken cancellationToken = default);
}

// Transactions/IPlaceOrderTransaction.cs
public interface IPlaceOrderTransaction
{
    Task<Result<OrderId>> ExecuteAsync(
        PlaceOrderRequest request,
        CancellationToken cancellationToken = default
    );
}
```

The default implementation contains the use case and owns the commit through its
base class:

```csharp
// Transactions/Defaults/PlaceOrderTransaction.cs
public sealed class PlaceOrderTransaction(
    IFetchArticlesQuery fetchArticles,
    ISaveOrderCommand saveOrder,
    IUnitOfWork unitOfWork
) : Transaction<PlaceOrderRequest, OrderId>(unitOfWork), IPlaceOrderTransaction
{
    protected override async Task<Result<OrderId>> ExecuteCoreAsync(
        PlaceOrderRequest request,
        CancellationToken cancellationToken
    )
    {
        ArgumentNullException.ThrowIfNull(request);

        var requestedIds = request.Items.Select(x => x.ArticleId).Distinct().ToArray();
        var articles = await fetchArticles.FetchAsync(requestedIds, cancellationToken);

        var foundIds = articles.Select(x => x.Id).ToHashSet(StringComparer.Ordinal);
        ImmutableArray<string> missingIds =
        [
            .. requestedIds.Where(x => !foundIds.Contains(x))
        ];

        if (missingIds.Length > 0)
        {
            return Result<OrderId>.Failure(new ArticlesMissingProblem(missingIds));
        }

        var articleById = articles.ToDictionary(x => x.Id);
        var order = new Order
        {
            Id = OrderId.New(),
            Items =
            [
                .. request.Items.Select(x =>
                {
                    var article = articleById[x.ArticleId];
                    return new OrderItem(article.Id, article.Description, article.Price, x.Quantity);
                })
            ]
        };

        await saveOrder.SaveAsync(order, cancellationToken);

        return Result<OrderId>.Success(order.Id);
    }
}
```

## Application Read Use Case

Return a query-specific Application projection. A Handler adds value by applying
pagination behavior; a single-record endpoint can call its query directly.

```csharp
// Models/Output/OrderListItem.cs
public sealed record OrderListItem(OrderId Id, Money Total, DateTimeOffset CreatedAt);

// Models/Output/OrdersPage.cs
public sealed record OrdersPage(
    ImmutableArray<OrderListItem> Items,
    string? Next,
    bool HasNext
);

// Data/IFetchOrdersPageQuery.cs
public interface IFetchOrdersPageQuery
{
    Task<ImmutableArray<OrderListItem>> FetchAsync(
        int count,
        string? after,
        CancellationToken cancellationToken = default
    );
}

// Handlers/IFetchOrdersPageHandler.cs
public interface IFetchOrdersPageHandler
{
    Task<OrdersPage> ExecuteAsync(
        int pageSize,
        string? after,
        CancellationToken cancellationToken = default
    );
}

// Handlers/Defaults/FetchOrdersPageHandler.cs
public sealed class FetchOrdersPageHandler(
    IFetchOrdersPageQuery query
) : IFetchOrdersPageHandler
{
    public async Task<OrdersPage> ExecuteAsync(
        int pageSize,
        string? after,
        CancellationToken cancellationToken = default
    )
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(pageSize, 1);

        var itemsPlusOne = await query.FetchAsync(pageSize + 1, after, cancellationToken);
        var items = itemsPlusOne.Take(pageSize).ToImmutableArray();

        return new OrdersPage(
            items,
            itemsPlusOne.Length > pageSize ? items[^1].Id.Value.ToString() : null,
            itemsPlusOne.Length > pageSize
        );
    }
}
```

## Database Adapter

EF types stay in `Acme.Database`:

```csharp
// Entities/OrderEntity.cs
public sealed class OrderEntity
{
    public required Guid Id { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
    public required List<OrderItemEntity> Items { get; init; } = [];
}

public sealed class OrderItemEntity
{
    public required Guid Id { get; init; }
    public required Guid OrderId { get; init; }
    public required string ArticleId { get; init; }
    public required string Description { get; init; }
    public required long PriceInCents { get; init; }
    public required uint Quantity { get; init; }
}

// ApplicationDbContext.cs
public sealed class ApplicationDbContext(
    DbContextOptions<ApplicationDbContext> options
) : DbContext(options), IUnitOfWork
{
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);
    }
}
```

Commands map Domain state into tracked persistence state but do not save:

```csharp
// Commands/SaveOrderCommand.cs
public sealed class SaveOrderCommand(
    ApplicationDbContext dbContext,
    OrderEntityMapper mapper
) : ISaveOrderCommand
{
    public Task SaveAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);
        dbContext.Orders.Add(mapper.ToEntity(order));
        return Task.CompletedTask;
    }
}
```

Queries project only required columns and do not expose EF types:

```csharp
// Queries/FetchOrdersPageQuery.cs
public sealed class FetchOrdersPageQuery(
    ApplicationDbContext dbContext
) : IFetchOrdersPageQuery
{
    public async Task<ImmutableArray<OrderListItem>> FetchAsync(
        int count,
        string? after,
        CancellationToken cancellationToken = default
    )
    {
        var afterId = after is null ? (Guid?)null : Guid.Parse(after);

        var rows = await dbContext.Orders
            .AsNoTracking()
            .Where(x => afterId == null || x.Id.CompareTo(afterId.Value) > 0)
            .OrderBy(x => x.Id)
            .Take(count)
            .Select(x => new
            {
                x.Id,
                TotalInCents = x.Items.Sum(i => i.PriceInCents * i.Quantity),
                x.CreatedAt
            })
            .ToArrayAsync(cancellationToken);

        return
        [
            .. rows.Select(x => new OrderListItem(
                new OrderId(x.Id),
                Money.FromCents(x.TotalInCents),
                x.CreatedAt
            ))
        ];
    }
}
```

Use an explicit mapper when loading a Domain object for behavior or persisting a
Domain object. A read projection does not need an intermediate Domain object.

## Minimal API Boundary

Keep HTTP contracts under `Acme.Api/Orders/Models`:

```csharp
public sealed record PlaceOrderDto(ImmutableArray<PlaceOrderItemDto> Items);

public sealed record PlaceOrderItemDto(string ArticleId, uint Quantity);

public sealed record OrderPointerDto(string Id, string Location);

public sealed record OrderListItemDto(string Id, long TotalInCents, DateTimeOffset CreatedAt)
{
    public static OrderListItemDto From(OrderListItem item) =>
        new(item.Id.Value.ToString(), item.Total.Cents, item.CreatedAt);
}

public sealed record OrdersPageDto(
    ImmutableArray<OrderListItemDto> Items,
    string? Next,
    bool HasNext
)
{
    public static OrdersPageDto From(OrdersPage page) =>
        new([.. page.Items.Select(OrderListItemDto.From)], page.Next, page.HasNext);
}
```

Map routes separately from their handlers:

```csharp
// Endpoints.cs
internal static class Endpoints
{
    public static RouteGroupBuilder MapOrders(this WebApplication app)
    {
        var group = app.MapGroup("/orders");

        group.MapGet("/", Handlers.GetOrdersPage)
            .WithName("GetOrdersPage");

        group.MapPost("/", Handlers.PlaceOrder)
            .WithName("PlaceOrder");

        group.MapGet("/{id}", Handlers.GetOrder)
            .WithName("GetOrder");

        return group;
    }
}
```

The API owns binding, DTO mapping, and Problem-to-HTTP mapping:

```csharp
// Handlers.cs
internal static class Handlers
{
    public static async Task<Results<BadRequest, Ok<OrdersPageDto>>> GetOrdersPage(
        IFetchOrdersPageHandler handler,
        [FromQuery] int pageSize = 50,
        [FromQuery] string? after = null,
        CancellationToken cancellationToken = default
    )
    {
        if (pageSize < 1 || (after is not null && !Guid.TryParse(after, out _)))
        {
            return TypedResults.BadRequest();
        }

        var page = await handler.ExecuteAsync(pageSize, after, cancellationToken);
        return TypedResults.Ok(OrdersPageDto.From(page));
    }

    public static async Task<Results<BadRequest, Created<OrderPointerDto>>> PlaceOrder(
        IPlaceOrderTransaction transaction,
        LinkGenerator links,
        [FromBody] PlaceOrderDto dto,
        CancellationToken cancellationToken
    )
    {
        var request = new PlaceOrderRequest(
            [.. dto.Items.Select(x => new PlaceOrderItemRequest(x.ArticleId, x.Quantity))]
        );

        var result = await transaction.ExecuteAsync(request, cancellationToken);

        if (!result.Ok)
        {
            return result.Error switch
            {
                ArticlesMissingProblem => TypedResults.BadRequest(),
                _ => throw new InvalidOperationException("Unmapped application problem")
            };
        }

        var id = result.Value.Value.ToString();
        var location = links.GetPathByName("GetOrder", new { id })
            ?? throw new InvalidOperationException("Failed to generate order location");

        return TypedResults.Created(location, new OrderPointerDto(id, location));
    }
}
```

`GetOrder` may call an `IFetchOrderQuery` port directly when it only maps null
to `404` and the returned projection to a DTO.

## Registration and Composition

Application registers its feature use cases:

```csharp
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddOrders(this IServiceCollection services)
    {
        services.AddScoped<IPlaceOrderTransaction, PlaceOrderTransaction>();
        services.AddScoped<IFetchOrdersPageHandler, FetchOrdersPageHandler>();
        return services;
    }
}
```

Database registers the context and port implementations:

```csharp
public static IServiceCollection AddAcmeDatabase(
    this IServiceCollection services,
    IConfiguration configuration
)
{
    var connectionString = configuration.GetConnectionString("Database")
        ?? throw new InvalidOperationException("Connection string 'Database' is required");

    services.AddDbContext<ApplicationDbContext>(options =>
        options.UseSqlite(connectionString)
    );

    services.AddScoped<IUnitOfWork>(provider =>
        provider.GetRequiredService<ApplicationDbContext>()
    );
    services.AddScoped<IFetchArticlesQuery, FetchArticlesQuery>();
    services.AddScoped<IFetchOrdersPageQuery, FetchOrdersPageQuery>();
    services.AddScoped<ISaveOrderCommand, SaveOrderCommand>();
    services.AddSingleton<OrderEntityMapper>();

    return services;
}
```

The API composes the application:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails();
builder.Services.AddOrders();
builder.Services.AddAcmeDatabase(builder.Configuration);

var app = builder.Build();

app.UseExceptionHandler();
app.MapOrders();

await app.RunAsync();
```

## Representative Tests

Unit-test invariants without the host or database:

```csharp
[Fact]
public void FromCents_RejectsNegativeValues()
{
    Assert.Throws<ArgumentOutOfRangeException>(() => Money.FromCents(-1));
}
```

Integration-test Transactions through the real DI graph and database provider:

```csharp
[Fact]
public async Task PlaceOrder_PersistsOrder()
{
    await testApp.PrepareDatabaseAsync();
    var articleId = await testApp.CreateArticleAsync("Coffee", 250);

    var result = await testApp.RunServiceAsync<IPlaceOrderTransaction, Result<OrderId>>(
        transaction => transaction.ExecuteAsync(
            new PlaceOrderRequest([new PlaceOrderItemRequest(articleId, 2)])
        )
    );

    Assert.True(result.Ok);
    Assert.NotNull(await testApp.FindOrderAsync(result.Value.Value));
}

[Fact]
public async Task PlaceOrder_WithMissingArticle_DoesNotPersistOrder()
{
    await testApp.PrepareDatabaseAsync();

    var result = await testApp.RunServiceAsync<IPlaceOrderTransaction, Result<OrderId>>(
        transaction => transaction.ExecuteAsync(
            new PlaceOrderRequest([new PlaceOrderItemRequest("missing", 1)])
        )
    );

    Assert.IsType<ArticlesMissingProblem>(result.Error);
    Assert.Equal(0, await testApp.CountOrdersAsync());
}
```

Exercise endpoints through `WebApplicationFactory<Program>` and public DTOs:

```csharp
[Fact]
public async Task PostOrder_ReturnsCreatedLocation()
{
    using var client = testApp.CreateClient();

    var response = await client.PostAsJsonAsync(
        "/orders",
        new PlaceOrderDto([new PlaceOrderItemDto(testApp.ArticleId, 2)])
    );

    Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    Assert.NotNull(response.Headers.Location);
}
```

The integration fixture should create isolated configuration and a fresh
database, apply real migrations, expose helpers for resolving services through
DI, and allow external adapters to be replaced with deterministic test
implementations.
