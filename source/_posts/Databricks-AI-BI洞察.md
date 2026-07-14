---
title: Databricks-AI-BI洞察
date: 2026-07-15 12:00:00
tags: AI
categories: 学习
---

### 1. Summary 概要

Databricks 以 AI/BI Genie（Compound AI 系统）+ Unity Catalog（统一治理）+ Delta Lake UniForm（开放表格式）构成湖仓一体的 AI 查询与治理方案。其开源语义层核心、ABAC 治理、Iceberg 互操作能力与 Snowflake 形成差异化对比，对产品线三库查询服务的语义层演进与开放存储选型具有横向参考价值。

### 2. Motivation 动机

1、产品线统一 SQL 查询服务当前依赖 AI 生成统一 SQL → Calcite 方言改写 → 下推 StarRocks/Druid/GaussDB 三库执行。上一篇 Snowflake 报告已结论：语义层编译器内改写不可直接移植（单引擎约束），可借鉴语义模型 YAML + VQR + 多模型选优。本篇是第 2 篇，分析 Databricks 这一 Snowflake 主要竞争对手的方案，形成横向对比，明确两个标杆在 AI 查询和开放存储层两个维度的差异与选型方向。

2、Databricks 是 DB-Engines 排名第 7 的数据平台（2026-07，164 分）[[E1]]，收入从 $5.4B 年化（2026-02，>65% YoY）[[E2]] 增长至 $6.9B 年化（2026-06，>80% YoY）[[E3]]，增速高于 Snowflake 同期。电信行业有 AT&T（10+PB/天数据，1.82 亿无线用户，300% 5 年 ROI）[[E4]][[E5]]、Nokia 合作（2026-06）[[E6]] 等采纳案例。其 AI/BI Genie + Unity Catalog + Delta Lake 组合代表了湖仓架构下 AI 查询 + 治理一体化 + 开放表格式的工程路径，值得深度拆解并与 Snowflake 横向对比。

3、开放表格式与目录标准正在分化：Delta Lake UniForm（Delta→Iceberg 单向读）与 Apache Polaris（中立目录，多引擎读写）代表两条路线，与产品线已采用的 StarRocks 存在交汇点，需评估布局时机。

    a、Apache Polaris 2026-02 毕业 TLP，支持 StarRocks/Trino/Spark/Flink/Dremio 等多引擎 [[E7]]，产品线 StarRocks 已具备对接条件。
    b、Unity Catalog OSS 已捐赠 Linux Foundation（LF AI & Data），Apache 2.0，支持 Delta/Iceberg/Hudi 多格式 [[E8]]，形成与 Polaris 的目录层竞争。
    c、Delta UniForm IcebergCompatV2 异步生成 Iceberg 元数据，不重写数据文件，单份数据支持双格式 [[E9]]，是 Databricks 的互操作路径。

### 3. 洞察内容

> 主要分析 Databricks AI/BI Genie 的 Compound AI 推理流水线、Unity Catalog 的 ABAC 治理与血缘、Delta UniForm 的 Iceberg 互操作、Metric Views 语义层，以及与产品线查询服务和 Snowflake 的横向对比。

#### 3.1 关键竞争力

Databricks 在 AI 查询与治理领域的竞争力可归纳为三个支柱。

**支柱一：Compound AI 系统 Genie。** Genie 不是单一 LLM，而是 Compound AI 系统，使用 Chain-of-Thought 推理：识别列→规划 SQL→组合查询 [[E10]]。Agent Mode 使用 Claude Sonnet 模型支持多步推理 [[E11]]。反馈机制有三优先级：SQL 表达式（定义 revenue/active_customers 等业务语义）> 示例 SQL 查询 > 文本指令 [[E12]]。Databricks 建议域特定问题准确率超过 80% 后再进入 UAT [[E13]]，说明 Genie 的准确率是可度量、可分阶段提升的。

**支柱二：统一治理 + 开放表格式。** Unity Catalog 三级命名空间 catalog.schema.table，四种访问控制：GRANT/REVOKE + ABAC 标签策略 + 行列过滤器/脱敏 + 工作区绑定 [[E14]]，自动列级血缘跨工作区聚合 [[E15]]。Delta UniForm IcebergCompatV2 异步生成 Iceberg 元数据，不重写数据文件 [[E9]]，实现单份数据双格式。这是与 Snowflake 封闭生态的根本差异——Databricks 通过开源 Unity Catalog OSS（捐赠 LF [[E8]]）和 UniForm 互操作构建开放生态。

