---
title: SQL数据库时区处理痛点——UTC部署与JDBC解决方案
date: 2026-08-11 15:00:00
tags: [数据库, StarRocks, GaussDB, Druid, 时区, JDBC]
categories: 学习
---

💡 一句话总结：数据库按 UTC 部署后，时间函数返回值与应用层差 8 小时——这不是一个 JDBC 参数能解决的，因为时区处理横跨存储层、会话层、应用层三层，每层机制各不相同。

## 背景

数据通信产品线查询引擎在部署中遇到一个高频痛点。数据库集群按运维规范以 UTC 时区拉起（`TZ=UTC` 或 `-Duser.timezone=UTC`），保证跨地域集群时间一致。但应用层部署在中国（UTC+8），业务期望看到北京时间。

当应用执行 `SELECT NOW()` 或 `SELECT CURRENT_TIMESTAMP`，返回的是 UTC 时间，与预期差 8 小时。

工程团队第一反应通常是："能否在 JDBC 连接字符串里加一个 timezone 参数解决？"这个看似简单的问题，实际上触及了数据库时区处理的深层架构。

不同数据库对时区的处理机制完全不同。StarRocks 用 MySQL 协议但有独立的 time_zone 变量体系，GaussDB 继承 PostgreSQL 的 GUC 参数体系，Apache Druid 用查询上下文参数。JDBC 驱动的 timezone 参数在不同数据库下行为和能力边界也各不相同。

本文厘清这三种数据库在 UTC 部署下的时区处理机制，明确 JDBC timezone 参数的能力边界，为部署配置和故障排查提供决策依据。

## 时区处理的三层架构

理解时区痛点的第一步，是看清三层架构：存储层、会话层、应用层。三层割裂是 UTC 部署痛点的根因。

### 存储层：epoch millis 与 naive datetime

时间存储有两种截然不同的模型。

**epoch millis 模型**：时间以"自 1970-01-01 00:00:00 UTC 以来的毫秒数"存储为一个 64 位整数。这种存储天然时区无关——一个时间点在全世界只有一个 epoch 值。Apache Druid 采用这种模型，`__time` 列在内部就是 LONG 类型的毫秒数，不携带任何时区信息。

**naive datetime 模型**：时间以"2024-01-15 10:30:00"这样的字符串/数值形式存储，不携带任何时区信息。StarRocks 的 DATETIME 列属于这种模型，官方 issue 承认"不存储 tz info"。GaussDB（基于 PostgreSQL）的 TIMESTAMP 类型也属于此类。

两种模型的根本差异在于：epoch millis 存储的是"绝对时间点"，无论从哪个时区读取都是同一个值，只是显示时需要转换；naive datetime 存储的是"墙钟时间"，含义完全取决于写入时假设的时区。如果写入时是 UTC+8，读取时按 UTC 解释，就会产生 8 小时偏差。

### 会话层：session timezone 决定函数行为

几乎所有数据库都有 session 级别的时区变量，决定 `NOW()`、`CURRENT_TIMESTAMP` 等时间函数的返回值。这个变量在连接建立时从服务器全局配置继承，但可以在 session 内修改。

当数据库以 UTC 部署时，这个 session 变量默认是 UTC，于是 `NOW()` 返回 UTC 时间。应用层如果在 UTC+8 环境，拿到的就是一个比预期少 8 小时的时间值。

但 session timezone 的作用范围是有边界的。以 StarRocks 为例，它影响时间函数的显示和存储行为，但不影响已存储的 DATE/DATETIME 列数据——这些数据是 naive 的，写入时用的什么时区就是什么时区，session timezone 改动不会追溯修改它们。

### 应用层：JDBC 驱动的时区转换

JDBC 驱动是应用与数据库之间的桥梁，它在时区处理中扮演两个角色。

第一，**传递 session timezone**：某些 JDBC 驱动在建立连接时会自动设置数据库的 session timezone 变量。例如 GaussDB 的 JDBC 驱动在 ConnectionFactoryImpl 中默认添加 `TimeZone` 参数，通过 `createPostgresTimeZone()` 方法将 JVM 时区传递给数据库。

第二，**转换时间值**：对于 TIMESTAMP 类型（存储为 UTC、读取时转换为 session timezone 的数据库，如 MySQL），JDBC 驱动负责在 server session timezone 和 JVM timezone 之间做转换。MySQL Connector/J 的 `preserveInstants` 参数控制这一行为。

