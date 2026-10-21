# LiteLLM 运维看板

基于 LiteLLM 代理 PostgreSQL 表 `"LiteLLM_SpendLogs"` 的六面板 Grafana 看板套件——用量总览、token 分析、流式延迟（TTFT/E2E/TPOT）与按 key 下钻。一条命令即可在全新 Grafana 上完整导入。English version: [README.md](README.md)。

## 特性

- 六个看板：用量总览、模型组合并汇总、token 分析、可调时间桶柱状/折线图、带失败请求明细表的 "Search Agent" 变体、面向客户的 "MaaS Operation Dashboard"。
- 流式延迟指标：TTFT、E2E、TPOT，外加非流式的提示词处理吞吐。
- 一键导入脚本，全新 Grafana 上完整复现。
- 完全离线运行；凭据来自权限 600 的环境变量文件，不写在代码里。
- 文字结论跟随调用方语言（`output_locale: auto | en | zh-CN`），指标与 SQL 与语言无关。

## 环境要求

- Grafana 11.x，可通过 HTTP 访问，具备管理员凭据（basic auth）。
- 指向 LiteLLM 数据库的 PostgreSQL 数据源（`litellm_db`，SELECT 权限即可），记下其 `uid`。
- 直连验证需要 `pg8000`。

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

## 快速上手

```bash
# 将全部六个看板导入目标 Grafana
GRAFANA_URL=http://<主机>:3000 GRAFANA_USER=admin GRAFANA_PASS=<密码> \
DATASOURCE_UID=<数据源uid> scripts/import-dashboards.sh
```

迁移步骤、指标定义、定时任务、截图渲染、错误分析、已知坑点与验证方法见 `SKILL.md`。

## 许可证

MIT
