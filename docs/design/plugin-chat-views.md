# Plugin Chat Views: one generic seam for drawing into chat

> 2026-11-28. Status: proposal, not implemented.
> Builds on NA protocol v1 (frozen 2026-10-25) + v1.1 deferred effects + v1.2 capabilities + v1.3 files, and view format v2. No protocol v2 is needed: everything below is additive.
> Problem: a plugin that wants a live card inside a chat reply currently has to add a new surface end-to-end (bridge → SDK → Dart client → App → docs). The earlier `feat/native-message-cards` implementation patched 37 files just to add `message.card`. That cost is paid once per card type, which does not scale.

## 1. Answer in one sentence

Land **one** generic, data-driven `chat.views` surface in the App; after that release, a plugin draws into chat by shipping only `package.json` + a host-half handler + a view tree — no App rebuild, ever again. There is no design in which the App never changes: the App cannot execute plugin code (Flutter AOT, security boundary), so it must be taught once how to render plugin-declared views at chat anchors. The goal is "one App change for all plugins", not "zero App changes for all time".

## 2. Hard boundary: what "draw anything" means here

The App may only draw what its fixed view catalog and whitelist allow:

- the v2 component catalog (42 node types in `sdk/plugin-kit/schema/view.schema.json`), v2 style whitelist, bindings `{ "$": "data.path" }`, and `asset:` / `data:image/...` images;
- declared anchors in chat (a fixed set, see §3.2), within byte/node/depth budgets;
- taps that only produce the existing effect whitelist (never phone control, credentials, approvals, plugin install).

It may **not** run plugin JavaScript, inject Flutter widgets, use HTML/CSS/SVG/arbitrary fonts, animate, replace the composer/top bar/sidebar, or open message-level web islands. Those remain rejected by `docs/design/plugin-ui-v3.md` §9 and `docs/design/plugin-platform.md` §3. So "anything" means *anything expressible in the view language at a declared chat anchor*, not arbitrary native UI.

Tool cards (`presentationMeta["dsh-go/view"]`) already achieve this with zero App changes, but they are static, bound to one tool call, live-free and (in v1) click-free. They stay as the zero-change fallback for simple cards, not the answer for live in-chat UI.

## 3. Design: `chat.views`

### 3.1 Manifest

Add one contribution slot alongside the existing ones. Item fields reuse the protocol's `Id`, `Text`, `IconName` types.

```jsonc
"dshGo": {
  "v": 1,
  "contributes": {
    "chat.views": [
      {
        "id": "pr-card",                 // unique across all surfaces, as today
        "anchor": "message.after",
        "title": { "zh": "PR 状态", "en": "PR status" }, // optional
        "icon": "code",                                   // optional
        "hint": { "role": "assistant", "tools": ["github_pr"] } // optional, App-side coarse filter
      }
    ]
  }
}
```

`hint` is **only an optimization**: it lets the App skip fetching a view for messages that cannot match. It is never authoritative — the plugin's `view(scope, caps)` is. `role` is `user | assistant`; `tools` is a list of tool-call names present in that message. An empty/absent hint means "ask for every message at this anchor", subject to the caps in §6.

Contribution response entry (same `ready`/`live` pattern as panels):

```jsonc
"chat.views": [{ "id": "pr-card", "anchor": "message.after", "hint": {...},
                 "title": "PR status", "icon": "code", "ready": true, "live": true }]
```

Unknown anchor → entry dropped with issue code `invalid-field` (warn). Unknown `hint` keys → ignored with `unknown-field`. More than 4 entries per plugin → keep first 4, `too-many`.

### 3.2 Anchors (v1 set)

| anchor | where | max per plugin | App budget |
|---|---|---|---|
| `message.after` | below the assistant reply text, above its action row | shared 4 | panel profile |
| `message.before` | above the assistant message bubble | shared 4 | panel profile |
| `turn.after` | turn footer area (next to `turn.note`) | shared 4 | panel profile |
| `composer.above` | above the composer (view form of `composer.strip`) | shared 4 | panel profile |
| `chat.overlay` | floating over the chat area, clipped between top bar and composer | shared 4 | panel profile |

All in-chat anchors reuse the App's existing `panel` profile (32768 bytes / 120 nodes / 8 depth), which the bridge already enforces on `GET /views` and the SDK checks with `--budget panel`. No new budget profile: taps are wired only for the panel profile in `plugin_view.dart`, and a separate budget would make the checker and renderer disagree. There is no per-anchor quota or global card counter: the per-plugin limit of 4 is the only cap, and the App draws a slot only where an anchor exists. Older Apps have no slots at all and ignore the unknown surface.

Anchors are a fixed v1 set validated on the bridge; there is no new caps parameter. A newer anchor therefore needs an App release (same reality as any new placement), but an App that does not draw an anchor simply renders no slot there — old Apps ignore the whole surface via `unknown-surface`, so no protocol version bump is needed.

`composer.above` views are stacked above the composer and, like the strip, are hidden while generating.

### 3.3 Host-half API

One new registration method, deliberately shaped like `panel(id, …)` so the bridge can reuse the `Feed` machinery unchanged:

```js
ctx.inject(['dshGo'], (ctx) => {
  ctx.dshGo.chatView('pr-card', {
    // Return a view tree, or null to say "nothing to show for this scope".
    // All matching logic lives here, in plugin code, where it belongs.
    view: (scope, caps) => {
      const pr = lookupPr(scope.messageId);
      return pr ? { v: 2, type: 'stack', children: [/* ... */] } : null;
    },
    // Optional live data, identical to panel data.
    data: (scope, emit, caps) => { emit(fetchPr(scope.callId)); return () => stop(); },
    // Optional in-view taps, identical to panel actions.
    actions: { refresh: (scope, event) => ({ toast: '已刷新', patch: { ... } }) },
  })
})
```

