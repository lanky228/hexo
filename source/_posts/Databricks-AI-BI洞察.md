---
title: Databricks-AI-BI洞察
date: 2026-07-15 12:00:00
tags: AI
categories: 学习
---

# Databricks AI/BI 洞察

> 💡 一句话总结：Databricks 用 AI/BI Genie（复合 AI 系统）+ Unity Catalog（统一治理）+ Delta Lake UniForm（开放表格式）构成湖仓一体的 AI 查询方案，其开源语义层和向量化执行与 Snowflake 形成差异化对比，核心参考价值在语义层可移植性和治理一体化。

## 背景

在分析完 Snowflake 的 AI 查询方案后，本篇聚焦其主要竞争对手 Databricks，形成横向对比，明确两个标杆在 AI 查询和开放存储两个维度的差异。

Databricks 是 DB-Engines 排名第 7 的数据平台（2026 年 7 月，164 分），年收入从 54 亿美元（2026 年 2 月，+65%）增长到 69 亿美元（2026 年 6 月，+80%），增速高于 Snowflake。电信行业有 AT&T（每天 10+PB 数据，1.82 亿无线用户，5 年 300% ROI）、Nokia 合作等采纳案例。

其 AI/BI Genie + Unity Catalog + Delta Lake 组合代表了湖仓架构下 AI 查询 + 治理一体化 + 开放表格式的工程路径，值得深度拆解。

## 三大支柱

Databricks 在 AI 查询与治理领域的竞争力来自三个支柱。

### 支柱一：复合 AI 系统 Genie

Genie 不是单一大模型，而是 Compound AI 系统（复合 AI），使用 Chain-of-Thought（思维链）推理：识别列 → 规划 SQL → 组合查询。

Agent Mode 使用 Claude Sonnet 模型支持多步推理。反馈机制有三优先级：SQL 表达式（精确定义业务语义）> 示例 SQL 查询 > 文本指令。

Databricks 建议域特定问题准确率超过 80% 后再进入 UAT（用户验收测试），说明 Genie 的准确率是可度量、可分阶段提升的。

### 支柱二：统一治理 + 开放表格式

Unity Catalog 三级命名空间（catalog.schema.table），四种访问控制：GRANT/REVOKE + ABAC（基于属性的访问控制）标签策略 + 行列过滤器/脱敏 + 工作区绑定，自动列级血缘跨工作区聚合。

Delta UniForm 异步生成 Iceberg 元数据，不重写数据文件，实现单份数据双格式。这是与 Snowflake 封闭生态的根本差异——Databricks 通过开源 Unity Catalog OSS 和 UniForm 互操作构建开放生态。

### 支柱三：开源语义层 + 向量化执行

Metric Views 于 2026 年 4 月正式发布，YAML 定义 source / joins / fields / measures / filter，核心已开源到 Apache Spark（SPARK-54119）。

Photon 是 C++ 向量化执行引擎，替代 JVM Spark SQL，客户工作负载平均 3 倍加速、最高 10 倍，曾创 TPC-DS 100TB 世界纪录。语义层开源 + 执行引擎向量化构成"语义可移植 + 性能有保障"的组合。

## 软件架构

Databricks 湖仓架构分三层：

- **Unity Catalog（治理层）**：三级命名空间，ABAC 标签 + 行列过滤/脱敏 + 权限管理 + 工作区绑定，自动列级血缘，内嵌 Metric Views 语义层
- **Photon 执行引擎（计算层）**：C++ 向量化执行，Catalyst 优化器查询规划，不支持算子时回退 Spark，SQL 级 AI 函数 ai_query
- **Delta Lake（存储层）**：事务日志，UniForm Iceberg 互操作，单份数据双格式

### 与 Snowflake 的根本差异

⚠️ Snowflake 是单引擎封闭架构，语义改写在编译器内完成；Databricks 是湖仓架构，治理层、执行层、存储层解耦，语义层作为治理层内嵌对象而非编译器内改写。

这意味着 Databricks 的语义层理论上可跨引擎复用（核心已开源到 Spark），而 Snowflake 的 Semantic Views 不可移植。

### 与我们架构的差异

我们是多库联邦架构（StarRocks / Druid / GaussDB），无统一治理层，语义改写依赖事后 SQL 转换。Databricks 的统一治理 + 语义层组合为我们提供了另一种参考架构——但我们的"统一"需要跨三个库，复杂度更高。

## AI/BI Genie 深度解析

### 思维链推理流水线

Genie 的核心推理流水线采用 Chain-of-Thought，分三步：

- **列识别**：从 Genie Space 元数据中识别相关列（每个 Space 最多 30 张表）
- **SQL 规划**：规划查询结构与 JOIN 路径，而非直接生成完整 SQL
- **查询组合**：在规划基础上组合最终 SQL

