# BrainBlitz

BrainBlitz is a web quiz game project with:
- frontend in `frontend/` (React + TypeScript + Vite),
- backend in `functions/` (Firebase Functions),
- Firestore/Auth via Firebase.

Flutter is no longer used in this repository.

## Stack

- Frontend:
  - React 19
  - TypeScript 5
  - Vite 7
  - React Router 7
  - Firebase Web SDK
  - Zustand
- Backend:
  - Firebase Functions (Node.js 22 runtime)
  - Firebase Admin SDK
- Infra:
  - Firestore (rules + indexes in repo)
  - Firebase Auth
  - Firebase Hosting (serves `frontend/dist`)
- Local development:
  - Firebase Emulator Suite

## Repository Layout

```text
.
├── frontend/                  # React app
│   ├── src/
│   ├── .env                   # local emulator-ready values
│   └── .env.example           # template for real Firebase values
├── functions/                 # Firebase Functions source + tests
│   ├── src/
│   ├── tests/
│   └── scripts/
├── firebase.json              # default Firebase config (includes hosting)
├── firebase.local.json        # local emulator-focused Firebase config
├── firestore.rules
├── firestore.indexes.json
└── dev.ps1                    # one-command Windows local startup
```

## Requirements

- Node.js 22+ (functions runtime is pinned to Node 22)
- npm
- Firebase CLI (`firebase`)

## Local Run

### Option A (Windows one-command)

From repository root:

```powershell
.\dev.ps1
```

`dev.ps1` does the following:
- frees emulator ports `8080` (Firestore), `9099` (Auth), `5001` (Functions),
- installs missing dependencies in `functions/` and `frontend/`,
- runs emulators and frontend together.

Default local project id used by script: `demo-si-game`.

### Option B (manual, all platforms)

1. Install dependencies:

```bash
npm --prefix functions install
npm --prefix frontend install
```

2. Start frontend + emulators:

```bash
firebase --config firebase.local.json emulators:exec --project demo-si-game "npm --prefix frontend run dev"
```

Vite will print the local frontend URL (usually `http://localhost:5173`).

## Frontend Commands

```bash
npm --prefix frontend run dev
npm --prefix frontend run lint
npm --prefix frontend run test
npm --prefix frontend run build
npm --prefix frontend run preview
```

## Backend Commands (Functions)

```bash
npm --prefix functions run test:unit
npm --prefix functions run test:emulator
npm --prefix functions run test:emulator:local
npm --prefix functions run serve
npm --prefix functions run deploy
```

Note: `functions` lint script is currently a placeholder (`no lint configured`).

## Environment Configuration

- Local emulator-ready values are committed in `frontend/.env`.
- For real Firebase projects, use `frontend/.env.example` as a template.

Important frontend flags:
- `VITE_USE_FIREBASE_EMULATORS=true` for local emulator mode.
- `VITE_FIREBASE_FUNCTIONS_REGION` for callable function region.
- `VITE_FIREBASE_FIRESTORE_DATABASE_ID` for custom Firestore DB id (if used).

## Firebase Config Notes

- `firebase.json`:
  - functions source: `functions`
  - Firestore rules/indexes: `firestore.rules`, `firestore.indexes.json`
  - hosting target: `finally`
  - hosting public dir: `frontend/dist`
  - SPA rewrite: `** -> /index.html`
- `firebase.local.json`:
  - local emulator host/port mapping
  - used by local startup flow

## Build & Hosting

Production build output is in:

```text
frontend/dist
```

Firebase Hosting is configured to serve this folder.

Typical deploy flow:

```bash
npm --prefix frontend run build
firebase deploy
```

If you use multiple hosting targets/projects, pass explicit `--project` / `--only` flags as needed.

## Current Product Status

- Active client: React web app.
- Active backend: Firebase Functions + Firestore.
- UI includes Apple-inspired dark liquid-glass styling refinements.
