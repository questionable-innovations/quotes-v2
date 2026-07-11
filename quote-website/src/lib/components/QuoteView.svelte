<script lang="ts">
	import { createEventDispatcher, getContext } from 'svelte';
	import { writable } from 'svelte/store';
	import { fuzzy } from 'fast-fuzzy';
	import { goto } from '$app/navigation';
	import type { Book, Quote } from '$lib/api';
	import Typewriter from '$lib/components/Typewriter.svelte';
	import AddQuote from '$lib/components/AddQuote.svelte';
	import AttachmentChip from '$lib/components/AttachmentChip.svelte';
	import ConfirmDeleteQuote from '$lib/components/ConfirmDeleteQuote.svelte';
	import { user } from '$lib/stores';

	// @ts-ignore - provided by svelte-simple-modal
	const { open } = getContext('simple-modal');

	export let book: Book;
	export let quotes: Quote[] = [];

	$: id = book.id;
	$: bookName = book.name || 'Untitled';

	const dispatch = createEventDispatcher();
	let search = writable('');

	function filter(quote: Quote, term: string) {
		if (!term) return true;
		return fuzzy(term, `${quote.person} ${quote.quote}`) > 0.75;
	}

	function canManage(quote: Quote) {
		return book.is_owner || quote.created_by === $user?.id;
	}

	function showConfirmDelete(q: Quote) {
		open(ConfirmDeleteQuote, {
			message: `"${q.quote}" - ${q.person}`,
			bookId: id,
			quoteId: q.id,
			callback: () => dispatch('reloadQuotes')
		});
	}

	$: shownCount = quotes.filter((q) => filter(q, $search)).length;
</script>

<div class="title">
	<h1>{bookName}</h1>
	{#if quotes.length > 0}
		<Typewriter
			options={quotes.map((quote) => `"${quote.quote}" - ${quote.person}`)}
			typingInterval={20}
			delay={3000}
		/>
	{/if}
</div>

<div class="owner">
	{#if book.is_owner}
		<button on:click={() => goto(`/book/${id}/options`)}>Book Settings</button>
	{:else}
		<button>{book.owner.email}</button>
	{/if}
	<button on:click={() => goto('/')}>Go Home</button>
</div>

<AddQuote bookId={id} on:reloadQuotes />

<div class="search">
	<input type="text" placeholder="Search" bind:value={$search} />
</div>

<p id="quote-count">{shownCount} quotes</p>

<div class="quote-container">
	{#each quotes as quote (quote.id)}
		<!-- svelte-ignore a11y-no-noninteractive-tabindex -->
		<div class="quote" class:hidden={!filter(quote, $search)} tabindex="0">
			<div class="quote-text">"{quote.quote}"</div>
			<div class="quote-name">
				{quote.person}, {new Date(quote.date).toLocaleDateString('en-GB')}
			</div>

			{#if quote.attachments.length > 0}
				<div class="attachments">
					{#each quote.attachments as attachment (attachment.id)}
						<AttachmentChip
							{attachment}
							canDelete={canManage(quote)}
							on:deleted={() => dispatch('reloadQuotes')}
						/>
					{/each}
				</div>
			{/if}

			{#if canManage(quote)}
				<img
					src="/bin.png"
					class="delete"
					alt="delete"
					on:click={() => showConfirmDelete(quote)}
					on:keydown={(e) => e.key === 'Enter' && showConfirmDelete(quote)}
				/>
			{/if}
		</div>
	{/each}
	{#if quotes.length === 0}
		<img src="/no-quotes.webp" alt="No Quotes?" class="no-quotes" />
	{/if}
</div>

<style lang="scss">
	#quote-count {
		text-align: center;
		opacity: 0.5;
	}
	.owner {
		text-align: center;
		margin: 1em auto 0 auto;
		button {
			opacity: 0.5;
			background-color: rgba(48, 60, 101, 0.8);
			border-radius: 5px;
			border-color: #252d4d;
			color: #ffffff;
			cursor: pointer;
			transition: all 0.1s ease-in-out;
			&:hover {
				opacity: 1;
				background-color: rgba(48, 60, 101, 1);
				border: 2px solid #cccccc;
				color: #eee;
			}
		}
	}
	.no-quotes {
		margin: auto;
		border-radius: 10px;
		width: 40vw;
	}
	h1 {
		text-align: center;
		margin-top: 0;
		margin-bottom: 0;
	}
	.quote-container {
		display: flex;
		flex-direction: row;
		flex-wrap: wrap;
		margin-top: 50px;

		.quote {
			&:hover {
				transform: scale(1.05);
			}
			&:focus {
				border: 2px solid #cccccc;
				.delete {
					display: block;
				}
			}
			.delete {
				display: none;
				position: absolute;
				right: 4px;
				bottom: 4px;
				height: 1.4em;
				opacity: 50%;
				transition: opacity 250ms ease-in-out;
				&:hover {
					opacity: 100%;
				}
			}
			&.hidden {
				display: none;
			}
			position: relative;
			cursor: pointer;
			opacity: 1;
			transform: scale(1);
			transition: 0.25s;
			margin: 8px;
			padding: 8px;
			border: 2px solid #252d4d;
			background-color: rgba(48, 60, 101, 0.8);
			border-radius: 5px;
			flex-grow: 1;
			box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
				12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
				41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);

			.quote-text {
				color: #ccc;
				text-align: center;
				font-weight: bold;
				font-size: 1.05rem;
			}

			.quote-name {
				color: #7e8ab6;
				font-style: italic;
				text-align: center;
			}

			.attachments {
				display: flex;
				flex-wrap: wrap;
				gap: 6px;
				justify-content: center;
				margin-top: 8px;
			}
		}
	}

	.search {
		display: flex;
		justify-content: center;
		margin-top: 50px;

		input {
			width: 100%;
			padding: 10px;
			margin: 8px;
			border: 2px solid #252d4d;
			border-radius: 5px;
			background-color: rgba(48, 60, 101, 0.8);
			color: #ccc;
			font-size: 1.05rem;
			box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
				12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
				41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);
			transition: all 0.1s ease-in-out;
			&:hover {
				background-color: rgba(48, 60, 101, 1);
				border: 2px solid #cccccc;
				color: #eee;
			}
		}
	}

	@media (max-width: 600px) {
		.title {
			margin-top: 4em;
			margin-bottom: 2em;
		}
	}
</style>