⚠️ 关键洞察：UTC 部署只改变了会话层的默认值，但存储层的数据模型和 JDBC 驱动的转换逻辑是独立的。这就是为什么"改一个参数解决所有问题"是不可能的。

## StarRocks：session 级 time_zone 与存储层割裂

### time_zone 变量机制

StarRocks 通过 `time_zone` 参数管理时区，支持 session 级和 global 级两种设置方式：

```sql
-- session 级（断开连接后失效）
SET time_zone = 'Asia/Shanghai';

-- global 级（持久化到 FE，永久生效）
SET global time_zone = 'Asia/Shanghai';
```

📌 **最关键的陷阱**：StarRocks 的 `time_zone` 默认值是 `Asia/Shanghai`，而不是 UTC。这意味着即使服务器主机设置为 UTC 时区，StarRocks 的 session 仍然默认使用 Asia/Shanghai 时区——除非有人在部署后手动改过。

这与"数据库按 UTC 部署"的直觉相反：你以为改了系统时区就改了数据库时区，但 StarRocks 有自己的默认值。

另一个相关变量是 `system_time_zone`，记录的是 FE 机器启动时的系统时区，不能手动修改。StarRocks 官方建议在导入数据前，将 global time_zone 设置为与 system_time_zone 相同的值，否则 DATE 类型数据会出错。

社区 issue #12447 揭示了更深的问题：修改部署机器时区后，system_time_zone 不会自动更新——它只在机器启动时记录一次。如果先以 UTC 启动机器，再改为 Asia/Shanghai，system_time_zone 仍然显示 Etc/UTC，导致 time_zone 与 system_time_zone 不一致。

### 哪些受影响、哪些不受影响

StarRocks 官方文档明确列出了 time_zone 设置的影响范围。

**受影响的函数**：

- `NOW()`：返回指定时区的当前日期时间
- `CURTIME()`：返回指定时区的当前时间
- `FROM_UNIXTIME()`：基于 UTC 时间戳返回指定时区的日期时间
- `UNIX_TIMESTAMP()`：基于指定时区的日期时间返回 UTC 时间戳
- `CONVERT_TZ()`：时区间转换

**不受影响的**：

- DATE 和 DATETIME 类型数据的存储值——naive 值，写入时用的时区就是什么
- CREATE TABLE 中 LESS THAN 分区的边界值——已分区的边界值不会变
- SHOW LOAD 和 SHOW BACKENDS 返回的时间值受影响

这意味着如果你在 UTC 时区下通过 Stream Load 导入了一个 `default current_timestamp` 的 DATETIME 列，存进去的是 UTC 时间。之后即使 `SET time_zone = 'Asia/Shanghai'`，已存储的数据也不会变——只有新写入的 `NOW()` 值才会用新时区。

### JDBC 层面的限制与格式陷阱

StarRocks 使用 MySQL 协议，客户端通常使用 MySQL Connector/J 连接。但 StarRocks 本身没有在 JDBC 连接字符串层面提供原生的 timezone 参数——不能在 URL 里加 `time_zone=Asia/Shanghai` 自动设置 session 时区。正确做法是连接后执行 `SET time_zone = 'xxx'`。

值得注意的是，StarRocks 的 time_zone 变量有格式限制：只支持 UTC 偏移（如 `+08:00`）和时区名称（如 `Asia/Shanghai`）两种格式，不支持时区缩写（CST 除外，会自动转换为 Asia/Shanghai）。

社区 issue #38855 报告了一个更隐蔽的问题：通过 `SET_VAR` hint 设置时区时，`-5:00` 这种偏移格式会报错，只有完整的时区名称如 `America/Detroit` 才能工作——FE 和 BE 对时区格式的处理存在不一致。

此外，StarRocks 在 JDBC Catalog（用于访问外部 JDBC 数据源）中曾有 URL 参数拼接 bug（PR #42947），导致用户在 jdbc_uri 中添加的参数被错误地放在数据库名后面。虽然已修复，但揭示了一个普遍问题：JDBC URL 参数的传递在不同场景下可能存在意外行为。

### 已知缺陷：硬编码时区

