module ProfilesHelper
  def render_markdown(content)
    return "" if content.blank?

    # Render markdown to HTML using GitHub-flavored markdown
    html = Commonmarker.to_html(content,
      plugins: { syntax_highlighter: nil },
      options: {
        parse: { smart: true },
        render: { unsafe: true } # Allow raw HTML (we'll sanitize it ourselves)
      }
    )

    # Sanitize HTML but allow safe tags including images
    sanitize(html, tags: %w[
      p br strong em b i u a img h1 h2 h3 h4 h5 h6
      ul ol li blockquote pre code hr div span
      table thead tbody tr th td
    ], attributes: %w[
      href src alt title class id width height
      align border cellpadding cellspacing
    ]).html_safe
  end
end
