import { get, writable } from 'svelte/store';
import { browser } from '$app/environment';

export const API_BASE =
	(import.meta.env.VITE_API_BASE as string | undefined)?.replace(/\/$/, '') ||
	'https://quote-db.qinnovate.nz';

// ---- Types (mirror the backend DTOs) ---------------------------------------

export interface User {
	id: string;
	email: string;
	email_verified: boolean;
}

export interface Owner {
	id: string;
	email: string;
}

export interface Book {
	id: string;
	name: string | null;
	owner: Owner;
	is_owner: boolean;
	quote_count: number;
}

export interface Attachment {
	id: string;
	filename: string;
	content_type: string;
	size_bytes: number;
	created_at: string;
}

export interface Quote {
	id: string;
	person: string;
	quote: string;
	date: string;
	created_by: string | null;
	created_at: string;
	attachments: Attachment[];
}

export interface Member {
	id: string;
	email: string;
}

export interface Invite {
	id: string;
	email: string;
	expires_at: string;
	created_at: string;
}

export interface ShareLink {
	id: string;
	url: string;
	expires_at: string | null;
	max_uses: number | null;
	uses: number;
	revoked: boolean;
	created_at: string;
}

export interface ShareLinkPreview {
	book_name: string | null;
	owner_email: string;
}

export interface AuthResponse {
	access_token: string;
	refresh_token: string;
	user: User;
}

// ---- Session state (persisted to localStorage) -----------------------------

interface AuthState {
	user: User;
	accessToken: string;
	refreshToken: string;
}

const STORAGE_KEY = 'quoteapp.auth';

function loadSession(): AuthState | null {
	if (!browser) return null;
	try {
		const raw = localStorage.getItem(STORAGE_KEY);
		return raw ? (JSON.parse(raw) as AuthState) : null;
	} catch {
		return null;
	}
}

export const auth = writable<AuthState | null>(loadSession());

auth.subscribe((value) => {
	if (!browser) return;
	if (value) localStorage.setItem(STORAGE_KEY, JSON.stringify(value));
	else localStorage.removeItem(STORAGE_KEY);
});

export function setSession(res: AuthResponse) {
	auth.set({ user: res.user, accessToken: res.access_token, refreshToken: res.refresh_token });
}

export function clearSession() {
	auth.set(null);
}

export function isLoggedIn(): boolean {
	return get(auth) != null;
}

// ---- Fetch layer with token refresh ----------------------------------------

export class ApiError extends Error {
	status: number;
	constructor(status: number, message: string) {
		super(message);
		this.status = status;
		this.name = 'ApiError';
	}
}

function rawFetch(path: string, init: RequestInit, withAuth: boolean): Promise<Response> {
	const headers = new Headers(init.headers);
	if (withAuth) {
		const session = get(auth);
		if (session) headers.set('Authorization', `Bearer ${session.accessToken}`);
	}
	return fetch(`${API_BASE}${path}`, { ...init, headers });
}

// Single-flight refresh so parallel 401s don't each spawn a refresh.
let refreshing: Promise<boolean> | null = null;

function refreshOnce(): Promise<boolean> {
	if (!refreshing) {
		refreshing = (async () => {
			const session = get(auth);
			if (!session) return false;
			const res = await rawFetch(
				'/api/auth/refresh',
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ refresh_token: session.refreshToken })
				},
				false
			);
			if (!res.ok) {
				clearSession();
				return false;
			}
			setSession((await res.json()) as AuthResponse);
			return true;
		})().finally(() => {
			refreshing = null;
		});
	}
	return refreshing;
}

interface RequestOpts {
	method?: string;
	body?: unknown;
	auth?: boolean;
}

async function buildInit(opts: RequestOpts): Promise<RequestInit> {
	const init: RequestInit = { method: opts.method ?? 'GET' };
	if (opts.body instanceof FormData) {
		init.body = opts.body;
	} else if (opts.body !== undefined) {
		init.body = JSON.stringify(opts.body);
		init.headers = { 'Content-Type': 'application/json' };
	}
	return init;
}

async function send(path: string, opts: RequestOpts): Promise<Response> {
	const withAuth = opts.auth !== false;
	const init = await buildInit(opts);
	let res = await rawFetch(path, init, withAuth);
	if (res.status === 401 && withAuth && get(auth)) {
		if (await refreshOnce()) {
			res = await rawFetch(path, init, withAuth);
		}
	}
	if (!res.ok) {
		let message = `Request failed (${res.status})`;
		try {
			const body = await res.json();
			if (body?.error) message = body.error;
		} catch {
			// non-JSON error body; keep the generic message
		}
		if (res.status === 401 && withAuth) clearSession();
		throw new ApiError(res.status, message);
	}
	return res;
}

async function request<T>(path: string, opts: RequestOpts = {}): Promise<T> {
	const res = await send(path, opts);
	if (res.status === 204) return undefined as T;
	const text = await res.text();
	return (text ? JSON.parse(text) : undefined) as T;
}