StarRocks v4.1 引入了一个严重的时区回归缺陷（issue #72025）：FE 核心的 TimeUtils.java 中硬编码了 Asia/Shanghai 时区：

```java
public static final String DEFAULT_TIME_ZONE = "Asia/Shanghai";
private static final ZoneId TIME_ZONE =
    ZoneOffset.ofTotalSeconds(8 * 3600);
private static final DateTimeFormatter DATETIME_TO_STRING_FORMAT =
    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
        .withZone(TIME_ZONE);
```

这意味着即使 JVM 设置为 UTC、system_time_zone 和 session time_zone 都设为 UTC，所有通过 TimeUtils.longToTimeString() 渲染的时间戳——包括心跳时间、FE/BE 状态、事务管理器、物化视图刷新时间、字典刷新时间等元数据——全部显示为 GMT+8 时间。

下游系统读取这些元数据表时会继承同样的 Shanghai 时区偏移，产生 8 小时偏差。根因是一次重构 PR（#66360）在 v4.1 和 main 分支引入的，已在 PR #73619 中修复。

但这个案例深刻说明：数据库的时区处理不仅依赖配置参数，还可能被代码层面的硬编码绕过。

## GaussDB：PostgreSQL 血统的 TimeZone GUC 参数

### TimeZone 参数与 enableTimeZone 属性

GaussDB 基于 openGauss/PostgreSQL，继承了一套 GUC（Grand Unified Configuration）参数体系。其中 `TimeZone` 参数控制"显示和解释时间类型数值时使用的时区"，是 USERSET 类型参数（可在 session 级修改），默认值为 "PRC"。

GaussDB 的 JDBC 驱动提供了一个专有属性 `enableTimeZone`（Boolean 类型，默认 true）：

- `true`：启用客户端时区设置，获取 JVM 时区来指定数据库时区
- `false`：不启用客户端时区设置，使用数据库时区

这个属性是 GaussDB JDBC 驱动对 PostgreSQL JDBC 驱动的增强。当 enableTimeZone=true 时，驱动在 ConnectionFactoryImpl 中调用 `createPostgresTimeZone()` 方法，将 JVM 时区映射为 PostgreSQL 时区名称，并通过连接参数 `TimeZone` 传递给数据库。

### JDBC 自动传递机制与三时区一致性

GaussDB JDBC 驱动在连接建立时默认添加以下参数：

```
params = {
    { "user", user },
    { "database", database },
    { "client_encoding", "UTF8" },
    { "DateStyle", "ISO" },
    { "extra_float_digits", "3" },
    { "TimeZone", createPostgresTimeZone() },
};
```

这意味着 GaussDB 的 JDBC 驱动**会自动设置 session 的 TimeZone 变量**——如果 JVM 在 UTC+8，连接后 session 的 TimeZone 会被设为 UTC+8 对应的时区。

但华为官方同时给出了一个"三时区一致性"建议：

1. JDBC 客户端所在主机的时区
2. GaussDB 集群所在主机的时区
3. GaussDB 集群配置过程中使用的时区

这三个时区应该一致。这个建议本身暴露了一个事实：仅靠 JDBC 的 enableTimeZone 参数无法覆盖所有场景。

如果数据库配置时区与主机时区不一致，或者客户端 JVM 时区与数据库主机时区不一致，仍然可能出现时间显示不一致的问题。华为文档指出，JDBC 默认添加的参数"可能导致 JDBC 客户端的行为与 gsql 客户端的行为不一致"。

### SET TIME ZONE 命令

除了 JDBC 属性，GaussDB 也支持 SQL 命令设置 session 时区：

```sql
SET SESSION TIME ZONE 'Asia/Shanghai';
SET LOCAL TIME ZONE '+08:00';
```

这是 PostgreSQL 标准的时区设置方式，对应的运行时参数就是 TimeZone GUC。`gs_initdb` 会在初始化时设置一个与系统环境一致的时区值，但之后修改时区文件需要重启集群才能生效。

## Apache Druid：sqlTimeZone 上下文参数

### UTC 默认与 __time 列的 epoch 存储

Apache Druid 在时区处理上采取了一种简洁但容易踩坑的设计：**默认所有时间操作使用 UTC 时区**。Druid 的 `__time` 列以 LONG 类型存储自 epoch 以来的毫秒数（UTC），不携带任何时区信息。

