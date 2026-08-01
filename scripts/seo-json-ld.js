'use strict';

/**
 * SEO + GEO Enhancement Script
 * 
 * Injects JSON-LD structured data:
 * - BlogPosting schema (author, description, keywords, dates) — in post content
 * - FAQPage schema (auto-extracted from Q&A format) — in post content
 * - Auto-generates meta description from excerpt
 */

// Inject BlogPosting + FAQPage JSON-LD
hexo.extend.filter.register('after_post_render', function(data) {
  if (!data.content) return data;

  var config = hexo.config;
  var baseUrl = config.url.replace(/\/$/, '');
  var postUrl = baseUrl + '/' + data.path;

  // --- BlogPosting JSON-LD ---
  var schema = {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": data.title,
    "author": {
      "@type": "Person",
      "name": config.author,
      "url": baseUrl
    },
    "publisher": {
      "@type": "Person",
      "name": config.author,
      "url": baseUrl
    },
    "datePublished": data.date ? data.date.format('YYYY-MM-DD') : '',
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": postUrl
    },
    "url": postUrl,
    "inLanguage": "zh-CN"
  };

  if (data.updated) {
    schema.dateModified = data.updated.format('YYYY-MM-DD');
  }

  if (data.description) {
    schema.description = data.description;
  }

  // Extract tag names for keywords
  if (data.tags && data.tags.length) {
    var tagNames = [];
    data.tags.forEach(function(tag) {
      if (tag && tag.name) tagNames.push(tag.name);
    });
    if (tagNames.length > 0) {
      schema.keywords = tagNames;
    }
  }

  data.content += '\n<script type="application/ld+json">' + JSON.stringify(schema) + '</script>\n';

  // --- FAQPage JSON-LD ---
  var faqPairs = [];
  var faqRegex = /<strong>\s*[QＱ][:：]\s*(.*?)\s*<\/strong>\s*(?:<br\s*\/?>)?\s*<p>(.*?)<\/p>|<strong>\s*[QＱ][:：]\s*(.*?)\s*<\/strong>\s*(.*?)(?=<strong>|$)/gs;
  var match;
  while ((match = faqRegex.exec(data.content)) !== null) {
    var q = (match[1] || match[3] || '').replace(/<[^>]+>/g, '').trim();
    var a = (match[2] || match[4] || '').replace(/<[^>]+>/g, '').trim();
    if (q && a) {
      faqPairs.push({ q: q, a: a });
    }
  }

  // Also check for markdown-style Q&A (before render)
  if (faqPairs.length === 0 && data.raw) {
    var rawFaqRegex = /\*\*[QＱ][:：]\s*(.*?)\*\*[\s\S]*?(?=\*\*[QＱ]|$)/g;
    while ((match = rawFaqRegex.exec(data.raw)) !== null) {
      var question = match[1].trim();
      var answer = match[0].replace(/\*\*[QＱ][:：].*?\*\*/, '').trim();
      if (question && answer) {
        faqPairs.push({ q: question, a: answer });
      }
    }
  }

  if (faqPairs.length >= 2) {
    var faqSchema = {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": faqPairs.map(function(pair) {
        return {
          "@type": "Question",
          "name": pair.q,
          "acceptedAnswer": {
            "@type": "Answer",
            "text": pair.a
          }
        };
      })
    };

    data.content += '\n<script type="application/ld+json">' + JSON.stringify(faqSchema) + '</script>\n';
  }

  return data;
});

// Add meta description if not set
hexo.extend.filter.register('before_post_render', function(data) {
  if (!data.description && data.excerpt) {
    // Auto-generate description from excerpt
    var stripped = data.excerpt.replace(/<[^>]+>/g, '').replace(/[#>*]/g, '').trim();
    if (stripped.length > 20) {
      data.description = stripped.substring(0, 160);
    }
  }
  return data;
});
