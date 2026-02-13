// supabase/functions/stripe-webhook/index.ts
// Supabase Edge Function: Stripe Webhook ハンドラー
//
// 配置先: c:\flight_mvp\supabase\functions\stripe-webhook\index.ts
// デプロイ: supabase functions deploy stripe-webhook
//
// Stripe Dashboard で Webhook URL を設定:
//   https://<project-ref>.supabase.co/functions/v1/stripe-webhook
//   イベント: checkout.session.completed

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

serve(async (req) => {
  try {
    // 1. Stripe署名検証
    const body = await req.text();
    const signature = req.headers.get("stripe-signature");

    if (!signature) {
      return new Response("Missing signature", { status: 400 });
    }

    let event: Stripe.Event;
    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
    } catch (err) {
      console.error("Webhook signature verification failed:", err);
      return new Response("Invalid signature", { status: 400 });
    }

    // 2. checkout.session.completed イベントのみ処理
    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;

      // 支払い完了確認
      if (session.payment_status !== "paid") {
        console.log("Payment not completed:", session.payment_status);
        return new Response("Payment not completed", { status: 200 });
      }

      const userId = session.client_reference_id || session.metadata?.user_id;
      if (!userId) {
        console.error("No user_id in session:", session.id);
        return new Response("No user_id", { status: 400 });
      }

      // 3. user_profiles を Pro に更新
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      const { error } = await supabase
        .from("user_profiles")
        .update({
          is_pro: true,
          pro_purchased_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (error) {
        console.error("DB update failed:", error);
        return new Response("DB update failed", { status: 500 });
      }

      console.log(`Pro activated for user: ${userId}, session: ${session.id}, amount: ${session.amount_total} JPY`);

      // 4. （オプション）購入ログをテーブルに記録
      await supabase.from("pro_purchases").insert({
        user_id: userId,
        stripe_session_id: session.id,
        stripe_payment_intent_id: session.payment_intent,
        amount: session.amount_total,
        currency: session.currency,
        customer_email: session.customer_email,
      }).then(({ error }) => {
        if (error) console.error("Purchase log failed:", error);
      });
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Webhook error:", error);
    return new Response("Webhook handler failed", { status: 500 });
  }
});
