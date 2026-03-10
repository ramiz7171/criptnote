import LoginForm from '../components/Auth/LoginForm'

export default function AuthPage() {
  return (
    <div className="relative h-screen bg-black overflow-hidden flex items-center justify-center px-4">
      <div className="relative z-10 w-full max-w-md">
        <LoginForm />
      </div>
    </div>
  )
}
