# Data Modeling Reference

## Entity-Relationship Design

### ER Diagram Notation

Use standard notation when designing data models:

- **Entity**: Rectangle with name (e.g., `User`, `Order`, `Product`)
- **Attribute**: Listed inside entity with type and constraints
- **Relationships**: Lines connecting entities with cardinality markers
  - `1:1` - One-to-one (User to Profile)
  - `1:N` - One-to-many (User to Orders)
  - `M:N` - Many-to-many (Order to Products, via OrderItem)

### Designing Entities

Start from the domain model. Each real-world concept becomes an entity:

```
User
  - id: UUID (PK)
  - email: String (UNIQUE, NOT NULL)
  - displayName: String (NOT NULL)
  - passwordHash: String (NOT NULL)
  - role: Enum(user, admin)
  - createdAt: Timestamp (NOT NULL)
  - updatedAt: Timestamp (NOT NULL)

Order
  - id: UUID (PK)
  - userId: UUID (FK -> User.id, NOT NULL)
  - status: Enum(pending, confirmed, shipped, delivered, cancelled)
  - totalAmount: Decimal(10,2) (NOT NULL)
  - shippingAddressId: UUID (FK -> Address.id)
  - createdAt: Timestamp (NOT NULL)
  - updatedAt: Timestamp (NOT NULL)

OrderItem
  - id: UUID (PK)
  - orderId: UUID (FK -> Order.id, NOT NULL)
  - productId: UUID (FK -> Product.id, NOT NULL)
  - quantity: Integer (NOT NULL, CHECK > 0)
  - unitPrice: Decimal(10,2) (NOT NULL)
  - subtotal: Decimal(10,2) (NOT NULL)
```

### Relationship Rules

1. Every M:N relationship becomes a junction/bridge table (e.g., `OrderItem`)
2. Foreign keys always point from child to parent
3. Decide ON DELETE behavior upfront: CASCADE, SET NULL, or RESTRICT
4. Add indexes on all foreign key columns

## Room Entities (Android Local Database)

### Basic Entity

```kotlin
@Entity(
    tableName = "users",
    indices = [
        Index(value = ["email"], unique = true),
        Index(value = ["created_at"])
    ]
)
data class UserEntity(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "email")
    val email: String,

    @ColumnInfo(name = "display_name")
    val displayName: String,

    @ColumnInfo(name = "avatar_url")
    val avatarUrl: String? = null,

    @ColumnInfo(name = "role")
    val role: String = "user",

    @ColumnInfo(name = "created_at")
    val createdAt: Long,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long,

    @ColumnInfo(name = "is_synced", defaultValue = "0")
    val isSynced: Boolean = false
)
```

### Entity with Foreign Key

```kotlin
@Entity(
    tableName = "orders",
    foreignKeys = [
        ForeignKey(
            entity = UserEntity::class,
            parentColumns = ["id"],
            childColumns = ["user_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["user_id"]),
        Index(value = ["status"]),
        Index(value = ["created_at"])
    ]
)
data class OrderEntity(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "user_id")
    val userId: String,

    @ColumnInfo(name = "status")
    val status: String,

    @ColumnInfo(name = "total_amount")
    val totalAmount: Double,

    @ColumnInfo(name = "created_at")
    val createdAt: Long,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long
)
```

### Embedded Objects and Type Converters

```kotlin
data class Address(
    val street: String,
    val city: String,
    val state: String,
    val zipCode: String,
    val country: String
)

@Entity(tableName = "shipping_addresses")
data class ShippingAddressEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "user_id") val userId: String,
    @Embedded(prefix = "addr_") val address: Address,
    @ColumnInfo(name = "is_default") val isDefault: Boolean = false
)

class Converters {
    @TypeConverter
    fun fromStringList(value: List<String>): String =
        Json.encodeToString(value)

    @TypeConverter
    fun toStringList(value: String): List<String> =
        Json.decodeFromString(value)

    @TypeConverter
    fun fromInstant(value: Instant): Long = value.toEpochMilli()

    @TypeConverter
    fun toInstant(value: Long): Instant = Instant.ofEpochMilli(value)
}
```

### DAO Pattern

```kotlin
@Dao
interface OrderDao {
    @Query("SELECT * FROM orders WHERE user_id = :userId ORDER BY created_at DESC")
    fun getOrdersByUser(userId: String): Flow<List<OrderEntity>>

    @Query("SELECT * FROM orders WHERE id = :orderId")
    suspend fun getOrderById(orderId: String): OrderEntity?

    @Query("""
        SELECT o.*, u.display_name as user_name
        FROM orders o
        INNER JOIN users u ON o.user_id = u.id
        WHERE o.status = :status
        ORDER BY o.created_at DESC
    """)
    fun getOrdersWithUserByStatus(status: String): Flow<List<OrderWithUser>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertOrders(orders: List<OrderEntity>)

    @Update
    suspend fun updateOrder(order: OrderEntity)

    @Query("DELETE FROM orders WHERE id = :orderId")
    suspend fun deleteOrder(orderId: String)

    @Transaction
    suspend fun replaceAllForUser(userId: String, orders: List<OrderEntity>) {
        deleteOrdersByUser(userId)
        upsertOrders(orders)
    }

    @Query("DELETE FROM orders WHERE user_id = :userId")
    suspend fun deleteOrdersByUser(userId: String)
}
```