**支柱三：开源语义层 + 向量化执行。** Metric Views 2026-04 GA，YAML 定义 source/joins/fields/measures/filter，核心已开源到 Apache Spark（SPARK-54119）[[E16]][[E17]]。Photon 是 C++ 向量化执行引擎，替代 JVM Spark SQL，客户工作负载平均 3x 加速、最高 10x [[E18]]，TPC-DS 100TB 世界纪录（2021-11）[[E18]]。语义层开源 + 执行引擎向量化构成"语义可移植 + 性能有保障"的组合。

#### 3.2 软件架构

Databricks 湖仓架构可分三层：

```
┌──────────────────────────────────────────────────────────┐
│              Unity Catalog（统一治理层）                    │
│  三级命名空间 catalog.schema.table                         │
│  ABAC标签 + 行列过滤/脱敏 + GRANT/REVOKE + 工作区绑定       │
│  自动列级血缘 / 跨工作区聚合                                │
│  ┌──────────────────────────────────────────────────┐    │
│  │  Metric Views（语义层，2026-04 GA）                │    │
│  │  YAML 定义 → MEASURE() 函数查询 / 语义元数据增强   │    │
│  └──────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────┤
│              Photon 执行引擎（计算层）                      │
│  C++ 向量化执行 / Catalyst 优化器查询规划                  │
│  不支持算子回退 Spark / TPC-DS 100TB 世界纪录              │
│  SQL 级 AI 函数：ai_query（通用，支持托管+外部模型）        │
├──────────────────────────────────────────────────────────┤
│              Delta Lake（存储层）                           │
│  事务日志 / UniForm IcebergCompatV2 / 单份数据双格式        │
│  Iceberg 客户端只读访问                                    │
└──────────────────────────────────────────────────────────┘
```

关键架构特征：

* Unity Catalog 是全局统一治理层，覆盖所有计算引擎（SQL Warehouse/Spark/Photon），非单引擎绑定 [[E14]]
* Photon 接管执行层，Catalyst 优化器仍做查询规划 [[E19]]，混合执行时不支持的算子回退 Spark [[E18]]
* Delta Lake UniForm 在存储层实现 Iceberg 互操作，无需数据迁移 [[E9]]
* Metric Views 作为语义层嵌入 Unity Catalog，与治理一体化 [[E16]]
* SQL 级 AI 函数 ai_query 支持调用 Databricks 托管模型（databricks-gpt-5-2、databricks-claude-sonnet-4-6 等）及外部模型 [[E20]]，旧函数 ai_generate_text 已废弃 [[E21]]

**与 Snowflake 架构的根本差异：** Snowflake 是单引擎封闭架构，语义改写在编译器内完成；Databricks 是湖仓架构，治理层（UC）、执行层（Photon）、存储层（Delta）解耦，语义层（Metric Views）作为 UC 内嵌对象而非编译器内改写。这意味着 Databricks 的语义层理论上可跨引擎复用（核心已开源到 Spark [[E16]]），而 Snowflake 的 Semantic Views 不可移植。

**与产品线架构的差异：** 产品线是三引擎联邦架构（StarRocks/Druid/GaussDB），无统一治理层，语义改写依赖 Calcite 事后方言翻译。Databricks 的 UC 统一治理 + Metric Views 语义层的组合，为产品线"统一治理 + 语义层"演进提供了另一种参考架构——但产品线的"统一"需要跨三库，复杂度高于 Databricks 单平台内的统一。

#### 3.3 AI/BI Genie 深度解析

##### Chain-of-Thought 推理流水线（关键能力）

Genie 是 Compound AI 系统，非单一 LLM [[E10]]。其核心推理流水线采用 Chain-of-Thought：

```
用户自然语言问题
         │
         ▼
┌────────────────────┐
│ 1. 列识别           │── 从 Genie Space 元数据中识别相关列
└────────┬───────────┘
         ▼
┌────────────────────┐
│ 2. SQL 规划         │── 规划查询结构与 JOIN 路径
└────────┬───────────┘
         ▼
┌────────────────────┐
│ 3. 查询组合         │── 组合生成最终 SQL
└────────┬───────────┘
         ▼
    最终 SQL + 结果
```

设计要点分析 [[E10]][[E22]]：

* 步骤 1（列识别）依赖 Genie Space 的表/列元数据，每个 Space 最多 30 张表 [[E23]]，限制范围以提高识别准确率
* 步骤 2（SQL 规划）将问题分解为查询结构规划，而非直接生成完整 SQL，降低一次性生成的错误率
* 步骤 3（查询组合）在规划基础上组合最终 SQL，Chain-of-Thought 的分步推理降低复杂查询的错误率

