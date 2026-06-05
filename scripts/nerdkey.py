#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
JSONAPI = "application/vnd.api+json"
UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")


class NerdKeyError(RuntimeError):
    pass


class ApiError(NerdKeyError):
    def __init__(self, status: int, payload: Any, message: str = "") -> None:
        self.status = status
        self.payload = payload
        super().__init__(message or f"Keygen API returned HTTP {status}")


def load_env(path: Path = ENV_PATH) -> dict[str, str]:
    file_env: dict[str, str] = {}
    if path.exists():
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export ") :].strip()
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
                value = value[1:-1]
            file_env[key] = value

    merged = dict(file_env)
    merged.update(os.environ)
    return merged


def require_env(env: dict[str, str], key: str) -> str:
    value = env.get(key, "").strip()
    if not value:
        raise NerdKeyError(f"Missing required environment variable: {key}")
    return value


def env_bool(env: dict[str, str], key: str, default: bool = False) -> bool:
    value = env.get(key)
    if value is None or value == "":
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def replace_env_value(path: Path, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    replaced = False
    output: list[str] = []
    for line in lines:
        candidate = line.strip()
        prefix = "export " if candidate.startswith("export ") else ""
        check = candidate[len(prefix) :] if prefix else candidate
        if check.startswith(f"{key}="):
            output.append(f"{key}={value}")
            replaced = True
        else:
            output.append(line)
    if not replaced:
        output.append(f"{key}={value}")
    path.write_text("\n".join(output) + "\n", encoding="utf-8")


def parse_scalar(value: str) -> Any:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    lowered = value.lower()
    if lowered in {"true", "false"}:
        return lowered == "true"
    if lowered in {"null", "none", "~"}:
        return None
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    return value


def split_yaml_pair(content: str) -> tuple[str, Any]:
    if ":" not in content:
        raise NerdKeyError(f"Invalid products.yaml line: {content}")
    key, value = content.split(":", 1)
    key = key.strip().replace("-", "_")
    value = value.strip()
    return key, None if value == "" else parse_scalar(value)


def load_products(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise NerdKeyError(f"Product registry not found: {path}")

    products: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    section: str | None = None
    seen_root = False

    for raw in path.read_text(encoding="utf-8").splitlines():
        without_comment = raw.split("#", 1)[0].rstrip()
        if not without_comment.strip():
            continue
        indent = len(without_comment) - len(without_comment.lstrip(" "))
        content = without_comment.strip()

        if indent == 0 and content == "products:":
            seen_root = True
            continue
        if not seen_root:
            continue

        if indent == 2 and content.startswith("- "):
            current = {}
            products.append(current)
            section = None
            rest = content[2:].strip()
            if rest:
                key, value = split_yaml_pair(rest)
                current[key] = value
            continue

        if current is None:
            raise NerdKeyError("Invalid products.yaml: product field before product item")

        if indent == 4:
            key, value = split_yaml_pair(content)
            if value is None:
                current[key] = [] if key in {"platforms"} else {}
                section = key
            else:
                current[key] = value
                section = None
            continue

        if indent == 6 and section:
            target = current[section]
            if content.startswith("- "):
                if not isinstance(target, list):
                    raise NerdKeyError(f"Invalid products.yaml: {section} is not a list")
                target.append(parse_scalar(content[2:].strip()))
            else:
                if not isinstance(target, dict):
                    raise NerdKeyError(f"Invalid products.yaml: {section} is not a mapping")
                key, value = split_yaml_pair(content)
                target[key] = value
            continue

        raise NerdKeyError(f"Unsupported products.yaml indentation/content: {raw}")

    for product in products:
        for key in ("slug", "name", "license"):
            if key not in product:
                raise NerdKeyError(f"Product entry is missing `{key}`")
        if not isinstance(product["license"], dict):
            raise NerdKeyError(f"Product `{product['slug']}` license block must be a mapping")
    return products


def write_products(path: Path, products: list[dict[str, Any]]) -> None:
    def emit_scalar(value: Any) -> str:
        if value is True:
            return "true"
        if value is False:
            return "false"
        if value is None:
            return "null"
        return str(value)

    lines = [
        "# NerdKey product registry.",
        "# One product block plus `python3 scripts/nerdkey.py apply` creates/updates Keygen resources.",
        "",
        "products:",
    ]
    for product in products:
        lines.append(f"  - slug: {product['slug']}")
        for key in ("name", "url"):
            if product.get(key):
                lines.append(f"    {key}: {emit_scalar(product[key])}")
        platforms = product.get("platforms", [])
        if platforms:
            lines.append("    platforms:")
            for platform in platforms:
                lines.append(f"      - {emit_scalar(platform)}")
        license_cfg = product.get("license", {})
        lines.append("    license:")
        for key, value in license_cfg.items():
            lines.append(f"      {key}: {emit_scalar(value)}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


class KeygenApi:
    def __init__(self, env: dict[str, str]) -> None:
        host = env.get("KEYGEN_HOST", "nerdkey.localhost")
        self.base_url = env.get("NERDKEY_BASE_URL") or f"https://{host}"
        self.base_url = self.base_url.rstrip("/")
        self.account = env.get("KEYGEN_ACCOUNT_ID", "").strip()
        self.token = env.get("KEYGEN_ADMIN_TOKEN", "").strip()
        self.verify_tls = env_bool(env, "NERDKEY_TLS_VERIFY", default=False)

    def api_path(self, path: str, account: bool = True) -> str:
        if path.startswith("http://") or path.startswith("https://"):
            return path
        if path.startswith("/v1/"):
            return f"{self.base_url}{path}"
        if account:
            if not self.account:
                raise NerdKeyError("Missing KEYGEN_ACCOUNT_ID")
            return f"{self.base_url}/v1/accounts/{self.account}/{path.lstrip('/')}"
        return f"{self.base_url}/v1/{path.lstrip('/')}"

    def request(
        self,
        method: str,
        path: str,
        *,
        body: Any | None = None,
        account: bool = True,
        bearer: str | None = None,
        license_key: str | None = None,
        basic: tuple[str, str] | None = None,
        auth: bool = True,
        query: dict[str, str] | None = None,
        ok: tuple[int, ...] = (200, 201, 204),
    ) -> Any:
        url = self.api_path(path, account=account)
        if query:
            url = f"{url}?{urllib.parse.urlencode(query)}"

        headers = {"Accept": JSONAPI}
        data = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = JSONAPI

        if basic:
            raw = f"{basic[0]}:{basic[1]}".encode("utf-8")
            headers["Authorization"] = f"Basic {base64.b64encode(raw).decode('ascii')}"
        elif license_key:
            headers["Authorization"] = f"License {license_key}"
        elif auth:
            token = bearer if bearer is not None else self.token
            if token:
                headers["Authorization"] = f"Bearer {token}"

        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        context = None
        if url.startswith("https://") and not self.verify_tls:
            context = ssl._create_unverified_context()
        try:
            with urllib.request.urlopen(request, context=context, timeout=30) as response:
                raw_body = response.read()
                if response.status not in ok:
                    raise ApiError(response.status, raw_body.decode("utf-8", errors="replace"))
                if not raw_body or not raw_body.strip():
                    return None
                text = raw_body.decode("utf-8")
                try:
                    return json.loads(text)
                except json.JSONDecodeError:
                    return {"body": text}
        except urllib.error.HTTPError as exc:
            raw_body = exc.read().decode("utf-8", errors="replace")
            try:
                payload = json.loads(raw_body)
            except json.JSONDecodeError:
                payload = raw_body
            raise ApiError(exc.code, payload) from exc
        except urllib.error.URLError as exc:
            raise NerdKeyError(f"Unable to reach Keygen at {url}: {exc.reason}") from exc

    def list_all(self, resource: str) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        next_path: str | None = resource
        while next_path:
            payload = self.request("GET", next_path)
            data = payload.get("data", [])
            if isinstance(data, dict):
                return [data]
            items.extend(data)
            next_link = payload.get("links", {}).get("next")
            if isinstance(next_link, dict):
                next_path = next_link.get("href")
            else:
                next_path = next_link
        return items


def api_error_summary(error: ApiError) -> str:
    payload = error.payload
    if isinstance(payload, dict) and "errors" in payload:
        parts = []
        for item in payload["errors"]:
            title = item.get("title") or item.get("code") or "error"
            detail = item.get("detail") or item.get("message")
            parts.append(f"{title}: {detail}" if detail else str(title))
        return "; ".join(parts)
    return str(payload)


def product_attrs(product: dict[str, Any]) -> dict[str, Any]:
    attrs = {
        "name": product["name"],
        "code": product["slug"],
        "metadata": {"source": "products.yaml", "nerdkeyProduct": product["slug"]},
    }
    if product.get("url"):
        attrs["url"] = product["url"]
    if product.get("platforms"):
        attrs["platforms"] = product["platforms"]
    return attrs


def policy_attrs(product: dict[str, Any]) -> dict[str, Any]:
    license_cfg = product["license"]
    seats = int(license_cfg.get("seats", 2))
    attrs = {
        "name": license_cfg.get("name", "Perpetual 2-seat"),
        "duration": None if license_cfg.get("model", "perpetual") == "perpetual" else license_cfg.get("duration"),
        "scheme": license_cfg.get("scheme", "ED25519_SIGN"),
        "strict": bool(license_cfg.get("strict", True)),
        "floating": bool(license_cfg.get("floating", seats > 1)),
        "protected": bool(license_cfg.get("protected", False)),
        "requireFingerprintScope": bool(license_cfg.get("require_fingerprint_scope", True)),
        "machineUniquenessStrategy": license_cfg.get("machine_uniqueness_strategy", "UNIQUE_PER_LICENSE"),
        "machineMatchingStrategy": license_cfg.get("machine_matching_strategy", "MATCH_ALL"),
        "machineLeasingStrategy": license_cfg.get("machine_leasing_strategy", "PER_LICENSE"),
        "overageStrategy": license_cfg.get("overage_strategy", "NO_OVERAGE"),
        "expirationStrategy": license_cfg.get("expiration_strategy", "RESTRICT_ACCESS"),
        "authenticationStrategy": license_cfg.get("authentication_strategy", "LICENSE"),
        "maxMachines": seats,
        "metadata": {"source": "products.yaml", "nerdkeyProduct": product["slug"]},
    }
    if seats > 1:
        attrs["floating"] = True
    return attrs


def policy_update_attrs(existing_policy: dict[str, Any], desired_attrs: dict[str, Any]) -> dict[str, Any]:
    existing_attrs = existing_policy.get("attributes", {})
    existing_scheme = existing_attrs.get("scheme")
    desired_scheme = desired_attrs.get("scheme")
    if existing_scheme and desired_scheme and existing_scheme != desired_scheme:
        raise NerdKeyError(
            "Existing Keygen policy has immutable scheme "
            f"`{existing_scheme}`, but products.yaml requests `{desired_scheme}`. "
            "Create a new policy or reset the local database."
        )

    attrs = dict(desired_attrs)
    attrs.pop("scheme", None)
    return attrs


def write_policy_reference(product: dict[str, Any]) -> None:
    out_dir = ROOT / "policies" / "products"
    out_dir.mkdir(parents=True, exist_ok=True)
    document = {
        "product": product_attrs(product),
        "policy": policy_attrs(product),
    }
    (out_dir / f"{product['slug']}.json").write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def find_product(api: KeygenApi, slug: str) -> dict[str, Any] | None:
    for item in api.list_all("products"):
        attrs = item.get("attributes", {})
        metadata = attrs.get("metadata", {}) or {}
        if attrs.get("code") == slug or metadata.get("nerdkeyProduct") == slug:
            return item
    return None


def find_policy(api: KeygenApi, product_id: str, name: str, slug: str) -> dict[str, Any] | None:
    for item in api.list_all("policies"):
        attrs = item.get("attributes", {})
        metadata = attrs.get("metadata", {}) or {}
        related_product = item.get("relationships", {}).get("product", {}).get("data", {}) or {}
        if related_product.get("id") != product_id:
            continue
        if attrs.get("name") == name or metadata.get("nerdkeyProduct") == slug:
            return item
    return None


def ensure_product_and_policy(api: KeygenApi, product: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    slug = product["slug"]
    attrs = product_attrs(product)
    existing_product = find_product(api, slug)
    if existing_product:
        product_id = existing_product["id"]
        product_payload = {
            "data": {
                "type": "products",
                "id": product_id,
                "attributes": attrs,
            }
        }
        keygen_product = api.request("PATCH", f"products/{product_id}", body=product_payload)["data"]
        print(f"updated product {slug} ({product_id})")
    else:
        product_payload = {"data": {"type": "products", "attributes": attrs}}
        keygen_product = api.request("POST", "products", body=product_payload)["data"]
        product_id = keygen_product["id"]
        print(f"created product {slug} ({product_id})")

    p_attrs = policy_attrs(product)
    existing_policy = find_policy(api, product_id, p_attrs["name"], slug)
    if existing_policy:
        policy_id = existing_policy["id"]
        policy_payload = {
            "data": {
                "type": "policies",
                "id": policy_id,
                "attributes": policy_update_attrs(existing_policy, p_attrs),
            }
        }
        keygen_policy = api.request("PATCH", f"policies/{policy_id}", body=policy_payload)["data"]
        print(f"updated policy {p_attrs['name']} ({policy_id})")
    else:
        policy_payload = {
            "data": {
                "type": "policies",
                "attributes": p_attrs,
                "relationships": {
                    "product": {
                        "data": {"type": "products", "id": product_id},
                    },
                },
            }
        }
        keygen_policy = api.request("POST", "policies", body=policy_payload)["data"]
        print(f"created policy {p_attrs['name']} ({keygen_policy['id']})")

    write_policy_reference(product)
    return keygen_product, keygen_policy


def selected_products(env: dict[str, str], slug: str | None = None) -> list[dict[str, Any]]:
    path = ROOT / env.get("NERDKEY_PRODUCTS_FILE", "products.yaml")
    products = load_products(path)
    if slug is None:
        return products
    matches = [product for product in products if product["slug"] == slug]
    if not matches:
        raise NerdKeyError(f"Unknown product slug in products.yaml: {slug}")
    return matches


def resolve_policy(api: KeygenApi, env: dict[str, str], slug: str) -> dict[str, Any]:
    product = selected_products(env, slug)[0]
    keygen_product = find_product(api, slug)
    if not keygen_product:
        keygen_product, keygen_policy = ensure_product_and_policy(api, product)
        return keygen_policy
    p_attrs = policy_attrs(product)
    keygen_policy = find_policy(api, keygen_product["id"], p_attrs["name"], slug)
    if not keygen_policy:
        _, keygen_policy = ensure_product_and_policy(api, product)
    return keygen_policy


def find_license(api: KeygenApi, identifier: str) -> dict[str, Any]:
    if UUID_RE.match(identifier):
        return api.request("GET", f"licenses/{identifier}")["data"]
    for item in api.list_all("licenses"):
        if item.get("attributes", {}).get("key") == identifier:
            return item
    raise NerdKeyError("License not found by id or key")


def print_json(payload: Any) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def account_public_keys_from_rails(env: dict[str, str]) -> dict[str, str]:
    account_id = require_env(env, "KEYGEN_ACCOUNT_ID")
    if not UUID_RE.match(account_id):
        raise NerdKeyError("KEYGEN_ACCOUNT_ID must be a UUID before reading account keys from Keygen")

    ruby = (
        "require 'base64'; require 'json'; "
        f"account = Account.find('{account_id}'); "
        "puts({"
        "ed25519: Base64.strict_encode64(account.ed25519_public_key), "
        "rsa2048: Base64.strict_encode64(account.public_key), "
        "ecdsa: Base64.strict_encode64(account.ecdsa_public_key)"
        "}.to_json)"
    )
    result = subprocess.run(
        ["docker", "compose", "exec", "-T", "web", "bin/rails", "runner", ruby],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "docker compose exec failed"
        raise NerdKeyError(f"Unable to read public keys from local Keygen container: {detail}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise NerdKeyError("Keygen container returned invalid public-key JSON") from exc
    return {str(key): str(value) for key, value in payload.items()}


def cmd_health(args: argparse.Namespace, env: dict[str, str]) -> int:
    payload = KeygenApi(env).request("GET", "health", account=False, auth=False)
    print_json(payload)
    return 0


def cmd_token_issue(args: argparse.Namespace, env: dict[str, str]) -> int:
    email = args.email or require_env(env, "KEYGEN_ADMIN_EMAIL")
    password = args.password or require_env(env, "KEYGEN_ADMIN_PASSWORD")
    api = KeygenApi(env)
    payload = api.request("POST", "tokens", basic=(email, password), auth=False)
    token = payload["data"]["attributes"]["token"]
    print(token)
    if args.save:
        replace_env_value(ENV_PATH, "KEYGEN_ADMIN_TOKEN", token)
        print(f"saved KEYGEN_ADMIN_TOKEN to {ENV_PATH}", file=sys.stderr)
    return 0


def cmd_account_public_key(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    try:
        payload = api.request("GET", f"/v1/accounts/{api.account}", account=False)
        keys = payload.get("meta", {}).get("keys", {})
    except ApiError as exc:
        if exc.status != 404:
            raise
        keys = account_public_keys_from_rails(env)
    if args.json:
        print_json(keys)
    else:
        print(keys.get("ed25519", ""))
    return 0


def cmd_apply(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    for product in selected_products(env, args.product):
        ensure_product_and_policy(api, product)
    return 0


def cmd_product_add(args: argparse.Namespace, env: dict[str, str]) -> int:
    path = ROOT / env.get("NERDKEY_PRODUCTS_FILE", "products.yaml")
    products = load_products(path)
    if any(product["slug"] == args.slug for product in products):
        raise NerdKeyError(f"Product already exists in products.yaml: {args.slug}")
    products.append(
        {
            "slug": args.slug,
            "name": args.name,
            "url": args.url,
            "platforms": args.platforms,
            "license": {
                "name": args.policy_name,
                "model": "perpetual",
                "seats": args.seats,
                "scheme": "ED25519_SIGN",
                "floating": args.seats > 1,
                "strict": True,
                "require_fingerprint_scope": True,
                "machine_uniqueness_strategy": "UNIQUE_PER_LICENSE",
                "machine_matching_strategy": "MATCH_ALL",
                "machine_leasing_strategy": "PER_LICENSE",
                "overage_strategy": "NO_OVERAGE",
                "authentication_strategy": "LICENSE",
            },
        }
    )
    write_products(path, products)
    print(f"added product {args.slug} to {path}")
    return 0


def cmd_license_issue(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    policy = resolve_policy(api, env, args.product)
    attrs: dict[str, Any] = {
        "name": args.name or f"{args.product} license",
        "metadata": {
            "source": "nerdkey",
            "nerdkeyProduct": args.product,
        },
    }
    if args.email:
        attrs["metadata"]["customerEmail"] = args.email
    payload = {
        "data": {
            "type": "licenses",
            "attributes": attrs,
            "relationships": {
                "policy": {"data": {"type": "policies", "id": policy["id"]}},
            },
        }
    }
    result = api.request("POST", "licenses", body=payload)["data"]
    if args.json:
        print_json(result)
    else:
        attrs = result["attributes"]
        print(f"id={result['id']}")
        print(f"key={attrs['key']}")
        print(f"status={attrs['status']}")
    return 0


def cmd_license_list(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    product_id = None
    if args.product:
        product = find_product(api, args.product)
        if not product:
            raise NerdKeyError(f"Product not found in Keygen: {args.product}")
        product_id = product["id"]

    licenses = []
    for item in api.list_all("licenses"):
        rel_product = item.get("relationships", {}).get("product", {}).get("data", {}) or {}
        if product_id and rel_product.get("id") != product_id:
            continue
        licenses.append(item)

    if args.json:
        print_json(licenses)
        return 0

    for item in licenses:
        attrs = item.get("attributes", {})
        key = attrs.get("key", "")
        short_key = key if len(key) <= 36 else f"{key[:18]}...{key[-12:]}"
        print(f"{item['id']}\t{attrs.get('status')}\t{attrs.get('name')}\t{short_key}")
    return 0


def cmd_license_revoke(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    license_obj = find_license(api, args.license)
    result = api.request("DELETE", f"licenses/{license_obj['id']}/actions/revoke")
    print_json(result)
    return 0


def cmd_license_validate(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    meta: dict[str, Any] = {"key": args.key}
    if args.fingerprint:
        meta["scope"] = {"fingerprint": args.fingerprint}
    payload = api.request(
        "POST",
        "licenses/actions/validate-key",
        body={"meta": meta},
        auth=False,
    )
    if args.json:
        print_json(payload)
    else:
        validation = payload.get("meta", {})
        print(f"valid={validation.get('valid')}")
        print(f"detail={validation.get('detail')}")
        data = payload.get("data")
        if isinstance(data, dict):
            print(f"id={data.get('id')}")
            print(f"status={data.get('attributes', {}).get('status')}")
    return 0 if payload.get("meta", {}).get("valid") else 1


def cmd_license_checkout(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    license_obj = find_license(api, args.license)
    query = {}
    if args.algorithm:
        query["algorithm"] = args.algorithm
    if args.ttl:
        query["ttl"] = str(args.ttl)
    payload = api.request("POST", f"licenses/{license_obj['id']}/actions/check-out", query=query)
    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"wrote license checkout response to {out}")
    else:
        print_json(payload)
    return 0


def cmd_machine_activate(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    license_obj = find_license(api, args.license) if not UUID_RE.match(args.license) else api.request("GET", f"licenses/{args.license}")["data"]
    license_key = args.key or license_obj["attributes"]["key"]
    body = {
        "data": {
            "type": "machines",
            "attributes": {
                "fingerprint": args.fingerprint,
                "platform": args.platform,
                "name": args.name or args.fingerprint,
            },
            "relationships": {
                "license": {"data": {"type": "licenses", "id": license_obj["id"]}},
            },
        }
    }
    try:
        payload = api.request("POST", "machines", body=body, license_key=license_key, auth=False)
    except ApiError as exc:
        if args.expect_failure:
            print(f"expected failure: HTTP {exc.status} {api_error_summary(exc)}")
            return 0
        raise

    if args.expect_failure:
        raise NerdKeyError("Machine activation succeeded but failure was expected")
    if args.json:
        print_json(payload)
    else:
        data = payload["data"]
        print(f"id={data['id']}")
        print(f"fingerprint={data['attributes']['fingerprint']}")
    return 0


def cmd_machine_deactivate(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    api.request("DELETE", f"machines/{args.machine}", ok=(200, 202, 204))
    print(f"deactivated machine {args.machine}")
    return 0


def cmd_smoke(args: argparse.Namespace, env: dict[str, str]) -> int:
    api = KeygenApi(env)
    require_env(env, "KEYGEN_ADMIN_TOKEN")
    product_slug = args.product
    print("health")
    cmd_health(argparse.Namespace(), env)

    print("apply")
    for product in selected_products(env, product_slug):
        ensure_product_and_policy(api, product)

    stamp = int(time.time())
    issue_args = argparse.Namespace(
        product=product_slug,
        email=f"smoke-{stamp}@nerdsmiths.test",
        name=f"Smoke {stamp}",
        json=True,
    )
    policy = resolve_policy(api, env, product_slug)
    payload = {
        "data": {
            "type": "licenses",
            "attributes": {
                "name": issue_args.name,
                "metadata": {
                    "source": "nerdkey-smoke",
                    "nerdkeyProduct": product_slug,
                    "customerEmail": issue_args.email,
                },
            },
            "relationships": {
                "policy": {"data": {"type": "policies", "id": policy["id"]}},
            },
        }
    }
    license_obj = api.request("POST", "licenses", body=payload)["data"]
    license_key = license_obj["attributes"]["key"]
    print(f"issued license {license_obj['id']}")

    for seat in (1, 2):
        fp = f"nerdkey-smoke-seat-{seat}-{stamp}"
        machine_args = argparse.Namespace(
            license=license_obj["id"],
            key=license_key,
            fingerprint=fp,
            platform="smoke",
            name=f"Smoke seat {seat}",
            expect_failure=False,
            json=False,
        )
        cmd_machine_activate(machine_args, env)

    validate_args = argparse.Namespace(key=license_key, fingerprint=f"nerdkey-smoke-seat-1-{stamp}", json=False)
    if cmd_license_validate(validate_args, env) != 0:
        raise NerdKeyError("Smoke validation failed for activated seat")

    third_args = argparse.Namespace(
        license=license_obj["id"],
        key=license_key,
        fingerprint=f"nerdkey-smoke-seat-3-{stamp}",
        platform="smoke",
        name="Smoke seat 3",
        expect_failure=True,
        json=False,
    )
    cmd_machine_activate(third_args, env)

    print("license list")
    cmd_license_list(argparse.Namespace(product=product_slug, json=False), env)

    print("revoke")
    cmd_license_revoke(argparse.Namespace(license=license_obj["id"]), env)
    print("PASS")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="nerdkey", description="NerdKey admin CLI for self-hosted Keygen CE")
    sub = parser.add_subparsers(dest="command", required=True)

    health = sub.add_parser("health")
    health.set_defaults(func=cmd_health)

    apply_cmd = sub.add_parser("apply")
    apply_cmd.add_argument("--product")
    apply_cmd.set_defaults(func=cmd_apply)

    smoke = sub.add_parser("smoke")
    smoke.add_argument("--product", default="nerdsmiths-demo")
    smoke.set_defaults(func=cmd_smoke)

    token = sub.add_parser("token")
    token_sub = token.add_subparsers(dest="token_command", required=True)
    token_issue = token_sub.add_parser("issue")
    token_issue.add_argument("--email")
    token_issue.add_argument("--password")
    token_issue.add_argument("--save", action="store_true")
    token_issue.set_defaults(func=cmd_token_issue)

    account = sub.add_parser("account")
    account_sub = account.add_subparsers(dest="account_command", required=True)
    account_key = account_sub.add_parser("public-key")
    account_key.add_argument("--json", action="store_true")
    account_key.set_defaults(func=cmd_account_public_key)

    product = sub.add_parser("product")
    product_sub = product.add_subparsers(dest="product_command", required=True)
    product_add = product_sub.add_parser("add")
    product_add.add_argument("--slug", required=True)
    product_add.add_argument("--name", required=True)
    product_add.add_argument("--url", default="")
    product_add.add_argument("--platforms", nargs="*", default=["macOS", "Windows"])
    product_add.add_argument("--seats", type=int, default=2)
    product_add.add_argument("--policy-name", default="Perpetual 2-seat")
    product_add.set_defaults(func=cmd_product_add)

    license_cmd = sub.add_parser("license")
    license_sub = license_cmd.add_subparsers(dest="license_command", required=True)
    license_issue = license_sub.add_parser("issue")
    license_issue.add_argument("--product", required=True)
    license_issue.add_argument("--email")
    license_issue.add_argument("--name")
    license_issue.add_argument("--json", action="store_true")
    license_issue.set_defaults(func=cmd_license_issue)

    license_list = license_sub.add_parser("list")
    license_list.add_argument("--product")
    license_list.add_argument("--json", action="store_true")
    license_list.set_defaults(func=cmd_license_list)

    license_revoke = license_sub.add_parser("revoke")
    license_revoke.add_argument("license", help="license id or key")
    license_revoke.set_defaults(func=cmd_license_revoke)

    license_validate = license_sub.add_parser("validate")
    license_validate.add_argument("--key", required=True)
    license_validate.add_argument("--fingerprint")
    license_validate.add_argument("--json", action="store_true")
    license_validate.set_defaults(func=cmd_license_validate)

    license_checkout = license_sub.add_parser("checkout")
    license_checkout.add_argument("license", help="license id or key")
    license_checkout.add_argument("--algorithm")
    license_checkout.add_argument("--ttl", type=int)
    license_checkout.add_argument("--output")
    license_checkout.set_defaults(func=cmd_license_checkout)

    machine = sub.add_parser("machine")
    machine_sub = machine.add_subparsers(dest="machine_command", required=True)
    machine_activate = machine_sub.add_parser("activate")
    machine_activate.add_argument("--license", required=True, help="license id or key")
    machine_activate.add_argument("--key", help="license key; inferred when admin token can read license")
    machine_activate.add_argument("--fingerprint", required=True)
    machine_activate.add_argument("--platform", default="unknown")
    machine_activate.add_argument("--name")
    machine_activate.add_argument("--expect-failure", action="store_true")
    machine_activate.add_argument("--json", action="store_true")
    machine_activate.set_defaults(func=cmd_machine_activate)

    machine_deactivate = machine_sub.add_parser("deactivate")
    machine_deactivate.add_argument("machine")
    machine_deactivate.set_defaults(func=cmd_machine_deactivate)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    env = load_env()
    try:
        return args.func(args, env)
    except ApiError as exc:
        print(f"error: HTTP {exc.status}: {api_error_summary(exc)}", file=sys.stderr)
        return 1
    except NerdKeyError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
