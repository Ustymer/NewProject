import { Hub } from 'aws-amplify/utils'
import { useEffect, useState } from 'react'
import { Link, Navigate, useSearchParams } from 'react-router'

import { AuthLayout } from '@/components/auth-layout'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/lib/auth'

function landingPath(): string {
  try {
    const from = sessionStorage.getItem('auth:from')
    sessionStorage.removeItem('auth:from')
    return from?.startsWith('/') ? from : '/home'
  } catch {
    return '/home'
  }
}

/**
 * Where Cognito sends the browser back with ?code=... The Amplify OAuth listener (imported
 * in main.tsx) exchanges the code for tokens; this page waits for that and moves on.
 */
export function AuthCallbackPage() {
  const { user } = useAuth()
  const [params] = useSearchParams()
  const [failure, setFailure] = useState<string | null>(params.get('error_description'))

  useEffect(() => {
    return Hub.listen('auth', ({ payload }) => {
      if (payload.event === 'signInWithRedirect_failure') {
        setFailure(payload.data?.error?.message ?? 'Sign-in failed')
      }
    })
  }, [])

  if (user) return <Navigate to={landingPath()} replace />
  // Opened by hand, without a code from Cognito: start over.
  if (user === null && !failure && !params.has('code')) return <Navigate to="/login" replace />

  return (
    <AuthLayout
      title={failure ? 'Sign-in failed' : 'Signing you in'}
      subtitle={failure ? 'Something went wrong.' : 'One moment...'}
      footer=""
    >
      {failure && (
        <>
          <Alert variant="destructive">
            <AlertDescription>{failure}</AlertDescription>
          </Alert>
          <Button asChild className="w-full">
            <Link to="/login">Try again</Link>
          </Button>
        </>
      )}
    </AuthLayout>
  )
}