与 Snowflake Cortex Analyst 六阶段 Agent 流水线对比：Genie 的三步 CoT 更轻量，Cortex 的六阶段更精细（含分类、特征提取、上下文增强、多模型生成、错误纠正、综合选优）。两者都采用分步推理降低单模型错误率，但 Cortex 的工程化程度更高（多模型并行 + 编译器校验闭环），Genie 更依赖单一 LLM（Claude Sonnet）的推理能力 [[E11]]。

##### 专家反馈学习机制（关键能力）

Genie 的反馈机制有三优先级 [[E12]]：

```
优先级 1（最高）：SQL 表达式
  ── 定义 revenue、active_customers 等业务语义的精确 SQL 表达式
  ── AI 直接采用，消除语义歧义

优先级 2：示例 SQL 查询
  ── 提供问题→SQL 的示例对
  ── 作为 few-shot 参考引导生成

优先级 3（最低）：文本指令
  ── 自然语言描述的业务规则
  ── AI 需自行理解并翻译为 SQL
```

反馈机制的核心设计：SQL 表达式优先级最高，因为它直接定义业务语义的精确 SQL，消除 AI 理解歧义；文本指令优先级最低，因为自然语言本身存在歧义 [[E12]]。

用户正面反馈可触发 Genie 建议新 SQL 片段 [[E22]]：当用户标记某个回答为正确时，Genie 会分析该查询并建议将其作为新的示例 SQL 或 SQL 表达式加入 Space，形成"使用→反馈→学习→建议"的闭环。

与 Snowflake VQR 对比：

| 维度 | Databricks Genie | Snowflake Cortex Analyst |
|------|------------------|--------------------------|
| 反馈载体 | SQL 表达式 + 示例 SQL + 文本指令 | Verified Query Repository |
| 优先级机制 | 三级优先级（SQL > 示例 > 文本）[[E12]] | VQR 检索 + 语义搜索 |
| 自动学习 | 用户正面反馈→建议新 SQL 片段 [[E22]] | 分析 VQR 使用模式→建议语义模型改进 |
| 准确率门槛 | 域特定问题 80% 后进入 UAT [[E13]] | 90%+（企业测试）|

关键差异：Genie 的反馈机制更侧重"业务语义精确定义"（SQL 表达式优先），Cortex 的 VQR 更侧重"已验证查询检索复用"。两者思路互补——产品线可同时借鉴：SQL 表达式定义核心业务指标（如"活跃用户数"的精确 SQL），VQR 收集已验证查询作为 few-shot 参考。

##### Agent Mode 多步推理（关键能力）

Agent Mode 使用 Claude Sonnet 模型，支持多步推理 [[E11]]：

```
用户复杂问题（需多步推理）
         │
         ▼
┌────────────────────────────┐
│ Agent Mode（Claude Sonnet）│
│  ├── 拆解子问题             │
│  ├── 逐步生成 SQL           │
│  ├── 执行中间查询           │
│  └── 基于结果继续推理       │
└────────┬───────────────────┘
         ▼
    多步推理结果
```

Agent Mode 的价值：处理需要多步推理的复杂问题（如"对比上季度 Top10 客户的本季度消费变化"），单次 CoT 不足以处理，需要 Agent 拆解为多个子查询并基于中间结果继续推理 [[E11]]。

限制 [[E11]][[E23]]：

* Agent Mode 仅 UI 可用，API 不支持——无法集成到产品线查询服务
* 每个 Genie Space 最多 30 张表——复杂业务域需拆分多个 Space
* 只读查询，不支持写操作
* 不解释结果——只返回数据，不提供分析洞察

第三方基准对比（2025-03）[[E24]]：Snowflake Cortex Analyst 在季度格式识别上优于 Genie，Cortex 自动填充样本值，Genie 当时无此能力。这说明 Genie 在某些语义理解场景上不如 Cortex，但 Databricks 持续迭代（如 Agent Mode 的多步推理能力）。

Genie Conversation API（2025-03 Public Preview）[[E25]]：

```
POST /api/2.0/genie/spaces/{space_id}/start-conversation
```

API 支持编程式调用 Genie，但 Agent Mode 不在 API 支持范围内 [[E11]]。这意味着产品线若集成 Genie，只能通过 API 使用基础 CoT 推理，无法使用 Agent Mode 的多步推理能力——这是集成时的能力边界。

#### 3.4 Unity Catalog + Delta UniForm 深度解析

