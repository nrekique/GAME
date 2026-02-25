# Dialogue Markdown Authoring

Dialogue files can now be authored as Markdown (`.md`) or JSON (`.json`).
Runtime loads both through `dialogue_resource_path` on `npc`.

## Top-level directives

Use `@key: value` before your first node:

- `@id: unique_dialogue_id`
- `@speaker: Default Speaker Name`
- `@start: intro_node_id`
- `@line_reveal_rate: 90`
- `@show_hints: true`

## Nodes

Each dialogue node starts with:

```md
## node_id
```

Optional inline node settings:

```md
## node_id | speaker=Harker | line_reveal_rate=110 | show_hints=false
```

Node body text is plain lines under the heading.

## Choices

Choice syntax:

```md
- Choice text -> target_node | key=value | key=value
```

Terminal choice:

```md
- Goodbye. -> END
```

## Supported choice keys

- Flow/checks:
  - `next_on_fail`
  - `check_skill`, `check_skill_min`
  - `skill`, `min_skill`
  - `faction`, `min_faction_rep`
  - `hide_if_locked`
- Facts:
  - `require_fact`, `exclude_fact`
  - `set_fact`, `clear_fact`
- Stat/rep changes:
  - `add_skill`, `set_skill`
  - `add_faction_rep`, `set_faction_rep`
- I/O hooks:
  - `io_target`, `io_input`, `io_arg`

List values use comma separation:

```md
| set_fact=quest_started,met_npc
```

Map values use `name:number` pairs:

```md
| add_skill=speech:1,science:2
| add_faction_rep=settlers:1
```

## Example

See: `data/dialogue/npc_default.md`
