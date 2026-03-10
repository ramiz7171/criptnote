import { useNavigate } from 'react-router-dom'
import SpotlightCard from '../components/Welcome/SpotlightCard'

export default function WelcomePage() {
  const navigate = useNavigate()

  return (
    <div className="relative h-screen bg-black text-white overflow-hidden flex flex-col">
      {/* Hero section */}
      <div className="relative z-10 flex flex-col items-center justify-center px-6 text-center pt-[12vh] pb-6">
        <div className="mb-4 overflow-visible pb-2">
          <h1 className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight text-white animate-[fadeInUp_0.8s_ease-out_both]">
            Welcome to Criptnote
          </h1>
        </div>

        <div className="mb-6 animate-[fadeInUp_0.8s_ease-out_0.3s_both]">
          <p className="text-xl sm:text-2xl md:text-3xl text-gray-400 font-light">
            You script, we encrypt.
          </p>
        </div>

        <button
          onClick={() => navigate('/auth')}
          className="group relative px-7 py-3 text-sm font-semibold rounded-xl bg-white text-black hover:bg-gray-100 transition-all duration-300 hover:scale-105 hover:shadow-[0_0_30px_rgba(177,158,239,0.3)] animate-[fadeInUp_0.8s_ease-out_0.6s_both]"
        >
          Get Started
          <span className="ml-2 inline-block transition-transform duration-300 group-hover:translate-x-1">
            &rarr;
          </span>
        </button>
      </div>

      {/* Feature cards section */}
      <div className="relative z-10 flex-1 flex items-center w-full max-w-5xl mx-auto px-6">
        <div className="w-full grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6">
          <div className="animate-[fadeInUp_0.8s_ease-out_0.9s_both]">
            <SpotlightCard spotlightColor="rgba(177, 158, 239, 0.15)">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-lg bg-purple-500/10 flex items-center justify-center">
                  <svg className="w-5 h-5 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <h3 className="text-base font-semibold text-white">End-to-End Encryption</h3>
              </div>
              <p className="text-sm text-gray-400 leading-relaxed">
                Your notes are encrypted with a passphrase only you know. Zero-knowledge architecture means even we can't read your data.
              </p>
            </SpotlightCard>
          </div>

          <div className="animate-[fadeInUp_0.8s_ease-out_1.1s_both]">
            <SpotlightCard spotlightColor="rgba(96, 165, 250, 0.15)">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-lg bg-blue-500/10 flex items-center justify-center">
                  <svg className="w-5 h-5 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                  </svg>
                </div>
                <h3 className="text-base font-semibold text-white">Two-Factor Auth & Passkeys</h3>
              </div>
              <p className="text-sm text-gray-400 leading-relaxed">
                Protect your account with TOTP-based 2FA, biometric passkeys, and PIN lock. Multiple layers of security built-in.
              </p>
            </SpotlightCard>
          </div>

          <div className="animate-[fadeInUp_0.8s_ease-out_1.3s_both]">
            <SpotlightCard spotlightColor="rgba(52, 211, 153, 0.15)">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                  <svg className="w-5 h-5 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                  </svg>
                </div>
                <h3 className="text-base font-semibold text-white">AI-Powered Notes</h3>
              </div>
              <p className="text-sm text-gray-400 leading-relaxed">
                Smart summaries, grammar fixes, and transcription powered by AI. Your notes stay private while getting intelligent assistance.
              </p>
            </SpotlightCard>
          </div>
        </div>
      </div>
    </div>
  )
}
