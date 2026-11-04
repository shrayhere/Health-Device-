import React, { useState } from 'react';
import { Bell, Clock, Sun, Moon, Palette, CheckCircle2 } from 'lucide-react';

export default function Alarms() {
  const [alarms, setAlarms] = useState([
    { id: 1, label: 'Morning Hydration', hour: 8, minute: 30, period: 'AM', enabled: true, color: '#00F0FF' },
    { id: 2, label: 'Post-Lunch Posture Check', hour: 2, minute: 15, period: 'PM', enabled: true, color: '#00FF88' },
    { id: 3, label: 'Evening Walk Reminders', hour: 6, minute: 45, period: 'PM', enabled: false, color: '#FF007A' }
  ]);

  const toggleAlarm = (id) => {
    setAlarms((prev) =>
      prev.map((a) => (a.id === id ? { ...a, enabled: !a.enabled } : a))
    );
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Bell className="w-5 h-5 text-[#00F0FF]" />
            Smart Hardware Alarms & Illumination
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Dual 12-hour AM/PM schedule with 24-bit RGB LED notification rings.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {alarms.map((alarm) => (
          <div
            key={alarm.id}
            className={`p-6 rounded-2xl border transition-all ${
              alarm.enabled
                ? 'bg-[#121824] border-[#1F293D] shadow-lg'
                : 'bg-[#121824]/50 border-[#1F293D]/40 opacity-60'
            }`}
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                {alarm.label}
              </span>
              <button
                onClick={() => toggleAlarm(alarm.id)}
                className={`w-11 h-6 flex items-center rounded-full p-1 transition-colors ${
                  alarm.enabled ? 'bg-[#00F0FF]' : 'bg-slate-700'
                }`}
              >
                <div
                  className={`bg-black w-4 h-4 rounded-full shadow-md transform transition-transform ${
                    alarm.enabled ? 'translate-x-5' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>

            {/* Time Display with AM/PM */}
            <div className="mt-4 flex items-baseline gap-2">
              <span className="text-3xl font-extrabold text-white">
                {String(alarm.hour).padStart(2, '0')}:{String(alarm.minute).padStart(2, '0')}
              </span>
              <span className="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded bg-[#1F293D] text-[#00F0FF]">
                {alarm.period === 'AM' ? <Sun className="w-3 h-3" /> : <Moon className="w-3 h-3" />}
                {alarm.period}
              </span>
            </div>

            {/* 24-bit RGB Ring Color Indicator */}
            <div className="mt-5 pt-3 border-t border-[#1F293D] flex items-center justify-between text-xs text-slate-400">
              <span className="flex items-center gap-1.5">
                <Palette className="w-3.5 h-3.5" />
                RGB Ring:
              </span>
              <span className="flex items-center gap-1.5 font-medium text-white">
                <span
                  className="w-3 h-3 rounded-full border border-white/20"
                  style={{ backgroundColor: alarm.color }}
                />
                {alarm.color}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
