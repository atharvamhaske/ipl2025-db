# Chat With Your Database

> Use [BLACKBOX](https://blackbox.ai) CLI to connect to your database and ask questions in plain English. Database tools run read-only queries and keep the connection active during your session for quick follow-ups.

---

**Created by Atharva Mhaske with pair programmer [@blackboxai](https://blackbox.ai)**

---

## Supported Databases

* PostgreSQL
* MySQL
* MongoDB
* Redis

## Setup

Configuring DB credentials following the steps below allows you to securely store the credentials in `DB_CONNECTION_URI` environment variable and it is not directly exposed to the model context.

### Option A (Recommended): Configure Once Per Machine

Run the interactive DB configuration to save your connection URI and reuse it across sessions.

```bash
/db configure
```

The wizard will:

* Ask you to pick a database type
* Prompt for a connection URI (input is hidden)
* Save it as `DB_CONNECTION_URI` and apply it to the current session

> **Tips:**
> * Use a read-only database user
> * If you have multiple databases, mention which one you want to connect to

### Option B: Configure On Request

If you miss configuring prior to the request, the model will automatically invoke the configuration screen during DB analyzing requests.

---

## Step-by-Step Usage

### Step 1: Start a Session

```bash
blackbox
```

### Step 2: Configure Your DB Connection (Optional, but Recommended)

```bash
/db configure
```

If you skip this step, you can configure during the session when the model invokes the configuration workflow automatically.

### Step 3: Ask Questions (Read-Only)

[BLACKBOX](https://blackbox.ai) CLI will connect (if needed), inspect schema, and translate your request into safe read-only queries.

```
> show the top 10 products by total revenue last quarter
```

```
> list users who signed up in the last 30 days
```

```
> summarize orders by status and sort by count
```

### Step 4: Refine and Iterate

You can keep asking follow-up questions without reconnecting.

```
> break that down by country
```

```
> only include customers with more than 5 orders
```

> **Note:** The connection stays active in the current session. Start a new session (or re-run `/db configure`) if you need to switch databases.

---

## Examples by Database

### PostgreSQL

Configure once:

```bash
/db configure
```

Then ask:

```
> find the top 5 customers by lifetime value
```

One-off (no saved config):

```
> find the top 5 customers by lifetime value
```

### MySQL

```bash
/db configure
```

```
> list products with low inventory and their suppliers
```

One-off:

```
> list products with low inventory and their suppliers. connect to mysql using mysql://readonly_user:password@db.example.com:3306/store
```

### MongoDB

If your MongoDB URI includes a database name (path), it can connect directly:

```
> connect to mongodb using mongodb://readonly_user:password@db.example.com:27017/ecommerce and show the collections
```

If you omit the DB name in the URI, include it in your request when asked:

```
> connect to mongodb using mongodb://readonly_user:password@db.example.com:27017 and use the database named ecommerce
```

### Redis

```bash
/db configure
```

```
> list keys that match user:* and show 10 examples
```

```
> connect to redis and get the value of user:123
```

---

## Best Practices

* **Be specific** about the data you want and the time range
* **Ask for a quick schema overview** if you are unsure of table or field names
* **Start broad**, then narrow down with follow-up prompts
* **Use a dedicated read-only database account** for safety

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "DB_CONNECTION_URI is not configured" | Run `/db configure`, then retry your request |
| Connection errors | Verify host, port, username, password, and database name |
| Permission errors | Confirm the account has read access to the tables/collections |
| Unexpected results | Ask to show the exact query that was run, then refine your request |

---

## Setting Up This IPL 2025 Database with [Blackbox](https://blackbox.ai) CLI

### Quick Setup

1. **Ensure PostgreSQL is running** with the `cricketdb` database populated (see main README.md)

2. **Start [Blackbox](https://blackbox.ai) CLI:**
   ```bash
   blackbox
   ```

3. **Configure the database connection:**
   ```bash
   /db configure
   ```
   
   Select PostgreSQL and enter your connection URI:
   ```
   postgresql://username:password@localhost:5432/cricketdb
   ```

4. **Start asking questions!**

### Example Connection URIs

```
# Local PostgreSQL (default port)
postgresql://postgres:password@localhost:5432/cricketdb

# Local PostgreSQL (custom port, like in our setup)
postgresql://atharvamhaske@localhost:5433/cricketdb

# Remote PostgreSQL
postgresql://readonly_user:password@db.example.com:5432/cricketdb
```

---

> **Documentation:** To find navigation and other pages in [Blackbox](https://blackbox.ai) documentation, fetch the llms.txt file at: https://docs.blackbox.ai/llms.txt
