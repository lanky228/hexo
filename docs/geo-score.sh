#!/bin/bash
# geo-score.sh — Lanky 博客 GEO+SEO 评分脚本 v1.1
# 用法: bash geo-score.sh
# 每次改进后运行，对比分数变化

BLOG_URL="https://lanky228.github.io"
POSTS_DIR="/root/workspace/hexo-blog/source/_posts"
SCORE=0
MAX=0
A_SCORE=0; B_SCORE=0; C_SCORE=0; D_SCORE=0

score() { SCORE=$((SCORE + $1)); }
add_max() { MAX=$((MAX + $1)); }

echo "╔══════════════════════════════════════╗"
echo "║  Lanky 博客 GEO+SEO 评分 v1.1       ║"
echo "╚══════════════════════════════════════╝"
echo "评分时间: $(date '+%Y-%m-%d %H:%M')"
echo ""

TOTAL_POSTS=$(find "$POSTS_DIR" -name '*.md' | wc -l)
TOTAL_POSTS=${TOTAL_POSTS:-0}

# ================================
# A. 技术基础设施 (30分)
# ================================
echo "=== A. 技术基础设施 (30分) ==="

# A1 域名一致性 (8分)
SITEMAP_DOMAIN=$(curl -sL "$BLOG_URL/sitemap.xml" 2>/dev/null | grep -oP '<loc>\K[^/]+' | head -1)
CANONICAL_DOMAIN=$(curl -sL "$BLOG_URL" 2>/dev/null | grep -oP 'canonical.*?href="\K[^"]+' | head -1 | grep -oP 'https?://[^/]+')
A1=0
if echo "$SITEMAP_DOMAIN" | grep -q "github.io" && echo "$CANONICAL_DOMAIN" | grep -q "github.io"; then
  A1=8; echo "A1 域名一致性: 8/8 ✓"
else
  echo "A1 域名一致性: 0/8 ✗ (sitemap=$SITEMAP_DOMAIN canonical=$CANONICAL_DOMAIN)"
fi
score $A1; A_SCORE=$((A_SCORE + A1)); add_max 8

# A2 robots.txt (4分)
ROBOTS=$(curl -sL "$BLOG_URL/robots.txt" 2>/dev/null)
A2=0
[ -n "$ROBOTS" ] && [ "$(echo "$ROBOTS" | tr -d '[:space:]')" != "" ] && A2=$((A2 + 1))
echo "$ROBOTS" | grep -qi "sitemap" && A2=$((A2 + 1))
echo "$ROBOTS" | grep -qi "GPTBot\|PerplexityBot\|Claude-Web\|Google-Extended" && A2=$((A2 + 2))
echo "A2 robots.txt: $A2/4"
score $A2; A_SCORE=$((A_SCORE + A2)); add_max 4

# A3 结构化数据覆盖 (8分) — 抽样3篇
JSONLD_COUNT=0
for slug in "AI编程实践洞察与工程原则" "ClickHouse-列式OLAP洞察" "DuckDB-嵌入式分析数据库洞察"; do
  ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$slug'))" 2>/dev/null)
  HTML=$(curl -sL "$BLOG_URL/2026/07/15/$ENCODED/" 2>/dev/null)
  echo "$HTML" | grep -q 'ld+json' && JSONLD_COUNT=$((JSONLD_COUNT + 1))
done
A3=$((JSONLD_COUNT * 8 / 3))
echo "A3 结构化数据: $A3/8 (抽样 $JSONLD_COUNT/3 篇有JSON-LD)"
score $A3; A_SCORE=$((A_SCORE + A3)); add_max 8

# A4 Sitemap完整性 (4分)
SITEMAP_COUNT=$(curl -sL "$BLOG_URL/sitemap.xml" 2>/dev/null | grep -c '<loc>')
SITEMAP_COUNT=${SITEMAP_COUNT:-0}
A4=0
if [ "$SITEMAP_COUNT" -ge "$TOTAL_POSTS" ] 2>/dev/null; then
  A4=4; echo "A4 Sitemap: 4/4 ✓ ($SITEMAP_COUNT URLs)"
else
  A4=2; echo "A4 Sitemap: 2/4 ⚠ ($SITEMAP_COUNT URLs vs $TOTAL_POSTS posts)"
fi
score $A4; A_SCORE=$((A_SCORE + A4)); add_max 4

