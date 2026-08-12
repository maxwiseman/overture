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
    <header className="site-header">
      <ProgressiveBlur className="site-header__blur" height="112px" position="top" />
      <div className="site-header__scrim" aria-hidden="true" />
      <div className="site-header__inner">
        <Link className="wordmark" href="/" aria-label="Overture home">
          Overture
        </Link>
        <nav className="primary-nav" aria-label="Primary navigation">
          {links.map(({ to, label }) => (
            <Link key={to} href={to}>
              {label}
            </Link>
          ))}
          <button
            className="search-trigger"
            type="button"
            aria-expanded={searchOpen}
            aria-controls="site-search"
            onClick={() => setSearchOpen((open) => !open)}
          >
            <Search aria-hidden="true" size={20} strokeWidth={1.8} />
            <span>Search</span>
          </button>
        </nav>
        <div className="profile-menu">
          <UserMenu />
        </div>
      </div>
      {searchOpen ? (
        <form id="site-search" className="site-search" action="/" role="search">
          <Search aria-hidden="true" size={20} />
          <label className="sr-only" htmlFor="search-query">Search stories</label>
          <input id="search-query" name="q" type="search" autoFocus placeholder="Search this issue" />
          <button className="search-submit" type="submit">Search</button>
          <button className="search-close" type="button" onClick={() => setSearchOpen(false)} aria-label="Close search">
            <X aria-hidden="true" size={20} />
          </button>
        </form>
      ) : null}
    </header>
  );
}
