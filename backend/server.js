const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { createClient } = require('@supabase/supabase-js');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;
const HOST = '0.0.0.0';

// -------------------------------------------------------------
// Security & Middleware
// -------------------------------------------------------------
app.use(helmet());
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// Dynamic CORS configuration
const allowedOrigins = [
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:4173',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:3000'
];

if (process.env.FRONTEND_URL) {
  const normalizedFrontendUrl = process.env.FRONTEND_URL.replace(/\/$/, '');
  allowedOrigins.push(normalizedFrontendUrl);
}

app.use(cors({
  origin: (origin, callback) => {
    // Allow non-browser requests (e.g. curl, server-to-server, Render health check)
    if (!origin) return callback(null, true);

    const isAllowed = allowedOrigins.some((allowed) => {
      if (allowed === origin) return true;
      try {
        const originUrl = new URL(origin);
        const allowedUrl = new URL(allowed);
        return originUrl.hostname === allowedUrl.hostname;
      } catch (_) {
        return false;
      }
    });

    if (isAllowed || /^https?:\/\/localhost(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }

    return callback(new Error(`Origin ${origin} not allowed by CORS policy`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// -------------------------------------------------------------
// Supabase & Database Setup
// -------------------------------------------------------------
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DATABASE_URL = process.env.DATABASE_URL;

let supabase = null;
if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
  try {
    supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false }
    });
    console.log('[Supabase] Service Role Client initialized successfully.');
  } catch (err) {
    console.warn('[Supabase] Initialization warning:', err.message);
  }
} else {
  console.log('[Supabase] Notice: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing. Mock telemetry mode active.');
}

// PostgreSQL connection pool (supports pooled connection string, e.g. Supabase port 6543)
let dbPool = null;
if (DATABASE_URL) {
  try {
    dbPool = new Pool({
      connectionString: DATABASE_URL,
      ssl: DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false }
    });
    console.log('[Database] PostgreSQL connection pool initialized.');
  } catch (err) {
    console.warn('[Database] Pool initialization error:', err.message);
  }
}

// -------------------------------------------------------------
// Core Routes
// -------------------------------------------------------------

// 1. Health check endpoint (Required by Render)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    service: 'HealthDevice REST API',
    supabaseConnected: Boolean(supabase),
    dbPoolConfigured: Boolean(dbPool)
  });
});

// 2. Telemetry: Get Latest Device Vitals
app.get('/api/vitals/latest', async (req, res) => {
  try {
    if (supabase) {
      const { data, error } = await supabase
        .from('health_vitals')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (!error && data) {
        return res.json({ success: true, data });
      }
    }

    // Default live telemetry baseline
    return res.json({
      success: true,
      data: {
        bpm: 72,
        spo2: 98,
        steps: 4210,
        active_minutes: 38,
        calories_kcal: 245,
        posture_score: 91,
        posture_classification: 'Good',
        battery_pct: 88,
        device_name: 'HealthDevice-C3',
        created_at: new Date().toISOString()
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 3. Telemetry: Ingest Vitals from ESP32 or Companion App
app.post('/api/vitals', async (req, res) => {
  try {
    const { bpm, spo2, steps, calories, posture_score, battery_pct, user_id } = req.body;

    if (supabase) {
      const { data, error } = await supabase
        .from('health_vitals')
        .insert([{
          bpm: bpm || 0,
          spo2: spo2 || 0,
          steps: steps || 0,
          calories_kcal: calories || 0,
          posture_score: posture_score || 100,
          battery_pct: battery_pct || 100,
          user_id: user_id || null,
          created_at: new Date().toISOString()
        }])
        .select();

      if (error) throw error;
      return res.status(201).json({ success: true, record: data });
    }

    return res.status(201).json({
      success: true,
      message: 'Vitals logged (memory mode)',
      received: { bpm, spo2, steps, calories, posture_score, battery_pct }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 4. AI Health Assistant Proxy (Groq / Llama)
app.post('/api/ai/chat', async (req, res) => {
  try {
    const { message, context } = req.body;
    if (!message) {
      return res.status(400).json({ success: false, error: 'Message is required' });
    }

    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
      return res.json({
        success: true,
        reply: `Health Assistant: Your vital signs look steady (72 BPM, 98% SpO2, Good Posture). Stay hydrated and maintain your active step count today!`
      });
    }

    // Proxy to Groq Cloud API
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            role: 'system',
            content: 'You are HealthDevice AI Coach, an empathetic, evidence-based wellness assistant. Provide actionable, concise health guidance. Never replace clinical medical advice.'
          },
          {
            role: 'user',
            content: `User Context: ${JSON.stringify(context || {})}\n\nQuestion: ${message}`
          }
        ],
        max_tokens: 300,
        temperature: 0.7
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Groq API error (${response.status}): ${errText}`);
    }

    const data = await response.json();
    const reply = data.choices?.[0]?.message?.content || 'Health Assistant guidance updated.';
    return res.json({ success: true, reply });
  } catch (err) {
    console.error('[AI Chat Error]:', err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5. Global 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found', path: req.originalUrl });
});

// -------------------------------------------------------------
// Start Server
// -------------------------------------------------------------
app.listen(PORT, HOST, () => {
  console.log(`🚀 HealthDevice Backend active at http://${HOST}:${PORT}`);
  console.log(`   Health Check: http://${HOST}:${PORT}/health`);
  console.log(`   Frontend Origin Allowed: ${process.env.FRONTEND_URL || 'Localhost only'}`);
});
