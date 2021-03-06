# frozen_string_literal: true

require 'date'
require 'erb'

module OCTool
    # Build DB, CSV, and markdown.
    class SSP
        attr_reader :build_date
        attr_reader :version

        def initialize(system, output_dir)
            @system = system
            @output_dir = output_dir
            @template_name = 'ssp'
            @version = OCTool::DEFAULT_SSP_VERSION
            @build_date = DateTime.now
        end

        def version=(version)
            # LaTeX fancyheader aborts on underscore in footer.
            @version = version.to_s.gsub(/_+/, ' ')
        end

        def pandoc
            @pandoc ||= begin
                # Load paru/pandoc late enough that help functions work
                # and early enough to be confident that we catch the correct error.
                require 'paru/pandoc'
                Paru::Pandoc.new
            end
        rescue UncaughtThrowError
            warn '[FAIL] octool requires pandoc to generate the SSP. Is pandoc installed?'
            exit(1)
        end

        def generate(version = nil, template_name = 'ssp')
            self.version = version if version
            @template_name = template_name if template_name
            unless File.writable?(@output_dir)
                warn "[FAIL] #{@output_dir} is not writable"
                exit(1)
            end
            render_template
            write_acronyms
            write 'pdf'
            write 'docx'
        end

        def render_template
            print "Building markdown #{md_path} ... "
            template = File.read(template_path)
            output = ERB.new(template, nil, '-').result(binding)
            File.open(md_path, 'w') { |f| f.puts output }
            puts 'done'
        end

        def write_acronyms
            return unless @system.acronyms

            out_path = File.join(@output_dir, 'acronyms.json')
            File.open(out_path, 'w') { |f| f.write JSON.pretty_generate(@system.acronyms) }
            ENV['PANDOC_ACRONYMS_ACRONYMS'] = out_path
        end

        # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        def write(type = 'pdf')
            out_path = File.join(@output_dir, "#{@template_name}.#{type}")
            print "Building #{out_path} ... "
            converter = pandoc.configure do
                from 'markdown+autolink_bare_uris'
                to type
                pdf_engine 'lualatex'
                highlight_style 'pygments'
                filter 'pandoc-acronyms' if ENV['PANDOC_ACRONYMS_ACRONYMS']
                # https://en.wikibooks.org/wiki/LaTeX/Source_Code_Listings#Encoding_issue
                # Uncomment the following line after the "listings" package is compatible with utf8
                # listings
            end
            output = converter << File.read(md_path)
            File.new(out_path, 'wb').write(output)
            puts 'done'
        end
        # rubocop:enable Metrics/AbcSize,Metrics/MethodLength

        def md_path
            File.join(@output_dir, "#{@template_name}.md")
        end

        def template_path
            File.join(ERB_DIR, "#{@template_name}.erb")
        end
    end
end
