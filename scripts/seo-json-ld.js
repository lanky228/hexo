'use strict';

/**
 * SEO + GEO Enhancement Script
 * 
 * Injects FAQPage JSON-LD structured data for posts containing FAQ sections.
 * Also adds meta description tags and Open Graph enhancements.
 */

hexo.extend.filter.register('after_post_render', function(data) {
  if (!data.content) return data;

  // Extract FAQ Q&A pairs from rendered content
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

    // Inject FAQ schema as a script tag at the end of content
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
