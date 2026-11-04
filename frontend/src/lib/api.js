const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || '').replace(/\/$/, '');

export async function fetchHealthStatus() {
  const url = API_BASE_URL ? `${API_BASE_URL}/health` : '/health';
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Health check failed (${res.status})`);
  return res.json();
}

export async function fetchLatestVitals() {
  const url = API_BASE_URL ? `${API_BASE_URL}/api/vitals/latest` : '/api/vitals/latest';
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch vitals (${res.status})`);
  return res.json();
}

export async function sendChatMessage(message, context) {
  const url = API_BASE_URL ? `${API_BASE_URL}/api/ai/chat` : '/api/ai/chat';
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, context })
  });
  if (!res.ok) throw new Error(`AI Chat error (${res.status})`);
  return res.json();
}
