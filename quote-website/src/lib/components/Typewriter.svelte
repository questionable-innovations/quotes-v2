<script lang="ts">
	import { onMount } from 'svelte';

	type Interval = ReturnType<typeof setInterval>;

	export let options: string[];
    export let delay = 3000;
    export let typingInterval = 50;

	const delayfn = (ms: number) =>
		new Promise((resolve) => {
			setTimeout(resolve, ms);
		});

	const randomOption = () => options[Math.floor(Math.random() * options.length)];

	let currentString = randomOption();
	let count = 1;

	let shown = '';

	let interval: Interval;

	const addText = async () => {
		if (count <= currentString.length) {
			shown = currentString.slice(0, count);
            count += 1;
		} else {
			clearInterval(interval);
			await delayfn(delay);
			interval = setInterval(removeText, typingInterval);
		}
	};

	const removeText = () => {
		if (shown.length > 0) {
            shown = shown.substring(0, shown.length - 1);
        } else {
			clearInterval(interval);
			setup();
		}
	};

	const setup = async () => {
        currentString = randomOption();
        count = 1;
		// await delayfn(delay);
		interval = setInterval(addText, typingInterval);
	};

	onMount(() => {
		setup();
	});
</script>

<h3>{shown}<span>|</span></h3>

<style lang="scss">
    h3{
        height: 30px;
        font-weight: 300;
        font-style: italic;
        text-align: center;
        margin: 0px;
        font-size: 1.1rem;

        span  {
            height: 100%;
            width: 1px;
            color: inherit;
            animation: blink 1.5s ease-in-out 0s infinite;
            opacity: 0;
            padding-left: 1px;
        }
    }

    @keyframes blink {
        5% {
            opacity: 0;
        }

        25% {
            opacity: 0.5;
        }

        75% {
            opacity: 0.5;
        }

        95% {
            opacity: 0;
        }
    }
</style>