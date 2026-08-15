import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";

import "../../index.css";
import Header from "@/components/header";
import Providers from "@/components/providers";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://maxw.news"),
  title: {
    default: "Overture",
    template: "%s — Overture",
  },
  description: "A daily briefing on the ideas opening tomorrow.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning data-scroll-behavior="smooth" className="scroll-smooth">
      <body className={`${geistSans.variable} ${geistMono.variable} bg-[#f4f2ec] antialiased`}>
        <Providers>
          <div className="min-h-svh">
            <Header />
            {children}
          </div>
        </Providers>
      </body>
    </html>
  );
}
