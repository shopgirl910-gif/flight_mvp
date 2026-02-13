// supabase/functions/create-checkout-session/index.ts
// Supabase Edge Function: Stripe Checkout セッション作成
//
// 配置先: c:\flight_mvp\supabase\functions\create-checkout-session\index.ts
// デプロイ: supabase functions deploy create-checkout-session

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. ユーザー認証チェック
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "認証が必要です" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "認証に失敗しました" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. 既にPro版か確認
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("is_pro")
      .eq("id", user.id)
      .single();

    if (profile?.is_pro) {
      return new Response(
        JSON.stringify({ error: "既にPro版をご利用中です" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. 現在の価格を決定（先着200名は100円、以降480円）
    const { data: stats } = await supabase
      .from("pro_purchase_stats")
      .select("*")
      .single();

    const remainingSlots = stats?.remaining_slots ?? 0;
    const priceYen = remainingSlots > 0 ? 100 : 480;

    // 4. Stripe Checkout セッション作成
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "jpy",
            product_data: {
              name: "マイル修行プランナー Pro版",
              description: remainingSlots > 0
                ? `リリース記念価格（残り${remainingSlots}枠）`
                : "Pro版（買い切り）",
            },
            unit_amount: priceYen, // JPYはセント単位不要
          },
          quantity: 1,
        },
      ],
      mode: "payment",
      success_url: `${Deno.env.get("APP_URL") || "https://mileage-run-planner.web.app"}/?payment=success`,
      cancel_url: `${Deno.env.get("APP_URL") || "https://mileage-run-planner.web.app"}/?payment=cancel`,
      client_reference_id: user.id, // Webhook側でユーザー特定用
      customer_email: user.email,
      metadata: {
        user_id: user.id,
        price_yen: priceYen.toString(),
      },
    });

    // 5. セッションURL返却
    return new Response(
      JSON.stringify({
        url: session.url,
        price: priceYen,
        remaining_slots: remainingSlots,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "決済セッションの作成に失敗しました" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
