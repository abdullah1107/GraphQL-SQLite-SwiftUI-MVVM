# GraphQL Demo — DummyJSON → GraphQL + SQLite → SwiftUI (MVVM)

```
 ┌────────────────────┐   REST    ┌──────────────────────────────┐  GraphQL (POST /)  ┌──────────────────────┐
 │  dummyjson.com     │ ────────▶ │  backend/  (Node + Apollo)   │ ◀────────────────▶ │  ios/  SwiftUI app   │
 │  /auth/login       │           │  • GraphQL schema/resolvers  │                    │  • MVVM              │
 │  /products         │           │  • SQLite DB (better-sqlite3)│                    │  • URLSession GraphQL│
 │  /carts            │           │    users, sessions, products,│                    │    client (no codegen│
 └────────────────────┘           │    reviews, carts, cart_items│                    │    needed)           │
                                  └──────────────────────────────┘                    └──────────────────────┘
```

- **backend/** — GraphQL API. Calls the three DummyJSON URLs, **saves everything into a SQLite database**, and serves queries from that database.
- **ios/** — Swift / SwiftUI app, MVVM, where every network call is a GraphQL operation.

---

## 1. Run the GraphQL server

Requires **Node.js 20+** (`node -v`).

```bash
cd backend
npm install
npm start
```

You should see:

```
🚀 GraphQL API ready at http://0.0.0.0:4000/
🗄️  SQLite database: …/backend/data/graphql-demo.db
✅ Synced 194 products from DummyJSON
✅ Synced 208 carts from DummyJSON
```

Open **http://localhost:4000/** in a browser to get Apollo Sandbox, where you can explore the schema and run queries.

| Command | What it does |
|---|---|
| `npm start` | Start the API (syncs DummyJSON → SQLite on start) |
| `npm run dev` | Same, restarts on file changes |
| `npm run sync` | Only pull products + carts into the DB, then exit |
| `npm run reset-db` | Delete the database file (re-created on next start) |

Defaults work out of the box. To change the port, DB path or `SYNC_ON_START`, copy `backend/.env.example` to `backend/.env` and edit it.

### How data gets into the database

| DummyJSON URL | When it is called | Stored in |
|---|---|---|
| `POST /auth/login` | `login` mutation | `users`, `sessions` |
| `GET /auth/me` | first request with a token the DB doesn't know | `users`, `sessions` |
| `GET /products?limit=0` | server start, `syncProducts`/`syncAll`, or first query on an empty DB | `products`, `reviews` |
| `GET /carts?limit=0` | server start, `syncCarts`/`syncAll`, or first query on an empty DB | `carts`, `cart_items` |

All writes are upserts inside a transaction, so re-syncing updates rows instead of duplicating them.
Carts created from the app (`addToCart`) are stored with `is_local = 1` and ids from 100000 up, so a re-sync never overwrites them.

### Cart rules

- **Add:** adding a product that's already in the cart increases its quantity. You can't go over the product's `stock`.
- **Prices stay current:** every cart read or change copies the latest title, price, discount and thumbnail from the `products` table, then recalculates each line total and the cart totals. A product sync reprices all users' carts.
- **Delete:** `removeFromCart` deletes one product, `updateCartItem(quantity: 0)` does the same, and `clearCart` deletes every item (the empty cart stays).
- Every cart mutation returns the full updated cart, so the app just swaps in the response.

Inspect the DB with any SQLite tool, e.g. `sqlite3 backend/data/graphql-demo.db "select id,title,price from products limit 5;"`.

### Schema at a glance (`backend/src/schema.graphql`)

```graphql
type Query {
  me: User!                                   # 🔒 needs Authorization: Bearer <token>
  products(search, category, limit, skip, sortBy, order): ProductPage!
  product(id: Int!): Product
  categories: [String!]!
  carts(userId, limit, skip): CartPage!
  cart(id: Int!): Cart
  myCarts: [Cart!]!                           # 🔒
  myCart: Cart                                # 🔒 your cart, prices refreshed from products
  syncStatus: [SyncResult!]!
}
type Mutation {
  login(username: String!, password: String!, expiresInMins: Int): AuthPayload!
  logout: Boolean!                            # 🔒
  syncProducts: SyncResult!
  syncCarts: SyncResult!
  syncAll: [SyncResult!]!
  addToCart(productId: Int!, quantity: Int): Cart!         # 🔒
  updateCartItem(productId: Int!, quantity: Int!): Cart!   # 🔒 (0 removes)
  removeFromCart(productId: Int!): Cart!                   # 🔒 delete one item
  clearCart: Cart!                                         # 🔒 delete all items
}
```

### Try it with curl

```bash
# Log in (any user from https://dummyjson.com/users works)
curl -s localhost:4000 -H 'Content-Type: application/json' -d '{
  "query":"mutation { login(username:\"emilys\", password:\"emilyspass\") { accessToken user { id fullName } } }"
}'

# Products from the database
curl -s localhost:4000 -H 'Content-Type: application/json' -d '{
  "query":"{ products(category:\"beauty\", limit:3, sortBy:PRICE, order:DESC) { total items { id title finalPrice } } }"
}'

# Add to cart (paste the accessToken from the login response)
curl -s localhost:4000 -H 'Content-Type: application/json' -H 'Authorization: Bearer <TOKEN>' -d '{
  "query":"mutation { addToCart(productId: 1, quantity: 2) { id totalQuantity discountedTotal items { title quantity } } }"
}'
```

---

## 2. Run the iOS app

Requires **Xcode 16 or newer**, iOS 17+ simulator/device.

1. Keep the server running.
2. Open `ios/GraphQLDemo.xcodeproj`.
3. Pick an iPhone simulator → **Run** (⌘R).
4. Log in with the pre-filled `emilys` / `emilyspass`.

**Real iPhone:** on the login screen, open **Server** and enter your Mac's IP (System Settings → Wi-Fi → Details), e.g. `http://192.168.1.20:4000/`. Phone and Mac must be on the same Wi-Fi. Set your Team under *Signing & Capabilities* first.

> If your Xcode is older than 16, generate the project instead: `brew install xcodegen && cd ios && xcodegen`.

### Screens

| Tab | GraphQL operations used |
|---|---|
| Login | `mutation Login` |
| Products — search, category chips, sort, infinite scroll, pull to refresh | `query Products`, `query Categories` |
| Product detail — gallery, specs, reviews, "Add · $price", "already in cart", confirmation sheet with the updated cart | `query ProductDetail`, `mutation AddToCart` |
| Cart → My cart — item details & prices, quantity stepper, swipe to delete, **Delete all**, tab badge | `query MyCart`, `mutation UpdateCartItem`, `mutation RemoveFromCart`, `mutation ClearCart` |
| Cart → All carts — every cart in the DB, read-only detail | `query Carts`, `query Cart` |
| Profile — user, DB row counts, "Sync now", logout | `query Me`, `query SyncStatus`, `mutation SyncAll`, `mutation Logout` |

### Project structure (MVVM)

```
ios/GraphQLDemo/
├── App/                    GraphQLDemoApp (entry), RootView, AppContainer (dependency injection)
├── Core/
│   ├── Network/            GraphQLClient, GraphQLOperation protocol, NetworkError, ServerSettings
│   ├── Storage/            TokenStore (Keychain)
│   └── Extensions/         Currency / percent formatting
├── GraphQL/                Typed operations: documents + Variables + Response (+ shared fragments)
├── Models/                 User, Product, Cart, Page, SyncResult (Codable)
├── Services/               AuthService, ProductService, CartService, SyncService (protocols + GraphQL impls)
├── ViewModels/             @Observable @MainActor view models (Session, Login, ProductList, ProductDetail,
│                           CartList, CartDetail, Profile) + CartStore (the shared cart) + AppRouter (tabs)
├── Views/                  SwiftUI screens and reusable components
└── Preview/                Mock services + sample data for SwiftUI previews
```

**Flow:** `View` → `ViewModel` (state + intent) → `Service` protocol → `GraphQLClient.execute(Operation)` → server.

### How the GraphQL layer works

Each operation is a small type:

```swift
struct ProductDetailQuery: GraphQLOperation {
    static let operationName = "ProductDetail"
    static let document = """
    query ProductDetail($id: Int!) {
      product(id: $id) { ...ProductCard ...ProductDetail }
    }
    """ + "\n" + GraphQLFragments.productCard + "\n" + GraphQLFragments.productDetail

    struct Variables: Encodable, Sendable { let id: Int }
    struct Response: Decodable, Sendable { let product: Product? }
    let variables: Variables
}

let product = try await client.execute(ProductDetailQuery(id: 1)).product
```

`GraphQLClient` POSTs `{ operationName, query, variables }`, adds `Authorization: Bearer <token>` from the Keychain, reads GraphQL `errors` first (and maps `UNAUTHENTICATED` to an auto-logout), then decodes `data` into `Response`.

**Adding a new call:** add a field to `schema.graphql` + resolver → add an operation struct in `ios/GraphQLDemo/GraphQL/` → expose it in a service → call it from a view model.

**Want Apollo iOS instead?** The `GraphQLClientProtocol` seam lets you swap in an Apollo-backed implementation without touching view models. Point Apollo's codegen at `http://localhost:4000/` for schema introspection.

---

## Notes

- DummyJSON's own `/carts/add` and update endpoints are simulated (they don't persist), so cart edits are stored in this server's SQLite database instead.
- Tokens are DummyJSON JWTs. `logout` revokes the token on this server.
- Errors include stack traces in development; start with `NODE_ENV=production npm start` to hide them.
