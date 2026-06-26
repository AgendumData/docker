<h1 align="center">AgendumData</h1>

<p align="center">
  <strong>The headless CRM that boots as a database and talks like an API.</strong><br>
  90% of the entities and business use-cases you were about to re-invent — already shipped.
</p>

<p align="center">
  <em>GraphQL · MCP — batteries included, schema not required.</em>
</p>

---

## `> whoami`

**Agendum Data** is a *headless CRM* — think of it as a business-aware database with an API bolted on
where the `ORM`, the `controllers` and the `schema` usually go. Instead of starting from an empty table,
you start from a domain model that already knows what a **Contact**, a **Company**, a **Deal**, an
**Invoice**, a **Product**, an **Activity** and ~the rest of the CRM universe~ actually are.

You don't design the backend. You `docker compose up` the backend.

## `> features --list`

- 🧠 **Headless by design** — no opinionated UI in the way. Your frontend, your rules.
- 📦 **90% pre-modeled** — the most common business entities and flows ship ready to use.
- 🔌 **Three APIs, one engine** — **GraphQL**, and an **MCP server** by default.
- 🤖 **LLM-native** — the built-in **Model Context Protocol** server lets agents read & write your data.
- 🐬 **Just add MariaDB** — persistence is a container, not a project.
- 🚀 **Zero-to-running** — one `curl`, one `docker compose up`. No build step.

## `> ports`

| Service             | URL                              | What it is                     |
|---------------------|----------------------------------|--------------------------------|
| Agendum Data API    | http://localhost:8800            | GraphQL · MCP endpoint         |
| GraphQL Explorer    | http://localhost:8801            | Interactive GraphQL playground |

---

## `> get-started`

Grab the stack with the classic one-liner — it pulls `docker-compose.yml` straight from the repo:

```bash
curl -O https://raw.githubusercontent.com/AgendumData/docker/main/docker-compose.yml
```

Then light it up:

```bash
docker compose up -d
```

The first time you boot, the container waits for its database schema and parks on a
**"Agendum is starting"** splash. Run the migration **once** to create all the tables:

```bash
docker compose exec agendum migrate
```

When it finishes you'll have:

- the **API** answering on <http://localhost:8800>
- the **GraphQL Explorer** waiting at <http://localhost:8801>
- a **MariaDB** instance keeping it all on disk

> `migrate` is a one-shot, first-run step — the schema persists in the volume, so you
> won't need it again unless you wipe the data. Re-running it is safe (it's a no-op).

Tear it down when you're done:

```bash
docker compose down
```

## `> discover` — read the manual the machine wrote

You don't need to read this README to find out what Agendum Data can do — **the running instance
documents itself**. Point any agent (or your own eyes) at:

```
http://localhost:8800/llms.txt
```

That single file is the LLM-friendly map of the whole instance: every entity, every endpoint,
every use-case the engine ships with. Feed it to your model and it instantly knows your backend.

## `> wire-up-the-mcp` — plug an AI agent straight into your data

Agendum Data exposes a **Model Context Protocol** server out of the box, served on the same
port as the API: **`http://localhost:8800`**. Drop this into your MCP client config
(e.g. Claude Code's `.mcp.json` or Claude Desktop's `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "agendum-data": {
      "type": "http",
      "url": "http://localhost:8800/mcp"
    }
  }
}
```

> Using the Claude Code CLI? One line does it:
>
> ```bash
> claude mcp add --transport http agendum-data http://localhost:8800/mcp
> ```

Now your agent can read and write the CRM directly. Give it a goal in plain language and let it
model the domain for you — for example:

```text
Using the agendum-data MCP server, build me a back-office to sell pet food:
create the catalog of products (dry food, wet food, treats, accessories) with
brand, animal type, weight and price; model customers, their pets, orders and
order lines; then seed a few sample products and place one test order so I can
see the whole flow working end to end.
```

That's the whole point: describe the business, and the 90% that's already modeled does the rest.

## `> use-with-opencode` — drive the CRM from agencode's CLI

[opencode](https://opencode.ai) is an interactive CLI coding agent. This project
ships with an [`opencode.json`](./opencode.json) file so the MCP server is wired up
the moment you open the repo in opencode — no extra configuration needed.

### The `opencode.json` file

The file lives at the repository root and registers the `agendum-data` MCP server:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "agendum-data": {
      "type": "remote",
      "url": "http://localhost:8800/mcp",
      "enabled": true
    }
  }
}
```

opencode auto-loads any `opencode.json` in the workspace, so once the stack is up
(see [`> get-started`](#-get-started)) the two `agendum-data` MCP tools are
available in the session with zero setup:

- **`agendum-data_crm_config_graphql`** — inspect/shape how the CRM behaves
  (modules, metadata, settings, admin operations).
- **`agendum-data_crm_data_graphql`** — read and mutate day-to-day business data
  (records, comments, emails, tags, dashboards, imports, …).

---

<p align="center"><sub>MIT Licensed · © 2026 AgendumData · Made for people who'd rather model deals than tables.</sub></p>