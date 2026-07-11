<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { ApiError, requestPasswordReset, resetPassword } from '$lib/api';

	let token: string | null = null;

	// Request-a-reset flow
	let email = '';
	let requested = false;

	// Set-new-password flow
	let password = '';
	let done = false;

	let error: string | null = null;
	let busy = false;

	onMount(() => {
		token = $page.url.searchParams.get('token');
	});

	async function request() {
		busy = true;
		error = null;
		try {
			await requestPasswordReset(email);
			requested = true;
		} catch (ex) {
			error = ex instanceof ApiError ? ex.message : 'Something went wrong';
		} finally {
			busy = false;
		}
	}

	async function submitNew() {
		busy = true;
		error = null;
		try {
			await resetPassword(token as string, password);
			done = true;
		} catch (ex) {
			error = ex instanceof ApiError ? ex.message : 'Something went wrong';
		} finally {
			busy = false;
		}
	}
</script>

<div class="card">
	{#if token}
		<h1>Set a new password</h1>
		{#if done}
			<p>Password updated. You can now log in.</p>
			<a href="/login">Go to login</a>
		{:else}
			<form on:submit|preventDefault={submitNew}>
				<input type="password" placeholder="New password (min 8 chars)" minlength="8" bind:value={password} required />
				{#if error}<p class="error-text">{error}</p>{/if}
				<button type="submit" disabled={busy}>Update password</button>
			</form>
		{/if}
	{:else}
		<h1>Reset your password</h1>
		{#if requested}
			<p>If that email has an account, a reset link is on its way.</p>
			<a href="/login">Back to login</a>
		{:else}
			<form on:submit|preventDefault={request}>
				<input type="email" placeholder="Email" bind:value={email} required />
				{#if error}<p class="error-text">{error}</p>{/if}
				<button type="submit" disabled={busy}>Send reset link</button>
			</form>
		{/if}
	{/if}
</div>

<style lang="scss">
	.card {
		text-align: center;
		max-width: 24em;
		margin: 2em auto;
		form {
			display: flex;
			flex-direction: column;
			gap: 8px;
		}
		input,
		button {
			padding: 8px;
			border: 2px solid #252d4d;
			border-radius: 5px;
			background-color: rgba(48, 60, 101, 0.8);
			color: #fff;
			font-size: 1.1em;
		}
		button {
			cursor: pointer;
			&:hover {
				border-color: #cccccc;
			}
		}
		a {
			color: #7e8ab6;
		}
	}
	.error-text {
		color: #ff8080;
		font-weight: bold;
	}
</style>
