import { Link } from 'react-router'

import { AuthLayout } from '@/components/auth-layout'
import { Button } from '@/components/ui/button'

/** Where Cognito's /logout sends the browser back. */
export function SignedOutPage() {
  return (
    <AuthLayout
      title="Signed out"
      subtitle="See you soon."
      footer="You can sign in again at any time."
    >
      <Button asChild className="w-full">
        <Link to="/login">Sign in</Link>
      </Button>
    </AuthLayout>
  )
}
