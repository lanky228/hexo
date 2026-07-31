{# SEO + GEO Enhancement — JSON-LD only, canonical/OG handled by NexT theme #}
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "name": "Lanky的技术博客",
  "url": "{{ config.url }}",
  "description": "{{ config.description }}",
  "inLanguage": "zh-CN"
}
</script>

{% if page.title %}
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "{{ page.title }}",
  "datePublished": "{{ page.date }}",
  "url": "{{ config.url }}/{{ page.path }}",
  "inLanguage": "zh-CN"
}
</script>

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "首页", "item": "{{ config.url }}" },
    { "@type": "ListItem", "position": 2, "name": "{{ page.title }}", "item": "{{ config.url }}/{{ page.path }}" }
  ]
}
</script>
{% endif %}