# A5 RSS Feed (3分)
FEED=$(curl -sL "$BLOG_URL/atom.xml" 2>/dev/null | head -5)
A5=0
if echo "$FEED" | grep -q '<feed'; then
  FEED_URL=$(curl -sL "$BLOG_URL/atom.xml" 2>/dev/null | grep -oP '<id>\K[^<]+' | head -1)
  if echo "$FEED_URL" | grep -q "github.io"; then
    A5=3; echo "A5 RSS Feed: 3/3 ✓"
  else
    A5=1; echo "A5 RSS Feed: 1/3 ⚠ (URL错误: $FEED_URL)"
  fi
else
  echo "A5 RSS Feed: 0/3 ✗"
fi
score $A5; A_SCORE=$((A_SCORE + A5)); add_max 3

# A6 页面性能 (3分)
SCRIPT_COUNT=$(curl -sL "$BLOG_URL" 2>/dev/null | grep -c '<script')
SCRIPT_COUNT=${SCRIPT_COUNT:-0}
A6=0
if [ "$SCRIPT_COUNT" -le 5 ] 2>/dev/null; then
  A6=3; echo "A6 性能: 3/3 ✓ ($SCRIPT_COUNT scripts)"
elif [ "$SCRIPT_COUNT" -le 10 ] 2>/dev/null; then
  A6=2; echo "A6 性能: 2/3 ⚠ ($SCRIPT_COUNT scripts)"
else
  A6=1; echo "A6 性能: 1/3 ⚠ ($SCRIPT_COUNT scripts)"
fi
score $A6; A_SCORE=$((A_SCORE + A6)); add_max 3

echo ">> A 小计: $A_SCORE/30"
echo ""

# ================================
# B. AI引擎可引用性 (35分)
# ================================
echo "=== B. AI引擎可引用性 (35分) ==="

# B1 FAQ覆盖 (8分) — 检查 markdown 中 **Q: 模式
FAQ_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  QCOUNT=$(grep -c '^\*\*Q:' "$f" 2>/dev/null)
  QCOUNT=${QCOUNT:-0}
  [ "$QCOUNT" -ge 3 ] 2>/dev/null && FAQ_POSTS=$((FAQ_POSTS + 1))
done
B1=$((FAQ_POSTS * 8 / (TOTAL_POSTS > 0 ? TOTAL_POSTS : 1)))
echo "B1 FAQ覆盖: $B1/8 ($FAQ_POSTS/$TOTAL_POSTS 篇有≥3个Q&A)"
score $B1; B_SCORE=$((B_SCORE + B1)); add_max 8

# B2 Meta description覆盖 (5分)
DESC_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  head -10 "$f" | grep -q '^description:' && DESC_POSTS=$((DESC_POSTS + 1))
done
B2=$((DESC_POSTS * 5 / (TOTAL_POSTS > 0 ? TOTAL_POSTS : 1)))
echo "B2 description: $B2/5 ($DESC_POSTS/$TOTAL_POSTS 篇有description)"
score $B2; B_SCORE=$((B_SCORE + B2)); add_max 5

# B3 可引用论断句 (6分) — 检查加粗+数据/比较句
QUOTE_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  QCOUNT=$(grep -cP '\*\*.*(\d+.*倍|快|慢|高|低|比|vs|对比).*\*\*' "$f" 2>/dev/null)
  QCOUNT=${QCOUNT:-0}
  [ "$QCOUNT" -ge 3 ] 2>/dev/null && QUOTE_POSTS=$((QUOTE_POSTS + 1))
done
B3=$((QUOTE_POSTS * 6 / 15))
[ "$B3" -gt 6 ] && B3=6
echo "B3 可引用论断: $B3/6 ($QUOTE_POSTS/15 篇有≥3个数据结论句)"
score $B3; B_SCORE=$((B_SCORE + B3)); add_max 6

# B4 表格化 (4分)
TABLE_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  TCOUNT=$(grep -c '^|' "$f" 2>/dev/null)
  TCOUNT=${TCOUNT:-0}
  [ "$TCOUNT" -ge 3 ] 2>/dev/null && TABLE_POSTS=$((TABLE_POSTS + 1))
done
B4=$((TABLE_POSTS * 4 / (TOTAL_POSTS > 0 ? TOTAL_POSTS : 1)))
[ "$B4" -gt 4 ] && B4=4
echo "B4 表格化: $B4/4 ($TABLE_POSTS/$TOTAL_POSTS 篇有表格)"
score $B4; B_SCORE=$((B_SCORE + B4)); add_max 4

