import "@overture/env/web";
import { withPayload } from "@payloadcms/next/withPayload";
import type { NextConfig } from "next";
import { withWorkflow } from "workflow/next";

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  typedRoutes: true,
  reactCompiler: true,
};

export default withWorkflow(withPayload(nextConfig));
