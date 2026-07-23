---
title: BigQuery-Looker-Gemini洞察
date: 2026-07-15 11:00:00
tags: AI
categories: 学习
---

# BigQuery + Looker 语义层与 Gemini AI 洞察

> 💡 一句话总结：LookML 是业界运行 14 年最成熟的语义建模语言，其多数据库连接与方言生成机制与我们的多库场景匹配度最高；Gemini 通过"AI 生成语义查询 + 确定性编译 SQL"路径把准确率从 80% 提升到 97%，验证了"让 AI 不直接写 SQL"是准确率主导因素。

## 背景

前两篇分析了 Snowflake 和 Databricks 的语义层方案，两者都建立在"数据已入单一平台"的前提上。本篇聚焦 LookML——业界最成熟的语义层（2012 年至今，14 年生产验证），其多数据库连接和方言生成机制是前两者不具备的能力。

Google Cloud 数据分析平台是市场重要力量。电信行业有多个采纳案例：Vodafone CZ 用 BigQuery 统一孤岛系统，成本降 46%；Vodafone Group 6 年战略合作，70+PB 平台，数据摄入从 36 小时降到 25 分钟；T-Mobile 用 BigQuery + BQML 预测使用趋势；Verizon Media/Yahoo 迁移后 47% 查询 <10 秒，总拥有成本降 26-34%。

LookML 的核心差异化在于多数据库连接：单个项目可跨 BigQuery / Snowflake / Redshift / AlloyDB / Databricks 查询。这与我们"一套语义模型感知三库差异"的需求高度吻合。

## 三大支柱

Google Cloud 数据分析平台的竞争力来自三个支柱。

### 支柱一：最成熟语义层建模语言

LookML 于 2012 年发布，是代码优先、版本控制的语义建模语言，编码维度、度量、JOIN 路径、访问权限、格式化、钻取。14 年生产验证使其在语义层领域具有最长运行记录。

相比之下，Snowflake Semantic Views 2025 年才正式发布，dbt MetricFlow 2023 年正式发布。LookML 的成熟度体现在：丰富的维度类型、持久化派生表策略、对称聚合 fan-out 保护等经过长期验证的能力。

### 支柱二：多数据库连接与方言生成

单个 LookML 项目可跨 BigQuery / Snowflake / Redshift / AlloyDB / Databricks 查询。同一套语义模型可生成不同数据库方言的 SQL。

这是 Snowflake Semantic Views（仅 Snowflake）不具备的能力。对我们三库场景（StarRocks / Druid / GaussDB），LookML 的多方言生成机制是最直接可借鉴的工程模式。

### 支柱三：Gemini AI + 语义层协同

Google 内部测试显示 Looker 语义层将 AI 自然语言查询数据错误减少多达 2/3。Conversational Analytics（对话式分析）于 2026 年 7 月正式发布，支持 BigQuery / Iceberg / Databricks / AWS Glue / SAP / Salesforce 多源。BigLake 统一开放格式存储层支持 Iceberg / Delta / Parquet 行列级安全。

## 软件架构

BigQuery 采用 Dremel 计算引擎 + Colossus + Capacitor 存储 + Jupiter 网络 + Borg 编排的架构：

- **客户端 / API 层**：SQL 查询 / BigQuery ML / Gemini AI / Data Canvas
- **Dremel 计算引擎层**：查询解析 → 执行计划 → Slot 公平调度 → 动态执行
- **存储层**：Capacitor 专有列式格式 / BigLake 开放格式，支持 Iceberg / Delta / Parquet 行列级安全
- **基础设施层**：Jupiter 网络（1PB/s）+ Borg 编排

关键特征：Dremel 是无服务器 MPP（大规模并行处理）查询引擎，用户无需管理基础设施；Slot 是虚拟计算单元，按需公平调度；存算分离。

### 与我们架构的差异

⚠️ BigQuery 是无服务器单引擎架构，Dremel 统一处理查询解析和执行。我们是多库架构，无统一计算引擎。

