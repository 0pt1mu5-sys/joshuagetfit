// AI coach. The OpenAI key lives only in Netlify environment variables, never in the browser.
// Env vars: OPENAI_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY (optional: OPENAI_MODEL)
const SYSTEM = `You are GetFit's friendly health coach for fasting, nutrition and fitness.
Rules: give general wellness guidance only; never diagnose; never recommend dangerous calorie deficits
(under 1200 kcal women / 1500 kcal men) or extreme fasting (over 36 hours); never guarantee results;
label calorie figures as estimates; if the user mentions pregnancy, diabetes, medication, an eating disorder,
chest pain, fainting or other serious symptoms, advise speaking to a doctor or dietitian. Prefer locally available
foods (nsima, chambo, beans, groundnuts, pumpkin leaves, cassava, sweet potato). Keep answers short and practical.
The app calculates all numbers; use the context figures and do not recompute totals.`;

exports.handler = async (e) => {
  if (e.httpMethod !== 'POST') return { statusCode: 405, body: JSON.stringify({ error: 'Method not allowed' }) };
  const token = (e.headers.authorization || '').replace('Bearer ', '');
  const u = await fetch(process.env.SUPABASE_URL + '/auth/v1/user', {
    headers: { apikey: process.env.SUPABASE_ANON_KEY, Authorization: 'Bearer ' + token },
  });
  if (!u.ok) return { statusCode: 401, body: JSON.stringify({ error: 'Please sign in again.' }) };
  const { messages = [], context = '' } = JSON.parse(e.body || '{}');
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + process.env.OPENAI_API_KEY },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      max_tokens: 500,
      messages: [
        { role: 'system', content: SYSTEM + (context ? '\n\nUser context (calculated by the app): ' + context : '') },
        ...messages.slice(-10).map((m) => ({ role: m.role === 'user' ? 'user' : 'assistant', content: String(m.content).slice(0, 1000) })),
      ],
    }),
  });
  const d = await r.json();
  return { statusCode: r.ok ? 200 : 502, body: JSON.stringify({ reply: d.choices?.[0]?.message?.content || 'The coach is unavailable right now.' }) };
};
