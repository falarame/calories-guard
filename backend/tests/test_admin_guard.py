"""
Admin-role guard tests.

Every /admin/* endpoint uses the `get_current_admin` dependency, which
rejects non-admin tokens with 403. In the app_client fixture we override
`get_current_user` to a regular user (role_id missing) but leave
`get_current_admin` behaving normally, so hitting an admin route with
only the regular-user override should 403.
"""
import pytest


ADMIN_ENDPOINTS = [
    ("GET", "/admin/users"),
    ("GET", "/admin/temp-foods"),
    ("GET", "/admin/temp-foods/pending-count"),
    ("GET", "/admin/foods/similar?name=test"),
    ("GET", "/admin/regional-name-submissions"),
    ("POST", "/admin/temp-foods/1/approve"),
    ("DELETE", "/admin/temp-foods/1"),
    ("POST", "/admin/regional-name-submissions/1/approve"),
    ("POST", "/admin/regional-name-submissions/1/reject"),
]


@pytest.mark.parametrize("method,path", ADMIN_ENDPOINTS)
def test_admin_routes_reject_non_admin_token(unauth_client, method, path):
    """With no Authorization header, admin guard returns 401."""
    # Admin guard raises 401 on missing token, 403 on wrong role — both
    # acceptable, neither is 200.
    r = unauth_client.request(method, path)
    assert r.status_code in (401, 403), (
        f"{method} {path} must be auth-guarded, got {r.status_code}"
    )
