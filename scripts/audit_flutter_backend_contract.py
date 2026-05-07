#!/usr/bin/env python3
"""Audit Flutter API calls against FastAPI route declarations.

This catches the common integration failure where the mobile app calls an
endpoint that no longer exists or uses the wrong HTTP method. It is deliberately
static and dependency-free so it can run in CI on any platform.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROUTERS = REPO_ROOT / "backend" / "app" / "routers"
BACKEND_MAIN = REPO_ROOT / "backend" / "main.py"
FLUTTER_LIB = REPO_ROOT / "flutter_application_1" / "lib"


@dataclass(frozen=True)
class Route:
    method: str
    path: str
    source: Path
    line: int

    @property
    def pattern(self) -> re.Pattern[str]:
        path = self.path.rstrip("/") or "/"
        regex = "^" + re.sub(r"\{[^/]+\}", r"[^/]+", path) + "/?$"
        return re.compile(regex)


@dataclass(frozen=True)
class ApiCall:
    method: str
    path: str
    source: Path
    line: int

    @property
    def comparable_path(self) -> str:
        return self.path.split("?")[0].rstrip("/") or "/"


METHOD_MAP = {
    "get": "GET",
    "post": "POST",
    "put": "PUT",
    "patch": "PATCH",
    "delete": "DELETE",
    "uploadBytes": "POST",
    "uploadFile": "POST",
}


def _line_number(text: str, offset: int) -> int:
    return text[:offset].count("\n") + 1


def collect_backend_routes() -> list[Route]:
    routes: list[Route] = []
    route_re = re.compile(r"@(router|app)\.(get|post|put|patch|delete)\([\"']([^\"']+)")
    files = sorted(BACKEND_ROUTERS.glob("*.py")) + [BACKEND_MAIN]
    for source in files:
        text = source.read_text(encoding="utf-8")
        for match in route_re.finditer(text):
            routes.append(
                Route(
                    method=match.group(2).upper(),
                    path=match.group(3),
                    source=source,
                    line=_line_number(text, match.start()),
                )
            )
    return routes


def collect_flutter_calls() -> list[ApiCall]:
    calls: list[ApiCall] = []
    call_patterns = [
        re.compile(
            r"ApiClient\(\)\.(get|post|put|patch|delete|uploadBytes|uploadFile)"
            r"\(\s*([\"'])([^\"']+)\2",
            re.S,
        ),
        re.compile(
            r"_api\.(get|post|put|patch|delete|uploadBytes|uploadFile)"
            r"\(\s*([\"'])([^\"']+)\2",
            re.S,
        ),
    ]
    direct_base_re = re.compile(r"AppConstants\.baseUrl\}/([^'\"\)]+)")

    for source in sorted(FLUTTER_LIB.rglob("*.dart")):
        text = source.read_text(encoding="utf-8")
        for pattern in call_patterns:
            for match in pattern.finditer(text):
                calls.append(
                    ApiCall(
                        method=METHOD_MAP[match.group(1)],
                        path=match.group(3),
                        source=source,
                        line=_line_number(text, match.start()),
                    )
                )

        for match in direct_base_re.finditer(text):
            calls.append(
                ApiCall(
                    method="GET",
                    path="/" + match.group(1),
                    source=source,
                    line=_line_number(text, match.start()),
                )
            )
    return calls


def route_matches(call: ApiCall, routes: list[Route]) -> bool:
    return any(
        route.method == call.method and route.pattern.match(call.comparable_path)
        for route in routes
    )


def rel(path: Path) -> str:
    return path.relative_to(REPO_ROOT).as_posix()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    routes = collect_backend_routes()
    calls = collect_flutter_calls()
    unmatched = [call for call in calls if not route_matches(call, routes)]

    print(f"Backend routes: {len(routes)}")
    print(f"Flutter API calls: {len(calls)}")
    print(f"Unmatched calls: {len(unmatched)}")

    if args.verbose:
        print("\nMatched calls:")
        for call in sorted(calls, key=lambda c: (str(c.source), c.line)):
            status = "OK" if route_matches(call, routes) else "MISSING"
            print(
                f"{status:7} {call.method:6} {call.path:45} "
                f"{rel(call.source)}:{call.line}"
            )

    if unmatched:
        print("\nMissing backend route matches:")
        for call in unmatched:
            print(f"- {call.method} {call.path} at {rel(call.source)}:{call.line}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
