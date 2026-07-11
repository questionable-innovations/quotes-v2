<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { ApiError, acceptShareLink, previewShareLink, type ShareLinkPreview } from '$lib/api';
	import { loggedIn } from '$lib/stores';
	import InlineAuth from '$lib/components/InlineAuth.svelte';

	let token: string | null = null;
	let preview: ShareLinkPreview | null = null;
	let state: 'loading' | 'ready' | 'accepting' | 'error' = 'loading';
	let error = 'This share link is invalid or has expired.';

	onMount(async () => {
		token = $page.url.searchParams.get('token');
		if (!token) {
			state = 'error';
			return;
		}
		try {
			preview = await previewShareLink(token);
			state = 'ready';
		} catch (ex) {
			error = ex instanceof ApiError ? ex.message : error;
			state = 'error';
		}
	});

	async function accept() {
		state = 'accepting';
		try {
			await acceptShareLink(token as string);
			await goto('/');
		} catch (ex) {
			error = ex instanceof ApiError ? ex.message : error;
			state = 'error';
		}
	}
</script>

<div class="card">
	{#if state === 'loading'}
		<h1>Loading…</h1>
	{:else if state === 'error'}
		<h1>Link error</h1>
		<p>{error}</p>
		<a href="/">Go home</a>
	{:else}
		<h1>{preview?.book_name || 'Untitled'}</h1>
		<p class="owner">Shared by {preview?.owner_email}</p>
		{#if $loggedIn}
			<button on:click={accept} disabled={state === 'accepting'}>Add to my books</button>
		{:else}
			<p>Log in or sign up to add this book to your account.</p>
			<InlineAuth on:authed={accept} />
		{/if}
	{/if}
</div>

<style lang="scss">
	.card {
		text-align: center;
		max-width: 26em;
		margin: 2em auto;
		.owner {
			opacity: 0.6;
		}
		button {
			padding: 10px 18px;
			border: 2px solid #252d4d;
			border-radius: 5px;
			background-color: rgba(48, 60, 101, 0.8);
			color: #fff;
			font-size: 1.1em;
			cursor: pointer;
			&:hover {
				border-color: #cccccc;
			}
		}
		a {
			color: #7e8ab6;
		}
	}
</style>
