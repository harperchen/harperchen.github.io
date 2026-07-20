/**
 * Pandoc wraps long math across lines inside <span class="math ...">.
 * Collapse that whitespace so MathJax can parse \(...\) / \[...\] reliably.
 */
hexo.extend.filter.register('after_post_render', function (data) {
  if (!data.content || data.content.indexOf('class="math') === -1) {
    return data;
  }

  data.content = data.content.replace(
    /<span class="math (inline|display)">([\s\S]*?)<\/span>/g,
    function (_match, kind, inner) {
      return '<span class="math ' + kind + '">' + inner.replace(/\s+/g, ' ').trim() + '</span>';
    }
  );

  return data;
});
