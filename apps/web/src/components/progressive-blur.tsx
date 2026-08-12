"use client";

import type React from "react";

export interface ProgressiveBlurProps {
  className?: string;
  height?: string;
  position?: "top" | "bottom" | "both";
  blurLevels?: number[];
  children?: React.ReactNode;
}

const defaultBlurLevels = [0.5, 1, 2, 4, 8, 16, 32, 64];

export function ProgressiveBlur({
  className = "",
  height = "100%",
  position = "top",
  blurLevels = defaultBlurLevels,
  children,
}: ProgressiveBlurProps) {
  const lastIndex = blurLevels.length - 1;

  return (
    <div
      aria-hidden="true"
      className={`progressive-blur ${className}`.trim()}
      data-position={position}
      style={{ height: position === "both" ? "100%" : height }}
    >
      {blurLevels.map((blur, index) => {
        const segment = 100 / blurLevels.length;
        const start = Math.max(0, (index - 1) * segment);
        const peakStart = index * segment;
        const peakEnd = Math.min(100, (index + 1) * segment);
        const end = Math.min(100, (index + 2) * segment);
        const direction = position === "bottom" ? "to bottom" : "to top";
        const mask = position === "both"
          ? "linear-gradient(to bottom, transparent 0%, black 8%, black 92%, transparent 100%)"
          : `linear-gradient(${direction}, transparent ${start}%, black ${peakStart}%, black ${peakEnd}%, transparent ${end}%)`;

        return (
          <div
            key={`${blur}-${index}`}
            className="progressive-blur__layer"
            style={{
              zIndex: lastIndex - index + 1,
              backdropFilter: `blur(${blur}px)`,
              WebkitBackdropFilter: `blur(${blur}px)`,
              maskImage: mask,
              WebkitMaskImage: mask,
            }}
          />
        );
      })}
      {children}
    </div>
  );
}
