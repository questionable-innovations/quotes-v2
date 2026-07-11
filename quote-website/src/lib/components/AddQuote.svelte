<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { createQuote, uploadAttachment } from '$lib/api';

	export let bookId: string;

	const dispatch = createEventDispatcher();

	const today = new Date().toISOString().slice(0, 10);

	let new_quote = '';
	let new_name = '';
	let date = today;
	let files: FileList | null = null;

	let submitButtonState: 'Submit' | 'Missing Fields!' | 'Saving…' | 'Error' = 'Submit';
	let errorTimeout: ReturnType<typeof setTimeout>;

	function flashError(text: 'Missing Fields!' | 'Error') {
		submitButtonState = text;
		clearTimeout(errorTimeout);
		errorTimeout = setTimeout(() => (submitButtonState = 'Submit'), 2000);
	}

	async function submitQuote() {
		if (new_quote.trim() === '' || new_name.trim() === '') {
			flashError('Missing Fields!');
			return;
		}
		submitButtonState = 'Saving…';
		try {
			const created = await createQuote(bookId, {
				quote: new_quote.trim(),
				person: new_name.trim(),
				date
			});
			if (files) {
				for (const file of Array.from(files)) {
					await uploadAttachment(created.id, file);
				}
			}
			new_quote = '';
			new_name = '';
			date = today;
			files = null;
			submitButtonState = 'Submit';
			dispatch('reloadQuotes');
		} catch {
			flashError('Error');
		}
	}
</script>

<div class="input-box">
	<h3>Add Quote</h3>
	<input type="text" bind:value={new_quote} placeholder="Quote" />
	<div class="name-date-box">
		<input type="text" id="name_input" bind:value={new_name} placeholder="Name" />
		<input type="date" max={today} bind:value={date} />
	</div>
	<label class="file-label">
		<span>📎 Attach files{files && files.length ? ` (${files.length})` : ''}</span>
		<input type="file" multiple bind:files />
	</label>
	<button id="submit_button" on:click={submitQuote} disabled={submitButtonState === 'Saving…'}>
		{submitButtonState}
	</button>
</div>

<style lang="scss">
	.name-date-box {
		display: flex;
		flex-direction: row;
		gap: 0 16px;
		width: 100%;
		#name_input {
			flex-grow: 1;
		}
		flex-wrap: wrap;
	}
	.input-box {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		margin: 8px;
		padding: 2em;
		border: 2px solid #252d4d;
		background-color: rgba(48, 60, 101, 0);
		backdrop-filter: blur(20px);
		border-radius: 30px 5px 30px 5px;
		flex-grow: 1;
		box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
			12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
			41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);
		h3 {
			margin: 0 0 8px;
			text-align: center;
		}

		input:not([type='file']),
		button {
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

			align-self: stretch;
			transition: all 0.1s ease-in-out;
			&:hover {
				background-color: rgba(48, 60, 101, 1);
				border: 2px solid #cccccc;
				color: #eee;
			}
		}

		.file-label {
			align-self: stretch;
			margin: 4px 0;
			cursor: pointer;
			color: #ccc;
			font-size: 0.95em;
			input[type='file'] {
				display: none;
			}
			span:hover {
				color: #eee;
			}
		}

		button {
			cursor: pointer;
		}
	}
</style>
