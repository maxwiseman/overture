import { revalidateTag } from "next/cache";
import type { CollectionAfterChangeHook, CollectionAfterDeleteHook } from "payload";

type PublishableDocument = {
	_status?: "draft" | "published" | null;
};

async function revalidatePublication(logger: { warn: (message: string) => void }) {
	try {
		revalidateTag("publication", { expire: 0 });
	} catch (error) {
		logger.warn(
			`Publication cache revalidation was unavailable: ${error instanceof Error ? error.message : "Unknown error"}`,
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
