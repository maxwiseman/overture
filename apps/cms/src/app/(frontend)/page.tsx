import config from "@payload-config";

export default async function HomePage() {
	const payloadConfig = await config;

	return (
		<main
			style={{
				fontFamily: "system-ui",
				margin: "4rem auto",
				maxWidth: 720,
				padding: "0 1.5rem",
			}}
		>
			<h1>Overture CMS</h1>
			<p>Manage articles, editions, and media in the Payload admin.</p>
			<a href={payloadConfig.routes.admin}>Open admin</a>
		</main>
	);
}
