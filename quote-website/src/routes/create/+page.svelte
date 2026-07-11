<script lang="ts">
	import { goto } from '$app/navigation';
	import { createBook } from '$lib/api';

	let book_name = '';
	let buttonText = 'Submit';
	let busy = false;

	async function submitBook() {
		if (book_name.trim().length === 0) {
			buttonText = 'Missing Fields!';
			setTimeout(() => (buttonText = 'Submit'), 2000);
			return;
		}
		busy = true;
		try {
			const book = await createBook(book_name.trim());
			buttonText = 'Added!';
			goto(`/book/${book.id}`);
		} catch {
			busy = false;
			buttonText = 'Error, try again';
			setTimeout(() => (buttonText = 'Submit'), 2000);
		}
	}
</script>

<div class="input-box">
	<h1>Create book</h1>
	<input type="text" bind:value={book_name} placeholder="Name" on:keydown={(e) => e.key === 'Enter' && submitBook()} />
	<input type="button" on:click={submitBook} value={buttonText} disabled={busy} />
</div>

<style lang="scss">
	.input-box {
		backdrop-filter: blur(20px);
		display: flex;
		flex-direction: column;
		margin: 8px;
		padding: 2em;
		border: 2px solid #252d4d;
		background-color: rgba(48, 60, 101, 0);
		border-radius: 30px 5px 30px 5px;
		flex-grow: 1;
		box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
			12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
			41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);
		h1 {
			margin: 0 0 8px;
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

			transition: all 0.1s ease-in-out;
			&:hover {
				opacity: 1;
				border: 2px solid #cccccc;
			}
		}
	}
</style>