这意味着 Druid 的时间存储是"绝对时间点"模型——无论从哪个时区查询，同一个 `__time` 值代表同一个时刻。

`sqlTimeZone` 是 Druid SQL 的查询上下文参数，默认值为 UTC（由 Broker 的 `druid.sql.planner.sqlTimeZone` 配置）。它影响：

- 时间函数行为：`CURRENT_TIMESTAMP` 和 `CURRENT_DATE` 返回值
- 时间戳字面量解释：`TIMESTAMP '2000-01-01 00:00:00'` 的解释时区
- `TIME_FORMAT` 和 `TIME_PARSE` 等函数的默认时区

当 sqlTimeZone 为 UTC 时，`CURRENT_TIMESTAMP` 返回 UTC 时间。Druid 的标量时间函数文档明确说明："默认使用 UTC 时区"。

### JDBC Properties 设置方式与 Avatica 限制

Druid 通过 Avatica JDBC 驱动提供 SQL 访问。设置 sqlTimeZone 的方式是通过 Properties 对象：

```java
String url = "jdbc:avatica:remote:url=http://localhost:8888"
    + "/druid/v2/sql/avatica/";
Properties props = new Properties();
props.setProperty("sqlTimeZone", "Asia/Shanghai");
Connection conn = DriverManager.getConnection(url, props);
```

⚠️ **关键限制**：Avatica JDBC 驱动不支持从连接字符串 URL 传递上下文参数——必须使用 Properties 对象。

Druid JDBC 文档明确指出："Avatica 不支持从连接字符串传递连接上下文参数到 Druid。这些上下文参数必须使用 Properties 对象传递。"

这意味着你不能在 URL 中写 `jdbc:avatica:remote:url=...;sqlTimeZone=Asia/Shanghai` 来设置时区。对于使用连接池（如 HikariCP）且只支持 URL 配置的场景，这是一个实际障碍——必须确保连接池支持 Properties 方式的参数传递。

### 函数级时区覆盖

Druid 的一些时间函数接受可选的 timezone 参数，可以覆盖连接级 sqlTimeZone 设置：

- `TIME_FORMAT(timestamp_expr[, pattern[, timezone]])`：格式化时间戳
- `TIME_PARSE(string_expr[, pattern[, timezone]])`：解析字符串为时间戳
- `TIME_EXTRACT(timestamp_expr, unit[, timezone])`：提取时间部分

这种设计允许在同一个查询中混用多个时区，比全局 session 级设置更灵活。但代价是：如果 sqlTimeZone 未正确设置，查询结果会静默返回 UTC 时间，而不会报错。

## JDBC timezone 参数的能力边界

### MySQL Connector/J 的参数演进

由于 StarRocks 使用 MySQL 协议，MySQL Connector/J 的 timezone 参数行为对 StarRocks 同样适用。Connector/J 的时区参数经历了一次重大演进。

**8.0.22 及之前**：使用 `serverTimezone` 参数。它告诉驱动服务器 session 的时区是什么，但不改变服务器 session 的 `time_zone` 变量。StackOverflow 上的高赞回答证实了这一点："serverTimezone 不改变 @@session.time_zone"。

**8.0.23 及之后**：引入三个新参数替代旧的体系：

- `connectionTimeZone`：接受 LOCAL（默认）、SERVER 或显式时区值。`serverTimezone` 成为其别名
- `forceConnectionTimeZoneToSession`（默认 false）：若为 true，将 connectionTimeZone 的值写入服务器 session 的 `time_zone` 变量
- `preserveInstants`（默认 true）：控制 java.sql.Timestamp 等 instant 类型值在 JVM 时区和 connectionTimeZone 之间的转换

📌 **核心区分**：`connectionTimeZone` 只是告诉驱动"我认为 session 时区是什么"，用于驱动内部的转换计算；`forceConnectionTimeZoneToSession=true` 才会真正执行 `SET time_zone` 改变服务器 session 变量。

两者经常被混淆——很多开发者以为在 URL 中加 `serverTimezone=UTC` 就会改变 session 时区，但实际上它只影响驱动端的转换逻辑。

### JDBC 能解决的场景

基于以上分析，JDBC timezone 参数在以下场景能解决问题：

