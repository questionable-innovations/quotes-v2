<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { ApiError, login, signup } from '$lib/api';

	const dispatch = createEventDispatcher();

	let mode: 'login' | 'signup' = 'login';
	let email = '';
	let password = '';
	let error: string | null = null;
	let busy = false;

	async function submit() {
		busy = true;
		error = null;
		try {
			if (mode === 'login') await login(email, password);
			else await signup(email, password);
			dispatch('authed');
		} catch (ex) {
			error = ex instanceof ApiError ? ex.message : 'Something went wrong';
		} finally {
			busy = false;
		}
	}
</script>

<form class="inline-auth" on:submit|preventDefault={submit}>
	<div class="tabs">
		<button type="button" class:active={mode === 'login'} on:click={() => (mode = 'login')}>Log In</button>
		<button type="button" class:active={mode === 'signup'} on:click={() => (mode = 'signup')}>Sign Up</button>
	</div>
	<input type="email" placeholder="Email" bind:value={email} required />
	<input
		type="password"
		placeholder={mode === 'signup' ? 'Password (min 8 chars)' : 'Password'}
		minlength={mode === 'signup' ? 8 : undefined}
		bind:value={password}
		required
	/>
	{#if error}<p class="error-text">{error}</p>{/if}
	<button type="submit" disabled={busy}>{mode === 'login' ? 'Log In' : 'Sign Up'} & Continue</button>
</form>

<style lang="scss">
	.inline-auth {
		display: flex;
		flex-direction: column;
		gap: 8px;
		max-width: 22em;
		margin: 1em auto;
	}
	.tabs {
		display: flex;
		gap: 8px;
		button {
			flex: 1;
			opacity: 0.5;
			&.active {
				opacity: 1;
			}
		}
	}
	input,
	button {
		padding: 8px;
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
	input {
		cursor: text;
	}
	.error-text {
		color: #ff8080;
		text-align: center;
		font-weight: bold;
		margin: 0;
	}
</style>