// ---- Auth -------------------------------------------------------------------

export async function signup(email: string, password: string, invite_token?: string) {
	const res = await request<AuthResponse>('/api/auth/signup', {
		method: 'POST',
		auth: false,
		body: { email, password, invite_token }
	});
	setSession(res);
	return res;
}

export async function login(email: string, password: string) {
	const res = await request<AuthResponse>('/api/auth/login', {
		method: 'POST',
		auth: false,
		body: { email, password }
	});
	setSession(res);
	return res;
}

export async function logout() {
	const session = get(auth);
	try {
		if (session) {
			await request('/api/auth/logout', {
				method: 'POST',
				auth: false,
				body: { refresh_token: session.refreshToken }
			});
		}
	} finally {
		clearSession();
	}
}

export function me() {
	return request<User>('/api/auth/me');
}

export function verifyEmail(token: string) {
	return request('/api/auth/verify-email', { method: 'POST', auth: false, body: { token } });
}

export function resendVerification() {
	return request('/api/auth/resend-verification', { method: 'POST' });
}

export function requestPasswordReset(email: string) {
	return request('/api/auth/request-password-reset', {
		method: 'POST',
		auth: false,
		body: { email }
	});
}

export function resetPassword(token: string, password: string) {
	return request('/api/auth/reset-password', {
		method: 'POST',
		auth: false,
		body: { token, password }
	});
}

// ---- Books ------------------------------------------------------------------

export function listBooks() {
	return request<Book[]>('/api/books');
}

export function createBook(name: string) {
	return request<Book>('/api/books', { method: 'POST', body: { name } });
}

export function getBook(id: string) {
	return request<Book>(`/api/books/${id}`);
}

export function renameBook(id: string, name: string) {
	return request<Book>(`/api/books/${id}`, { method: 'PATCH', body: { name } });
}

export function deleteBook(id: string) {
	return request(`/api/books/${id}`, { method: 'DELETE' });
}

// ---- Members ----------------------------------------------------------------

export function listMembers(bookId: string) {
	return request<Member[]>(`/api/books/${bookId}/members`);
}

export interface AddMemberResult {
	added: boolean;
	invited: boolean;
	invite?: Invite;
}

export function addMember(bookId: string, email: string) {
	return request<AddMemberResult>(`/api/books/${bookId}/members`, {
		method: 'POST',
		body: { email }
	});
}

export function removeMember(bookId: string, userId: string) {
	return request(`/api/books/${bookId}/members/${userId}`, { method: 'DELETE' });
}

// ---- Invites ----------------------------------------------------------------

export function listInvites(bookId: string) {
	return request<Invite[]>(`/api/books/${bookId}/invites`);
}

export function deleteInvite(bookId: string, inviteId: string) {
	return request(`/api/books/${bookId}/invites/${inviteId}`, { method: 'DELETE' });
}

export function acceptInvite(token: string) {
	return request(`/api/invites/${token}/accept`, { method: 'POST' });
}

// ---- Share links ------------------------------------------------------------

export function listShareLinks(bookId: string) {
	return request<ShareLink[]>(`/api/books/${bookId}/share-links`);
}

export function createShareLink(
	bookId: string,
	options: { expires_at?: string | null; max_uses?: number | null } = {}
) {
	return request<ShareLink>(`/api/books/${bookId}/share-links`, {
		method: 'POST',
		body: { expires_at: options.expires_at ?? null, max_uses: options.max_uses ?? null }
	});
}

export function deleteShareLink(bookId: string, linkId: string) {
	return request(`/api/books/${bookId}/share-links/${linkId}`, { method: 'DELETE' });
}

export function previewShareLink(token: string) {
	return request<ShareLinkPreview>(`/api/share-links/${token}`, { auth: false });
}

export function acceptShareLink(token: string) {
	return request(`/api/share-links/${token}/accept`, { method: 'POST' });
}

// ---- Quotes -----------------------------------------------------------------

export function listQuotes(bookId: string) {
	return request<Quote[]>(`/api/books/${bookId}/quotes`);
}

export function createQuote(bookId: string, quote: { person: string; quote: string; date: string }) {
	return request<Quote>(`/api/books/${bookId}/quotes`, { method: 'POST', body: quote });
}

export function deleteQuote(bookId: string, quoteId: string) {
	return request(`/api/books/${bookId}/quotes/${quoteId}`, { method: 'DELETE' });
}

// ---- Attachments ------------------------------------------------------------

export function uploadAttachment(quoteId: string, file: File) {
	const form = new FormData();
	form.append('file', file);
	return request<Attachment>(`/api/quotes/${quoteId}/attachments`, { method: 'POST', body: form });
}

export function deleteAttachment(id: string) {
	return request(`/api/attachments/${id}`, { method: 'DELETE' });
}

export async function attachmentBlob(id: string): Promise<Blob> {
	const res = await send(`/api/attachments/${id}`, {});
	return res.blob();
}
