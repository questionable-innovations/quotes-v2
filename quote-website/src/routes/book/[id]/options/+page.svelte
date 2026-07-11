<script lang="ts">
	import { getContext, onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import {
		ApiError,
		addMember,
		createShareLink,
		deleteInvite,
		deleteShareLink,
		getBook,
		listInvites,
		listMembers,
		listShareLinks,
		removeMember,
		renameBook,
		type Invite,
		type Member,
		type ShareLink
	} from '$lib/api';
	import ConfirmDeleteBook from '$lib/components/ConfirmDeleteBook.svelte';
	import type { PageData } from './$types';

	// @ts-ignore - provided by svelte-simple-modal
	const { open } = getContext('simple-modal');

	export let data: PageData;
	const id = data.id;

	let currentBookName = '';
	let newBookName = '';
	let renameLabel = 'Change';

	let addEmail = '';
	let shareMessage = '';

	let members: Member[] = [];
	let invites: Invite[] = [];
	let shareLinks: ShareLink[] = [];

	let loaded = false;
	let loadError = false;

	// Share-link creation options + the freshly-minted URL (only shown once).
	let linkExpiry = '';
	let linkMaxUses: number | null = null;
	let createdLink: ShareLink | null = null;
	let copyLabel = 'Copy';

	onMount(load);

	async function load() {
		try {
			const book = await getBook(id);
			if (!book.is_owner) {
				await goto(`/book/${id}`);
				return;
			}
			currentBookName = book.name || '';
			await refreshSharing();
			loaded = true;
		} catch {
			loadError = true;
		}
	}

	async function refreshSharing() {
		[members, invites, shareLinks] = await Promise.all([
			listMembers(id),
			listInvites(id),
			listShareLinks(id)
		]);
	}

	async function renameBookAction() {
		if (newBookName.trim() === '') {
			renameLabel = 'Book Name Empty';
			setTimeout(() => (renameLabel = 'Change'), 2000);
			return;
		}
		await renameBook(id, newBookName.trim());
		currentBookName = newBookName.trim();
		newBookName = '';
		renameLabel = 'Book Name Changed';
		setTimeout(() => (renameLabel = 'Change'), 2000);
	}

	async function addMemberAction() {
		const email = addEmail.trim();
		if (!email) return;
		try {
			const result = await addMember(id, email);
			shareMessage = result.invited
				? `Invite emailed to ${email}`
				: `${email} now has access`;
			addEmail = '';
			await refreshSharing();
		} catch (ex) {
			shareMessage = ex instanceof ApiError ? ex.message : 'Could not share book';
		}
		setTimeout(() => (shareMessage = ''), 4000);
	}

	async function removeMemberAction(member: Member) {
		await removeMember(id, member.id);
		await refreshSharing();
	}

	async function cancelInvite(invite: Invite) {
		await deleteInvite(id, invite.id);
		await refreshSharing();
	}

	async function createLink() {
		createdLink = await createShareLink(id, {
			expires_at: linkExpiry ? new Date(linkExpiry).toISOString() : null,
			max_uses: linkMaxUses
		});
		linkExpiry = '';
		linkMaxUses = null;
		copyLabel = 'Copy';
		await refreshSharing();
	}

	async function copyLink() {
		if (!createdLink) return;
		await navigator.clipboard.writeText(createdLink.url);
		copyLabel = 'Copied!';
		setTimeout(() => (copyLabel = 'Copy'), 2000);
	}

	async function revokeLink(link: ShareLink) {
		await deleteShareLink(id, link.id);
		await refreshSharing();
	}

	function deleteBookAction() {
		open(ConfirmDeleteBook, {
			message: `Are you sure you want to delete the book "${currentBookName}"?`,
			book: id
		});
	}

	function fmtDate(iso: string) {
		return new Date(iso).toLocaleDateString('en-GB');
	}
</script>

<h1>Book Options</h1>
{#if loadError}
	<p>There was an error</p>
	<a href="/">Go home</a>
{:else if !loaded}
	<h2>Loading...</h2>
{:else}
	<h2>{currentBookName}</h2>
{/if}

<div class="return-container">
	<button class="return-to-book" on:click={() => goto(`/book/${id}`)}>Return to Book</button>
</div>

{#if loaded}
	<div class="options-grid">
		<div class="panel">
			<h3>Book Name</h3>
			<input type="text" placeholder="Book Name" bind:value={newBookName} />
			<button on:click={renameBookAction}>{renameLabel}</button>
		</div>

		<div class="panel">
			<h3>Share by Email</h3>
			<input type="email" placeholder="User Email" bind:value={addEmail} />
			<button on:click={addMemberAction}>Share</button>
			{#if shareMessage}<p class="hint">{shareMessage}</p>{/if}
		</div>

		<div class="panel">
			<h3>Members (click to remove)</h3>
			<div class="chips">
				{#each members as member (member.id)}
					<button class="chip removable" on:click={() => removeMemberAction(member)}>
						{member.email}
					</button>
				{/each}
				{#if members.length === 0}<p class="hint">No members yet</p>{/if}
			</div>
			{#if invites.length > 0}
				<h4>Pending invites</h4>
				<div class="chips">
					{#each invites as invite (invite.id)}
						<button class="chip removable pending" on:click={() => cancelInvite(invite)}>
							{invite.email} (pending)
						</button>
					{/each}
				</div>
			{/if}
		</div>

		<div class="panel">
			<h3>Share Links</h3>
			<div class="link-form">
				<label>Expires <input type="date" bind:value={linkExpiry} /></label>
				<label>Max uses <input type="number" min="1" placeholder="∞" bind:value={linkMaxUses} /></label>
				<button on:click={createLink}>Create link</button>
			</div>
			{#if createdLink}
				<div class="new-link">
					<input type="text" readonly value={createdLink.url} />
					<button on:click={copyLink}>{copyLabel}</button>
				</div>
				<p class="hint">Copy this now — it won't be shown again.</p>
			{/if}
			<div class="chips vertical">
				{#each shareLinks as link (link.id)}
					<div class="link-row" class:revoked={link.revoked}>
						<span>
							{link.uses}{link.max_uses ? `/${link.max_uses}` : ''} uses
							{#if link.expires_at}· expires {fmtDate(link.expires_at)}{/if}
							{#if link.revoked}· revoked{/if}
						</span>
						{#if !link.revoked}
							<button class="chip removable" on:click={() => revokeLink(link)}>Revoke</button>
						{/if}
					</div>
				{/each}
				{#if shareLinks.length === 0}<p class="hint">No share links</p>{/if}
			</div>
		</div>

		<div class="panel delete">
			<h3>Delete Book</h3>
			<button on:click={deleteBookAction}>Delete</button>
		</div>
	</div>
{/if}

<style lang="scss">
	.options-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		grid-column-gap: 20px;
		grid-row-gap: 20px;
		margin: 32px 0 0 0;
		padding: 2em;
		border: 2px solid #252d4d;
		background-color: rgba(48, 60, 101, 0);
		backdrop-filter: blur(20px);
		border-radius: 30px 5px 30px 5px;
		flex-grow: 1;
		box-shadow: 2.8px 2.8px 2.2px rgba(0, 0, 0, 0.059), 6.7px 6.7px 5.3px rgba(0, 0, 0, 0.085),
			12.5px 12.5px 10px rgba(0, 0, 0, 0.105), 22.3px 22.3px 17.9px rgba(0, 0, 0, 0.125),
			41.8px 41.8px 33.4px rgba(0, 0, 0, 0.151), 100px 100px 80px rgba(0, 0, 0, 0.21);
	}

	h1 {
		text-align: center;
		margin-bottom: 0;
	}
	h2 {
		text-align: center;
		font-style: italic;
		font-weight: 300;
		margin: 0;
	}
	h3 {
		margin: 0 0 0.5em 0;
		text-align: center;
	}
	h4 {
		margin: 0.75em 0 0.4em;
		opacity: 0.6;
		text-align: center;
	}
	.hint {
		opacity: 0.6;
		font-size: 0.9em;
		text-align: center;
		margin: 0.4em 0 0;
	}
	.chips {
		display: flex;
		flex-direction: row;
		flex-wrap: wrap;
		gap: 0.5em;
		&.vertical {
			flex-direction: column;
		}
	}
	.chip {
		border: 2px solid #252d4d;
		border-radius: 5px;
		background-color: rgba(48, 60, 101, 0.8);
		color: white;
		padding: 0.4em 0.6em;
		cursor: pointer;
		&.removable:hover {
			text-decoration: line-through;
			border-color: #d24d4d;
		}
		&.pending {
			opacity: 0.7;
			font-style: italic;
		}
	}
	.link-form {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5em;
		align-items: end;
		label {
			display: flex;
			flex-direction: column;
			font-size: 0.85em;
			opacity: 0.8;
		}
		input {
			width: 8em;
		}
	}
	.new-link {
		display: flex;
		gap: 0.5em;
		margin-top: 0.6em;
		input {
			flex-grow: 1;
		}
	}
	.link-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.5em;
		font-size: 0.9em;
		&.revoked {
			opacity: 0.5;
		}
	}

	input {
		width: 100%;
		padding: 0.5em;
		border: 2px solid #252d4d;
		border-radius: 5px;
		background-color: rgba(48, 60, 101, 0.8);
		color: white;
		margin-bottom: 0.5em;
		font-size: 1.1em;
		box-sizing: border-box;
		transition: all 0.1s ease-in-out;
		&:hover {
			background-color: rgba(48, 60, 101, 1);
			border: 2px solid #cccccc;
			color: #eee;
		}
	}
	button:not(.return-to-book):not(.chip) {
		width: 100%;
		padding: 0.5em;
		border: 2px solid #252d4d;
		border-radius: 5px;
		background-color: rgba(48, 60, 101, 0.8);
		color: white;
		cursor: pointer;
		font-size: 1.1em;
		transition: all 0.1s ease-in-out;
		&:hover {
			background-color: rgba(48, 60, 101, 1);
			border: 2px solid #cccccc;
			color: #eee;
		}
	}
	.link-form button,
	.new-link button {
		width: auto;
	}
	.return-to-book {
		text-align: center;
		opacity: 0.5;
		margin: 1em auto 0 auto;
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
	.return-container {
		display: flex;
		justify-content: center;
	}

	@media (max-width: 600px) {
		.options-grid {
			grid-template-columns: repeat(1, 1fr);
		}
	}
</style>
