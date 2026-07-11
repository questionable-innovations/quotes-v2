<script lang="ts">
	import Modal from 'svelte-simple-modal';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { loggedIn } from '$lib/stores';
	import MainFooter from '$lib/components/MainFooter.svelte';

	// Routes reachable without a session (they handle their own auth prompts).
	const PUBLIC_PREFIXES = ['/login', '/verify-email', '/reset-password', '/invite', '/share'];

	function isPublic(pathname: string) {
		return PUBLIC_PREFIXES.some((p) => pathname === p || pathname.startsWith(p + '/'));
	}

	$: if (!$loggedIn && !isPublic($page.url.pathname)) {
		goto('/login', { replaceState: true });
	}
</script>

<svelte:head>
	<title>Quote Book</title>
</svelte:head>

<Modal
	styleWindow={{ background: 'rgba(48, 60, 101, 0.2)', border: '2px solid #252d4d' }}
	styleBg={{ backdropFilter: 'blur(10px)' }}
	closeButton={false}
>
	<div class="main_content">
		<slot />
	</div>
	<div class="background" />

	<MainFooter />
</Modal>

<style global lang="scss">
	body {
		padding: 0;
		margin: 0;
		min-height: 100vh;
		position: relative;
	}

	.background {
		position: fixed;
		z-index: -1;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background-image: url('/background.webp');
		background-attachment: fixed;
		background-repeat: no-repeat;
		background-size: cover;
		filter: blur(0.5em) brightness(0.8) sepia(0.5) hue-rotate(160deg);
		transform: scale(1.2);
	}

	.main_content {
		padding: 5em;
		background: rgba(9, 16, 40, 0);
		color: #eee;
		border-radius: 1em;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif,
			'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol';
	}

	@media (max-width: 600px) {
		.main_content {
			margin: 0;
			padding: 1em;
		}
	}
</style>