分步推理降低复杂查询的错误率。与 Snowflake 六阶段 Agent 流水线对比：Genie 的三步更轻量，Cortex 的六阶段更精细（含分类、特征提取、上下文增强、多模型生成、错误纠正、综合选优）。

两者都采用分步推理，但 Cortex 的工程化程度更高（多模型并行 + 编译器校验闭环），Genie 更依赖单一模型的推理能力。

### 专家反馈学习机制

Genie 的反馈机制有三优先级：

- **优先级 1（最高）**：SQL 表达式——直接定义业务语义的精确 SQL，消除歧义
- **优先级 2**：示例 SQL 查询——问题→SQL 的示例对，作为参考
- **优先级 3（最低）**：文本指令——自然语言描述的业务规则，AI 需自行理解

设计核心：SQL 表达式优先级最高，因为它精确消除歧义；文本指令最低，因为自然语言本身存在歧义。

用户正面反馈可触发 Genie 建议新 SQL 片段，形成"使用→反馈→学习→建议"闭环。

📌 与 Snowflake 对比：Genie 的反馈侧重"业务语义精确定义"（SQL 表达式优先），Cortex 的已验证查询侧重"已验证查询检索复用"。两者思路互补，可同时借鉴。

### Agent Mode 多步推理

Agent Mode 使用 Claude Sonnet，支持多步推理，能处理需要拆解子问题、执行中间查询、基于结果继续推理的复杂问题。

⚠️ 关键限制：

- Agent Mode 仅 UI 可用，API 不支持——无法集成到我们的查询服务
- 每个 Genie Space 最多 30 张表——复杂业务域需拆分多个 Space
- 只读查询，不支持写操作
- 不解释结果——只返回数据，不提供分析洞察

Genie Conversation API（2025 年 3 月公测）支持编程式调用，但 Agent Mode 不在 API 范围内。若集成 Genie，只能用基础推理，无法用多步推理——这是集成时的能力边界。

## Unity Catalog + Delta UniForm 深度解析

### ABAC 治理与血缘

Unity Catalog 四种访问控制：

- **GRANT/REVOKE**：基于角色的权限管理
- **ABAC 标签策略**：基于标签按数据分类（如个人隐私数据）控制访问
- **行列过滤器/脱敏**：行级安全 + 列脱敏，细粒度保护
- **工作区绑定**：工作区与 Catalog 绑定，实现隔离

自动列级血缘跨工作区聚合，提供端到端数据血缘可视化。这对我们"数据血缘跨三库追踪"有参考价值——当前三个库各自独立，缺乏统一血缘视图。

⚠️ 跨引擎策略不自动同步：Snowflake 可通过 Catalog-Linked Databases 读写 Unity Catalog 表，但每个平台执行自己的策略。Unity Catalog 的统一治理是"Databricks 平台内统一"，跨引擎时治理策略仍需各引擎独立维护。

### Delta UniForm Iceberg 互操作

Delta UniForm IcebergCompatV2 的核心机制：

- 异步生成 Iceberg 元数据，不重写数据文件——零数据迁移成本
- 单份数据支持 Delta + Iceberg 双格式
- Iceberg 客户端只读，不支持写——写入仍需通过 Delta
- Databricks 声称比 Snowflake 快 6 倍 Parquet 摄入、成本低 90%

DDL 语法示例：

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

📌 与 Apache Polaris 对比：UniForm 是"Delta 为主，Iceberg 单向读"的 Databricks 主导路径；Polaris 是"中立目录，多引擎平等读写"的开放标准。我们若选择 Iceberg 化，Polaris 的多引擎读写能力（含 StarRocks）比 UniForm 单向读更契合三库联邦需求。

### Metric Views 语义层

Metric Views YAML 定义 source / joins / fields / measures / filter 五层，核心已开源到 Apache Spark：

```yaml
name: orders_metric_view
source:
  table: orders
  fields:
    - name: order_month
      expr: date_trunc('month', order_date)
joins:
  - name: customers
    source:
      table: customers
    on: orders.customer_id = customers.customer_id
measures:
  - name: Total Revenue
    expr: SUM(order_total)
    format: currency
    synonyms: ["revenue", "营收"]
...
```

查询使用 `MEASURE()` 函数。语义元数据（显示名、格式化、同义词）同时服务 BI 工具和大模型，让 AI 理解"总收入"="revenue"="营收"是同一指标。

📌 与 Snowflake Semantic Views 对比：

| 维度 | Databricks Metric Views | Snowflake Semantic Views |
|------|------------------------|--------------------------|
| 定义格式 | YAML | YAML + DDL |
| 改写位置 | 运行时（Spark/Photon） | 编译器内 |
| 开源 | 核心开源到 Spark | 未开源 |
| 平台锁定 | 单平台，但核心可移植 | 不可移植 |

