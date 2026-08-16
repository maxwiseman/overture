"use client";

import { Button } from "@overture/ui/components/button";
import { IconBrandAppleFilled, IconUser } from "@tabler/icons-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@overture/ui/components/dialog";
import { useEffect, useState } from "react";
import { toast } from "sonner";

import { authClient } from "@/lib/auth-client";

export default function AuthDialog() {
  const [isOpen, setIsOpen] = useState(false);
  const [isSigningIn, setIsSigningIn] = useState(false);

  useEffect(() => {
    if (window.location.hash === "#sign-in") setIsOpen(true);
  }, []);

  function setDialogOpen(open: boolean) {
    setIsOpen(open);

    if (!open && window.location.hash === "#sign-in") {
      window.history.replaceState(null, "", `${window.location.pathname}${window.location.search}`);
    }
  }

  async function signInWithApple() {
    setIsSigningIn(true);

    try {
      const result = await authClient.signIn.social({
        provider: "apple",
        callbackURL: `${window.location.pathname}${window.location.search}`,
      });

      if (result.error) {
        toast.error(result.error.message ?? "Apple sign in failed");
        setIsSigningIn(false);
      }
    } catch {
      toast.error("Apple sign in failed");
      setIsSigningIn(false);
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={setDialogOpen}>
      <DialogTrigger
        render={
          <Button
            className="size-11 rounded-full border-white/40 bg-white/4 p-0 text-white hover:bg-white/12 hover:text-white"
            variant="outline"
            aria-label="Sign in"
          />
        }
      >
        <IconUser aria-hidden="true" size={20} stroke={1.8} />
      </DialogTrigger>
      <DialogContent className="max-w-[calc(100%-2.5rem)] gap-0 bg-background px-7 pt-12 pb-7 text-foreground sm:max-w-[390px] sm:px-9 sm:pt-14 sm:pb-9">
        <DialogHeader className="gap-3 text-center">
          <DialogTitle className="[font-family:Georgia,'Times_New_Roman',serif] text-[2.15rem] leading-none font-normal tracking-[-0.045em]">
            Welcome to Overture
          </DialogTitle>
          <DialogDescription className="text-sm leading-6 text-publication-muted">
            Sign in with your Apple Account to continue.
          </DialogDescription>
        </DialogHeader>
        <Button
          className="mt-8 h-12 w-full gap-2.5 rounded-[8px] bg-foreground text-[0.95rem] font-medium text-background hover:bg-foreground/82"
          type="button"
          onClick={signInWithApple}
          disabled={isSigningIn}
        >
          <IconBrandAppleFilled aria-hidden="true" className="size-5" />
          {isSigningIn ? "Connecting…" : "Sign in with Apple"}
        </Button>
      </DialogContent>
    </Dialog>
  );
}