##### ABAC 治理与血缘（关键能力）

Unity Catalog 三级命名空间 catalog.schema.table，四种访问控制 [[E14]]：

| 控制类型 | 机制 | 适用场景 |
|----------|------|----------|
| GRANT/REVOKE | RBAC 角色权限 | 基础权限管理 |
| ABAC 标签策略 | 基于标签的属性访问控制 | 按数据分类（如 PII）控制访问 |
| 行列过滤器/脱敏 | 行级安全 + 列脱敏 | 细粒度数据保护 |
| 工作区绑定 | 工作区与 Catalog 绑定 | 工作区隔离 |

自动列级血缘跨工作区聚合 [[E15]]：UC 自动捕获列级血缘，跨工作区聚合，提供端到端数据血缘可视化。这对产品线"数据血缘跨三库追踪"有参考价值——当前产品线三库各自独立，缺乏统一血缘视图。

跨引擎策略不自动同步 [[E26]]：Snowflake 可通过 Catalog-Linked Databases（CLD，2025-10 GA）读写 UC 表，但每个平台在自己计算引擎上执行自己的策略——UC 的策略不会自动同步到 Snowflake 引擎。这意味着 UC 的统一治理是"Databricks 平台内统一"，跨引擎时治理策略仍需各引擎独立维护。

与 Snowflake Horizon 对比 [[E26]][[E8]][[E7]]：

| 维度 | Databricks Unity Catalog | Snowflake Horizon |
|------|--------------------------|-------------------|
| 命名空间 | 三级 catalog.schema.table [[E14]] | 三级 database.schema.table |
| 访问控制 | RBAC + ABAC + 行列过滤/脱敏 + 工作区绑定 [[E14]] | RBAC + 动态数据掩码 + 行访问策略 + 标签 |
| 血缘 | 自动列级，跨工作区 [[E15]] | 列级血缘 |
| 开源 | UC OSS 捐赠 LF，Apache 2.0 [[E8]] | Horizon 未开源 |
| 跨引擎 | CLD 读写 UC 表，策略不自动同步 [[E26]] | Polaris 目录支持多引擎 [[E7]] |

关键差异：UC OSS 已开源捐赠 LF [[E8]]，是 Databricks 推动开放治理生态的布局；Snowflake Horizon 未开源，但其 Polaris 目录支持多引擎读写 [[E7]]。两者在"开放"路径上不同——Databricks 开源治理层，Snowflake 推动目录标准。

##### Delta UniForm Iceberg 互操作（关键能力）

Delta UniForm IcebergCompatV2 的核心机制 [[E9]]：

```
Delta 表（原数据格式）
   │
   ├── 数据文件（Parquet，不变）
   │
   └── IcebergCompatV2
        │
        ├── 异步生成 Iceberg 元数据（不重写数据文件）
        │
        └── Iceberg 客户端只读访问
```

DDL 语法 [[E9]]：

```sql
CREATE TABLE orders (
  order_id BIGINT,
  customer_id BIGINT,
  order_total DECIMAL(10,2)
)
USING DELTA
TBLPROPERTIES (
  'delta.enableIcebergCompatV2'='true',
  'delta.universalFormat.enabledFormats'='iceberg'
);
```

关键特性 [[E9]][[E27]]：

* 异步生成 Iceberg 元数据，不重写数据文件——零数据迁移成本
* 单份数据支持 Delta + Iceberg 双格式
* Iceberg 客户端只读，不支持写——写入仍需通过 Delta
* GA 基准：Databricks 声称比 Snowflake 快 6x Parquet 摄入、成本低 90% [[E27]]

与 Apache Polaris 对比 [[E7]][[E8]]：

| 维度 | Delta UniForm | Apache Polaris |
|------|---------------|----------------|
| 互操作方向 | Delta→Iceberg 单向读 [[E9]] | 中立目录，多引擎读写 [[E7]] |
| 数据格式 | Delta 主，Iceberg 元数据只读 | Iceberg 原生 |
| 引擎支持 | Iceberg 客户端只读 | StarRocks/Trino/Spark/Flink/Dremio [[E7]] |
| 开放性 | Databricks 主导 | Apache TLP（2026-02）[[E7]] |

关键差异：UniForm 是"Delta 为主，Iceberg 为辅"的单向互操作；Polaris 是"中立目录，多引擎平等读写"的开放标准。产品线若选择 Iceberg 化路径，Polaris 的多引擎读写能力（含 StarRocks [[E7]]）比 UniForm 的单向读更契合三库联邦需求。

