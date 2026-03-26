import os
import logging
import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

OFF_BASE_URL = "https://world.openfoodfacts.org/cgi/search.pl"

app = FastAPI(title="Food Nutrition API")


class NutritionInfo(BaseModel):
    food_name:       str
    source:          str
    serving_size_g:  float | None = None
    calories_kcal:   float | None = None
    total_fat_g:     float | None = None
    saturated_fat_g: float | None = None
    trans_fat_g:     float | None = None
    cholesterol_mg:  float | None = None
    sodium_mg:       float | None = None
    total_carbs_g:   float | None = None
    dietary_fiber_g: float | None = None
    total_sugars_g:  float | None = None
    protein_g:       float | None = None
    vitamin_d_mcg:   float | None = None
    calcium_mg:      float | None = None
    iron_mg:         float | None = None
    potassium_mg:    float | None = None


async def fetch_off(food_name: str) -> NutritionInfo | None:
    log.info(f"[OpenFoodFacts] Searching for '{food_name}' ...")
    async with httpx.AsyncClient() as client:
        resp = await client.get(OFF_BASE_URL, params={
            "search_terms":  food_name,
            "search_simple": 1,
            "action":        "process",
            "json":          1,
            "page_size":     1,
        })
        resp.raise_for_status()
        products = resp.json().get("products", [])
        if not products:
            log.info(f"[OpenFoodFacts] No results for '{food_name}'")
            return None

        p          = products[0]
        nutriments = p.get("nutriments", {})
        name       = p.get("product_name", food_name)
        log.info(f"[OpenFoodFacts] Found '{name}'")

        def mg(val):
            return val * 1000 if val is not None else None

        return NutritionInfo(
            food_name       = name,
            source          = "Open Food Facts",
            serving_size_g  = p.get("serving_quantity"),
            calories_kcal   = nutriments.get("energy-kcal_100g"),
            total_fat_g     = nutriments.get("fat_100g"),
            saturated_fat_g = nutriments.get("saturated-fat_100g"),
            trans_fat_g     = nutriments.get("trans-fat_100g"),
            cholesterol_mg  = mg(nutriments.get("cholesterol_100g")),
            sodium_mg       = mg(nutriments.get("sodium_100g")),
            total_carbs_g   = nutriments.get("carbohydrates_100g"),
            dietary_fiber_g = nutriments.get("fiber_100g"),
            total_sugars_g  = nutriments.get("sugars_100g"),
            protein_g       = nutriments.get("proteins_100g"),
            vitamin_d_mcg   = nutriments.get("vitamin-d_100g"),
            calcium_mg      = mg(nutriments.get("calcium_100g")),
            iron_mg         = mg(nutriments.get("iron_100g")),
            potassium_mg    = mg(nutriments.get("potassium_100g")),
        )


@app.get("/nutrition/{food_name}", response_model=NutritionInfo)
async def get_nutrition(food_name: str):
    log.info(f"[API] GET /nutrition/{food_name}")
    result = await fetch_off(food_name)
    if not result:
        raise HTTPException(status_code=404, detail=f"No nutrition data found for '{food_name}'")
    return result


@app.get("/health")
async def health():
    return {"status": "ok"}