关键差异：两者都是单平台原生对象，但 Databricks 开源了核心，理论上可在非 Databricks Spark 上运行；Snowflake 完全锁定。若采用开源语义层，Metric Views 比专有方案更具可移植性。

## 横向对比

| 维度 | Databricks | Snowflake | 我们现状 |
|------|-----------|-----------|---------|
| AI 查询 | Genie（复合 AI，思维链） | 六阶段 Agent | AI 生成统一 SQL |
| 反馈学习 | SQL 表达式 > 示例 > 文本 | 已验证查询检索 | 无 |
| 准确率 | 域特定 80% 后 UAT | 90%+ 企业测试 | 无系统化方法 |
| 语义层 | Metric Views（开源核心） | Semantic Views（未开源） | 无 |
| 治理 | UC（ABAC + 行列过滤） | Horizon | 各库独立 |
| 开放表格式 | UniForm（单向读） | Polaris（多引擎读写） | 无 |
| 执行引擎 | Photon C++ 向量化（3-10 倍） | 自研 MPP | StarRocks/Druid/GaussDB |
| 联邦下推 | 不支持（数据需入湖仓） | 不支持 | 支持（实时下推三库） |

### 关键结论

**可借鉴：** Metric Views YAML 五层结构（核心开源）、语义元数据增强 AI 理解、Genie 三级反馈优先级、Unity Catalog 自动列级血缘、Photon 向量化执行思路。

**不可借鉴：** Genie Agent Mode（仅 UI）、UniForm 单向读（我们需要多引擎读写）、跨引擎策略不自动同步（三库治理仍需独立设计）。

**根本差异：** 两个标杆的语义层都建立在"数据已入平台"前提上。Databricks 的优势是语义层核心开源可移植，Snowflake 的优势是 Agent 工程化程度更高。我们的核心差异化仍是"感知三库能力差异，事前生成各库 SQL"——这是两个标杆都未解决的领域。

## 现状与建议

### 现状

- AI 生成统一 SQL → 转换各库语法 → 下推三库执行
- Druid 报文场景等价函数依赖风险已验证失败
- 无系统化准确率测试、无反馈学习、无语义模型层、无统一治理层

### 分层建议

**高优先级（验证项）：**

- 语义模型 YAML 规范草案，参考 Metric Views 五层结构
- 语义元数据增加 synonyms / display_name / format 字段
- 反馈机制按三级优先级设计：SQL 表达式 > 示例 > 文本
- 语义层增加 engine_capabilities 字段，AI 生成时感知目标引擎

**中优先级（观察项）：**

- 准确率门槛设定（域特定 80% 后 UAT），分阶段提升
- Apache Polaris 对接评估（StarRocks 已支持），作为开放目录标准
- Unity Catalog OSS 跟踪（已捐赠 Linux 基金会），评估统一治理参考

**布局项：**

- Delta UniForm vs Polaris 路线选型（单向读 vs 多引擎读写）
- Genie Conversation API 集成评估（注意 Agent Mode 不可用）

### 演进路径

分四阶段推进：

- **阶段一**：语义模型层建立——定义 YAML 规范（参考五层 + engine_capabilities），语义元数据增强，反馈三级优先级
- **阶段二**：事前方言感知——AI 感知目标引擎直接生成该库 SQL，SQL 转换降级为兜底
- **阶段三**：准确率与反馈闭环——门槛设定，正面反馈→建议新 SQL，多模型选优
- **阶段四**：开放生态对接——Polaris 对接评估，Unity Catalog 治理参考，路线选型

## 总结

✅ 三个核心观点：

**一、Databricks 和 Snowflake 验证了同一结论：语义模型 + 反馈学习是 text-to-SQL 准确率的关键变量。** Genie 更依赖单一模型推理能力，Cortex 更依赖多模型并行 + 编译器校验。两者准确率门槛不同，但可同时借鉴：Genie 的三级反馈优先级（SQL 表达式优先）+ Cortex 的已验证查询检索 + 多模型选优。

**二、Metric Views 核心开源是与 Snowflake 的根本差异，对我们"不绑定单一平台"的需求更契合。** 两者都是单平台原生对象，但 Databricks 开源核心意味着语义模型理论上可跨平台复用。若采用开源语义层路径，Metric Views 的 YAML 规范比专有方案更具可移植性。

**三、开放表格式存在两条路线，Polaris 比 UniForm 更契合我们的多库需求。** UniForm 是"Delta 为主，Iceberg 单向读"的 Databricks 主导路径；Polaris 是"中立目录，多引擎平等读写"的开放标准。我们已采用 StarRocks（Polaris 已支持），推进 Iceberg 化应布局 Polaris 对接评估，UniForm 作为观察项。两个标杆都未解决"感知多库能力差异、事前生成各库 SQL"，这正是我们的核心差异化。