**场景一：TIMESTAMP 类型值的写入/读取转换**。MySQL 的 TIMESTAMP 类型在存储时从 session 时区转换为 UTC，读取时从 UTC 转换回 session 时区。Connector/J 的 `preserveInstants=true` 配合 `connectionTimeZone=SERVER` 可以正确处理这一转换。

**场景二：通过 JDBC 设置 session 时区变量**。使用 `connectionTimeZone=Asia/Shanghai&forceConnectionTimeZoneToSession=true`，驱动会在连接建立时执行 `SET time_zone='Asia/Shanghai'`。这样 session 的 `NOW()` 等函数就会返回 UTC+8 时间。

**场景三：Druid 的 sqlTimeZone 设置**。通过 Properties 对象设置 `sqlTimeZone=Asia/Shanghai`，Druid 的 `CURRENT_TIMESTAMP` 和 `TIME_FORMAT` 等函数会按 UTC+8 处理。

**场景四：GaussDB 的 enableTimeZone=true**。驱动自动将 JVM 时区传递给 session 的 TimeZone 变量。

### JDBC 不能解决的场景

以下场景 JDBC timezone 参数无能为力：

**场景一：已入库的 naive DATETIME 数据**。StarRocks 的 DATETIME 列不存储时区信息。如果数据在 UTC 时区下导入，存储的就是 UTC 的"墙钟时间"。之后即使通过 JDBC 设置 `time_zone=Asia/Shanghai`，已存储的 DATETIME 值不会改变——只有通过 CONVERT_TZ() 函数查询时手动转换。这是最常见的"改了参数但历史数据仍然差 8 小时"的根因。

**场景二：分区边界值**。StarRocks 的 time_zone 设置不影响 CREATE TABLE 中 LESS THAN 分区的边界值。如果分区按 UTC 时间定义，修改 session 时区不会改变分区边界——查询时可能出现数据落入错误分区的问题。

**场景三：Druid 的 Avatica URL 传参限制**。Druid 的 sqlTimeZone 不能通过 JDBC URL 字符串传递，只能通过 Properties 对象。对于只支持 URL 配置的连接池或框架，这个限制是硬性的。

**场景四：数据库内部硬编码的时区**。StarRocks v4.1 的 TimeUtils 硬编码 Asia/Shanghai 缺陷是 JDBC 参数完全无法触及的——代码层面的硬编码绕过了所有配置参数。

**场景五：system_time_zone 与 time_zone 不一致**。StarRocks 的 system_time_zone 在机器启动时记录一次，之后修改机器时区不会更新。如果导入数据时 system_time_zone 与 time_zone 不一致，DATE 类型数据会出错——这不是 JDBC 参数能修复的。

**场景六：多客户端时区不一致**。如果 JDBC 应用通过 forceConnectionTimeZoneToSession 设置了 session 时区为 Asia/Shanghai，但同一数据库上还有其他客户端（如 gsql 命令行、BI 工具）使用 UTC 时区查询，不同客户端看到的时间显示会不一致。GaussDB 文档特别警告了 JDBC 客户端与 gsql 客户端的行为差异。

## 跨数据库对比与产品线关联

下面是三种数据库在时区处理上的对比（受限于手机屏幕，仅列关键维度）：

| 维度 | StarRocks | GaussDB | Druid |
|------|-----------|---------|-------|
| 时区变量 | `time_zone` | `TimeZone` GUC | `sqlTimeZone` |
| 默认值 | Asia/Shanghai | PRC | UTC |
| 存储模型 | naive DATETIME | naive TIMESTAMP | epoch millis |
| JDBC 设置 | 连接后 SET | `enableTimeZone` | Properties 对象 |

补充说明：

- URL 传参：StarRocks 不支持原生 timezone 参数；GaussDB 支持属性传参；**Druid 不支持 URL 传参**（Avatica 限制）
- 函数级覆盖：StarRocks 用 CONVERT_TZ()；GaussDB 用 SET TIME ZONE；Druid 用 TIME_FORMAT/TIME_PARSE 参数
- 已知缺陷：StarRocks v4.1 硬编码 Asia/Shanghai；GaussDB 三时区一致性约束；Druid Avatica URL 传参限制

从产品线查询引擎视角，这三种数据库代表三种不同范式。

