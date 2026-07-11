<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { ApiError, acceptInvite } from '$lib/api';
	import { loggedIn } from '$lib/stores';
	import InlineAuth from '$lib/components/InlineAuth.svelte';

	let token: string | null = null;
	let state: 'loading' | 'need-auth' | 'accepting' | 'error' = 'loading';
	let error = 'This invite is invalid or has expired.';

	onMount(async () => {
		token = $page.url.searchParams.get('token');
		if (!token) {
			state = 'error';
			return;
		}
		if ($loggedIn) await accept();
		else state = 'need-auth';
	});

	async function accept() {
		state = 'accepting';
		try {
			await acceptInvite(token as string);
			await goto('/');
		} catch (ex) {
			error = ex instanceof ApiError ? ex.message : error;
			state = 'error';
		}
	}
</script>

<div class="card">
	{#if state === 'loading' || state === 'accepting'}
		<h1>Joining book…</h1>
	{:else if state === 'need-auth'}
		<h1>You've been invited</h1>
		<p>Log in or sign up to add this shared book to your account.</p>
		<InlineAuth on:authed={accept} />
	{:else}
		<h1>Invite error</h1>
		<p>{error}</p>
		<a href="/">Go home</a>
	{/if}
</div>

<style lang="scss">
	.card {
		text-align: center;
		max-width: 26em;
		margin: 2em auto;
		a {
			color: #7e8ab6;
		}
	}
</style>
