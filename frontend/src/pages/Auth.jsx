import React, { useState } from 'react';
import { Lock, Mail, User, CheckCircle, AlertCircle } from 'lucide-react';
import { supabase, isSupabaseConfigured } from '../lib/supabase';

export default function Auth({ user, setUser }) {
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [message, setMessage] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleAuth = async (e) => {
    e.preventDefault();
    setError(null);
    setMessage(null);
    setLoading(true);

    if (!isSupabaseConfigured) {
      // Local demo sign in
      setTimeout(() => {
        setUser({ email: email || 'shaurya@healthdevice.com', name: name || 'Shaurya' });
        setMessage('Signed in via local session (Add Supabase env keys on Render for live cloud DB sync).');
        setLoading(false);
      }, 500);
      return;
    }

    try {
      if (isSignUp) {
        const { data, error: supaErr } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: { name: name || 'Health User' }
          }
        });
        if (supaErr) throw supaErr;
        setMessage('Registration successful! Please check your email inbox to confirm your account.');
      } else {
        const { data, error: supaErr } = await supabase.auth.signInWithPassword({
          email,
          password
        });
        if (supaErr) throw supaErr;
        setUser(data.user);
        setMessage('Welcome back! Connected to Supabase Cloud.');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSignOut = async () => {
    if (supabase) await supabase.auth.signOut();
    setUser(null);
    setMessage('Logged out successfully.');
  };

  if (user) {
    return (
      <div className="max-w-md mx-auto p-8 bg-[#121824] border border-[#1F293D] rounded-2xl text-center space-y-4 shadow-xl">
        <div className="w-14 h-14 mx-auto rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
          <CheckCircle className="w-8 h-8" />
        </div>
        <h2 className="text-xl font-bold text-white">Authenticated Session Active</h2>
        <p className="text-sm text-slate-300">
          Signed in as: <span className="font-semibold text-[#00F0FF]">{user.email || 'Shaurya'}</span>
        </p>
        <button
          onClick={handleSignOut}
          className="mt-4 px-6 py-2.5 bg-rose-500/20 text-rose-300 border border-rose-500/40 hover:bg-rose-500/30 rounded-xl text-sm font-medium transition-all"
        >
          Sign Out
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-md mx-auto p-8 bg-[#121824] border border-[#1F293D] rounded-2xl shadow-xl space-y-6">
      <div className="text-center">
        <h2 className="text-2xl font-bold text-white">
          {isSignUp ? 'Create HealthDevice Account' : 'Welcome to HealthDevice'}
        </h2>
        <p className="text-xs text-slate-400 mt-1">
          {isSupabaseConfigured
            ? 'Connected to Supabase Authentication & Database'
            : 'Supabase keys pending: running in offline demo mode'}
        </p>
      </div>

      {message && (
        <div className="p-3 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-xs text-emerald-300 flex items-center gap-2">
          <CheckCircle className="w-4 h-4 shrink-0" />
          <span>{message}</span>
        </div>
      )}

      {error && (
        <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-xl text-xs text-rose-300 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <form onSubmit={handleAuth} className="space-y-4">
        {isSignUp && (
          <div>
            <label className="text-xs font-semibold text-slate-300 block mb-1">Full Name</label>
            <div className="relative">
              <User className="w-4 h-4 absolute left-3.5 top-3.5 text-slate-500" />
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Shaurya Gupta"
                className="w-full pl-10 pr-4 py-2.5 bg-[#0A0E17] border border-[#1F293D] focus:border-[#00F0FF] rounded-xl text-sm text-white placeholder-slate-500 outline-none"
              />
            </div>
          </div>
        )}

        <div>
          <label className="text-xs font-semibold text-slate-300 block mb-1">Email Address</label>
          <div className="relative">
            <Mail className="w-4 h-4 absolute left-3.5 top-3.5 text-slate-500" />
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="user@healthdevice.com"
              className="w-full pl-10 pr-4 py-2.5 bg-[#0A0E17] border border-[#1F293D] focus:border-[#00F0FF] rounded-xl text-sm text-white placeholder-slate-500 outline-none"
            />
          </div>
        </div>

        <div>
          <label className="text-xs font-semibold text-slate-300 block mb-1">Password</label>
          <div className="relative">
            <Lock className="w-4 h-4 absolute left-3.5 top-3.5 text-slate-500" />
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••••••"
              className="w-full pl-10 pr-4 py-2.5 bg-[#0A0E17] border border-[#1F293D] focus:border-[#00F0FF] rounded-xl text-sm text-white placeholder-slate-500 outline-none"
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full py-3 bg-[#00F0FF] hover:bg-[#00F0FF]/90 text-black font-semibold rounded-xl text-sm transition-all disabled:opacity-50 mt-2"
        >
          {loading ? 'Processing...' : isSignUp ? 'Create Cloud Account' : 'Sign In'}
        </button>
      </form>

      <div className="text-center pt-2 border-t border-[#1F293D]">
        <button
          type="button"
          onClick={() => {
            setIsSignUp(!isSignUp);
            setError(null);
            setMessage(null);
          }}
          className="text-xs text-[#00F0FF] hover:underline"
        >
          {isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Create one"}
        </button>
      </div>
    </div>
  );
}
