import React, { useState } from 'react';
import { Send, Bot, User, Sparkles } from 'lucide-react';
import { sendChatMessage } from '../lib/api';

export default function AiAssistant() {
  const [messages, setMessages] = useState([
    {
      role: 'assistant',
      content: 'Hello Shaurya! I am your HealthDevice AI Assistant. How can I assist with your posture metrics, vitals trends, or hydration reminders today?'
    }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!input.trim() || loading) return;

    const userMessage = input.trim();
    setInput('');
    setMessages((prev) => [...prev, { role: 'user', content: userMessage }]);
    setLoading(true);

    try {
      const res = await sendChatMessage(userMessage, {
        currentBpm: 72,
        currentSpo2: 98,
        postureClassification: 'Good',
        stepsToday: 4210
      });

      setMessages((prev) => [
        ...prev,
        { role: 'assistant', content: res.reply || 'Guidance received.' }
      ]);
    } catch (err) {
      setMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content: 'Unable to reach backend AI service right now. Please verify your Render Backend URL and GROQ_API_KEY environment variable.'
        }
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-4">
      <div className="p-6 bg-[#121824] border border-[#1F293D] rounded-2xl flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-[#00F0FF]" />
            AI Health & Ergonomic Coach
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Real-time biometric advice powered by Render backend and Groq LLMs.
          </p>
        </div>
      </div>

      {/* Chat Area */}
      <div className="bg-[#121824] border border-[#1F293D] rounded-2xl p-6 min-h-[420px] max-h-[560px] flex flex-col justify-between shadow-xl">
        <div className="space-y-4 overflow-y-auto pr-2">
          {messages.map((msg, i) => (
            <div
              key={i}
              className={`flex items-start gap-3 ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}
            >
              <div
                className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                  msg.role === 'user' ? 'bg-[#00F0FF] text-black font-bold' : 'bg-slate-800 text-[#00F0FF]'
                }`}
              >
                {msg.role === 'user' ? <User className="w-5 h-5" /> : <Bot className="w-5 h-5" />}
              </div>
              <div
                className={`p-4 rounded-2xl max-w-[80%] text-sm leading-relaxed ${
                  msg.role === 'user'
                    ? 'bg-[#00F0FF]/10 text-white border border-[#00F0FF]/30 rounded-tr-none'
                    : 'bg-[#1F293D]/70 text-slate-200 border border-[#1F293D] rounded-tl-none'
                }`}
              >
                {msg.content}
              </div>
            </div>
          ))}
          {loading && (
            <div className="flex items-center gap-2 text-slate-400 text-sm italic">
              <span className="w-2 h-2 rounded-full bg-[#00F0FF] animate-ping"></span>
              AI Coach is analyzing vitals and composing guidance...
            </div>
          )}
        </div>

        {/* Input */}
        <form onSubmit={handleSubmit} className="mt-6 flex items-center gap-3">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask about your posture score, heart rate, or hydration reminders..."
            className="flex-1 px-4 py-3 bg-[#0A0E17] border border-[#1F293D] focus:border-[#00F0FF] rounded-xl text-sm text-white placeholder-slate-500 outline-none transition-colors"
          />
          <button
            type="submit"
            disabled={loading || !input.trim()}
            className="px-5 py-3 bg-[#00F0FF] hover:bg-[#00F0FF]/90 text-black font-semibold rounded-xl text-sm transition-all disabled:opacity-40 flex items-center gap-2"
          >
            <span>Send</span>
            <Send className="w-4 h-4" />
          </button>
        </form>
      </div>
    </div>
  );
}
