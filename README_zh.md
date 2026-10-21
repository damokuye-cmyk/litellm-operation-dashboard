# LiteLLM 运维看板（Litellm Operation Dashboard）

在本技能中部署、维护并在不同 Grafana 实例间迁移基于 LiteLLM 代理 PostgreSQL 表 `"LiteLLM_SpendLogs"` 的六看板 Grafana 分析包。支持中英双语。英文主文档见 [README.md](README.md)。

本技能由原 `litellm-spendlogs-dashboards-en` / `-cn` 两个 skill 整合而来，共享的看板、脚本与表结构参考与原始版本逐字节一致。

## 特性

- 六个看板：用量总览、模型组合并汇总、token 分析、可调时间桶柱状/折线图、"Search Agent" 变体（含失败请求明细表）、以及面向客户的 "MaaS Operation Dashboard"。
- 流式延迟指标：TTFT、E2E、TPOT 与非流式提示词处理吞吐。
- 一键导入脚本，可在全新的 Grafana 上完整复现。
- 通过 `output_locale` 参数（`auto | en | zh-CN`）实现语言自适应输出。
- 完全离线运行；凭据来自权限 600 的环境变量文件，绝不写死。

## 环境要求

- Grafana 11.x 可经 HTTP 访问；管理员凭据（basic auth）。
- 指向 LiteLLM 数据库（`litellm_db`，SELECT 权限用户）的 PostgreSQL 数据源，记下其 `uid`。
- 直连验证用 `pg8000`。

## 目录结构

```
SKILL.md                          双语使用说明（英文主序 + 行内中文）
README.md                         本文件（英文主序）
README_zh.md                      中文翻译
references/schema-and-metrics.md  SQL 参考、指标守卫、合理范围（语言无关）
assets/dashboards/                6 个看板 JSON
scripts/import-dashboards.sh      一键导入到目标 Grafana
scripts/update-key-group.sh       更新全部 6 个看板的 api_key 成员
scripts/render-dashboard.sh       无头 Chrome 看板截图 -> PNG（环境变量驱动）
```

## 快速上手

```bash
# 将全部六个看板导入目标 Grafana
GRAFANA_URL=http://<主机>:3000 GRAFANA_USER=admin GRAFANA_PASS=<密码> \
DATASOURCE_UID=<数据源uid> scripts/import-dashboards.sh
```

详细流程、指标定义、调度、渲染、错误分析、坑点与验证见 `SKILL.md`。

## 许可证

MIT
