<script lang="ts">
	import { createEventDispatcher, onDestroy, onMount } from 'svelte';
	import { attachmentBlob, deleteAttachment, type Attachment } from '$lib/api';

	export let attachment: Attachment;
	export let canDelete = false;

	const dispatch = createEventDispatcher();

	let objectUrl: string | null = null;
	let isImage = attachment.content_type.startsWith('image/');
	let deleting = false;

	onMount(async () => {
		if (!isImage) return;
		try {
			objectUrl = URL.createObjectURL(await attachmentBlob(attachment.id));
		} catch {
			isImage = false;
		}
	});

	onDestroy(() => {
		if (objectUrl) URL.revokeObjectURL(objectUrl);
	});

	async function download() {
		const url = objectUrl ?? URL.createObjectURL(await attachmentBlob(attachment.id));
		const a = document.createElement('a');
		a.href = url;
		a.download = attachment.filename;
		a.click();
		if (url !== objectUrl) URL.revokeObjectURL(url);
	}

	async function remove() {
		deleting = true;
		try {
			await deleteAttachment(attachment.id);
			dispatch('deleted');
		} catch {
			deleting = false;
		}
	}
</script>

<div class="attachment">
	{#if isImage && objectUrl}
		<button class="thumb" on:click={download} title={attachment.filename}>
			<img src={objectUrl} alt={attachment.filename} />
		</button>
	{:else}
		<button class="file" on:click={download} title={attachment.filename}>📎 {attachment.filename}</button>
	{/if}
	{#if canDelete}
		<button class="remove" on:click={remove} disabled={deleting} title="Remove attachment">×</button>
	{/if}
</div>

<style lang="scss">
	.attachment {
		position: relative;
		display: inline-flex;
	}
	.thumb {
		padding: 0;
		border: 1px solid #252d4d;
		border-radius: 4px;
		background: none;
		cursor: pointer;
		img {
			display: block;
			max-height: 80px;
			max-width: 120px;
			border-radius: 4px;
		}
	}
	.file {
		border: 1px solid #252d4d;
		border-radius: 4px;
		background-color: rgba(48, 60, 101, 0.8);
		color: #ccc;
		padding: 4px 8px;
		cursor: pointer;
		font-size: 0.85rem;
		&:hover {
			border-color: #cccccc;
		}
	}
	.remove {
		position: absolute;
		top: -6px;
		right: -6px;
		width: 18px;
		height: 18px;
		line-height: 1;
		padding: 0;
		border-radius: 50%;
		border: none;
		background: #d24d4d;
		color: #fff;
		cursor: pointer;
		font-size: 0.8rem;
	}
</style>
