<script lang="ts">
	import { ApiError, login as apiLogin, signup as apiSignup } from '$lib/api';

	let loginEmail = '';
	let loginPassword = '';
	let loginError: string | null = null;

	let signupEmail = '';
	let signupPassword = '';
	let signupError: string | null = null;

	let busy = false;

	function message(ex: unknown): string {
		if (ex instanceof ApiError) return ex.message;
		return 'An unknown error has occurred';
	}

	const login = async () => {
		busy = true;
		loginError = null;
		try {
			await apiLogin(loginEmail, loginPassword);
		} catch (ex) {
			loginError = ex instanceof ApiError && ex.status === 401 ? 'Invalid email or password' : message(ex);
		} finally {
			busy = false;
		}
	};

	const signup = async () => {
		busy = true;
		signupError = null;
		try {
			await apiSignup(signupEmail, signupPassword);
			// signup logs us straight in; a verification email is sent in the background.
		} catch (ex) {
			signupError = message(ex);
		} finally {
			busy = false;
		}
	};
</script>

<h1>The Quote Book</h1>
<div class="flex-row">
	<form class="login" on:submit|preventDefault={login}>
		<h2>Log In</h2>
		<input type="email" placeholder="Email" bind:value={loginEmail} required />
		<input type="password" placeholder="Password" bind:value={loginPassword} required />
		{#if loginError}
			<p class="error-text">{loginError}</p>
		{/if}
		<input class="mouse-pointer" type="submit" value="Login" disabled={busy} />
		<a class="forgot" href="/reset-password">Forgot password?</a>
	</form>
	<form class="login" on:submit|preventDefault={signup}>
		<h2>Sign Up</h2>
		<input type="email" placeholder="Email" bind:value={signupEmail} required />
		<input type="password" placeholder="Password (min 8 chars)" minlength="8" bind:value={signupPassword} required />
		{#if signupError}
			<p class="error-text">{signupError}</p>
		{/if}
		<input class="mouse-pointer" type="submit" value="Sign Up" disabled={busy} />
	</form>
</div>

<style lang="scss">
	.flex-row {
		display: flex;
		flex-direction: row;
		flex-wrap: wrap;
	}

	h1 {
		text-align: center;
		margin-bottom: 2em;
	}

	.login {
		display: flex;
		flex-direction: column;
		margin: 8px;
		padding: 2em;
		border: 2px solid #252d4d;
		background-color: rgba(48, 60, 101, 0.8);
		border-radius: 30px 5px 30px 5px;
		flex-grow: 1;

		h2 {
			text-align: center;
		}

		input {
			margin: 8px 0;
			padding: 8px;
			border: 2px solid #252d4d;
			border-radius: 5px;
			background-color: rgba(48, 60, 101, 0.8);
			color: #fff;
			font-size: 1.2em;
			box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
				12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
				41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);
		}
	}

	.mouse-pointer {
		cursor: pointer;
	}

	.forgot {
		text-align: center;
		color: #7e8ab6;
		font-size: 0.9em;
		margin-top: 8px;
	}

	.error-text {
		text-align: center;
		color: #ff8080;
		font-weight: bold;
	}
</style>
