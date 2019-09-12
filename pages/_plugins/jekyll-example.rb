require 'htmlbeautifier'

module Jekyll
  module Tags
    class ExampleBlock < Liquid::Block
      include Liquid::StandardFilters

      SYNTAX = /^([a-zA-Z0-9.+#-]+)((\s+[\w-]+(=((\w|[0-9_-])+|"([0-9]+\s)*[0-9]+"))?)*)$/

      def initialize(tag_name, markup, tokens)
        super
        if markup.strip == ""
          markup = 'html'
        end

        if markup.strip =~ SYNTAX
          @lang = $1.downcase
          @options = {}
          if defined?($2) && $2 != ''
            # Split along 3 possible forms -- key="<quoted list>", key=value, or key
            $2.scan(/(?:[\w-]+(?:=(?:(?:\w|[0-9_-])+|"[^"]*")?)?)/) do |opt|
              key, value = opt.split('=')
              # If a quoted list, convert to array
              if value && value.include?("\"")
                value.gsub!(/"/, "")
                value = value.split
              end
              @options[key.to_sym] = value || true
            end
          end
          @options[:linenos] = false
        else
          raise SyntaxError.new <<-eos
Syntax Error in tag 'example' while parsing the following markup:

  #{markup}

Valid syntax: example <lang> [id=foo]
          eos
        end
      end

      def render(context)
        prefix = context["highlighter_prefix"] || ""
        suffix = context["highlighter_suffix"] || ""
        code = super.to_s.strip

        output = case context.registers[:site].highlighter

                 when 'rouge'
                   render_rouge(code)
                 end

        # output = HtmlBeautifier.beautify(output, indent: "\t")

        rendered_output = example(code) + add_code_tag(output)
        prefix + rendered_output + suffix
      end

      def example(output)
        output = output.gsub(/<hide>/, "").gsub(/<\/hide>/, "")

        "<div class=\"example" + (@options[:columns] ? " example-bg" : "") + "\"" + (@options[:id] ? " data-example-id=\"#{@options[:id]}\"" : "") + ">\n" + (@options[:columns] ? "<div class=\"example-column example-column-" + @options[:columns] + "\">\n" : "") + (@options[:wrapper] ? "<div class=\"" + @options[:wrapper] + "\">\n" : "") + (@options[:"max-width"] ? "<div style=\"max-width: " + @options[:"max-width"] + "px; margin: 0 auto;\">\n" : "") + "#{output}" + (@options[:wrapper] ? "\n</div>" : "") + (@options[:columns] ? "\n</div>" : "") + (@options[:"max-width"] ? "\n</div>" : "") + "\n</div>"
      end

      def remove_example_classes(code)
        # Find `bd-` classes and remove them from the highlighted code. Because of how this regex works, it will also
        # remove classes that are after the `bd-` class. While this is a bug, I left it because it can be helpful too.
        # To fix the bug, replace `(?=")` with `(?=("|\ ))`.
        code = code.gsub(/(?!class=".)\ *?bd-.+?(?=")/, "")
        # Find empty class attributes after the previous regex and remove those too.
        code = code.gsub(/\ class=""/, "")
      end

      def render_rouge(code)
        require 'rouge'
        formatter = Rouge::Formatters::HTML.new(line_numbers: @options[:linenos], wrap: false)
        lexer = Rouge::Lexer.find_fancy(@lang, code) || Rouge::Lexers::PlainText
        code = remove_example_classes(code)
        code = code.gsub(/<hide>.*?<\/hide>/, "")
        code = formatter.format(lexer.lex(code))
        code = code.strip.gsub /^[\t\s]*$\n/, ''
        code = code.gsub /\t/, "\s\s"
        code = code.gsub "javascript:void(0)", "#"
        code = code.gsub "../", "./"
        "<div class=\"highlight\"><pre>#{code}</pre></div>"
      end

      def add_code_tag(code)
        # Add nested <code> tags to code blocks
        code = code.sub(/<pre>\n*/, '<pre><code class="language-' + @lang.to_s.gsub("+", "-") + '" data-lang="' + @lang.to_s + '">')
        code = code.sub(/\n*<\/pre>/, "</code></pre>")
        code.strip
      end

    end
  end
end

Liquid::Template.register_tag('example', Jekyll::Tags::ExampleBlock)
