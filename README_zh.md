# LiteLLM 运维看板

基于 LiteLLM 代理 PostgreSQL 表 `"LiteLLM_SpendLogs"` 的六面板 Grafana 看板套件——用量总览、token 分析、流式延迟（TTFT/E2E/TPOT）与按 key 下钻。一条命令即可在全新 Grafana 上完整导入。English version: [README.md](README.md)。

## 目录

- [看板清单](#看板清单)
- [特性](#特性)
- [环境要求](#环境要求)
- [快速上手](#快速上手)
- [目录结构](#目录结构)
- [已知坑点](#已知坑点)
- [文档](#文档)
- [许可证](#许可证)

## 看板清单

| 看板 | 内容 |
|---|---|
| litellm-dashboard.json | 按模型的总览与请求标签矩阵。 |
| litellm-dashboard-grouped.json | `key_group` 过滤、模型组合并、流式指标（TTFT/E2E/TPOT）。 |
| litellm-dashboard-tokens.json | token 分布、分位数、输出/输入比。 |
| litellm-dashboard-grouped-bars.json | 可调时间桶（5 分钟～7 天）：数量柱状、延迟折线。 |
| litellm-dashboard-bars-search-agent.json | 在上一块基础上将 api_key 重命名为 **Search Agent**，附失败请求明细表。 |
| maas-operation-dashboard-customer.json | 面向客户的 "MaaS Operation Dashboard"（N1–N20 布局），同一 `key_group` 变量。 |

所有分组图共用一套配色：glm-text = 绿、deepseek-v4-flash = 蓝、glm53-flash = 橙、Search Agent = 紫、`<none>` = 灰。

## 特性

- 流式延迟指标：TTFT、E2E、TPOT，外加非流式的提示词处理吞吐。
- 一键导入脚本，全新 Grafana 上完整复现。
- 完全离线运行；凭据来自权限 600 的环境变量文件，不写在代码里。
- 文字结论跟随调用方语言（`output_locale: auto | en | zh-CN`），指标与 SQL 与语言无关。
- 随附表结构与指标参考文档，含有效性过滤与实测值范围。

## 环境要求

| 组件 | 要求 |
|---|---|
| Grafana | 11.x，可通过 HTTP 访问，具备管理员凭据（basic auth） |
| PostgreSQL 数据源 | 指向 LiteLLM 数据库（`litellm_db`），SELECT 权限即可 |
| Python | 直连验证需要 `pg8000`（无需 psql 客户端） |

## 快速上手

```bash
# 将全部六个看板导入目标 Grafana
GRAFANA_URL=http://<主机>:3000 GRAFANA_USER=admin GRAFANA_PASS=<密码> \
DATASOURCE_UID=<数据源uid> scripts/import-dashboards.sh
```

## 目录结构

```
SKILL.md                                操作手册（英文）
README.md                               英文版说明
README_zh.md                            中文版说明（本文件）
references/schema-and-metrics.md        SQL 参考、有效性过滤、实测值范围
assets/dashboards/                      6 个看板 JSON
scripts/import-dashboards.sh            一键导入到目标 Grafana
scripts/update-key-group.sh             一次更新全部 6 个看板的 api_key 成员
scripts/render-dashboard.sh             无头 Chrome 看板截图 -> PNG（环境变量驱动）
```

## 已知坑点

动手改看板之前建议先知道这几条；完整清单在 `SKILL.md`：

- 表名与列名大小写敏感——`"LiteLLM_SpendLogs"`、`"startTime"`、`"endTime"` 必须加双引号。
- 看板变量必须放在 `templating.list` 而非 `templating.var`；放错位置所有面板都会 500。
- LiteLLM 未配置成本追踪时 `spend` 全为 0.0。

## 文档

| 文档 | 用途 |
|---|---|
| [SKILL.md](SKILL.md) | 完整操作流程：迁移步骤、指标定义、定时任务、截图渲染、错误分析与验证 |
| [references/schema-and-metrics.md](references/schema-and-metrics.md) | SpendLogs 表结构、指标公式、有效性过滤、实测值范围 |
| [README.md](README.md) | 本文件的英文版 |

## 许可证

MIT
