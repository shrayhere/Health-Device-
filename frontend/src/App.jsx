import React, { useState } from 'react';
import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { Activity, Sparkles, Bell, User, HeartPulse, Github, ExternalLink } from 'lucide-react';
import Dashboard from './pages/Dashboard';
import AiAssistant from './pages/AiAssistant';
import Alarms from './pages/Alarms';
import Auth from './pages/Auth';

function Navigation() {
  const location = useLocation();
  const navItems = [
    { path: '/', label: 'Live Telemetry', icon: Activity },
    { path: '/ai', label: 'AI Health Coach', icon: Sparkles },
    { path: '/alarms', label: 'Alarms & RGB', icon: Bell },
    { path: '/auth', label: 'Account & Cloud', icon: User }
  ];

  return (
    <nav className="flex items-center gap-1 sm:gap-2">
      {navItems.map((item) => {
        const Icon = item.icon;
        const isActive = location.pathname === item.path;
        return (
          <Link
            key={item.path}
            to={item.path}
            className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs sm:text-sm font-medium transition-all ${
              isActive
                ? 'bg-[#00F0FF]/15 text-[#00F0FF] border border-[#00F0FF]/30'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
            }`}
          >
            <Icon className="w-4 h-4 shrink-0" />
            <span className="hidden md:inline">{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}

export default function App() {
  const [user, setUser] = useState(null);

  return (
    <BrowserRouter>
      <div className="min-h-screen flex flex-col bg-[#0A0E17] text-slate-100">
        {/* Header */}
        <header className="sticky top-0 z-50 backdrop-blur-md bg-[#0A0E17]/80 border-b border-[#1F293D] px-4 lg:px-8 py-3.5">
          <div className="max-w-7xl mx-auto flex items-center justify-between">
            <Link to="/" className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-[#00F0FF] to-cyan-600 flex items-center justify-center text-black font-extrabold shadow-lg shadow-cyan-500/20">
                <HeartPulse className="w-5 h-5 text-black" />
              </div>
              <div>
                <span className="font-bold text-base tracking-tight text-white block">HealthDevice</span>
                <span className="text-[10px] text-cyan-400 font-medium tracking-wide uppercase">Render Production Portal</span>
              </div>
            </Link>

            <Navigation />

            <div className="flex items-center gap-3">
              <a
                href="https://github.com/shrayhere/Health-Device-"
                target="_blank"
                rel="noreferrer"
                className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-[#1F293D] hover:bg-slate-800 text-xs font-medium text-slate-300 transition-colors"
              >
                <Github className="w-3.5 h-3.5" />
                <span>GitHub Repo</span>
                <ExternalLink className="w-3 h-3 text-slate-500" />
              </a>
            </div>
          </div>
        </header>

        {/* Content Body */}
        <main className="flex-1 max-w-7xl w-full mx-auto px-4 lg:px-8 py-8">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/ai" element={<AiAssistant />} />
            <Route path="/alarms" element={<Alarms />} />
            <Route path="/auth" element={<Auth user={user} setUser={setUser} />} />
            <Route path="*" element={<Dashboard />} />
          </Routes>
        </main>

        {/* Footer */}
        <footer className="border-t border-[#1F293D] bg-[#0A0E17] py-6 px-4 text-center text-xs text-slate-500">
          <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-3">
            <span>HealthDevice Capsule & AI Posture Ecosystem • Engineered by <strong>Shaurya Gupta</strong></span>
            <span>Distributed under MIT License • Hosted on Render</span>
          </div>
        </footer>
      </div>
    </BrowserRouter>
  );
}