##### Metric Views 语义层（关键能力）

Metric Views 2026-04 GA，YAML 定义 source/joins/fields/measures/filter，核心已开源到 Apache Spark（SPARK-54119）[[E16]][[E17]]：

```yaml
# Metric View YAML 结构 [[E17]]
name: orders_metric_view
description: "Order revenue analysis"
source:
  table: orders
  fields:
    - name: order_id
      expr: order_id
    - name: order_month
      expr: date_trunc('month', order_date)
joins:
  - name: customers
    source:
      table: customers
    on: orders.customer_id = customers.customer_id
    fields:
      - name: customer_name
        expr: c_name
measures:
  - name: Total Revenue
    expr: SUM(order_total)
    format: currency
    display_name: "总收入"
    synonyms: ["revenue", "营收"]
filter:
  - name: active_orders
    expr: status = 'active'
```

查询使用 MEASURE() 函数 [[E28]]：

```sql
SELECT order_month, MEASURE("Total Revenue")
FROM orders_metric_view
GROUP BY order_month;
```

语义元数据增强 BI 和 LLM [[E29]]：display_name（显示名）、format（格式化）、synonyms（同义词）等语义元数据同时服务于 BI 工具和 LLM，让 AI 理解"总收入"="revenue"="营收"是同一指标。

与 Snowflake Semantic Views 对比 [[E30]]：

| 维度 | Databricks Metric Views | Snowflake Semantic Views |
|------|-------------------------|--------------------------|
| GA 时间 | 2026-04 [[E16]] | 2025-11（GA）|
| 定义格式 | YAML [[E17]] | YAML + DDL |
| 查询接口 | MEASURE() 函数 [[E28]] | SEMANTIC_VIEW() + AGG() |
| 改写位置 | 运行时（Spark/Photon）| 编译器内 |
| 开源 | 核心开源到 Apache Spark（SPARK-54119）[[E16]] | 未开源 |
| 平台锁定 | 单平台，但核心开源可移植 [[E30]] | 单平台，不可移植 [[E30]] |
| 语义元数据 | display_name/format/synonyms [[E29]] | synonyms/description |

关键差异：两者都是原生对象、单平台锁定 [[E30]]，但 Databricks 开源了 Metric Views 核心到 Apache Spark [[E16]]，理论上可在非 Databricks Spark 上运行；Snowflake Semantic Views 未开源，完全锁定。产品线若采用开源语义层，Metric Views 的核心（SPARK-54119）比 Snowflake 的专有方案更具可移植性。

#### 3.5 与产品线查询服务及 Snowflake 的对比

| 维度 | Databricks | Snowflake | 产品线 As-Is | 产品线 To-Be |
|------|------------|-----------|-------------|-------------|
| 架构 | 湖仓（UC+Photon+Delta）| 单引擎封闭 | 三引擎联邦 | 三引擎联邦 |
| AI 查询 | Genie（Compound AI，CoT）[[E10]] | Cortex Analyst（六阶段 Agent）| AI 生成统一 SQL | 语义模型驱动生成 |
| AI 模型 | Claude Sonnet（Agent Mode）[[E11]] | 多模型并行选优 | 单模型 | 多模型选优 |
| 反馈学习 | SQL 表达式 > 示例 > 文本 [[E12]] | VQR 检索 + 语义搜索 | 无 | 可借鉴两者 |
| 准确率 | 域特定 80% 后 UAT [[E13]] | 90%+（企业测试）| 无系统化方法 | 需建立 |
| 语义层 | Metric Views（YAML，开源核心）[[E16]] | Semantic Views（编译器内，未开源）| 无 | 可借鉴 YAML 规范 |
| 语义查询 | MEASURE() 函数 [[E28]] | SEMANTIC_VIEW() + AGG() | 无 | 评估 |
| 治理 | UC（RBAC+ABAC+行列过滤+工作区绑定）[[E14]] | Horizon（RBAC+掩码+行策略+标签）| 各库独立 | 需设计跨库治理 |
| 血缘 | 自动列级，跨工作区 [[E15]] | 列级血缘 | 各库独立 | 可借鉴 |
| 开放表格式 | Delta UniForm（Delta→Iceberg 单向读）[[E9]] | Polaris（多引擎读写）[[E7]] | 无 | 评估 Polaris |
| 目录标准 | UC OSS（捐赠 LF）[[E8]] | Polaris（TLP）[[E7]] | 无 | 评估 |
| 执行引擎 | Photon C++ 向量化（3x-10x）[[E18]] | 自研 MPP | StarRocks/Druid/GaussDB | 保持三库 |
| SQL 级 AI | ai_query（托管+外部模型）[[E20]] | Cortex AI Functions | 无 | 评估 |
| API 集成 | Conversation API（无 Agent Mode）[[E25]] | REST API | 内部 API | 评估 |
| 联邦下推 | 不支持（数据需入湖仓）| 不支持（ingestion-based）| 支持（实时下推三库）| 保持 |

