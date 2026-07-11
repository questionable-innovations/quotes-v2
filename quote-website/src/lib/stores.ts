import { derived } from 'svelte/store';
import { auth, type User } from '$lib/api';

export const user = derived(auth, ($auth) => $auth?.user ?? null);
export const loggedIn = derived(auth, ($auth) => $auth != null);

export type { User };
