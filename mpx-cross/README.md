# imink 跨端迁移（MPX 版本）

这个目录是把原 SwiftUI 项目迁移到 MPX 的第一版可运行骨架，目标是：

1. 保留核心功能（登录、主页、对战、鲑鱼跑、我的）。
2. 将 Swift 页面逐个映射为 MPX 页面（已生成 77 个页面占位）。
3. 数据层从本地 SQLite 迁移到 MySQL（本地开发环境先搭建）。

## 目录说明

- `src/`: MPX 前端代码。
  - `pages/login|home|battle|coop|me|trash`: 核心页面。
  - `pages/swift/**`: 与每个 Swift 页面一一对应的迁移占位页面。
  - `pages/swift-index`: Swift -> MPX 路由映射索引。
- `server/`: Node.js + Express + MySQL API 服务。
  - `sql/schema.mysql.sql`: MySQL 建表脚本（按 SplatDatabase 的表族适配）。
  - `sql/seed.sql`: 示例数据。

## 与原生特性差异（本版已移除/降级）

- 已移除 iOS 原生特性：
  - Widget / Live Activity。
  - Haptics 精细触感反馈。
  - SwiftUI 原生动画效果（替换为跨端通用布局）。
- 保留并迁移：
  - 登录鉴权流程。
  - 对战和鲑鱼跑记录查看。
  - 基础个人中心数据。

## 本地搭建 MySQL

1. 创建数据库与表结构：

```bash
mysql -uroot -p < server/sql/schema.mysql.sql
```

2. 复制配置：

```bash
cd server
cp .env.example .env
```

3. 启动服务：

```bash
npm i
npm run dev
```

4. 导入示例数据（可选）：

```bash
mysql -uroot -p < server/sql/seed.sql
```

## 登录方式

- 默认账号：`demo`
- 默认密码：`demo123456`
- 登录接口：`POST /api/auth/login`
- 登录后使用 `Bearer token` 访问：
  - `/api/auth/profile`
  - `/api/schedules`
  - `/api/battles`
  - `/api/coops`

## 说明

`SplatDatabase` 仓库在网络受限环境下无法直接拉取 SQL，因此本版基于该仓库 README 中公开的表集合做了兼容性 MySQL 建模。后续你可以把官方字段逐表补齐到 `schema.mysql.sql`。
