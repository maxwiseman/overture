"use client";

import { Button, useDocumentInfo } from "@payloadcms/ui";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";

export function GenerateArticleVariants() {
	const { id, collectionSlug } = useDocumentInfo();
	const router = useRouter();
	const [isStarting, setIsStarting] = useState(false);

	if (!id || collectionSlug !== "articles") return null;

	async function startGeneration() {
		setIsStarting(true);
		try {
			const response = await fetch(`/api/articles/${id}/generate-variants`, {
				method: "POST",
				credentials: "same-origin",
			});
			const result = (await response.json()) as {
				message?: string;
				runID?: string;
			};
			if (!response.ok)
				throw new Error(result.message ?? "Unable to start generation.");
			toast.success("Variant generation started", {
				description: result.runID ? `Workflow ${result.runID}` : undefined,
			});
			router.refresh();
		} catch (error) {
			toast.error(
				error instanceof Error ? error.message : "Unable to start generation.",
			);
		} finally {
			setIsStarting(false);
		}
	}

	return (
		<div style={{ marginBottom: "1.5rem" }}>
			<Button
				buttonStyle="primary"
				disabled={isStarting}
				onClick={startGeneration}
				type="button"
			>
				{isStarting ? "Starting…" : "Generate or regenerate shorter versions"}
			</Button>
			<p style={{ color: "var(--theme-elevation-500)", marginTop: ".5rem" }}>
				This creates a reviewable draft. It never publishes the article
				automatically.
			</p>
		</div>
	);
}
