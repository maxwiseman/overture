import { withPayload } from "@payloadcms/next/withPayload";
import type { NextConfig } from "next";
import { withWorkflow } from "workflow/next";

const nextConfig: NextConfig = {};

export default withWorkflow(withPayload(nextConfig));
