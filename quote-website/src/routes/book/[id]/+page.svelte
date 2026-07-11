<script lang="ts">
	import QuoteView from '$lib/components/QuoteView.svelte';
	import { getBook, listQuotes, type Book, type Quote } from '$lib/api';
	import type { PageData } from './$types';

	export let data: PageData;
	const id = data.id;

	let load = async (): Promise<{ book: Book; quotes: Quote[] }> => {
		const [book, quotes] = await Promise.all([getBook(id), listQuotes(id)]);
		return { book, quotes };
	};

	let promise = load();
</script>

{#await promise}
	<p>Loading</p>
{:then { book, quotes }}
	<QuoteView {book} {quotes} on:reloadQuotes={() => (promise = load())} />
{:catch}
	<p>There was an error loading this book.</p>
	<a href="/">Go home</a>
{/await}
