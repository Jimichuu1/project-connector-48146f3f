# Revert to readable URLs, keep 404 for restricted pages

## Goal

Restore the original readable URL structure (`/dashboard`, `/leads`, `/clients`, `/p/...` removed). Restricted pages keep returning 404 for users without the right role — this is already handled by `RoleProtectedRoute` (it renders `<NotFound />` when the role check fails), so no behavior change there.

## Why this fixes the bug

After the hashed-URL migration, all in-app `navigate("/leads")`, `navigate("/dashboard")`, etc. silently fall through to the `*` NotFound route because only `/p/...` paths are registered. Agents/Super Agents land on `/leads` after login → NotFound. Reverting to readable URLs makes every existing call site valid again with zero per-file edits.

## Changes

### 1. `src/App.tsx` — switch routes back to readable paths

- Remove `import { ROUTE_HASHES } from "@/lib/routeMap"` and the `const H = ROUTE_HASHES` helper.
- Replace each `path={H["/foo"]}` with the readable string, e.g. `path="/dashboard"`, `path="/leads"`, `path="/leads/:id"`, etc.
- Keep `RoleProtectedRoute` wrappers exactly as-is (they already render `<NotFound />` for unauthorized roles → restricted pages 404 for the wrong role).
- Keep `/`, `/access-denied-preview`, and the `*` NotFound catch-all unchanged.

### 2. `src/components/AppSidebar.tsx` — drop `toHashedPath`

- Replace `to={toHashedPath(item.url) ?? item.url}` with `to={item.url}`.
- Remove the now-unused `toHashedPath` import.

### 3. `src/components/auth/ReadableRedirect.tsx` — delete

No longer used. Remove the file (and any remaining import — currently none in `App.tsx`).

### 4. `src/lib/routeMap.ts` — delete

No longer referenced. Remove the file. (A grep confirms only `App.tsx`, `AppSidebar.tsx`, and `ReadableRedirect.tsx` import from it; all are handled above.)

### 5. Optional safety net — keep old `/p/...` bookmarks working

To avoid breaking any browser bookmarks users saved during the hashed era, add a tiny redirect component **before** deleting `routeMap.ts` is final, OR inline a small map in `App.tsx`:

```tsx
// Legacy hashed → readable redirects (so old bookmarks still work)
const LEGACY: Record<string, string> = {
  "/p/h7Qx2": "/dashboard", "/p/k9Lm4": "/live-traffic",
  "/p/v2Nx8": "/settings/live", "/p/b6Tq1": "/settings/app-integration",
  "/p/a3Wc5": "/leads", "/p/m8Yz3": "/clients", "/p/r4Hb9": "/pipeline",
  "/p/n7Df2": "/reports", "/p/s1Kj6": "/salary", "/p/w5Pv0": "/targets",
  "/p/u9Rg7": "/user-management", "/p/c2Ze4": "/convert-queue",
  "/p/t6Ma8": "/attendance", "/p/g0Sn3": "/settings",
  "/p/p4Bx9": "/settings/profile", "/p/x8Cv1": "/security-monitoring",
  "/p/y5Lr2": "/team-management", "/p/z3Qm7": "/tenant-management",
  "/p/d1Wt4": "/notifications", "/p/f7Hn0": "/scripts",
  "/p/q2Jp8": "/favourite-clients",
};
{Object.entries(LEGACY).map(([from, to]) => (
  <Route key={from} path={from} element={<Navigate to={to} replace />} />
))}
{/* detail variants */}
{["/p/a3Wc5", "/p/m8Yz3", "/p/k9Lm4"].map((from) => (
  <Route key={from + "/:id"} path={from + "/:id"} element={<LegacyDetailRedirect from={from} />} />
))}
```

Where `LegacyDetailRedirect` reads `useParams().id` and `Navigate`s to `LEGACY[from] + "/" + id`. This keeps the user reachable even if they saved `/p/c2Ze4` as a tab.

## Files touched

- `src/App.tsx` — edit (route paths + optional legacy redirects)
- `src/components/AppSidebar.tsx` — edit (drop `toHashedPath`)
- `src/components/auth/ReadableRedirect.tsx` — delete
- `src/lib/routeMap.ts` — delete

## Verification

1. Log in as Super Agent → lands on `/leads` and the page loads.
2. Log in as Tenant Owner → lands on `/dashboard`.
3. Super Agent navigates to `/dashboard` directly → sees NotFound (RoleProtectedRoute).
4. Sidebar links all navigate to readable URLs and load correctly.
5. Old bookmark `/p/c2Ze4` → redirects to `/convert-queue` (if optional step 5 is included).

## Out of scope

No DB / RLS / business-logic changes. Frontend routing only.