**对比关键结论：**

1、**可借鉴：** Metric Views YAML 规范（source/joins/fields/measures/filter 五层结构，核心开源 [[E16]]）、语义元数据（display_name/format/synonyms [[E29]]）增强 AI 理解、Genie 三级反馈优先级（SQL 表达式 > 示例 > 文本 [[E12]]）、UC 自动列级血缘 [[E15]]、Photon 向量化执行思路（StarRocks 已有向量化，可参考混合执行回退机制 [[E18]]）。

2、**不可借鉴：** Genie Agent Mode（仅 UI，API 不支持 [[E11]]）、UniForm 的 Delta→Iceberg 单向读（产品线需要多引擎读写，Polaris 更契合 [[E7]]）、UC 的跨引擎策略不自动同步 [[E26]]（产品线三库治理仍需独立设计）。

3、**根本差异：** Databricks 和 Snowflake 的语义层都建立在"数据已入平台"前提上，产品线语义层需处理"数据分布在三库"的现实。Databricks 的优势是语义层核心开源 [[E16]]，理论上可移植；Snowflake 的优势是六阶段 Agent 工程化程度更高、准确率数据更充分。产品线的核心差异化仍是"感知三库能力差异，事前生成各库 SQL"——这是两个标杆都未解决的领域。

### 4. 我们现状与下一步

**现状（As-Is）：**

* AI 生成统一 SQL → Calcite 方言改写 → 下推 StarRocks/Druid/GaussDB 三库执行
* Druid 报文场景等价函数依赖风险已验证失败
* 无系统化准确率测试方法、无反馈学习机制、无语义模型层、无统一治理层

**下一步建议（分层）：**

| 层级 | 建议项 | 依据 | 优先级 |
|------|--------|------|--------|
| 验证项 | 语义模型 YAML 规范草案，参考 Metric Views 五层结构（source/joins/fields/measures/filter） | 开源核心 SPARK-54119 [[E16]]，YAML 规范 [[E17]] | 高 |
| 验证项 | 语义元数据增加 synonyms/display_name/format 字段，增强 AI 语义理解 | Databricks 语义元数据设计 [[E29]] | 高 |
| 验证项 | 反馈机制按三级优先级设计：SQL 表达式（核心指标定义）> 示例 SQL > 文本指令 | Genie 反馈优先级 [[E12]] | 高 |
| 验证项 | 语义层增加 engine_capabilities 字段，AI 生成时感知目标引擎直接生成该库 SQL | 产品线三引擎方言差异是核心问题 | 高 |
| 验证项 | 准确率门槛设定（如域特定 80% 后进入 UAT），建立分阶段提升机制 | Databricks 80% UAT 门槛 [[E13]] | 中 |
| 观察项 | Apache Polaris 对接评估（StarRocks 已支持），作为开放目录标准 | Polaris 多引擎读写 [[E7]]，TLP 毕业 | 中 |
| 观察项 | Unity Catalog OSS 跟踪（已捐赠 LF），评估作为统一治理层参考 | UC OSS 开源 [[E8]] | 中 |
| 观察项 | Photon 混合执行回退机制参考（StarRocks 已有向量化，可借鉴回退设计） | Photon 不支持算子回退 Spark [[E18]] | 低 |
| 布局项 | Delta UniForm vs Polaris 路线选型评估（单向读 vs 多引擎读写） | UniForm 单向 [[E9]]，Polaris 多引擎 [[E7]] | 中 |
| 布局项 | Genie Conversation API 集成评估（注意 Agent Mode 不可用） | API Public Preview [[E25]]，Agent Mode 仅 UI [[E11]] | 低 |

**演进路径建议：**

