import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const CLOUDFLARE_ACCOUNT_ID = Deno.env.get("CLOUDFLARE_ACCOUNT_ID") || "";
const CLOUDFLARE_API_TOKEN = Deno.env.get("CLOUDFLARE_API_TOKEN") || "";

function cleanJsonString(str: string): string {
  let cleaned = str.trim();
  if (cleaned.startsWith("```json")) {
    cleaned = cleaned.substring(7);
  } else if (cleaned.startsWith("```")) {
    cleaned = cleaned.substring(3);
  }
  if (cleaned.endsWith("```")) {
    cleaned = cleaned.substring(0, cleaned.length - 3);
  }
  cleaned = cleaned.trim();
  const startIdx = cleaned.indexOf("{");
  const endIdx = cleaned.lastIndexOf("}");
  if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
    cleaned = cleaned.substring(startIdx, endIdx + 1);
  }
  return cleaned;
}

function formatNutritionOutput(parsed: any, fallbackName: string) {
  const dishName = parsed.dish_name || parsed.meal_name || parsed.name || fallbackName;
  const calories = Number(parsed.total_calories ?? parsed.calories ?? 0);
  const protein = Number(parsed.total_protein_g ?? parsed.total_protein ?? parsed.protein ?? 0);
  const fats = Number(parsed.total_fats_g ?? parsed.total_fats ?? parsed.fats ?? 0);
  const carbs = Number(parsed.total_carbs_g ?? parsed.total_carbs ?? parsed.carbs ?? 0);
  const fiber = Number(parsed.total_fiber_g ?? parsed.total_fiber ?? parsed.fiber ?? 0);

  const rawItems = Array.isArray(parsed.items) ? parsed.items : [];
  const items = rawItems.map((i: any) => ({
    name: i.name || i.item || i.ingredient || "Item",
    weight: i.weight || (i.weight_g != null ? `${i.weight_g}g` : undefined) || i.portion,
    calories: Number(i.calories ?? i.calories_kcal ?? 0),
    protein: Number(i.protein_g ?? i.protein ?? 0),
    fats: Number(i.fats_g ?? i.fats ?? 0),
    carbs: Number(i.carbs_g ?? i.carbs ?? 0),
  }));

  const cleanedDescription = parsed.cleaned_description ||
    items.map((i: any) => i.weight ? `${i.name} (${i.weight})` : i.name).join(", ");

  return {
    meal_name: dishName,
    calories,
    protein,
    fats,
    carbs,
    fiber,
    items,
    cleaned_description: cleanedDescription,
    confidence: parsed.confidence ?? 0.9,
    health_score: parsed.health_score ?? 8,
  };
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      body = {};
    }

    const images: string[] = Array.isArray(body.images) ? body.images : [];
    const mealName: string = body.meal_name || body.name || body.dish_name || "";
    const ingredientsRaw = body.ingredients || [];
    const ingredients: string[] = Array.isArray(ingredientsRaw)
      ? ingredientsRaw.map((i: any) =>
          typeof i === "string"
            ? i
            : i.name
            ? `${i.name}${i.quantity ? ` (${i.quantity} ${i.unit || ""})` : ""}`
            : JSON.stringify(i)
        )
      : typeof ingredientsRaw === "string" && ingredientsRaw.trim().length > 0
      ? [ingredientsRaw]
      : [];
    const userNote: string = body.user_note || body.note || "";
    const textPrompt: string = body.text_prompt || body.text || "";

    const hasImages = images.length > 0 && typeof images[0] === "string" && images[0].trim().length > 0;
    const cfModel = "@cf/meta/llama-3.2-11b-vision-instruct";

    if (hasImages) {
      // 1. Photo Analysis Flow (Preserved Intact)
      const systemPrompt = `You are a professional nutritionist and food recognition AI.
Analyze the provided food image(s) and estimate the nutritional information with high accuracy.
Return ONLY a valid JSON object without markdown formatting, backticks, or preamble:
{
  "dish_name": "Name of the dish or meal",
  "total_calories": 550,
  "total_protein_g": 35.5,
  "total_fats_g": 18.0,
  "total_carbs_g": 45.0,
  "total_fiber_g": 6.0,
  "health_score": 8,
  "confidence": 0.95,
  "items": [
    {
      "name": "Grilled Chicken Breast",
      "weight_g": 150,
      "calories": 240,
      "protein_g": 31.0,
      "fats_g": 5.0,
      "carbs_g": 0.0,
      "fiber_g": 0.0
    }
  ]
}`;
      const userMessage = userNote ? `Note from user: ${userNote}` : "Analyze this food.";

      const cfResponse = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/ai/run/${cfModel}`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            image: images[0],
            prompt: `${systemPrompt}\n\n${userMessage}`,
            max_tokens: 1024,
          }),
        }
      );

      if (!cfResponse.ok) {
        const errorText = await cfResponse.text();
        throw new Error(`Cloudflare AI error (${cfResponse.status}): ${errorText}`);
      }

      const cfData = await cfResponse.json();
      const rawText = cfData.result?.response || cfData.result?.description || JSON.stringify(cfData.result);
      const cleanedJson = cleanJsonString(rawText);
      const parsed = JSON.parse(cleanedJson);

      return new Response(JSON.stringify(formatNutritionOutput(parsed, mealName || "Analyzed Meal")), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    } else {
      // 2. Text-Based Macro Estimation Flow (Speech-to-Text Conversational Recipe Parsing)
      const mealDescription = mealName || textPrompt || "Meal";
      const ingredientsDescription = ingredients.length > 0 ? ingredients.join(", ") : "Standard recipe ingredients";

      const systemPrompt = `You are a certified nutritionist and speech-to-text food parsing expert.
Analyze the provided conversational speech or recipe text to extract and calculate comprehensive nutritional information.
CRITICAL INSTRUCTIONS:
1. SPEECH-TO-TEXT HANDLING: The input may be conversational transcribed speech (in Russian, English, or mixed) containing filler words ("а", "в", "наверное", "ну"), hesitation phrases, stutter corrections (e.g. "два, нет, один помидор" -> take 1 tomato), and unpunctuated running words. Filter out all speech noise.
2. EXTRACT EVERY INGREDIENT: Identify and parse ALL individual foods mentioned in the recipe without omitting any item. For each item, extract or estimate realistic gram weights (if omitted, default to standard single adult portions), calculate calories and macros (protein, fats, carbs, fiber), and format its display name cleanly in English (or bilingual).
3. ACCUMULATE TOTALS: Calculate total calories, total protein, total fats, total carbs, and total fiber as the sum across ALL recognized ingredients.
4. CLEANED DESCRIPTION: Provide a clean, formatted list of the recognized ingredients with their gram weights.
5. Return ONLY a valid JSON object without markdown formatting, backticks, or commentary in this exact structure:
{
  "dish_name": "${mealDescription}",
  "total_calories": 500,
  "total_protein_g": 30.0,
  "total_fats_g": 15.0,
  "total_carbs_g": 60.0,
  "total_fiber_g": 5.0,
  "health_score": 8,
  "confidence": 0.9,
  "cleaned_description": "Clean list of ingredients with weights",
  "items": [
    {
      "name": "Clean Ingredient Name",
      "weight_g": 100,
      "calories": 200,
      "protein_g": 15.0,
      "fats_g": 5.0,
      "carbs_g": 20.0,
      "fiber_g": 2.0
    }
  ]
}`;

      const userMessage = `Meal: ${mealDescription}\nIngredients: ${ingredientsDescription}${
        userNote ? `\nUser Note: ${userNote}` : ""
      }`;

      const cfResponse = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/ai/run/${cfModel}`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            prompt: `${systemPrompt}\n\n${userMessage}`,
            max_tokens: 1024,
          }),
        }
      );

      if (!cfResponse.ok) {
        const errorText = await cfResponse.text();
        throw new Error(`Cloudflare AI error (${cfResponse.status}): ${errorText}`);
      }

      const cfData = await cfResponse.json();
      const rawText = cfData.result?.response || cfData.result?.description || JSON.stringify(cfData.result);
      const cleanedJson = cleanJsonString(rawText);
      const parsed = JSON.parse(cleanedJson);

      return new Response(JSON.stringify(formatNutritionOutput(parsed, mealDescription)), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }
  } catch (error: any) {
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to process food nutrition request",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
