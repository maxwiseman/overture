"use client";

import { Bookmark } from "lucide-react";
import { useEffect, useState } from "react";

const storageKey = "overture-saved-stories";

export function getSavedStorySlugs() {
  try {
    return JSON.parse(window.localStorage.getItem(storageKey) ?? "[]") as string[];
  } catch {
    return [];
  }
}

export default function SaveStoryButton({ slug, title }: { slug: string; title: string }) {
  const [saved, setSaved] = useState(false);

  useEffect(() => setSaved(getSavedStorySlugs().includes(slug)), [slug]);

  function toggleSaved() {
    const current = getSavedStorySlugs();
    const next = current.includes(slug)
      ? current.filter((savedSlug) => savedSlug !== slug)
      : [...current, slug];
    window.localStorage.setItem(storageKey, JSON.stringify(next));
    setSaved(next.includes(slug));
    window.dispatchEvent(new Event("overture-saved-stories"));
  }

  return (
    <button type="button" aria-label={`${saved ? "Remove" : "Save"} ${title}`} aria-pressed={saved} onClick={toggleSaved}>
      <Bookmark size={18} fill={saved ? "currentColor" : "none"} />
    </button>
  );
}
