# Frontend

React + TypeScript client for BrainBlitz.

## Run

```bash
npm install
npm run dev
```

## Quality checks

```bash
npm run lint
npm run test
npm run build
```

## Environment

- `.env` contains local emulator-ready values.
- `.env.example` is a template for real Firebase project values.

Key flags:

- `VITE_USE_FIREBASE_EMULATORS=true` to run against local emulators
- `VITE_FIREBASE_FUNCTIONS_REGION` for callable functions region
- `VITE_FIREBASE_FIRESTORE_DATABASE_ID` for Firestore database id