```
Phase 1: 语义模型层建立（验证项）
  ├── 定义 YAML 规范（参考 Metric Views 五层 + engine_capabilities）
  ├── 语义元数据增加 synonyms/display_name/format
  └── 反馈机制三级优先级设计（SQL 表达式 > 示例 > 文本）

Phase 2: 事前方言感知（验证项 → 观察项）
  ├── 语义模型增加 engine_capabilities 字段
  ├── AI 生成时感知目标引擎，直接生成该库 SQL
  └── Calcite 改写降级为兜底路径

Phase 3: 准确率与反馈闭环（验证项）
  ├── 准确率门槛设定（域特定 80% 后 UAT）
  ├── 用户正面反馈→建议新 SQL 片段（借鉴 Genie 闭环 [[E22]]）
  └── 多模型选优 PoC

Phase 4: 开放生态对接（布局项）
  ├── Polaris 对接评估（StarRocks 已支持，多引擎读写）
  ├── UC OSS 治理参考（统一血缘视图）
  └── Delta UniForm vs Polaris 路线选型
```

### 5. Conclusion 观点

1、Databricks AI/BI Genie 的 Compound AI + Chain-of-Thought 推理 [[E10]] 是与 Snowflake 六阶段 Agent 流水线不同的工程路径。Genie 更依赖单一 LLM（Claude Sonnet）的推理能力 [[E11]]，Cortex 更依赖多模型并行 + 编译器校验闭环。两者准确率门槛不同（Genie 域特定 80% 后 UAT [[E13]]，Cortex 90%+ 企业测试），但都验证了"语义模型 + 反馈学习"是 text-to-SQL 准确率的关键变量。产品线可同时借鉴两者：Genie 的三级反馈优先级（SQL 表达式 > 示例 > 文本 [[E12]]）+ Cortex 的 VQR 检索 + 多模型选优。

2、Databricks Metric Views 核心开源到 Apache Spark（SPARK-54119）[[E16]] 是与 Snowflake Semantic Views 的根本差异。两者都是单平台原生对象 [[E30]]，但 Databricks 开源核心意味着语义模型理论上可跨平台复用，Snowflake 完全锁定。产品线若采用开源语义层路径，Metric Views 的 YAML 规范 [[E17]] + 语义元数据 [[E29]] 比 Snowflake 专有方案更具可移植性——这与产品线"不绑定单一平台"的需求更契合。

3、Delta UniForm 与 Apache Polaris 代表开放表格式的两条路线 [[E9]][[E7]]。UniForm 是"Delta 为主，Iceberg 单向读"的 Databricks 主导路径；Polaris 是"中立目录，多引擎平等读写"的 Apache 标准路径。产品线已采用 StarRocks（Polaris 已支持 [[E7]]），若推进 Iceberg 化，Polaris 的多引擎读写能力比 UniForm 的单向读更契合三库联邦需求。建议布局 Polaris 对接评估，UniForm 作为观察项。

4、Unity Catalog 的 ABAC 治理 + 自动列级血缘 [[E14]][[E15]] 是产品线统一治理的参考方向，但跨引擎策略不自动同步 [[E26]] 是现实约束。产品线三库治理仍需独立设计，UC 的统一血缘视图可作为 To-Be 目标参考。UC OSS 开源捐赠 LF [[E8]] 值得跟踪，但不宜短期押注。

5、Databricks 和 Snowflake 的语义层都建立在"数据已入平台"前提上，产品线的核心差异化仍是"感知三库能力差异，事前生成各库 SQL"——这是两个标杆都未解决的领域。上一篇 Snowflake 报告结论（语义模型 YAML + VQR + 多模型选优可借鉴，编译器内改写不可移植）在本篇得到印证：Databricks 的 Metric Views 虽开源核心，但运行时改写仍绑定 Spark/Photon [[E16]]，不可直接移植到 StarRocks/Druid/GaussDB。产品线的语义层演进应优先解决三引擎方言感知问题（验证项），开放表格式与目录标准对接是后续布局项。

### 6. References

[[E1]] DB-Engines Ranking (2026-07): https://db-engines.com/en/ranking

[[E2]] Databricks $5.4B Revenue Run-Rate (2026-02, >65% YoY): https://www.prnewswire.com/news-releases/databricks-grows-65-yoy-surpasses-5-4-billion-revenue-run-rate-doubles-down-on-lakebase-and-genie-302682674.html

[[E3]] Databricks $6.9B Annualized Revenue (2026-06, >80% YoY): https://www.cnbc.com/2026/06/16/databricks-revenue-growth-tops-80percent-to-6point9-billion-annualized.html

[[E4]] Databricks AT&T Customer Case: https://www.databricks.com/customers/att

[[E5]] AT&T Data Modernization Lakehouse Blog: https://www.databricks.com/blog/2022/04/11/data-att-modernization-lakehouse.html