**StarRocks 代表"MySQL 协议但独立时区体系"范式**。虽然使用 MySQL 协议和 MySQL JDBC 驱动，但 time_zone 变量体系完全独立，默认值是 Asia/Shanghai 而非 UTC。UTC 部署场景下，如果不手动设置 `SET time_zone = 'Asia/Shanghai'`，`NOW()` 等函数会返回 UTC 时间。

但由于 DATETIME 是 naive 存储，已入库数据不受影响——这造成了一个微妙问题：新数据的 `NOW()` 返回 UTC+8，但历史 DATETIME 数据仍是 UTC，两者在同一张表中混合，查询时容易混淆。

**GaussDB 代表"PostgreSQL GUC 体系 + JDBC 自动传递"范式**。enableTimeZone=true 的设计思路是让 JDBC 驱动自动处理时区，但这依赖 JVM 时区正确。如果应用部署在 Docker 容器中且容器时区未正确设置（默认 UTC），enableTimeZone=true 反而会将错误的 UTC 时区传递给 session。

华为的"三时区一致性"建议虽然稳妥，但在容器化部署环境中难以保证——容器时区、数据库主机时区、数据库配置时区三者经常不一致。

**Apache Druid 代表"epoch 存储 + 查询上下文"范式**。这是三种中最干净的设计：存储层完全时区无关（epoch millis），时区只影响查询时的函数行为和显示。sqlTimeZone 通过 Properties 设置后，所有时间函数和字面量都按指定时区处理，不存在存储层与会话层割裂的问题。

但 Avatica 的 URL 传参限制是一个工程障碍——需要确保所有使用 Druid JDBC 的连接池和框架都支持 Properties 方式传参。

### 统一查询层的分库策略

对于产品线查询引擎的统一 SQL 查询服务，一个关键洞察是：**不能假设"一个 JDBC timezone 参数解决所有数据库"**。统一查询层如果需要对接 StarRocks/GaussDB/Druid 三种数据库，时区处理策略必须分库配置：

- StarRocks：连接后执行 `SET time_zone = 'Asia/Shanghai'`，或使用 SET_VAR hint
- GaussDB：确保 `enableTimeZone=true` 且 JVM 时区正确，或连接后执行 `SET TIME ZONE 'Asia/Shanghai'`
- Druid：通过 Properties 设置 `sqlTimeZone=Asia/Shanghai`，不能用 URL 传参

更深层的建议是：统一查询层应该在 SQL 生成层面处理时区，而非依赖底层数据库的 session 变量。例如对 StarRocks 使用 `CONVERT_TZ(NOW(), 'UTC', 'Asia/Shanghai')`，对 Druid 使用 `TIME_FORMAT(__time, 'yyyy-MM-dd HH:mm:ss', 'Asia/Shanghai')`。这种方式不依赖 session 状态，更加确定和可测试。

## ✅ 总结

1. **JDBC timezone 参数不能"一键解决"UTC 部署的时间偏差问题**。它只能解决 TIMESTAMP 类型的读写转换（preserveInstants 机制）和 session 级时区变量设置（forceConnectionTimeZoneToSession）。对于已入库的 naive DATETIME 数据、分区边界值、数据库内部硬编码时区缺陷，JDBC 参数完全无能为力。正确策略是：部署时就设置正确的 global time_zone（而非依赖 JDBC 运行时修改），并在应用层对历史数据使用 CONVERT_TZ 等函数显式转换。

2. **三种数据库的时区处理范式不同，统一查询层必须分库配置**。StarRocks 需要连接后 SET time_zone，GaussDB 依赖 enableTimeZone 属性和 JVM 时区，Druid 必须通过 Properties 对象设置 sqlTimeZone。统一 SQL 查询服务应在 SQL 生成层按数据库方言处理时区（如 StarRocks 用 CONVERT_TZ、Druid 用 TIME_FORMAT 的 timezone 参数），而非依赖 session 级变量——这样更确定、可测试、不依赖连接状态。

3. **Druid 的 epoch millis 存储模型最干净，StarRocks 的 naive DATETIME 模型问题最多**。如果产品线查询引擎在新场景选型中有时区处理需求，优先考虑类 Druid 的 epoch 存储模型。对于已有 StarRocks 部署，需特别注意 v4.1 的硬编码时区缺陷（PR #73619 已修复），以及 system_time_zone 不可变导致的导入数据时区问题。

## 参考文章

