#!/usr/bin/env python3
"""重新生成 imink 的 `splatnet3_webview_data.json`（SplatNet 3 的 web_app_ver + GraphQL hash）。

为什么需要它：SplatNet 3 的 GraphQL 是 persisted query，请求体里必须带
`extensions.persistedQuery.sha256Hash`，这个 hash 只能从官方 web app 的 JS 里抽。
Nintendo 每次发版都会换 build（`10.0.0-xxxxxxxx`），hash 也可能跟着变；
如果用旧 hash 请求，服务端会返回 `PersistedQueryNotFound` 或直接的 4xx。

数据来源（都是公开的）：
  1. `https://cdn.jsdelivr.net/gh/nintendoapis/nintendo-app-versions/data/splatnet3-app.json`
     → `web_app_ver`（build 号，同时就是 `X-Web-View-Ver`）、`script_url`、`graphql_queries`
  2. `script_url` 指向的 `main.<hash>.js`，里面每个 query 都有
     `params:{id:"<sha256>",metadata:{},name:"<OperationName>",operationKind:"query"}`

用法：
    python3 script/update-splatnet3-webview-data.py --check
        只比对打包内的 json 与线上是否一致，不一致时打印有差异的 query（不写文件）。
    python3 script/update-splatnet3-webview-data.py
        把线上数据写回 Shared/SplatNet3/splatnet3_webview_data.json。

退出码：0 一致/已更新，1 有差异（--check），2 拉取失败。
"""

import argparse
import json
import pathlib
import re
import sys
import urllib.request

APP_VERSIONS_URL = (
    "https://cdn.jsdelivr.net/gh/nintendoapis/nintendo-app-versions/data/splatnet3-app.json"
)
TARGET = pathlib.Path(__file__).resolve().parent.parent / "Shared/SplatNet3/splatnet3_webview_data.json"

# main.js 里 Relay 编译产物的形状：
#   params:{id:"e11a8cf2...",metadata:{},name:"CoopHistoryQuery",operationKind:"query"
QUERY_RE = re.compile(
    r'params:\{id:"([0-9a-f]{64})",metadata:\{\},name:"([A-Za-z0-9_]+)",operationKind:"(\w+)"'
)


def fetch(url: str, timeout: int = 30) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "imink-update-webview/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def live_configuration() -> tuple[str, dict, str]:
    meta = json.loads(fetch(APP_VERSIONS_URL))
    web_app_ver = meta["web_app_ver"]
    script_url = meta["script_url"]

    queries: dict[str, str] = dict(meta.get("graphql_queries") or {})

    # graphql_queries 已经带了 113 条，但还是从 JS 里再抽一遍：
    # 版本服务偶尔滞后，JS 才是服务端真正校验的那份。
    js = fetch(script_url).decode("utf-8", "replace")
    from_js = {name: sha for sha, name, kind in QUERY_RE.findall(js) if kind == "query"}
    if not from_js:
        print("warning: JS 里没抽到任何 query，只用版本服务的 graphql_queries", file=sys.stderr)

    conflicts = {k: (queries.get(k), v) for k, v in from_js.items() if queries.get(k) not in (None, v)}
    if conflicts:
        print(f"warning: 版本服务与 JS 不一致，以 JS 为准：{conflicts}", file=sys.stderr)
    queries.update(from_js)

    return web_app_ver, queries, script_url


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="只比对，不写文件")
    parser.add_argument("--out", default=str(TARGET), help="输出路径")
    args = parser.parse_args()

    try:
        web_app_ver, queries, script_url = live_configuration()
    except Exception as error:  # noqa: BLE001 - 网络/JSON 失败统一报错
        print(f"拉取线上配置失败：{error}", file=sys.stderr)
        return 2

    bundled = json.loads(pathlib.Path(args.out).read_text())
    bundled_version = bundled.get("version")
    bundled_hashes = bundled.get("graphql", {}).get("hash_map", {})

    stale = {k: (bundled_hashes.get(k, "")[:8], v[:8]) for k, v in queries.items()
             if bundled_hashes.get(k) != v}
    missing = [k for k in queries if k not in bundled_hashes]
    extra = [k for k in bundled_hashes if k not in queries]

    print(f"live   web_app_ver={web_app_ver}  queries={len(queries)}")
    print(f"bundled version={bundled_version}  queries={len(bundled_hashes)}  script={script_url}")

    if args.check:
        if not stale and not missing and bundled_version == web_app_ver:
            print("OK：打包内数据与线上一致")
            return 0
        print(f"DIFF：{len(stale)} 个 hash 不同，{len(missing)} 个缺失，{len(extra)} 个线上已移除")
        for name, (old, new) in sorted(stale.items()):
            print(f"  hash  {name}: {old} -> {new}")
        for name in missing:
            print(f"  miss  {name}")
        for name in extra:
            print(f"  extra {name}（线上已没有，保留无害）")
        return 1

    bundled["version"] = web_app_ver
    bundled.setdefault("graphql", {})["hash_map"] = queries
    pathlib.Path(args.out).write_text(
        json.dumps(bundled, ensure_ascii=False, indent=2) + "\n"
    )
    print(f"已写入 {args.out}（{len(queries)} 个 query，web_app_ver={web_app_ver}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
