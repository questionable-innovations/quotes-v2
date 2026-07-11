<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { listBooks, logout, resendVerification, type Book } from '$lib/api';
	import { user } from '$lib/stores';

	let booksPromise: Promise<Book[]>;
	let resendState: 'idle' | 'sending' | 'sent' = 'idle';

	onMount(() => {
		booksPromise = listBooks();
	});

	async function doLogout() {
		await logout();
		goto('/login');
	}

	async function resend() {
		resendState = 'sending';
		try {
			await resendVerification();
			resendState = 'sent';
		} catch {
			resendState = 'idle';
		}
	}

	function bookName(book: Book) {
		return book.name || 'Untitled';
	}
</script>

<h1>Questionable Quote App</h1>
<div class="logout">
	{$user?.email} - <button on:click={doLogout}>Logout</button>
</div>

{#if $user && !$user.email_verified}
	<div class="verify-banner">
		Please verify your email address.
		{#if resendState === 'sent'}
			<span>Verification email sent.</span>
		{:else}
			<button on:click={resend} disabled={resendState === 'sending'}>Resend email</button>
		{/if}
	</div>
{/if}

{#if !booksPromise}
	<div><h1>Please wait</h1></div>
{:else}
	{#await booksPromise}
		<div><h1>Loading Books</h1></div>
	{:then books}
		{@const owned = books.filter((b) => b.is_owner)}
		{@const shared = books.filter((b) => !b.is_owner)}

		<p class="book-headings">My books</p>
		<div class="books">
			{#each owned as book}
				<div class="book-container">
					<button class="book-btn" on:click={() => goto(`book/${book.id}`)}>
						<span class="book-name">{bookName(book)}</span>
						<span class="book-email">{book.quote_count} quotes</span>
					</button>
				</div>
			{/each}
			<div class="book-container">
				<button class="new-book-btn" on:click={() => goto('create/')}>+ New Book</button>
			</div>
		</div>

		{#if shared.length > 0}
			<p class="book-headings">Shared with me</p>
			<div class="books">
				{#each shared as book}
					<div class="book-container">
						<button class="book-btn" on:click={() => goto(`book/${book.id}`)}>
							<span class="book-name">{bookName(book)}</span>
							<span class="book-email">{book.owner.email}</span>
						</button>
					</div>
				{/each}
			</div>
		{/if}
	{:catch}
		<p class="book-headings">Failed to load books. Is the backend running?</p>
	{/await}
{/if}

<style lang="scss">
	.logout {
		text-align: center;
		margin: 3px auto 0 auto;
		button {
			background-color: rgba(48, 60, 101, 0.8);
			border-radius: 5px;
			border-color: #252d4d;
			color: #ffffff;
			opacity: 0.5;
			cursor: pointer;
			transition: all 0.1s ease-in-out;
			&:hover {
				opacity: 1;
				border: 2px solid #cccccc;
			}
		}
	}
	.verify-banner {
		text-align: center;
		margin: 1em auto;
		padding: 0.6em 1em;
		max-width: 30em;
		border: 2px solid #252d4d;
		border-radius: 5px;
		background-color: rgba(48, 60, 101, 0.8);
		button {
			margin-left: 0.5em;
			background-color: rgba(48, 60, 101, 0.8);
			border: 2px solid #252d4d;
			border-radius: 5px;
			color: #fff;
			cursor: pointer;
			&:hover {
				border: 2px solid #cccccc;
			}
		}
	}
	h1 {
		text-align: center;
		margin-bottom: 0;
	}
	.books {
		display: block;
		flex-direction: column;
		align-items: center;
	}
	.book-btn {
		&:hover {
			scale: 1.05;
			opacity: 1;
			border: 2px solid #cccccc;
		}
		opacity: 1;
		transform: scale(1);
		transition: 0.25s;
		margin: 3px;
		padding: 8px;
		border: 2px solid #252d4d;
		background-color: rgba(48, 60, 101, 0.8);
		border-radius: 5px;
		flex-grow: 1;
		box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
			12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
			41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);

		color: #ccc;
		text-align: center;
		font-weight: bold;
		font-size: 1.05rem;
		cursor: pointer;
		display: flex;
		flex-direction: column;
	}
	.book-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}
	.book-email {
		opacity: 0.5;
		font-size: small;
		text-align: center;
		margin: auto;
	}
	.book-headings {
		text-align: center;
		opacity: 0.4;
		margin: 1.5em auto 0.2em auto;
	}
	.new-book-btn {
		&:hover {
			scale: 1.05;
			opacity: 1;
			border: 2px solid #cccccc;
		}
		backdrop-filter: blur(20px);
		opacity: 0.7;
		transform: scale(1);
		transition: 0.25s;
		font-style: italic;
		margin: 3px;
		padding: 8px;
		border: 2px solid #252d4d;
		background-color: rgba(48, 60, 101, 0);
		border-radius: 5px;
		flex-grow: 1;
		box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
			12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
			41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);

		color: #ccc;
		text-align: center;
		font-weight: bold;
		font-size: 1.05rem;
		cursor: pointer;
		display: flex;
		flex-direction: column;
	}
</style>