关键在于：LookML 作为独立语义层，附着在 BigQuery 之上但不内嵌于 Dremel——这与 Snowflake Semantic Views 内嵌编译器的路径不同，反而是我们可借鉴的模式：语义层独立于执行引擎，通过方言生成适配多库。

## LookML 语义层深度解析

### 维度、度量与派生表

LookML 在 view 文件中定义维度（dimension）、度量（measure）和派生表：

```lookml
view: sessions {
  measure: count {
    type: count
    drill_fields: [detail*]
  }
  dimension: session_id {
    type: number
    sql: ${TABLE}.session_id ;;
  }
  dimension: is_bounce_session {
    type: yesno
    sql: ${number_of_events_in_session} = 1 ;;
  }
  measure: count_bounce_sessions {
    type: count
    filters: { field: is_bounce_session  value: "yes" }
  }
}
```

关键设计要点：

- `dimension` 定义维度，`sql` 用 `${TABLE}` 占位符引用物理列，编译时替换为实际表别名
- `measure` 定义度量，`drill_fields` 定义钻取字段集
- `filters` 把业务逻辑（"跳出会话"）编码进度量定义，AI 查询时无需理解"跳出"的物理计算

PDT（Persisted Derived Table，持久化派生表）支持多种物化策略。其方言特定参数体现了 LookML 的多方言适配能力：

| 参数 | 适用数据库 | 作用 |
|------|-----------|------|
| partition_keys | BigQuery / Presto | 分区键 |
| indexes | MySQL / Postgres | 索引 |
| cluster_keys | BigQuery / Snowflake | 聚簇键 |
| sortkeys | Redshift | 排序键 |

📌 这组参数表明：LookML 在语义模型层面感知目标数据库的物理优化能力，为不同数据库生成不同的 DDL 优化参数。这正是"感知底层库直接生成各库 SQL"思路的工程实现——语义模型不仅定义业务语义，还编码目标库的物理特性。

### 多数据库连接与方言生成

单个 LookML 项目可跨多数据库查询。其方言生成机制：语义模型（数据库无关）→ 根据 connection 参数 → 编译生成目标库方言 SQL。

`${TABLE}` 占位符和 `sql` 参数在编译时根据目标 connection 替换为对应方言的 SQL。维度/度量定义中的 SQL 片段是方言感知的——开发者可针对特定 connection 编写方言特定逻辑。

📌 与 Snowflake 的根本差异：Snowflake 语义层内嵌于单引擎编译器，改写发生在编译时；LookML 是独立语义层，通过 connection 参数适配多数据库，编译产物是目标库方言 SQL。

对我们而言，LookML 的独立语义层 + 多 connection 模式比 Snowflake 编译器内改写更可移植——无需三库各自实现编译器内改写，只需在语义层根据目标库生成对应方言。

### 对称聚合与 fan-out 保护

LookML 通过对称聚合解决 fan-out（扇出）问题。当一对多 JOIN 导致度量重复计算时，LookML 自动生成去重聚合逻辑，确保度量结果正确。

例如计算"每个客户的订单数"时，若客户表与订单表 JOIN 产生扇出，LookML 的 count measure 会自动生成 `COUNT(DISTINCT ...)` 或子查询去重逻辑，而非简单的行计数。

价值：度量定义一次，编译器自动处理 fan-out 保护，AI 查询时无需理解 JOIN 基数对聚合的影响。

⚠️ LookML 的局限：学习曲线陡峭，数据请求仍瓶颈在工程团队；Schema drift（模式漂移）问题——无法自动检测 schema 变更导致定义过期。采纳时需评估：建模需专人维护，schema 变更需要流程化同步机制。

## Gemini AI 查询深度解析

### NL2LookML vs NL2SQL

📌 这是本篇最关键的对比。BigQuery 提供两种自然语言查 SQL 的路径：

- **NL2SQL 直连路径**：用户自然语言 → Gemini 直接生成 SQL → BigQuery 执行，准确率 80%（无上下文时 30%）
- **NL2LookML 路径**：用户自然语言 → Gemini 生成 JSON 语义查询（字段+过滤器）→ Looker 确定性编译 SQL → 数据库执行，准确率 97%