# B5 标签语义化 (4分)
SEMANTIC_TAG_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  TAGS=$(head -10 "$f" | grep -oP 'tags:\s*\K.*')
  TAG_COUNT=$(echo "$TAGS" | tr ',' '\n' | wc -l)
  TAG_COUNT=${TAG_COUNT:-0}
  if [ "$TAG_COUNT" -ge 2 ] 2>/dev/null; then
    SEMANTIC_TAG_POSTS=$((SEMANTIC_TAG_POSTS + 1))
  elif echo "$TAGS" | grep -qvP '^\s*AI\s*$' 2>/dev/null; then
    SEMANTIC_TAG_POSTS=$((SEMANTIC_TAG_POSTS + 1))
  fi
done
B5=$((SEMANTIC_TAG_POSTS * 4 / (TOTAL_POSTS > 0 ? TOTAL_POSTS : 1)))
echo "B5 标签语义化: $B5/4 ($SEMANTIC_TAG_POSTS/$TOTAL_POSTS 篇有具体标签)"
score $B5; B_SCORE=$((B_SCORE + B5)); add_max 4

# B6 llms.txt (3分)
LLMS=$(curl -sL "$BLOG_URL/llms.txt" 2>/dev/null)
B6=0
if [ -n "$LLMS" ] && echo "$LLMS" | grep -q "##"; then
  B6=3; echo "B6 llms.txt: 3/3 ✓"
else
  echo "B6 llms.txt: 0/3 ✗"
fi
score $B6; B_SCORE=$((B_SCORE + B6)); add_max 3

# B7 AI爬虫允许 (3分)
AI_BOTS=$(echo "$ROBOTS" | grep -ci 'GPTBot\|PerplexityBot\|Claude-Web\|Google-Extended')
AI_BOTS=${AI_BOTS:-0}
B7=0
[ "$AI_BOTS" -gt 0 ] 2>/dev/null && B7=3
echo "B7 AI爬虫允许: $B7/3"
score $B7; B_SCORE=$((B_SCORE + B7)); add_max 3

# B8 内部链接 (2分) — 检查 markdown 中指向其他文章的链接
INTERNALLINK_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  ILCOUNT=$(grep -cP '\]\(/20[0-9]{2}/' "$f" 2>/dev/null)
  ILCOUNT=${ILCOUNT:-0}
  [ "$ILCOUNT" -ge 2 ] 2>/dev/null && INTERNALLINK_POSTS=$((INTERNALLINK_POSTS + 1))
done
B8=$((INTERNALLINK_POSTS * 2 / (TOTAL_POSTS > 0 ? TOTAL_POSTS : 1)))
echo "B8 内部链接: $B8/2 ($INTERNALLINK_POSTS/$TOTAL_POSTS 篇有≥2个内链)"
score $B8; B_SCORE=$((B_SCORE + B8)); add_max 2

echo ">> B 小计: $B_SCORE/35"
echo ""

# ================================
# C. 内容权威信号 (20分)
# ================================
echo "=== C. 内容权威信号 (20分) ==="

# C1 外链密度 (6分) — 统计 markdown 链接到外部 URL 的数量
EXTLINK_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  ELCOUNT=$(grep -oP '\]\(https?://[^)]+\)' "$f" 2>/dev/null | wc -l)
  ELCOUNT=${ELCOUNT:-0}
  [ "$ELCOUNT" -ge 5 ] 2>/dev/null && EXTLINK_POSTS=$((EXTLINK_POSTS + 1))
done
C1=$((EXTLINK_POSTS * 6 / 15))
[ "$C1" -gt 6 ] && C1=6
echo "C1 外链密度: $C1/6 ($EXTLINK_POSTS/15 篇有≥5外链)"
score $C1; C_SCORE=$((C_SCORE + C1)); add_max 6

# C2 原创数据标记 (5分)
BENCHMARK_POSTS=$(grep -rl 'TPC-DS\|实测\|benchmark\|DB-Engines' "$POSTS_DIR" 2>/dev/null | wc -l)
BENCHMARK_POSTS=${BENCHMARK_POSTS:-0}
C2=0
if [ "$BENCHMARK_POSTS" -ge 5 ] 2>/dev/null; then
  C2=3; echo "C2 原创数据: 3/5 ($BENCHMARK_POSTS篇有数据，但无Schema标记)"
elif [ "$BENCHMARK_POSTS" -ge 1 ] 2>/dev/null; then
  C2=1; echo "C2 原创数据: 1/5 ($BENCHMARK_POSTS篇)"
else
  echo "C2 原创数据: 0/5"
fi
score $C2; C_SCORE=$((C_SCORE + C2)); add_max 5

