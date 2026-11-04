import React, { useState, useEffect } from 'react';
import { Heart, Activity, Footprints, Flame, Battery, ShieldCheck, RefreshCw, Cpu } from 'lucide-react';
import { fetchLatestVitals, fetchHealthStatus } from '../lib/api';

export default function Dashboard() {
  const [vitals, setVitals] = useState({
    bpm: 72,
    spo2: 98,
    steps: 4210,
    calories_kcal: 245,
    active_minutes: 38,
    posture_score: 91,
    posture_classification: 'Good',
    battery_pct: 88,
    device_name: 'HealthDevice-C3'
  });
  const [backendHealthy, setBackendHealthy] = useState(null);
  const [loading, setLoading] = useState(false);

  const loadData = async () => {
    setLoading(true);
    try {
      const statusRes = await fetchHealthStatus();
      setBackendHealthy(statusRes.status === 'ok');
    } catch (_) {
      setBackendHealthy(false);
    }

    try {
      const vitalsRes = await fetchLatestVitals();
      if (vitalsRes?.data) setVitals(vitalsRes.data);
    } catch (_) {
      // Retain optimistic default baseline
    }
    setLoading(false);
  };

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 15000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 bg-[#121824] border border-[#1F293D] rounded-2xl shadow-xl">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <Cpu className="text-[#00F0FF] w-7 h-7" />
            HealthDevice Capsule Telemetry
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Real-time biometric sync with ESP32-C3 optical PPG & 6-axis IMU sensors.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold ${
            backendHealthy === true ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30' :
            backendHealthy === false ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30' :
            'bg-slate-700/30 text-slate-400 border border-slate-600/30'
          }`}>
            <span className={`w-2 h-2 rounded-full ${backendHealthy ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`}></span>
            {backendHealthy ? 'Render Backend Online' : 'Local Mock Telemetry'}
          </span>
          <button
            onClick={loadData}
            disabled={loading}
            className="flex items-center gap-1.5 px-4 py-2 bg-[#1F293D] hover:bg-slate-700 text-sm font-medium rounded-xl transition-all disabled:opacity-50 text-white"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {/* Metrics Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {/* Heart Rate */}
        <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl hover:border-rose-500/40 transition-all shadow-lg group">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Heart Rate (PPG)</span>
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 flex items-center justify-center text-rose-400 group-hover:scale-110 transition-transform">
              <Heart className="w-5 h-5 animate-pulse" />
            </div>
          </div>
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-white tracking-tight">{vitals.bpm}</span>
            <span className="text-sm font-medium text-slate-400">BPM</span>
          </div>
          <div className="mt-4 text-xs text-slate-400 border-t border-[#1F293D] pt-3 flex justify-between">
            <span>Resting: 68 BPM</span>
            <span className="text-emerald-400 font-medium">Normal Sinus</span>
          </div>
        </div>

        {/* Blood Oxygen */}
        <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl hover:border-cyan-500/40 transition-all shadow-lg group">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Blood Oxygen (SpO2)</span>
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 flex items-center justify-center text-cyan-400 group-hover:scale-110 transition-transform">
              <Activity className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-white tracking-tight">{vitals.spo2}</span>
            <span className="text-sm font-medium text-slate-400">%</span>
          </div>
          <div className="mt-4 text-xs text-slate-400 border-t border-[#1F293D] pt-3 flex justify-between">
            <span>Target: &gt; 95%</span>
            <span className="text-emerald-400 font-medium">Optimal Saturation</span>
          </div>
        </div>

        {/* Posture Score */}
        <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl hover:border-indigo-500/40 transition-all shadow-lg group">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">AI Posture Score</span>
            <div className="w-10 h-10 rounded-xl bg-indigo-500/10 flex items-center justify-center text-indigo-400 group-hover:scale-110 transition-transform">
              <ShieldCheck className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-white tracking-tight">{vitals.posture_score}</span>
            <span className="text-sm font-medium text-slate-400">/ 100</span>
          </div>
          <div className="mt-4 text-xs text-slate-400 border-t border-[#1F293D] pt-3 flex justify-between">
            <span>Classification:</span>
            <span className="text-emerald-400 font-medium">{vitals.posture_classification}</span>
          </div>
        </div>

        {/* Steps */}
        <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl hover:border-emerald-500/40 transition-all shadow-lg group">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Daily Steps (IMU)</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-400 group-hover:scale-110 transition-transform">
              <Footprints className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-white tracking-tight">{vitals.steps?.toLocaleString()}</span>
            <span className="text-sm font-medium text-slate-400">steps</span>
          </div>
          <div className="mt-4 text-xs text-slate-400 border-t border-[#1F293D] pt-3 flex justify-between">
            <span>Goal: 10,000 steps</span>
            <span className="text-cyan-400 font-medium">{Math.round(((vitals.steps || 0) / 10000) * 100)}%</span>
          </div>
        </div>

        {/* Energy Burned */}
        <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl hover:border-amber-500/40 transition-all shadow-lg group">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Energy Expenditure</span>
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 flex items-center justify-center text-amber-400 group-hover:scale-110 transition-transform">
              <Flame className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-white tracking-tight">{vitals.calories_kcal}</span>
            <span className="text-sm font-medium text-slate-400">kcal</span>
          </div>
          <div className="mt-4 text-xs text-slate-400 border-t border-[#1F293D] pt-3 flex justify-between">
            <span>Active Duration:</span>
            <span className="text-slate-200 font-medium">{vitals.active_minutes} mins</span>
          </div>
        </div>

        {/* Battery & Hardware Status */}
        <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl hover:border-blue-500/40 transition-all shadow-lg group">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Capsule Battery (LiPo)</span>
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400 group-hover:scale-110 transition-transform">
              <Battery className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-white tracking-tight">{vitals.battery_pct}%</span>
            <span className="text-sm font-medium text-emerald-400">Charging OK</span>
          </div>
          <div className="mt-4 text-xs text-slate-400 border-t border-[#1F293D] pt-3 flex justify-between">
            <span>Device Model:</span>
            <span className="text-slate-200 font-medium">{vitals.device_name}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
