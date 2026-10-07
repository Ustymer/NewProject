import { useEffect, useRef, useState } from 'react'
import { useLocation } from 'react-router'

import { AuthLayout, AuthNotConfigured } from '@/components/auth-layout'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { authConfigured, isSigningOut, startSignIn } from '@/lib/auth'

type LocationState = { from?: string } | null

/**
 * The URL to hand in: opening it sends the browser straight to Cognito's managed login,
 * which offers email + password (with sign-up) and "Continue with Google". The redirect
 * must start here: the library keeps the OAuth state and the PKCE verifier in this browser,
 * and the callback page needs them to accept the code.
 */
export function LoginPage() {
  const from = (useLocation().state as LocationState)?.from
  const [error, setError] = useState<string | null>(null)
  const started = useRef(false)

  const go = () => {
    setError(null)
    // Where to land after the round trip through Cognito (read on /auth/callback).
    try {
      if (from) sessionStorage.setItem('auth:from', from)
    } catch {
      // Storage can be blocked; the user then lands on /home.
    }
    startSignIn().catch((e: unknown) =>
      setError(e instanceof Error ? e.message : 'Could not start sign-in'),
    )
  }

  useEffect(() => {
    // StrictMode runs effects twice in development; one redirect is enough. Signing out
    // sends the browser to Cognito's /logout, which must not be overridden by a new sign-in.
    if (!authConfigured || started.current || isSigningOut()) return
    started.current = true
    go()
    // oxlint-disable-next-line react-hooks/exhaustive-deps -- runs once, on load
  }, [])

  return (
    <AuthLayout
      title="Welcome back"
      subtitle="Taking you to the sign-in page..."
      footer="Email and password, or your Google account."
    >
      {!authConfigured && <AuthNotConfigured />}
      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}
      <Button type="button" className="w-full" disabled={!authConfigured} onClick={go}>
        Sign in
      </Button>
    </AuthLayout>
  )
}
