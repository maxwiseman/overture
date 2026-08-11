import type { ReactNode } from "react";

export const metadata = {
	description: "Overture editorial CMS",
	title: "Overture CMS",
};

export default function FrontendLayout({ children }: { children: ReactNode }) {
	return (
		<html lang="en">
			<body>{children}</body>
		</html>
	);
}