关键区别：NL2LookML 路径中 Gemini 不直接写 SQL，而是生成结构化 JSON 语义查询，由 Looker 确定性编译为目标 SQL。AI 的不确定性被限制在"语义理解"阶段，SQL 生成阶段是确定性的编译过程。

对比 NL2SQL 直连——AI 同时承担语义理解和 SQL 语法生成两个不确定任务，错误率更高。

### 语义层驱动的准确率提升

同一 Gemini API、同一数据集对比测试：

| 路径 | 准确率 | AI 职责 | SQL 生成 |
|------|--------|---------|----------|
| NL2SQL（无上下文） | 30% | 语义理解 + SQL 生成 | AI 直接生成 |
| NL2SQL（有上下文） | 80% | 语义理解 + SQL 生成 | AI 直接生成 |
| NL2LookML | 97% | 仅语义理解（生成 JSON） | Looker 确定性编译 |

📌 语义层是准确率主导因素：从 80% 到 97% 的提升（+17%）主要由"AI 不直接写 SQL"这一架构决策贡献。Google 内部测试进一步印证：语义层将错误减少多达 2/3。

与 Snowflake 对比：Snowflake 采用"AI 看语义模型元数据但仍直接写 SQL"，准确率从 51% 提升到 90%+。Looker 采用"AI 生成语义查询 + 确定性编译 SQL"，准确率从 80% 提升到 97%。

两条路径差异在于 SQL 生成是否由 AI 承担——Looker 路径将 SQL 生成完全确定化，理论上限更高，但受限于语义模型的表达覆盖范围。

### 对话式分析 API

Conversational Analytics 于 2026 年 7 月正式发布，是聊天式数据代理。其四层元数据架构：

- **第一层**：知识目录——数据资产盘点、标签、分类
- **第二层**：BigQuery 知识图谱——表/列/关系元数据
- **第三层**：已验证查询——问题-SQL 对（类似 Snowflake VQR）
- **第四层**：自定义代理指令——业务上下文、查询偏好

四层架构与 Snowflake Cortex Analyst 的上下文增强机制思路一致。已验证查询层对应 Snowflake VQR，是反馈学习的工程基础。BigQuery 知识图谱层将表/列/关系建模为图谱，为 AI 提供结构化的表间关系理解。

我们可借鉴四层架构思路：知识目录 → 查询图谱 → 已验证查询 → 自定义指令。

## 横向对比

### 三大语义层对比

| 维度 | LookML | Snowflake SV | dbt MetricFlow | 我们现状 |
|------|--------|-------------|----------------|---------|
| 首发年份 | 2012 | 2025 | 2023 | — |
| 多仓库支持 | ✅ 多数据库 | ❌ 仅 Snowflake | ✅ 6 仓库 | ❌ 事后转换 |
| 开源 | ❌ | ❌ | ✅ | — |
| AI 集成 | 97% | 90%+ | 早期 | 单模型直连 |
| 方言生成 | ✅ 多 connection | ❌ 单引擎 | ✅ 多仓库 | ❌ 事后转换 |
| Schema drift | 无法自动检测 | — | 无法自动检测 | — |

📌 LookML 是三大语义层中目前唯一同时具备"多数据库连接 + 独立语义层 + 14 年生产验证"的方案。其多 connection 方言生成机制最接近我们"一套语义模型感知三库差异"的需求。

### 采纳现状

120 个数据团队调查（2024.12-2026.01）显示：LookML 28%、Power BI 22%、dbt SL 18%、Cube 12%、自定义/无 35%。Gartner 2026 年 3 月预测：到 2030 年通用语义层将被视为关键基础设施。

语义层赛道尚未收敛，LookML 占据最高份额但自定义/无仍占 35%，说明语义层建设仍处于早期。

⚠️ BigQuery 数据锁定风险最高（Capacitor 专有格式，仅 GCP）。BigQuery Omni 不原生支持 StarRocks / Druid / GaussDB。借鉴 LookML 语义层时，应关注语义模型本身的可移植性，避免从一个锁定跳入另一个锁定。

