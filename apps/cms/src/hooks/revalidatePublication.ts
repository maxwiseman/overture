import type { CollectionAfterChangeHook, CollectionAfterDeleteHook } from "payload";

type PublishableDocument = {
	_status?: "draft" | "published" | null;
};

async function revalidatePublication(logger: { warn: (message: string) => void }) {
	const webURL = process.env.OVERTURE_WEB_URL;
	const secret = process.env.PUBLICATION_REVALIDATE_SECRET;

	if (!webURL || !secret) return;

	try {
		const response = await fetch(new URL("/api/publication/revalidate", webURL), {
			method: "POST",
			headers: {
				Authorization: `Bearer ${secret}`,
			},
			signal: AbortSignal.timeout(5_000),
		});

		if (!response.ok) {
			logger.warn(`Publication cache revalidation returned ${response.status}.`);
		}
	} catch (error) {
		logger.warn(
			`Publication cache revalidation failed: ${error instanceof Error ? error.message : "Unknown error"}`,
		);
	}
}

export const revalidatePublicationAfterChange: CollectionAfterChangeHook = async ({
	doc,
	previousDoc,
	req,
}) => {
	if (req.context.disableRevalidate) return doc;

	const currentStatus = (doc as PublishableDocument)._status;
	const previousStatus = (previousDoc as PublishableDocument | undefined)?._status;

	if (currentStatus === "published" || previousStatus === "published") {
		await revalidatePublication(req.payload.logger);
	}

	return doc;
};

export const revalidatePublicationAfterDelete: CollectionAfterDeleteHook = async ({ doc, req }) => {
	if (req.context.disableRevalidate) return doc;

	if ((doc as PublishableDocument)._status === "published") {
		await revalidatePublication(req.payload.logger);
	}

	return doc;
};
