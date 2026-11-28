# chat.views — frozen implementation contract (wire-level)

Authoritative design: `docs/design/plugin-chat-views.md`. This file fixes the exact identifiers so bridge, SDK, client and App match byte-for-byte. Do not invent alternate spellings.

## Surface

- Wire surface string: `"chat.views"` (everywhere: manifest key, `contributes` key, `invoke.surface`).
- Dart: `DshGoSurfaces.chatView` const in `packages/dsh_client/lib/src/dsh_go_api.dart`, added to `DshGoSurfaces.all`. `NativeSurface.chatView` in `app/lib/plugins/native/native_model.dart`.
- No new caps query param; anchors are a fixed v1 set validated on the bridge. Old Apps ignore the unknown surface via `unknown-surface` (warn) and render nothing.

## Manifest item (package.json → dshGo.contributes["chat.views"])

Allowed keys exactly: `id`, `anchor`, `title`, `icon`, `hint`.
- `id`: existing `ID` regex, unique across all surfaces.
- `anchor`: one of `message.after`, `message.before`, `turn.after`, `composer.above`, `chat.overlay`. Invalid → issue `invalid-field` error, entry dropped. Required.
- `title`: optional `Text`, ≤ 16 chars (`LIMITS.textChars.chatViewTitle = 16`), resolved by locale. Not required.
- `icon`: optional `IconName`.
- `hint`: optional object, keys `role` (`"user" | "assistant"`) and `tools` (array of ≤ 8 strings, each ≤ 64 chars). Unknown keys → `unknown-field` warn. Invalid → drop just `hint`. Purely advisory; the App uses it to skip fetches, never to decide what to render.
- No `effect`, no `view` file, no static fallback. `ready` = registered via `ctx.dshGo.chatView(id, …)` (or `on(id)` fallback for actions only). `live` = data function registered (same semantics as a panel).

Limits: `LIMITS.perPlugin["chat.views"] = 4`; `SURFACES` gains `"chat.views"`; `ITEM_KEYS["chat.views"]` = the five keys above.

## Host service

`ctx.dshGo.chatView(id, { view, data?, actions? })` — same shape and validation as `ctx.dshGo.panel(id, …)`. Registered in core under kind `views` (internal map name) with `REG_NAMES.views = "chatView"`. `view` must be an object or function; may return `null` → the bridge answers `view: null` with no feed/subscription instead of 409 `no-handler`. `data` / `actions` behave exactly as for panels. `refresh(id, scope)` works unchanged.

## Routes (all existing paths; no new route)

- `GET /dsh-go/v1/views/<pkg>/<id>`: accepts `chat.views` ids in addition to panels; same scope params; response adds `anchor`, `hint`, `title` (may be null), and keeps `view`/`data`/`rev`/`live`/`stats`/`issues`. A `null` view returns 200 with `view: null`, `live: false`, no feed.
- `WS /dsh-go/v1/stream` `sub`: accepts declared `chat.views` ids with a scope; identical patch/sync/stale/end semantics to panels.
- `POST /dsh-go/v1/invoke`: surface `"chat.views"` behaves like `panel` — `action` (1–64 chars) and `value` (≤ `invokeValueBytes`) allowed; handlers come from `actions[action]` first, then `on(id)`. Effects and deferred results unchanged.
- `contributions`: `row.contributes["chat.views"] = [{ id, anchor, title, icon?, hint?, ready, live }]`.

## View format

No changes to the component catalog or budgets. A chat view is a live panel mounted in chat: the App decodes it with the existing `panel` profile (32768 bytes / 120 nodes / 8 depth), which is also what the bridge enforces on `GET /views` and what the SDK checker uses with `--budget panel`. Do not introduce a separate `chatView` profile: taps are only wired for the panel profile in `plugin_view.dart`, so a distinct budget would make `check` and the App disagree.

## Dart client

- `DshGoPlugin.chatViews`: `List<DshGoChatView>`, parsed from `contributes['chat.views']` with fields `id`, `anchor`, `title`, `icon`, `hint` (role/tools), `ready`, `live`. Unknown anchors filtered out client-side too (defense in depth).
- `DshGoSurfaces.chatView` / `.all`.

## Flutter App

- Generic widget `app/lib/ui/plugins/native/chat_view_slot.dart`: `ChatViewSlot({anchor, scope, onAction})`, filters `nativeContributionsProvider` plugins by `nativeSurfaceOnProvider((pkg, NativeSurface.chatView))`, then by anchor and `hint.role` / `hint.tools` (when the slot gives a role or tool names). Renders each matching view through `PluginFrame + PluginView` exactly like the prior `NativeMessageCardSlot`, with `showTitle: false`, `imageResolver` for `asset:`, and `onAction` → `runNativeTap(..., surface: NativeSurface.chatView, ...)`.
- Place one slot per anchor: `message.after` and `message.before` in `assistant_message.dart` (and the user-message widget if present), `turn.after` in the turn footnote area of `chat_list.dart`, `composer.above` above the composer, `chat.overlay` in the chat stack (clipped). Do not replace any existing chat widget; append slots.
- `native_surface.dart`: treat `NativeSurface.chatView` like a panel for GET/stream; add it to the availability switch.
- l10n: one new plugslots surface label key in `app/lib/l10n/parts/plugslots_{zh,en}.arb` (and generated `app_en/zh.arb` via `l10n_merge.py`).

## Tests

- Bridge: `runtime/tests/native-chat-views.test.mjs` — manifest parse/validation, ready/live, view null, invoke actions, stream sub.
- SDK: add cases to existing tests; keep `sync-bridge`, `gen-types`, `sync-messages`, `sync-skill` checks green.
- App: extend `app/test/plugins/native/new_seams_test.dart` with chat.views parsing + slot behavior where feasible.
