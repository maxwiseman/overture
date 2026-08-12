"use client";
import { Search, X } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

import { ProgressiveBlur } from "./progressive-blur";
import UserMenu from "./user-menu";

export default function Header() {
  const [searchOpen, setSearchOpen] = useState(false);
  const links = [
    { to: "/", label: "Today" },
    { to: "/dashboard", label: "Saved" },
    { to: "/#next-stories", label: "Stories" },
  ] as const;

  return (
    <header className="isolate sticky top-0 z-50 mb-[-88px] h-[88px] text-white max-[800px]:mb-[-72px] max-[800px]:h-[72px]">
      <ProgressiveBlur className="-z-2" height="112px" position="top" />
      <div className="pointer-events-none absolute inset-x-0 top-0 -z-1 h-[140px] bg-[linear-gradient(to_bottom,rgb(2_5_9_/_0.62),rgb(2_5_9_/_0.2)_58%,transparent)] max-[800px]:h-[118px]" aria-hidden="true" />
      <div className="relative z-1 mx-auto grid h-[88px] max-w-[1440px] grid-cols-[1fr_auto_1fr] items-center px-[42px] max-[800px]:h-[72px] max-[800px]:grid-cols-[1fr_auto] max-[800px]:px-5">
        <Link className="[font-family:Georgia,'Times_New_Roman',serif] text-[clamp(2.25rem,3vw,3.25rem)] tracking-[-0.045em] max-[800px]:text-4xl" href="/" aria-label="Overture home">
          Overture
        </Link>
        <nav className="flex items-center gap-[42px] text-[0.95rem] max-[800px]:hidden [&>a]:text-white [&>a]:opacity-80 [&>a]:transition-opacity [&>a:first-child]:opacity-100 [&>a:hover]:opacity-100" aria-label="Primary navigation">
          {links.map(({ to, label }) => (
            <Link key={to} href={to}>
              {label}
            </Link>
          ))}
          <button
            className="flex cursor-pointer items-center gap-[9px] border-0 bg-transparent text-white opacity-80 transition-opacity hover:opacity-100"
            type="button"
            aria-expanded={searchOpen}
            aria-controls="site-search"
            onClick={() => setSearchOpen((open) => !open)}
          >
            <Search aria-hidden="true" size={20} strokeWidth={1.8} />
            <span>Search</span>
          </button>
        </nav>
        <div className="justify-self-end">
          <UserMenu />
        </div>
      </div>
      {searchOpen ? (
        <form id="site-search" className="absolute inset-x-0 top-[88px] z-2 flex min-h-[74px] items-center gap-4 border-t border-white/12 bg-[rgb(4_10_18_/_0.82)] px-[max(42px,calc((100vw-1440px)/2+42px))] backdrop-blur-[24px] max-[800px]:top-[72px] max-[800px]:px-5" action="/" role="search">
          <Search aria-hidden="true" size={20} />
          <label className="sr-only" htmlFor="search-query">Search stories</label>
          <input className="flex-1 border-0 bg-transparent text-[1.1rem] text-white outline-0" id="search-query" name="q" type="search" autoFocus placeholder="Search this issue" />
          <button className="cursor-pointer rounded-full border-0 bg-[#326fda] px-4 py-2.5 text-white" type="submit">Search</button>
          <button className="cursor-pointer border-0 bg-transparent p-2 text-white" type="button" onClick={() => setSearchOpen(false)} aria-label="Close search">
            <X aria-hidden="true" size={20} />
          </button>
        </form>
      ) : null}
    </header>
  );
}