`view` may return a `Promise`; null / `undefined` means "no card" and the bridge answers with `view: null` instead of an error. Taps not handled by `actions` fall back to `ctx.dshGo.on(id)` as panels already do. Dispose semantics, violations, degradation and `refresh(id, scope)` all reuse existing behavior.

### 3.4 Wire (no new routes)

| step | reuse | change |
|---|---|---|
| discovery | `GET /dsh-go/v1/contributions` | new `chat.views` key, `ready`/`live` |
| initial view | `GET /dsh-go/v1/views/<pkg>/<id>` | `view` becomes nullable; new scope values are the existing `sessionId`/`turnId`/`messageId`/`callId` |
| updates | `WS /dsh-go/v1/stream` `sub`/`patch`/`stale` | feed kind `chatView` treated exactly like `panel` |
| taps | `POST /dsh-go/v1/invoke` | add `chat.views` to the `surface` enum; `action`/`value` same as panel |

Adding a nullable `view` and one enum value is a relaxation, not a removal or tightening, so it stays protocol v1. Older bridge → 404 on the view route → App hides the slot; older App → ignores the unknown surface with `unknown-surface` warn, no UI change. `minApp` works unchanged.

### 3.5 App integration — the only App change

1. `packages/dsh_client/lib/src/dsh_go_api.dart`: `DshGoSurfaces.chatView = 'chat.views'`, add to `.all`, parse the new contribution key into `DshGoPlugin.chatViews`.
2. `app/lib/plugins/native/native_model.dart` / `native_state.dart`: add `NativeSurface.chatView` and provider; `native_surface.dart` treats it as a panel for GET/stream purposes.
3. One generic widget, e.g. `app/lib/ui/chat/widgets/chat_view_slot.dart`: given `(anchor, scope)`, filter contributions by anchor + `hint`, call the existing surface controller, and render the returned tree with the existing native view renderer. Loading/offline/failure → render nothing (never disturb chat). Reuse the panel renderer; do not write a second decoder.
4. Place that widget once at each anchor: `message.after` / `message.before` in `assistant_message.dart` (and the user-message widget), `turn.after` in the turn footer, `composer.above` above the composer, `chat.overlay` in the chat stack.
5. Tests: bridge + SDK unit tests, `native_model` parse test, one slot widget test per anchor with goldens, plus a real-device pass — goldens do not prove in-chat layout on arm64.

After this lands, the PR Card plugin becomes a normal plugin change: `message.card` → `chat.views` with `anchor: "message.after"`, `ctx.dshGo.messageCard` → `ctx.dshGo.chatView`. The 37-file branch should not be merged as-is.

## 4. Limits and safety

- Per-plugin 4 entries; per-anchor caps in §3.2; global visible cap 8 cards per chat session, oldest off-screen cards dropped first.
- `hint` is metadata only, validated on the bridge (role `user|assistant`, `tools` ≤ 8 names of ≤ 64 chars) and used by the App to skip fetches; the plugin's `view()` remains authoritative.
- Feed/coalescing limits unchanged: `feeds: 64`, 4 Hz, 32 KiB data / 16 KiB patch.
- View budget for in-chat anchors is the tool-card budget (8 KiB / 40 nodes / 6 depth); add a `chatView` budget to `view.schema.json` `x-dsh-go` and to the checker's `--budget`.
- Effects: same whitelist; `insert` never auto-sends; taps route only to the owning plugin; no capability escalation.
- Privacy: `scope` carries ids only. A plugin that needs message text can already read the conversation on the host, like any web plugin; no new `want` is introduced.
- A plugin returning `null` costs one GET and no feed; a plugin that emits nothing gets no subscription. Slow plugins degrade after 5 violations exactly as today.

## 5. Alternatives considered

| option | why not |
|---|---|
| bespoke surface per card type (`message.card`, then `issue.card`, …) | 37 files per card type; does not scale |
| tool cards only | zero App change, but static, one_call only, no live feed, no taps in v1 |
| message-level web islands | rejected: 80–150 MB JS heap, renderer crash kills all islands, `plugin-ui-v3.md` §9 |
| QuickJS / JS in App | rejected: AOT + security boundary (`native-plugins.md` §2.6) |
| declarative match language inside App | duplicates plugin logic; `view()` returning `null` is simpler and keeps App generic |

## 6. Rollout

One PR in the standard seam order (`plugin-platform.md` §5): bridge `limits.js`/`manifest.js`/`core.js`/`routes.js` → SDK `sync-bridge.mjs`, schemas, types, checker, `sync-skill.mjs` → `dsh_client` → App generic slot → docs (`native-plugins-protocol.md`, `docs/plugins/slots.md` zh/en, `versions.md`). Verify with `node --test runtime/tests/*.test.mjs`, `cd sdk/plugin-kit && npm test`, Dart/Flutter analyze+test, `kit/bin/check.mjs --load --budget chatView`, and a real-device chat check. No merge, tag or release without explicit approval.

## 7. What this does and does not buy

- **After one release:** unlimited plugins can draw live, tappable cards at declared chat anchors with no App rebuild — the answer to the PR Card problem.
- **Before that release:** only tool cards give zero-App-change drawing, with the limitations in §2.
- **Forever impossible:** arbitrary native widgets, arbitrary CSS/HTML/JS, and replacing core chat chrome. Those are deliberate stability and safety boundaries, not missing features.
