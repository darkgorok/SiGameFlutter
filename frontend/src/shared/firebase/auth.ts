import { onAuthStateChanged, signInAnonymously, type User } from 'firebase/auth';

import { auth } from './client';

export async function ensureAnonymousAuth(): Promise<User> {
  if (auth.currentUser) {
    return auth.currentUser;
  }
  const result = await signInAnonymously(auth);
  return result.user;
}

export function watchAuthState(onUser: (user: User | null) => void): () => void {
  return onAuthStateChanged(auth, onUser);
}
