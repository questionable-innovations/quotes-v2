<script lang="ts">
	import Login from '$lib/components/Login.svelte';
	import { goto } from '$app/navigation';
	import { loggedIn } from '$lib/stores';

	$: if ($loggedIn) {
		goto('/');
	}
</script>

<Login />
