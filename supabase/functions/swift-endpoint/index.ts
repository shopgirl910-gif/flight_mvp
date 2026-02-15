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
    const { emailText } = await req.json();

    if (!emailText || emailText.trim().length === 0) {
      throw new Error('メール本文が空です');
    }

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) {
      throw new Error('ANTHROPIC_API_KEY not configured');
    }

    const prompt = `あなたは航空会社の予約確認メールを解析するエキスパートです。
以下のメール本文から、フライト情報を抽出してJSON形式で返してください。

【メール本文】
${emailText}

【空港名→コード対応表】
羽田/東京国際/羽田空港/Tokyo → HND
成田/成田国際/Narita → NRT
那覇/那覇空港/Naha → OKA
新千歳/札幌/Sapporo/New Chitose → CTS
伊丹/大阪国際/Osaka Itami → ITM
関西/関西国際/Kansai → KIX
中部/セントレア/名古屋/Chubu/Nagoya → NGO
福岡/Fukuoka → FUK
仙台/Sendai → SDJ
鹿児島/Kagoshima → KOJ
神戸/Kobe → UKB
宮崎/Miyazaki → KMI
熊本/Kumamoto → KMJ
長崎/Nagasaki → NGS
大分/Oita → OIT
松山/Matsuyama → MYJ
高松/Takamatsu → TAK
広島/Hiroshima → HIJ
岡山/Okayama → OKJ
富山/Toyama → TOY
小松/Komatsu → KMQ
能登/Noto → NTQ
米子/Yonago → YGJ
出雲/Izumo → IZO
石垣/Ishigaki → ISG
宮古/Miyako → MMY
久米島/Kumejima → UEO
与那国/Yonaguni → OGN
青森/Aomori → AOJ
秋田/Akita → AXT
山形/Yamagata → GAJ
花巻/Hanamaki → HNA
庄内/Shonai → SYO
福島/Fukushima → FKS
新潟/Niigata → KIJ

【抽出ルール】
1. 航空会社の判定:
   - JAL/日本航空/ジャル/JL/Japan Airlines → "JAL"
   - ANA/全日空/全日本空輸/NH/All Nippon Airways → "ANA"

2. 便名:
   - 数字部分のみ抽出（例: JAL123 → "123", NH456 → "456", JL901 → "901"）
   - 英字は除去

3. 空港コード:
   - 上記対応表を使用して日本語→3レターコードに変換
   - 既に3レターコードの場合はそのまま使用

4. 日付・時刻:
   - 日付: YYYY/MM/DD形式（例: 2025/03/15）
   - 時刻: HH:MM形式・24時間制（例: 07:00, 13:45）
   - 1桁の時刻は0埋め（7:00 → 07:00）

5. 運賃種別（そのまま抽出、正規化不要）:
   - JAL: フレックス、先得、特便、セイバー、スペシャルセイバー、株主割引、スカイメイト等
   - ANA: プレミアム運賃、片道、往復、ビジネス、バリュー、スーパーバリュー、トランジット、いっしょにマイル割、株主優待、スマートシニア等

6. 座席クラス:
   - JAL: 普通席、クラスJ、ファーストクラス
   - ANA: 普通席、プレミアムクラス
   - メール内で「ファースト」とあれば「ファーストクラス」

7. 運賃:
   - 数字のみ（カンマ除去）
   - 「円」「,」などは除去
   - **重要**: 各レグごとの運賃が明記されていない場合:
     - 合計運賃をレグ数で割った金額を各レグに設定
     - 例: 合計43,060円、2レグ → 各レグ21,530円
     - 割り切れない場合は切り捨て（整数）
   - 見つからない場合はnull

8. 判定できない項目はnullにする

【具体例1: JAL予約確認メール】
入力:
(1) 2025年3月15日 JAL 901便  羽田(08:30発) → 那覇(11:15着)  普通席 ご利用運賃 先得/合計 15,000円

出力:
{
  "legs": [
    {
      "airline": "JAL",
      "flight_number": "901",
      "date": "2025/03/15",
      "departure": "HND",
      "arrival": "OKA",
      "departure_time": "08:30",
      "arrival_time": "11:15",
      "fare_type": "先得",
      "seat_class": "普通席",
      "fare": 15000
    }
  ]
}

【具体例2: ANA予約確認メール】
入力:
[1] 2025年4月20日(月)  ANA 089    東京(羽田)(08:15) - 石垣(11:30)    普通席  (往復)片道   25,800円

出力:
{
  "legs": [
    {
      "airline": "ANA",
      "flight_number": "089",
      "date": "2025/04/20",
      "departure": "HND",
      "arrival": "ISG",
      "departure_time": "08:15",
      "arrival_time": "11:30",
      "fare_type": "片道",
      "seat_class": "普通席",
      "fare": 25800
    }
  ]
}

【具体例4: 合計運賃のみ（各レグ運賃なし）】
入力:
[1] 2026年3月2日(月)  ANA 089    東京(羽田)(08:15) - 石垣(11:30)    普通席    (往復)スーパーバリュー28K
[2] 2026年3月5日(木)  ANA 090    石垣(12:25) - 東京(羽田)(15:00)    普通席    (往復)スーパーバリュー28M
運賃額等43,060円

出力:
{
  "legs": [
    {
      "airline": "ANA",
      "flight_number": "089",
      "date": "2026/03/02",
      "departure": "HND",
      "arrival": "ISG",
      "departure_time": "08:15",
      "arrival_time": "11:30",
      "fare_type": "スーパーバリュー28K",
      "seat_class": "普通席",
      "fare": 21530
    },
    {
      "airline": "ANA",
      "flight_number": "090",
      "date": "2026/03/05",
      "departure": "ISG",
      "arrival": "HND",
      "departure_time": "12:25",
      "arrival_time": "15:00",
      "fare_type": "スーパーバリュー28M",
      "seat_class": "普通席",
      "fare": 21530
    }
  ]
}

【具体例3: 複数レグ】
入力:
(1) 2025年3月15日 JAL901便  羽田 7:00発 → 那覇 9:15着  普通席 フレックス 15,000円
(2) 2025年3月15日 JAL902便  那覇 10:00発 → 羽田 12:30着  クラスJ フレックス 18,000円

出力:
{
  "legs": [
    {
      "airline": "JAL",
      "flight_number": "901",
      "date": "2025/03/15",
      "departure": "HND",
      "arrival": "OKA",
      "departure_time": "07:00",
      "arrival_time": "09:15",
      "fare_type": "フレックス",
      "seat_class": "普通席",
      "fare": 15000
    },
    {
      "airline": "JAL",
      "flight_number": "902",
      "date": "2025/03/15",
      "departure": "OKA",
      "arrival": "HND",
      "departure_time": "10:00",
      "arrival_time": "12:30",
      "fare_type": "フレックス",
      "seat_class": "クラスJ",
      "fare": 18000
    }
  ]
}

【重要】
- 上記の例を参考に、同じ形式で抽出してください
- JSONのみを返してください（説明文は不要）
- 複数レグがある場合は順番に抽出してください`;

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5-20250929',
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    const data = await response.json();

    if (data.error) {
      throw new Error(data.error.message);
    }

    const text = data.content[0].text;

    let jsonStr = text;
    const jsonMatch = text.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1];
    } else {
      const braceMatch = text.match(/\{[\s\S]*\}/);
      if (braceMatch) {
        jsonStr = braceMatch[0];
      }
    }

    const parsed = JSON.parse(jsonStr);

    return new Response(
      JSON.stringify(parsed),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
