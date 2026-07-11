<script lang="ts">
	import { getContext } from 'svelte';
	import { goto } from '$app/navigation';
	import { deleteBook } from '$lib/api';

	export let message = '';
	export let book: string;

	// @ts-ignore - provided by svelte-simple-modal
	const { close } = getContext('simple-modal');

	let busy = false;

	async function del() {
		busy = true;
		try {
			await deleteBook(book);
			close();
			goto('/');
		} catch {
			busy = false;
		}
	}
</script>

<div class="popup">
	<h2>WARNING, THIS CANNOT BE RESTORED</h2>
	<p>{message}</p>
	<div class="popup_buttons">
		<button on:click={del} disabled={busy}>Delete</button>
		<button on:click={close}>Cancel</button>
	</div>
</div>

<style lang="scss">
	.popup {
		display: flex;
		flex-direction: column;
		justify-content: center;
		text-align: center;
		color: #eee;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif,
			'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol';
		h1 {
			font-size: 1.5rem;
			margin-bottom: 0;
		}
	}
	.popup_buttons {
		display: flex;
		justify-content: center;

		button {
			width: 100%;
			padding: 10px;
			margin: 5px;
			border: 2px solid #252d4d;
			border-radius: 5px;
			background-color: rgba(48, 60, 101, 0.8);
			color: #ccc;
			font-size: 1.05rem;
			cursor: pointer;
			transition: all 0.1s ease-in-out;

			&:hover {
				background-color: rgba(48, 60, 101, 1);
				border: 2px solid #cccccc;
				color: #eee;
			}
		}
	}
</style>