# C3 内容更新频率 (4分)
LATEST_DATE=$(cd /root/workspace/hexo-blog && git log -1 --format='%ci' -- source/_posts/ 2>/dev/null | cut -d' ' -f1)
if [ -n "$LATEST_DATE" ]; then
  DAYS_AGO=$(( ($(date +%s) - $(date -d "$LATEST_DATE" +%s 2>/dev/null || echo 0)) / 86400 ))
else
  DAYS_AGO=999
fi
C3=0
if [ "$DAYS_AGO" -le 30 ] 2>/dev/null; then
  C3=4; echo "C3 更新频率: 4/4 ✓ ($DAYS_AGO天前)"
elif [ "$DAYS_AGO" -le 90 ] 2>/dev/null; then
  C3=2; echo "C3 更新频率: 2/4 ⚠ ($DAYS_AGO天前)"
else
  echo "C3 更新频率: 0/4 ✗ ($DAYS_AGO天前)"
fi
score $C3; C_SCORE=$((C_SCORE + C3)); add_max 4

# C4 内容深度 (3分)
AVG_CHARS=$(find "$POSTS_DIR" -name '*.md' -exec wc -m {} + | tail -1 | awk '{print $1}')
AVG_CHARS=${AVG_CHARS:-0}
if [ "$TOTAL_POSTS" -gt 0 ] 2>/dev/null; then
  AVG_CHARS=$((AVG_CHARS / TOTAL_POSTS))
fi
C4=0
if [ "$AVG_CHARS" -ge 3000 ] 2>/dev/null; then
  C4=3; echo "C4 内容深度: 3/3 ✓ (平均${AVG_CHARS}字)"
elif [ "$AVG_CHARS" -ge 1500 ] 2>/dev/null; then
  C4=2; echo "C4 内容深度: 2/3 ⚠ (平均${AVG_CHARS}字)"
else
  C4=1; echo "C4 内容深度: 1/3 ⚠ (平均${AVG_CHARS}字)"
fi
score $C4; C_SCORE=$((C_SCORE + C4)); add_max 3

# C5 专题聚合页 (2分)
echo "C5 专题聚合页: 0/2 ✗"
score 0; C_SCORE=$((C_SCORE + 0)); add_max 2

echo ">> C 小计: $C_SCORE/20"
echo ""

# ================================
# D. 内容资产质量 (15分)
# ================================
echo "=== D. 内容资产质量 (15分) ==="

# D1 高质量内容占比 (5分)
DEEP_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  CHARS=$(wc -m < "$f" 2>/dev/null)
  CHARS=${CHARS:-0}
  [ "$CHARS" -ge 3000 ] 2>/dev/null && DEEP_POSTS=$((DEEP_POSTS + 1))
done
RATIO=0
if [ "$TOTAL_POSTS" -gt 0 ] 2>/dev/null; then
  RATIO=$((DEEP_POSTS * 100 / TOTAL_POSTS))
fi
D1=0
if [ "$RATIO" -ge 50 ] 2>/dev/null; then
  D1=5; echo "D1 高质量占比: 5/5 ✓ ($DEEP_POSTS/$TOTAL_POSTS = ${RATIO}%)"
elif [ "$RATIO" -ge 30 ] 2>/dev/null; then
  D1=3; echo "D1 高质量占比: 3/5 ⚠ ($DEEP_POSTS/$TOTAL_POSTS = ${RATIO}%)"
else
  D1=1; echo "D1 高质量占比: 1/5 ⚠ ($DEEP_POSTS/$TOTAL_POSTS = ${RATIO}%)"
fi
score $D1; D_SCORE=$((D_SCORE + D1)); add_max 5

# D2 薄内容处理 (4分)
THIN_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  CHARS=$(wc -m < "$f" 2>/dev/null)
  CHARS=${CHARS:-0}
  [ "$CHARS" -lt 1000 ] 2>/dev/null && THIN_POSTS=$((THIN_POSTS + 1))
done
NOINDEX_POSTS=0
for f in $(find "$POSTS_DIR" -name '*.md'); do
  head -10 "$f" | grep -q 'noindex' && NOINDEX_POSTS=$((NOINDEX_POSTS + 1))
done
D2=0
if [ "$THIN_POSTS" -eq 0 ] 2>/dev/null; then
  D2=4; echo "D2 薄内容处理: 4/4 ✓ (无薄内容)"
elif [ "$NOINDEX_POSTS" -ge "$THIN_POSTS" ] 2>/dev/null; then
  D2=4; echo "D2 薄内容处理: 4/4 ✓ ($THIN_POSTS篇已noindex)"