### Room Database Definition

```kotlin
@Database(
    entities = [
        UserEntity::class,
        OrderEntity::class,
        OrderItemEntity::class,
        ProductEntity::class,
        ShippingAddressEntity::class
    ],
    version = 3,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
    abstract fun orderDao(): OrderDao
    abstract fun productDao(): ProductDao
}
```

## PostgreSQL Schema (Backend)

### Table Definitions

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE user_role AS ENUM ('user', 'admin', 'moderator');
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled');

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url  TEXT,
    role        user_role NOT NULL DEFAULT 'user',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    sku         VARCHAR(50) UNIQUE,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status              order_status NOT NULL DEFAULT 'pending',
    total_amount        NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    shipping_address_id UUID REFERENCES shipping_addresses(id) ON DELETE SET NULL,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal    NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    UNIQUE (order_id, product_id)
);

-- Indexes for common query patterns
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_products_sku ON products(sku) WHERE sku IS NOT NULL;
CREATE INDEX idx_products_active ON products(is_active) WHERE is_active = TRUE;

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

## Normalization Guide

### Normal Forms Applied

| Form | Rule | Example Violation | Fix |
|---|---|---|---|
| 1NF | No repeating groups, atomic values | `tags: "a,b,c"` in one column | Separate `tags` table with M:N |
| 2NF | No partial dependencies on composite key | `order_item` has `product_name` | Move `product_name` to `products` |
| 3NF | No transitive dependencies | `order` has `user_email` | Fetch via JOIN on `users` |

### When to Denormalize

Denormalization is acceptable when:
- **Read-heavy paths** need sub-millisecond latency (e.g., product listing with seller name)
- **Aggregations** are expensive (e.g., store `order_count` on user, updated via trigger)
- **Historical accuracy** requires snapshotting (e.g., `unit_price` on `order_items` captures the price at the time of purchase, not the current product price)
- **Offline-first mobile** needs self-contained records (store denormalized display data on the entity)

Always document why a field is denormalized and how it stays in sync.

## Migration Strategy

### Room Migrations (Android)

```kotlin
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE users ADD COLUMN avatar_url TEXT")
    }
}

val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        // Create new table with updated schema
        db.execSQL("""
            CREATE TABLE orders_new (
                id TEXT NOT NULL PRIMARY KEY,
                user_id TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                total_amount REAL NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        """)
        // Copy data
        db.execSQL("""
            INSERT INTO orders_new (id, user_id, status, total_amount, created_at, updated_at)
            SELECT id, user_id, status, total_amount, created_at, updated_at FROM orders
        """)
        // Swap tables
        db.execSQL("DROP TABLE orders")
        db.execSQL("ALTER TABLE orders_new RENAME TO orders")
        db.execSQL("CREATE INDEX idx_orders_user_id ON orders(user_id)")
    }
}

// Database builder
Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
    .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
    .fallbackToDestructiveMigrationOnDowngrade()
    .build()
```

### Backend Migrations (Flyway / Liquibase)

Name migrations sequentially: `V001__create_users_table.sql`, `V002__create_products_table.sql`.

```sql
-- V003__add_user_avatar_and_index.sql
ALTER TABLE users ADD COLUMN avatar_url TEXT;
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
```

### Migration Best Practices

1. **Never drop columns in production** without a deprecation period
2. **Add columns as nullable first**, backfill data, then add NOT NULL if needed
3. **Use `CREATE INDEX CONCURRENTLY`** in PostgreSQL to avoid locking the table
4. **Test migrations** on a copy of production data, not just empty databases
5. **Export Room schemas** (`exportSchema = true`) and commit them to version control for diffing
6. **Destructive migration** is acceptable only for debug builds; production must always have a migration path
7. **Idempotent migrations**: use `IF NOT EXISTS` / `IF EXISTS` guards where possible

## Domain-to-Data Mapping

### Mapper Pattern

```kotlin
// Domain model (clean, no database annotations)
data class Order(
    val id: String,
    val userId: String,
    val status: OrderStatus,
    val items: List<OrderItem>,
    val totalAmount: BigDecimal,
    val createdAt: Instant
)

// Entity <-> Domain mappers
fun OrderEntity.toDomain(items: List<OrderItemEntity>): Order = Order(
    id = id,
    userId = userId,
    status = OrderStatus.valueOf(status),
    items = items.map { it.toDomain() },
    totalAmount = totalAmount.toBigDecimal(),
    createdAt = Instant.ofEpochMilli(createdAt)
)

fun Order.toEntity(): OrderEntity = OrderEntity(
    id = id,
    userId = userId,
    status = status.name,
    totalAmount = totalAmount.toDouble(),
    createdAt = createdAt.toEpochMilli(),
    updatedAt = Instant.now().toEpochMilli()
)
```

Keep domain models free of framework annotations. The data layer owns the mapping.