- Apache Druid SQL data types — https://druid.apache.org/docs/latest/querying/sql-data-types/ — 明确 __time 列以 LONG 存储 epoch millis 且不携带时区信息
- StarRocks issue #37471: Have StarRocks store timezone data in UTC — https://github.com/StarRocks/starrocks/issues/37471 — 官方承认 timestamp 不存储时区信息，需应用层处理
- StarRocks Configure a time zone — https://docs.starrocks.io/docs/administration/management/timezone/ — time_zone 变量的 session/global 设置方式、影响范围、默认值 Asia/Shanghai
- GaussDB JDBC Client Programming Specifications — https://support.huaweicloud.com/intl/en-us/centralized-devg-v8-gaussdb/gaussdb-42-2090.html — JDBC 驱动 ConnectionFactoryImpl 默认传递 TimeZone 参数、三时区一致性建议
- MySQL Connector/J Preserving Time Instants — https://dev.mysql.com/doc/connector-j/en/connector-j-time-instants.html — preserveInstants/connectionTimeZone/forceConnectionTimeZoneToSession 三个参数的行为定义
- StarRocks issue #12447: system_time_zone does not take effect — https://github.com/StarRocks/starrocks/issues/12447 — system_time_zone 只在机器启动时记录，修改机器时区后不更新
- StarRocks issue #38855: Unable to set TZ as session var unless full TZ name is used — https://github.com/StarRocks/starrocks/issues/38855 — SET_VAR hint 中偏移格式报错，FE/BE 时区格式处理不一致
- StarRocks PR #42927: Fix the incorrect jdbc url concatenation — https://github.com/StarRocks/starrocks/pull/42947 — JDBC Catalog 中 URL 参数被错误拼接到数据库名后面的 bug 修复
- StarRocks issue #72025: Incorrect timezone used for frontends because of hardcoded timezone — https://github.com/StarRocks/starrocks/issues/72025 — v4.1 TimeUtils.java 硬编码 Asia/Shanghai 时区缺陷及 PR #73619 修复
- GaussDB Locale and Formatting GUC Parameters (TimeZone) — https://support.huaweicloud.com/intl/en-us/centralized-devg-v8-gaussdb/gaussdb-40-0360.html — TimeZone GUC 参数说明、USERSET 类型、默认值 PRC、gs_initdb 初始化行为
- openGauss SET command — https://docs.opengauss.org/en/docs/latest/sql_reference/set.html — SET TIME ZONE 语法、TimeZone 运行时参数、默认值 PRC
- GaussDB Connection Parameter Reference (enableTimeZone) — https://support.huaweicloud.com/intl/zh-cn/centralized-devg-v3-gaussdb/gaussdb-42-1509.html — enableTimeZone 布尔属性：true 获取 JVM 时区指定数据库时区，false 使用数据库时区
- GaussDB SET SQL Syntax — https://support.huaweicloud.com/intl/en-us/distributed-devg-v3-gaussdb/gaussdb-12-0630.html — SET SESSION/LOCAL TIME ZONE 语法、对应 TimeZone GUC 参数
- Apache Druid SQL query context (sqlTimeZone) — https://druid.apache.org/docs/28.0.0/querying/sql-query-context — sqlTimeZone 查询上下文参数、默认 UTC、通过 Properties 或 context 对象设置
- Apache Druid SQL scalar functions — https://druid.apache.org/docs/latest/querying/sql-scalar/ — 时间函数默认 UTC、TIME_FORMAT/TIME_PARSE 接受可选 timezone 参数覆盖连接级设置
- Apache Druid SQL JDBC driver API — https://druid.apache.org/docs/28.0.1/api-reference/sql-jdbc — Avatica 不支持从连接字符串 URL 传递上下文参数，必须用 Properties 对象
- MySQL Connector/J Datetime types processing — https://dev.mysql.com/doc/connector-j/en/connector-j-connp-props-datetime-types-processing.html — connectionTimeZone/forceConnectionTimeZoneToSession/preserveInstants 参数详细说明及 serverTimezone 别名关系
- StackOverflow: Does serverTimezone param change session.time_zone in MySQL — https://stackoverflow.com/questions/51196041/does-servertimezone-param-change-session-time-zone-in-mysql — serverTimezone 不改变 @@session.time_zone，需 sessionTimeZone 属性或 SET 语句
