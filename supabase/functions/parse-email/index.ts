// supabase/functions/parse-email/index.ts
// AIメール解析 Edge Function - Claude Haiku 4.5 API
// 約0.5円/回のコストで航空券予約メールからフライト情報を抽出

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const CLAUDE_MODEL = "claude-haiku-4-5-20251001";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// JAL/ANA空港コードマッピング（主要空港）
const AIRPORT_ALIASES: Record<string, string> = {
  "羽田": "HND", "成田": "NRT", "関西": "KIX", "伊丹": "ITM",
  "新千歳": "CTS", "福岡": "FUK", "那覇": "OKA", "中部": "NGO",
  "名古屋": "NGO", "小松": "KMQ", "鹿児島": "KOJ", "宮崎": "KMI",
  "大分": "OIT", "熊本": "KMJ", "長崎": "NGS", "松山": "MYJ",
  "高松": "TAK", "高知": "KCZ", "広島": "HIJ", "岡山": "OKJ",
  "出雲": "IZO", "鳥取": "TTJ", "秋田": "AXT", "山形": "GAJ",
  "青森": "AOJ", "花巻": "HNA", "仙台": "SDJ", "新潟": "KIJ",
  "富山": "TOY", "能登": "NTQ", "石垣": "ISG", "宮古": "MMY",
  "奄美": "ASJ", "徳島": "TKS", "北九州": "KKJ", "佐賀": "HSG",
  "対馬": "TSJ", "壱岐": "IKI", "五島": "FUJ", "種子島": "TNE",
  "屋久島": "KUM", "久米島": "UEO", "女満別": "MMB", "旭川": "AKJ",
  "釧路": "KUH", "帯広": "OBO", "函館": "HKD", "稚内": "WKJ",
  "利尻": "RIS", "紋別": "MBE", "中標津": "SHB",
  "神戸": "UKB", "南紀白浜": "SHM", "但馬": "TJH",
  "名古屋(小牧)": "NKM", "県営名古屋": "NKM",
  // IATA 3レターはそのまま通す
};

interface ParsedFlight {
  airline: string;        // "JAL" | "ANA"
  flightNumber: string;   // "JL901" | "NH461"
  origin: string;         // "HND"
  destination: string;    // "OKA"
  flightDate: string;     // "2026-03-15"
  departureTime: string;  // "08:00"
  arrivalTime: string;    // "10:30"
  fareType: string | null;       // "運賃3" など（推定）
  fareTypeName: string | null;   // "セイバー" など
  seatClass: string | null;      // "普通席" | "クラスJ" | "プレミアムクラス"
  fareAmount: number | null;     // 運賃金額（税込）
}

interface ParseResponse {
  flights: ParsedFlight[];
  rawText: string;
  confidence: string;     // "high" | "medium" | "low"
  warnings: string[];
}

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { emailText } = await req.json();

    if (!emailText || emailText.trim().length < 20) {
      return new Response(
        JSON.stringify({ error: "メール本文が短すぎます" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Claude Haiku 4.5 APIコール
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 1024,
        system: `あなたはJAL/ANAの航空券予約確認メールを解析するアシスタントです。
メール本文から以下の情報をJSON形式で抽出してください。

抽出項目:
- airline: "JAL" または "ANA"（JLはJAL、NHはANA）
- flightNumber: 便名（"JL901"形式。JAL901→JL901、ANA461→NH461に変換）
- origin: 出発空港の3レターコード（羽田→HND、那覇→OKA等）
- destination: 到着空港の3レターコード
- flightDate: 搭乗日（YYYY-MM-DD形式）
- departureTime: 出発時刻（HH:MM形式）
- arrivalTime: 到着時刻（HH:MM形式）
- fareType: 運賃種別の推定（わかる場合のみ）
  - JAL: "運賃1"(フレックス), "運賃2"(株主割引), "運賃3"(セイバー), "運賃4"(スペシャルセイバー), "運賃5"(包括旅行), "運賃6"(スカイメイト)
  - ANA: "運賃1"(プレミアム), "運賃3"(片道往復), "運賃5"(特割A), "運賃6"(特割B), "運賃7"(特割C), "運賃8"(個人包括/U25/SALE)
- fareTypeName: 運賃種別の名称（"セイバー"、"特割A"等）
- seatClass: 座席クラス（"普通席"、"クラスJ"、"ファーストクラス"、"プレミアムクラス"）
- fareAmount: 運賃金額（数値のみ、税込。不明ならnull）

複数レグ（往復・乗り継ぎ）がある場合は配列で返してください。
推定できない項目はnullにしてください。

必ず以下のJSON形式のみで返答してください（説明文不要）:
{
  "flights": [...],
  "confidence": "high" | "medium" | "low",
  "warnings": ["注意事項があれば"]
}`,
        messages: [
          {
            role: "user",
            content: `以下の航空券予約メールを解析してください:\n\n${emailText}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("Claude API error:", errorText);
      return new Response(
        JSON.stringify({ error: "AI解析に失敗しました。しばらく後に再試行してください。" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const aiResponse = data.content[0]?.text || "";

    // JSON抽出（```json ... ``` ラッパー除去）
    let parsed: ParseResponse;
    try {
      const jsonStr = aiResponse.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
      parsed = JSON.parse(jsonStr);
    } catch (e) {
      console.error("JSON parse error:", aiResponse);
      return new Response(
        JSON.stringify({
          error: "メール内容を解析できませんでした。航空券の予約確認メールを貼り付けてください。",
          rawResponse: aiResponse,
        }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // バリデーション: 空港コードの正規化
    for (const flight of parsed.flights) {
      if (flight.origin && flight.origin.length > 3) {
        flight.origin = AIRPORT_ALIASES[flight.origin] || flight.origin;
      }
      if (flight.destination && flight.destination.length > 3) {
        flight.destination = AIRPORT_ALIASES[flight.destination] || flight.destination;
      }
      // 便名正規化
      if (flight.flightNumber) {
        flight.flightNumber = flight.flightNumber
          .replace(/^JAL\s?/, "JL")
          .replace(/^ANA\s?/, "NH")
          .replace(/\s/g, "");
      }
    }

    return new Response(
      JSON.stringify(parsed),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "予期しないエラーが発生しました" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
