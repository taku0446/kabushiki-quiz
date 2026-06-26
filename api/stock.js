// Vercel Serverless Function
// このファイルを api/stock.js に置くと、Vercelが自動的に
// https://あなたのサイト/api/stock?code=7203 というAPIエンドポイントを作成します。
//
// サーバー側（Node.js環境）からYahoo Financeにリクエストするため、
// ブラウザのCORS制約を受けません。これにより株価取得が安定します。

export default async function handler(req, res) {
  // CORSヘッダー（同一サイトからの呼び出しのみだが念のため設定）
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');

  const { code } = req.query;

  if (!code || !/^[0-9A-Za-z]{1,5}$/.test(code)) {
    return res.status(400).json({ error: '銘柄コードが不正です' });
  }

  const symbol = `${code}.T`;
  const queryVariants = [
    `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=10d&region=JP&lang=ja-JP`,
    `https://query2.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=10d&region=JP&lang=ja-JP`,
  ];

  let lastError = null;

  for (const url of queryVariants) {
    try {
      const response = await fetch(url, {
        headers: {
          // YahooがブラウザらしいUser-Agentを期待することがあるため付与
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        signal: AbortSignal.timeout(8000),
      });

      if (!response.ok) {
        lastError = `HTTP ${response.status}`;
        continue;
      }

      const data = await response.json();
      const result = data?.chart?.result?.[0];
      const apiError = data?.chart?.error;

      if (apiError || !result) {
        lastError = apiError?.description || 'データが見つかりません';
        continue;
      }

      // 成功。最低限必要な部分だけブラウザに返す（レスポンスを軽量化）
      const timestamps = result.timestamp || [];
      const closes = result.indicators?.quote?.[0]?.close || [];

      const validDays = [];
      for (let i = 0; i < timestamps.length; i++) {
        if (closes[i] != null) {
          validDays.push({ ts: timestamps[i], close: closes[i] });
        }
      }

      if (validDays.length < 2) {
        lastError = '十分な営業日データがありません';
        continue;
      }

      const latest = validDays[validDays.length - 1];
      const previous = validDays[validDays.length - 2];

      return res.status(200).json({
        success: true,
        code,
        symbol,
        latest: { ts: latest.ts, close: latest.close },
        previous: { ts: previous.ts, close: previous.close },
      });
    } catch (e) {
      lastError = e.message || '不明なエラー';
      continue;
    }
  }

  return res.status(502).json({
    success: false,
    error: `株価取得に失敗しました: ${lastError}`,
  });
}