### 关键结论

**可借鉴：** 多 connection 方言生成机制、维度/度量/派生表定义结构、方言特定参数、对称聚合 fan-out 保护、NL2LookML 的"AI 生成语义查询 + 确定性编译"架构、四层元数据架构。

**不可直接采纳：** LookML 是闭源商业产品，运行时依赖 Looker 平台，无法直接嵌入；学习曲线陡峭，建模需专人维护；Schema drift 无法自动检测。

**与 Snowflake 路径的差异：** Snowflake 是"AI 直接生成 SQL"，Looker 是"AI 生成语义查询 + 确定性编译 SQL"。Looker 路径准确率上限更高（97% vs 90%+），但受限于语义模型表达覆盖范围。可结合两者：高覆盖场景用确定性编译，低覆盖场景用 AI 直接生成回退。

## 现状与建议

### 现状

- AI 生成统一 SQL → 转换各库语法 → 下推三库执行
- Druid 报文场景等价函数依赖风险已验证失败
- 无系统化准确率测试、无反馈学习机制、无语义模型层

### 分层建议

**高优先级（验证项）：**

- 建立语义模型规范草案，参考 LookML 的维度/度量/派生表/过滤结构
- 语义模型增加 connection + dialect_params 字段，标注各库支持的函数/语法/物理优化参数
- AI 查询路径引入"语义查询中间表示"——AI 生成结构化 JSON，由确定性编译器生成目标库 SQL
- 建立已验证查询仓库，作为 AI 上下文增强输入

**中优先级（验证/观察项）：**

- 建立准确率回归测试，基于真实查询场景量化语义层边际贡献
- 对称聚合 fan-out 保护纳入语义层编译器
- SQL 转换降级为兜底路径（语义模型覆盖范围外的查询回退）
- Schema drift 检测机制设计

**布局项：**

- 跟踪 OSI / Apache Ossie 语义模型交换标准，评估格式对齐
- 跟踪 Gartner 预测的 2030 年通用语义层趋势，评估定位

### 演进路径

分四阶段推进：

- **阶段一**：语义模型层建立——定义规范（参考 LookML），增加 connection + dialect_params，建立已验证查询初始集
- **阶段二**：事前方言感知 + 语义查询中间表示——AI 生成结构化 JSON，确定性编译器生成各库 SQL，SQL 转换降级为兜底
- **阶段三**：反馈学习 + 准确率闭环——已验证查询自动收集，准确率回归测试，对称聚合保护，Schema drift 检测上线
- **阶段四**：生态标准跟踪——Ossie 标准跟踪，语义模型格式与开放标准对齐评估

## 总结

✅ 三个核心观点：

**一、LookML 的多数据库连接与方言生成机制与我们的多库场景匹配度最高。** 它是业界运行时间最长（14 年）的语义建模语言，多 connection 编译生成目标库方言 SQL 的能力是 Snowflake 单引擎语义层不具备的。语义层演进应重点借鉴"语义模型数据库无关 + 编译时方言生成"模式，而非 Snowflake 的"编译器内改写"模式。

**二、"让 AI 不直接写 SQL"是准确率提升的主导因素。** NL2LookML 的 97%（vs NL2SQL 直连 80%）证明：将 SQL 生成从 AI 不确定任务转为确定性编译，是提升准确率的关键。我们应引入"语义查询中间表示"——AI 生成结构化字段+过滤器 JSON，由确定性编译器生成目标库 SQL。这是投入产出比最高的架构转变。

**三、语义层不仅要定义业务语义，还要编码目标库的物理特性。** LookML 的方言特定参数（分区键、索引、聚簇键、排序键）表明，语义模型应增加 dialect_params 字段，标注各库支持的函数/语法/物理优化参数，在编译阶段就规避方言不兼容——从"事后转换"转向"事前方言感知"。同时保留现有 SQL 转换作为兜底路径，这与 Snowflake 语义 SQL 覆盖率仅约 10% 的实践结论一致。
