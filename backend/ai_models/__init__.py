"""Calories Guard AI layer — Ollama-backed LLM + Thai nutrition agents."""
from ai_models import llm_provider
from ai_models.coach_agent import CoachAgent
from ai_models.nutrition_analysis import NutritionAnalysisAgent

__all__ = [
    "llm_provider",
    "CoachAgent",
    "NutritionAnalysisAgent",
]