[[E6]] Nokia Partnership with Databricks (2026-06): https://simplywall.st/stocks/fi/tech/hel-nokia/nokia-oyj-shares/news/nokia-hlsenokia-partners-with-nvidia-aws-and-databricks-on-t

[[E7]] Apache Polaris GitHub (TLP 2026-02, StarRocks support): https://github.com/apache/polaris/

[[E8]] Choosing an Iceberg Control Plane (UC OSS donated to LF AI & Data): https://iceberglakehouse.com/posts/2026-05-24-choosing-iceberg-control-plane/

[[E9]] Databricks Delta Lake UniForm (IcebergCompatV2): https://docs.databricks.com/aws/en/delta/uniform

[[E10]] Databricks AI/BI Genie Concepts (Compound AI, Chain-of-Thought): https://docs.databricks.com/aws/en/genie/concepts

[[E11]] Databricks Genie Agent Mode (Claude Sonnet, multi-step reasoning): https://docs.databricks.com/aws/en/genie/agent-mode

[[E12]] Databricks Genie Best Practices (feedback priority: SQL expression > example SQL > text instructions): https://docs.databricks.com/aws/en/genie/best-practices

[[E13]] How Databricks Genie Brings Natural-Language Analytics to Enterprise Data Teams (80% accuracy UAT threshold): https://medium.com/@kanerika/how-databricks-genie-brings-natural-language-analytics-to-enterprise-data-teams-3d744e35ef25

[[E14]] Databricks Unity Catalog Access Control (RBAC + ABAC + row/column filters + workspace binding): https://docs.databricks.com/aws/en/data-governance/unity-catalog/access-control/

[[E15]] Databricks Unity Catalog Data Lineage (column-level, cross-workspace): https://docs.databricks.com/gcp/en/data-governance/unity-catalog/data-lineage

[[E16]] Databricks Redefining Semantics Data Layer (Metric Views 2026-04 GA, SPARK-54119 open source): https://www.databricks.com/blog/redefining-semantics-data-layer-future-bi-and-ai

[[E17]] Databricks Metric Views YAML Reference (source/joins/fields/measures/filter): https://docs.databricks.com/aws/en/business-semantics/metric-views/yaml-reference

[[E18]] Photon VLDB CIDR 2022 Paper (TPC-DS 100TB world record, 3x-10x speedup, hybrid execution fallback): https://vldb.org/cidrdb/papers/2022/a100-behm.pdf

[[E19]] Databricks Photon Execution Engine (C++ vectorized, Catalyst optimizer): https://docs.databricks.com/aws/en/compute/photon

[[E20]] Databricks ai_query Function (managed models + external models): https://docs.databricks.com/aws/en/large-language-models/ai-query

[[E21]] Databricks ai_generate_text (deprecated, use ai_query): https://docs.databricks.com/aws/en/sql/language-manual/functions/ai_generate_text

[[E22]] Databricks Talk to Genie (positive feedback triggers new SQL snippet suggestions): https://docs.databricks.com/aws/en/genie/talk-to-genie

[[E23]] Databricks Genie Set Up (30 tables per Space limit, read-only): https://docs.databricks.com/aws/en/genie/set-up

[[E24]] Snowflake Cortex Analyst vs Databricks Genie Benchmark (LinkedIn, 2025-03): https://www.linkedin.com/posts/arunthulasidharan_i-recently-did-a-benchmark-between-snowflake-activity-7305948904984915968-Zhn8

[[E25]] Databricks Genie Conversation API (2025-03 Public Preview): https://docs.databricks.com/api/workspace/genie

[[E26]] Snowflake Iceberg Catalog: Horizon vs Unity Catalog (CLD 2025-10 GA, cross-engine policy not auto-synced): https://www.snowflake.com/en/blog/engineering/iceberg-catalog-snowflake-horizon-vs-unity-catalog/

[[E27]] Databricks Delta Lake Universal Format (UniForm) GA Blog (6x Parquet ingestion, 90% cost reduction): https://www.databricks.com/blog/delta-lake-universal-format-uniform-iceberg-compatibility-now-ga

[[E28]] Databricks Metric Views Create (MEASURE() function): https://docs.databricks.com/aws/en/business-semantics/metric-views/create

[[E29]] Databricks Metric Views Semantic Metadata (display_name, format, synonyms): https://docs.databricks.com/aws/en/metric-views/data-modeling/semantic-metadata

[[E30]] Semantic Layer Comparison: MetricFlow vs Snowflake vs Databricks (native objects, single-platform lock-in): https://www.typedef.ai/resources/semantic-layer-metricflow-vs-snowflake-vs-databricks
