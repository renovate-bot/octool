# frozen_string_literal: true

module OCTool
    # Representation of a system
    class System
        attr_accessor :config
        attr_accessor :data

        TABLE_NAMES = [
            'components',
            'satisfies',
            'attestations',
            'standards',
            'controls',
            'families',
            'certifications',
            'requires',
        ].freeze

        def initialize(config)
            @config = config
            @data = []
        end

        def acronyms
            @acronyms ||= config['acronyms']
        end

        def certifications
            @certifications ||= data.select { |e| e['type'] == 'certification' }
        end

        def components
            @components ||= data.select { |e| e['type'] == 'component' }
        end

        def standards
            @standards ||= data.select { |e| e['type'] == 'standard' }
        end

        # List of all attestations claimed by components in the system.
        def attestations
            @attestations ||= components.map { |c| c['attestations'] }.flatten
        end

        # List of all coverages.
        def satisfies
            @satisfies ||= attestations.map { |a| a['satisfies'] }.flatten
        end

        # List of all controls defined by standards in the system.
        def controls
            @controls ||= standards.map { |s| s['controls'] }.flatten
        end

        # List of all families defined by standards in the system.
        def families
            @families ||= standards.map { |s| s['families'] }.flatten
        end

        # List of required controls for all certifications.
        def requires
            @requires ||= certifications.map { |c| c['requires'] }.flatten
        end

        def dump(writable_dir)
            TABLE_NAMES.each do |table|
                write_csv method(table.to_sym).call, File.join(writable_dir, "#{table}.csv")
            end
        end

        # Convert array of hashes into a CSV.
        def write_csv(ary, filename)
            # Throw away nested hashes. The parser already created separate tables for them.
            ary = ary.map { |e| e.reject { |_, val| val.is_a?(Enumerable) } }

            warn "[INFO] write #{filename}"
            CSV.open(filename, 'wb') do |csv|
                column_names = ary.first.keys
                csv << column_names
                ary.each { |hash| csv << hash.values_at(*column_names) }
            end
        end
    end
end
