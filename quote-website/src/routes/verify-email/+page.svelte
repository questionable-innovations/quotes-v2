<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { auth, me, verifyEmail } from '$lib/api';
	import { loggedIn } from '$lib/stores';

	let status: 'working' | 'done' | 'error' = 'working';

	onMount(async () => {
		const token = $page.url.searchParams.get('token');
		if (!token) {
			status = 'error';
			return;
		}
		try {
			await verifyEmail(token);
			// Refresh the cached user so the "verify your email" banner disappears.
			if ($loggedIn) {
				try {
					const user = await me();
					auth.update((a) => (a ? { ...a, user } : a));
				} catch {
					// ignore: verification still succeeded
				}
			}
			status = 'done';
		} catch {
			status = 'error';
		}
	});
</script>

<div class="card">
	{#if status === 'working'}
		<h1>Verifying…</h1>
	{:else if status === 'done'}
		<h1>Email verified ✓</h1>
		<p>Your email address is confirmed.</p>
		<a href={$loggedIn ? '/' : '/login'}>Continue</a>
	{:else}
		<h1>Verification failed</h1>
		<p>This link is invalid or has expired.</p>
		<a href="/login">Back to login</a>
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
