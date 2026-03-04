# BrainBlitz

Web game project using Firebase backend and a React + TypeScript frontend (`frontend/`).

## Current stack

- Frontend: React 19 + TypeScript + Vite
- Backend: Firebase Functions + Firestore + Auth
- Local run: Firebase Emulator Suite

## Quick start (one command)

From project root:

```powershell
.\dev.ps1
```

What it does:

- frees emulator ports (`8080`, `9099`, `5001`) if needed
- installs missing dependencies in `functions/` and `frontend/`
- starts Firebase emulators + Vite dev server in one terminal

Default emulator project id: `demo-si-game`.

## Manual start

1. Install dependencies:

```powershell
npm --prefix functions install
npm --prefix frontend install
```

2. Start emulators + frontend:

```powershell
firebase --config firebase.local.json emulators:exec --project demo-si-game "npm --prefix frontend run dev"
```

## Frontend environment

Local emulator values are already provided in `frontend/.env`.

Template for real Firebase values: `frontend/.env.example`.

## Frontend scripts

```powershell
npm --prefix frontend run dev
npm --prefix frontend run lint
npm --prefix frontend run test
npm --prefix frontend run build
```

## Backend scripts

```powershell
npm --prefix functions test
```

## Firebase files

- `firebase.json` - default project config (includes hosting target)
- `firebase.local.json` - local emulator config used by `dev.ps1`
- `firestore.rules`
- `firestore.indexes.json`

## Migration status

Flutter frontend was fully removed from this repository.
Active frontend is only the React application in `frontend/`.