else
  D2=$((NOINDEX_POSTS * 4 / (THIN_POSTS > 0 ? THIN_POSTS : 1)))
  echo "D2 薄内容处理: $D2/4 ⚠ ($THIN_POSTS篇薄内容, $NOINDEX_POSTS篇已noindex)"
fi
score $D2; D_SCORE=$((D_SCORE + D2)); add_max 4

# D3 原创性 (3分)
ORIG_POSTS=$(grep -rl 'TPC-DS\|实测\|原创' "$POSTS_DIR" 2>/dev/null | wc -l)
ORIG_POSTS=${ORIG_POSTS:-0}
D3=0
if [ "$ORIG_POSTS" -ge 5 ] 2>/dev/null; then
  D3=3; echo "D3 原创性: 3/3 ✓ ($ORIG_POSTS篇有原创数据)"
elif [ "$ORIG_POSTS" -ge 1 ] 2>/dev/null; then
  D3=2; echo "D3 原创性: 2/3 ⚠ ($ORIG_POSTS篇)"
else
  echo "D3 原创性: 0/3 ✗"
fi
score $D3; D_SCORE=$((D_SCORE + D3)); add_max 3

# D4 内容一致性 (3分)
CATEGORIES=$(grep -rh '^categories:' "$POSTS_DIR" | sort -u | wc -l)
CATEGORIES=${CATEGORIES:-0}
D4=0
if [ "$CATEGORIES" -le 3 ] 2>/dev/null; then
  D4=3; echo "D4 内容一致性: 3/3 ✓ ($CATEGORIES个分类)"
elif [ "$CATEGORIES" -le 5 ] 2>/dev/null; then
  D4=2; echo "D4 内容一致性: 2/3 ⚠ ($CATEGORIES个分类)"
else
  D4=1; echo "D4 内容一致性: 1/3 ⚠ ($CATEGORIES个分类, 主题杂)"
fi
score $D4; D_SCORE=$((D_SCORE + D4)); add_max 3

echo ">> D 小计: $D_SCORE/15"
echo ""

# ================================
# 汇总
# ================================
echo "╔══════════════════════════════════════╗"
echo "║           评 分 汇 总                ║"
echo "╠══════════════════════════════════════╣"
printf "║  A. 技术基础设施:  %2d / 30         ║\n" $A_SCORE
printf "║  B. AI可引用性:    %2d / 35         ║\n" $B_SCORE
printf "║  C. 内容权威信号:  %2d / 20         ║\n" $C_SCORE
printf "║  D. 内容资产质量:  %2d / 15         ║\n" $D_SCORE
echo "╠══════════════════════════════════════╣"
printf "║  总分:             %2d / 100        ║\n" $SCORE
echo "╚══════════════════════════════════════╝"
echo ""
echo "评分等级:"
if [ "$SCORE" -ge 85 ] 2>/dev/null; then
  echo "  🏆 卓越 (85+) — AI 引擎优先引用源"
elif [ "$SCORE" -ge 70 ] 2>/dev/null; then
  echo "  🟢 良好 (70-84) — AI 引擎可发现并引用"
elif [ "$SCORE" -ge 50 ] 2>/dev/null; then
  echo "  🟡 中等 (50-69) — 基础设施达标，内容需优化"
elif [ "$SCORE" -ge 30 ] 2>/dev/null; then
  echo "  🟠 不足 (30-49) — 基础设施有严重缺陷"
else
  echo "  🔴 严重不足 (<30) — AI 引擎几乎不可见"
fi
echo ""
echo "建议下一步:"
if [ $A1 -eq 0 ] 2>/dev/null; then
  echo "  [紧急] 修复域名一致性 (_config.yml url → github.io)"
elif [ $A2 -lt 3 ] 2>/dev/null; then
  echo "  [高] 创建/完善 robots.txt (含 AI 爬虫声明)"
elif [ $A3 -lt 4 ] 2>/dev/null; then
  echo "  [高] 注入 JSON-LD 结构化数据"
elif [ $B1 -lt 4 ] 2>/dev/null; then
  echo "  [高] 为技术文章添加 FAQ 段落"
elif [ $B2 -lt 3 ] 2>/dev/null; then
  echo "  [中] 为所有文章补充 description"
elif [ $C1 -lt 3 ] 2>/dev/null; then
  echo "  [中] 为技术文章补充外链到权威源"
elif [ $B5 -lt 2 ] 2>/dev/null; then
  echo "  [中] 精细化标签（AI → 具体技术名）"
else
  echo "  持续优化中，关注外部引用指标"
fi
