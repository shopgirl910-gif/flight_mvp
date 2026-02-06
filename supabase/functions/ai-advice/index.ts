import "https://deno.land/x/xhr@0.1.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { legs, jalCard, anaCard, jalStatus, anaStatus, jalTourPremium, targetFop, targetPp } = await req.json();

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) {
      throw new Error('ANTHROPIC_API_KEY not configured');
    }

    // 旅程データを整形
    const legsSummary = legs.map((leg: any, i: number) => 
      `レグ${i + 1}: ${leg.departure}→${leg.arrival} ${leg.airline} ${leg.fareType} ${leg.seatClass} ¥${leg.fareAmount || '未入力'} → ${leg.fop || leg.pp}${leg.airline === 'JAL' ? 'FOP' : 'PP'}, ${leg.miles}マイル`
    ).join('\n');

    // 合計計算
    const totalFop = legs.filter((l: any) => l.airline === 'JAL').reduce((sum: number, l: any) => sum + (l.fop || 0), 0);
    const totalPp = legs.filter((l: any) => l.airline === 'ANA').reduce((sum: number, l: any) => sum + (l.pp || 0), 0);
    const totalFare = legs.reduce((sum: number, l: any) => sum + (l.fareAmount || 0), 0);
    const totalMiles = legs.reduce((sum: number, l: any) => sum + (l.miles || 0), 0);

    // 単価計算
    const jalUnitPrice = totalFop > 0 && totalFare > 0 ? (totalFare / totalFop).toFixed(1) : null;
    const anaUnitPrice = totalPp > 0 && totalFare > 0 ? (totalFare / totalPp).toFixed(1) : null;

    // 乗り継ぎ時間チェック用データ
    const connectionTimes = [];
    for (let i = 0; i < legs.length - 1; i++) {
      if (legs[i].arrival === legs[i + 1].departure && legs[i].arrivalTime && legs[i + 1].departureTime) {
        const arr = legs[i].arrivalTime.split(':').map(Number);
        const dep = legs[i + 1].departureTime.split(':').map(Number);
        const minutes = (dep[0] * 60 + dep[1]) - (arr[0] * 60 + arr[1]);
        connectionTimes.push({ from: i + 1, to: i + 2, minutes, airport: legs[i].arrival });
      }
    }

    const prompt = `あなたは航空会社の修行（ステータス獲得のための搭乗）に詳しいアドバイザーです。
以下の旅程を分析して、4つの観点からアドバイスしてください。

【旅程データ】
${legsSummary}

【合計】
- JAL FOP: ${totalFop} / ANA PP: ${totalPp}
- 総マイル: ${totalMiles}
- 総額: ¥${totalFare || '未入力'}
${jalUnitPrice ? `- JAL単価: ¥${jalUnitPrice}/FOP` : ''}
${anaUnitPrice ? `- ANA単価: ¥${anaUnitPrice}/PP` : ''}

【ユーザー設定】
- JALカード: ${jalCard || '未設定'}
- ANAカード: ${anaCard || '未設定'}
- JALステータス: ${jalStatus || 'なし'}
- ANAステータス: ${anaStatus || 'なし'}
- ツアープレミアム: ${jalTourPremium ? '加入' : '未加入'}
- 目標FOP: ${targetFop || '未設定'}
- 目標PP: ${targetPp || '未設定'}

【乗り継ぎ情報】
${connectionTimes.length > 0 ? connectionTimes.map(c => `レグ${c.from}→${c.to}: ${c.airport}空港で${c.minutes}分`).join('\n') : '乗り継ぎなし'}

以下の4セクションで回答してください（各セクション2-3文で簡潔に）:

📊 効率評価
単価の評価（良い/標準/改善余地あり）と、その理由。

💡 改善提案
座席クラスのアップグレードや運賃種別の変更で効率が上がる可能性があれば提案。なければ現状が最適と伝える。

⚠️ 乗り継ぎ注意
乗り継ぎ時間が30分未満の場合は警告。問題なければ「乗り継ぎ時間は十分です」と記載。

🎯 目標達成
目標が設定されていれば、あと何ポイント必要か、同じ旅程を何回繰り返せば達成できるか試算。未設定なら目標設定を推奨。`;

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5-20250929',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    const data = await response.json();
    
    if (data.error) {
      throw new Error(data.error.message);
    }

    const advice = data.content[0].text;

    return new Response(
      JSON.stringify({ advice }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});