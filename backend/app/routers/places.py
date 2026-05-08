"""Google Places proxy — Nearby Search + Photo.

Mobile clients calling maps.googleapis.com with an API key restricted to
Android/iOS apps often get REQUEST_DENIED on the legacy REST endpoints.
Proxying through the backend uses a server-side key (IP or unrestricted + API restrictions).
"""

from __future__ import annotations

import os
from typing import Any, Dict, Optional

import requests
from fastapi import APIRouter, HTTPException, Request, Response
from slowapi import Limiter
from slowapi.util import get_remote_address

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)

_NEARBY_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
_PHOTO_URL = "https://maps.googleapis.com/maps/api/place/photo"


def _maps_key() -> str:
    return os.getenv("GOOGLE_MAPS_API_KEY", "").strip()


@router.get("/places/nearby")
@limiter.limit("40/minute")
def places_nearby(
    request: Request,
    lat: float,
    lng: float,
    radius: int = 1000,
    keyword: Optional[str] = None,
) -> Dict[str, Any]:
    """Proxy to Places API Nearby Search. Returns Google's JSON (incl. status, results)."""
    key = _maps_key()
    if not key:
        raise HTTPException(
            status_code=503,
            detail="Places search unavailable (GOOGLE_MAPS_API_KEY not set)",
        )
    if radius < 100 or radius > 50000:
        raise HTTPException(status_code=400, detail="radius must be between 100 and 50000")
    params: Dict[str, str] = {
        "location": f"{lat},{lng}",
        "radius": str(radius),
        "type": "restaurant",
        "language": "th",
        "key": key,
    }
    if keyword and keyword.strip():
        params["keyword"] = keyword.strip()
    try:
        r = requests.get(_NEARBY_URL, params=params, timeout=25)
        r.raise_for_status()
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"Upstream Places error: {e}") from e
    try:
        return r.json()
    except ValueError as e:
        raise HTTPException(status_code=502, detail="Invalid JSON from Places") from e


@router.get("/places/photo")
@limiter.limit("120/minute")
def place_photo(
    request: Request,
    photo_reference: str,
    maxwidth: int = 400,
) -> Response:
    """Proxy Place Photos. Follows redirect to final image bytes."""
    key = _maps_key()
    if not key:
        raise HTTPException(
            status_code=503,
            detail="Place photo unavailable (GOOGLE_MAPS_API_KEY not set)",
        )
    if maxwidth < 1 or maxwidth > 1600:
        raise HTTPException(status_code=400, detail="maxwidth must be 1-1600")
    # photo_reference can be long; pass as query param
    try:
        r = requests.get(
            _PHOTO_URL,
            params={
                "maxwidth": maxwidth,
                "photo_reference": photo_reference,
                "key": key,
            },
            timeout=30,
            allow_redirects=True,
        )
        r.raise_for_status()
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"Upstream photo error: {e}") from e
    ct = r.headers.get("content-type", "image/jpeg").split(";")[0].strip()
    return Response(content=r.content, media_type=ct)
